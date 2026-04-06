"""
Full RASP pipeline — domain.yaml → WPS → WRF → windgrams.

Single entry point that runs the entire forecast pipeline:
1. Generate namelists from domain config
2. Download GRIB data (or use pre-provided)
3. Run WPS (geogrid, ungrib, metgrid)
4. Run WRF (real.exe, wrf.exe)
5. Render windgrams for all sites

Usage:
    python -m rasp.pipeline domain.yaml --sites sites.csv --output-dir ./output
    python -m rasp.pipeline domain.yaml --date 2026-04-06 --cycle 00 --sites sites.csv
"""

import argparse
import math
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

from .namelist_generator import generate_namelists, load_domain_config, MODELS
from .windgram import render_windgram


def _run(cmd, desc, cwd=None):
    """Run a shell command, stream output, raise on failure."""
    print(f"\n{'='*60}")
    print(f"  {desc}")
    print(f"{'='*60}\n", flush=True)
    result = subprocess.run(
        cmd, shell=True, cwd=cwd,
        stdout=sys.stdout, stderr=sys.stderr,
    )
    if result.returncode != 0:
        print(f"\nERROR: {desc} failed (exit {result.returncode})")
        sys.exit(result.returncode)


def _run_exe(args, desc, cwd):
    """Run an executable (not shell), stream output, raise on failure."""
    print(f"  {desc}...", flush=True)
    result = subprocess.run(
        args, cwd=cwd,
        stdout=sys.stdout, stderr=sys.stderr,
    )
    if result.returncode != 0:
        print(f"\n  ERROR: {desc} failed (exit {result.returncode})")
        sys.exit(result.returncode)
    return result.returncode


def _download_grib(model_cfg, date, cycle, fhours, dest_dir):
    """Download GRIB files using the model's URL pattern."""
    print(f"\n{'='*60}")
    print(f"  Downloading GRIB data ({model_cfg['name']})")
    print(f"{'='*60}\n", flush=True)

    Path(dest_dir).mkdir(parents=True, exist_ok=True)
    date_compact = date.replace("-", "")
    url_pattern = model_cfg["url_pattern"]

    downloaded = 0
    for fhr in fhours:
        url = url_pattern.format(
            date=date_compact, cycle=f"{int(cycle):02d}", fhr=fhr
        )
        fname = url.split("/")[-1]
        dest = Path(dest_dir) / fname

        if dest.exists() and dest.stat().st_size > 1_000_000:
            print(f"  {fname}: cached ({dest.stat().st_size // 1_000_000}MB)")
            downloaded += 1
            continue

        print(f"  Downloading {fname}...", flush=True)
        success = False
        for attempt in range(1, 4):
            result = subprocess.run(
                ["curl", "--http1.1", "-fsSL", "--retry", "2", "--retry-delay", "5",
                 "--progress-bar", url, "-o", str(dest)],
                stdout=sys.stdout, stderr=sys.stderr,
            )
            if result.returncode == 0 and dest.exists() and dest.stat().st_size > 1_000_000:
                print(f"  {fname}: OK ({dest.stat().st_size // 1_000_000}MB)")
                success = True
                downloaded += 1
                break
            print(f"  Attempt {attempt} failed, retrying in 10s...")
            if dest.exists():
                dest.unlink()
            time.sleep(10)

        if not success:
            print(f"  ERROR: {fname} download failed after 3 attempts")
            sys.exit(1)

    print(f"\n  Downloaded {downloaded}/{len(fhours)} files to {dest_dir}")


def _detect_latest_cycle(model, date=None):
    """Auto-detect the latest available cycle from NOMADS.

    Returns (date_str, cycle_str) e.g. ("2026-04-06", "06").
    """
    if date is None:
        date = datetime.utcnow().strftime("%Y-%m-%d")

    date_compact = date.replace("-", "")
    model_cfg = MODELS[model]

    if model_cfg.get("source") != "nomads":
        return date, "00"

    # Try each known cycle (newest first) and check if a sample file exists
    url_pattern = model_cfg["url_pattern"]
    known_cycles = sorted(model_cfg.get("cycles", [0, 6, 12, 18]), reverse=True)

    for try_date in [date, (datetime.strptime(date, "%Y-%m-%d") - timedelta(days=1)).strftime("%Y-%m-%d")]:
        dc = try_date.replace("-", "")
        for cyc in known_cycles:
            # Check if a low forecast hour file exists (fhr 3 as probe)
            probe_url = url_pattern.format(date=dc, cycle=f"{cyc:02d}", fhr=3)
            try:
                result = subprocess.run(
                    ["curl", "--http1.1", "-sfI", "--max-time", "5", probe_url],
                    capture_output=True, text=True, timeout=8
                )
                if result.returncode == 0 and "200" in (result.stdout + result.stderr):
                    print(f"  Auto-detected latest cycle: {try_date} {cyc:02d}z")
                    return try_date, f"{cyc:02d}"
            except Exception:
                continue

    print(f"  WARNING: Could not detect cycles, defaulting to {date} 00z")
    return date, "00"


def _utc_offset_from_lon(lon):
    """Estimate UTC offset from longitude (rough, ignores DST)."""
    # -122 → -8 (PST), -121 → -8, etc.
    # Add 1 for daylight savings (rough approximation for North America in summer)
    offset = round(lon / 15)
    # Assume DST for simplicity (April-October)
    offset += 1
    return offset


def run_pipeline(config_path, date=None, cycle=None, sites_csv=None,
                 output_dir="./output", grib_dir=None, geog_path="/mnt/geog",
                 basedir="/opt/rasp", num_procs=1, utc_offset=None, start_hour=8):
    """Run the full forecast pipeline."""
    config = load_domain_config(config_path)
    model = config["model"]
    model_cfg = MODELS[model]

    # Auto-detect UTC offset from domain center longitude
    if utc_offset is None:
        utc_offset = _utc_offset_from_lon(config["center_lon"])
        print(f"  UTC offset: {utc_offset} (from center lon {config['center_lon']:.1f})")

    # Auto-detect latest cycle if not provided
    if date is None or cycle is None:
        auto_date, auto_cycle = _detect_latest_cycle(model, date)
        if date is None:
            date = auto_date
        if cycle is None:
            cycle = auto_cycle

    # Compute forecast hours needed to cover the soaring window.
    # Soaring window in UTC: (12 - utc_offset)z to (20 - utc_offset)z
    # e.g. PDT (offset=-7): 8am=15z, 8pm=03z next day
    target_start_local = 8   # 8am local
    target_end_local = 20    # 8pm local
    target_start_utc = target_start_local - utc_offset
    target_end_utc = target_end_local - utc_offset

    base_dt = datetime.strptime(f"{date}_{cycle}", "%Y-%m-%d_%H")
    cycle_hour = int(cycle)

    interval_hours = model_cfg["interval_seconds"] // 3600
    fhr_start = target_start_utc - cycle_hour
    fhr_end = target_end_utc - cycle_hour
    if fhr_start < 0:
        fhr_start += 24
        fhr_end += 24
    fhr_start = max(fhr_start, 3)
    download_fhours = list(range(fhr_start, fhr_end + 1, interval_hours))

    start_dt = base_dt + timedelta(hours=download_fhours[0])
    end_dt = base_dt + timedelta(hours=download_fhours[-1])
    start_valid = start_dt.strftime("%Y-%m-%d_%H")
    end_valid = end_dt.strftime("%Y-%m-%d_%H")
    run_hours = download_fhours[-1] - download_fhours[0]
    interval_seconds = model_cfg["interval_seconds"]

    # Directories
    wps_dir = f"{basedir}/wps"
    run_dir = f"{basedir}/runs/{config['name']}"
    scripts_dir = f"{basedir}/scripts"

    # Resolve paths before any chdir
    if sites_csv:
        sites_csv = str(Path(sites_csv).resolve())
    config_path = str(Path(config_path).resolve())
    output_dir = str(Path(output_dir).resolve())

    print(f"\n  Pipeline: {config['name']}")
    print(f"  Model: {model.upper()}, Date: {date} {cycle}z")
    print(f"  Valid: {start_valid} to {end_valid} ({run_hours}h)")
    print(f"  UTC offset: {utc_offset}")
    print(f"  WPS dir: {wps_dir}")
    print(f"  Run dir: {run_dir}", flush=True)

    # ── Step 1: Generate namelists ──────────────────────────────────────
    result = generate_namelists(
        config_path, date, cycle,
        output_dir=wps_dir,
        geog_path=geog_path,
        start_date=start_valid,
        end_date=end_valid,
        run_hours=run_hours,
    )

    # Also copy namelist.input to the WRF run dir
    Path(run_dir).mkdir(parents=True, exist_ok=True)
    shutil.copy(f"{wps_dir}/namelist.input", f"{run_dir}/namelist.input")

    # ── Step 2: Download GRIB ───────────────────────────────────────────
    if grib_dir is None:
        grib_dir = f"{basedir}/grib"
        _download_grib(model_cfg, date, cycle, download_fhours, grib_dir)

    # ── Step 3: Run WPS (geogrid → ungrib → metgrid) ───────────────────
    print(f"\n{'='*60}")
    print(f"  Running WPS")
    print(f"{'='*60}\n", flush=True)

    os.chdir(wps_dir)

    # 3a. geogrid
    if not Path(f"{wps_dir}/geo_em.d01.nc").exists():
        _run_exe(["./geogrid.exe"], "geogrid", cwd=wps_dir)
        print(f"  geogrid: OK")
    else:
        print(f"  geogrid: cached (geo_em files exist)")

    # 3b. Link GRIB files
    for f in Path(wps_dir).glob("GRIBFILE.*"):
        f.unlink()
    grib_files = sorted(Path(grib_dir).glob("*.grib2"))
    if not grib_files:
        print(f"  ERROR: No GRIB2 files found in {grib_dir}")
        sys.exit(1)
    for i, f in enumerate(grib_files):
        c1 = chr(65 + i // 676)
        c2 = chr(65 + (i % 676) // 26)
        c3 = chr(65 + i % 26)
        link = Path(wps_dir) / f"GRIBFILE.{c1}{c2}{c3}"
        link.symlink_to(f)
    print(f"  Linked {len(grib_files)} GRIB files")

    # 3c. Link Vtable
    vtable_name = model_cfg["vtable"]
    vtable_src = Path(wps_dir) / "Variable_Tables" / vtable_name
    vtable_dst = Path(wps_dir) / "Vtable"
    if vtable_dst.exists() or vtable_dst.is_symlink():
        vtable_dst.unlink()
    vtable_dst.symlink_to(vtable_src)
    print(f"  Vtable: {vtable_name}")

    # 3d. ungrib
    _run_exe(["./ungrib.exe"], "ungrib", cwd=wps_dir)
    file_count = len(list(Path(wps_dir).glob("FILE:*")))
    print(f"  ungrib: OK ({file_count} intermediate files)")

    # 3e. metgrid
    _run_exe(["./metgrid.exe"], "metgrid", cwd=wps_dir)
    met_files = sorted(Path(wps_dir).glob("met_em.d0*.nc"))
    print(f"  metgrid: OK ({len(met_files)} met_em files)")
    for f in met_files:
        print(f"    {f.name}")

    # ── Step 4: Run WRF (real.exe → wrf.exe) ───────────────────────────
    print(f"\n{'='*60}")
    print(f"  Running WRF ({run_hours}h, {num_procs} procs)")
    print(f"{'='*60}\n", flush=True)

    run_path = Path(run_dir)
    run_path.mkdir(parents=True, exist_ok=True)
    os.chdir(run_dir)

    # Link met_em files
    for f in met_files:
        dst = run_path / f.name
        if dst.exists() or dst.is_symlink():
            dst.unlink()
        dst.symlink_to(f)
    print(f"  Linked {len(met_files)} met_em files")

    # Link WRF run tables
    wrf_run_dir = Path(f"{basedir}/run")
    if wrf_run_dir.exists():
        for f in wrf_run_dir.iterdir():
            dst = run_path / f.name
            if not dst.exists():
                dst.symlink_to(f)

    # Link executables
    for exe in ["real.exe", "wrf.exe", "ndown.exe"]:
        src = Path(f"{basedir}/bin/{exe}")
        dst = run_path / exe
        if dst.exists() or dst.is_symlink():
            dst.unlink()
        if src.exists():
            dst.symlink_to(src)

    # Auto-detect num_metgrid_levels from met_em
    met_sample = met_files[0] if met_files else None
    if met_sample:
        try:
            r = subprocess.run(
                f"ncdump -h {met_sample} | awk '/num_metgrid_levels =/ {{print $3+0; exit}}'",
                shell=True, capture_output=True, text=True
            )
            nml = int(r.stdout.strip())
            nl_path = run_path / "namelist.input"
            nl_text = nl_path.read_text()
            nl_text = re.sub(
                r'num_metgrid_levels\s*=\s*\d+',
                f'num_metgrid_levels = {nml}',
                nl_text
            )
            nl_path.write_text(nl_text)
            print(f"  num_metgrid_levels: {nml}")
        except Exception as e:
            print(f"  WARNING: Could not detect num_metgrid_levels: {e}")

    # 4a. real.exe
    if num_procs > 1:
        _run_exe(["mpirun", "--allow-run-as-root", "--oversubscribe", "-np", "1", "./real.exe"],
                 "real.exe", cwd=run_dir)
    else:
        _run_exe(["./real.exe"], "real.exe", cwd=run_dir)

    if not (run_path / "wrfinput_d01").exists():
        print("  ERROR: real.exe failed — no wrfinput_d01")
        rsl = run_path / "rsl.error.0000"
        if rsl.exists():
            print(rsl.read_text()[-500:])
        sys.exit(1)
    print(f"  real.exe: OK")

    # 4b. wrf.exe — cap procs at available CPUs inside container
    try:
        avail = len(os.sched_getaffinity(0))
    except AttributeError:
        avail = os.cpu_count() or 4
    if num_procs > avail:
        print(f"  Note: capping MPI procs from {num_procs} to {avail} (container limit)")
        num_procs = avail

    t0 = time.time()
    if num_procs > 1:
        _run_exe(["mpirun", "--allow-run-as-root", "--oversubscribe", "-np", str(num_procs), "./wrf.exe"],
                 f"wrf.exe ({num_procs} procs)", cwd=run_dir)
    else:
        _run_exe(["./wrf.exe"], "wrf.exe", cwd=run_dir)
    elapsed = time.time() - t0
    print(f"  wrf.exe: completed in {int(elapsed//60)}m {int(elapsed%60)}s")

    # Check wrf.exe output
    wrfout_files = sorted(run_path.glob("wrfout_d*"))
    if not wrfout_files:
        print("  ERROR: wrf.exe produced no output")
        rsl = run_path / "rsl.error.0000"
        if rsl.exists():
            print(rsl.read_text()[-500:])
        sys.exit(1)
    print(f"  wrfout files: {len(wrfout_files)}")
    for f in wrfout_files:
        size_mb = f.stat().st_size / 1e6
        print(f"    {f.name} ({size_mb:.0f}MB)")

    # Copy wrfout to output if /mnt/wrfout is available
    wrfout_mount = Path("/mnt/wrfout")
    if wrfout_mount.exists() and os.access(str(wrfout_mount), os.W_OK):
        for f in wrfout_files:
            shutil.copy(str(f), str(wrfout_mount / f.name))
        print(f"  Copied wrfout to {wrfout_mount}")

    # ── Step 5: Render windgrams ────────────────────────────────────────
    print(f"\n{'='*60}")
    print(f"  Rendering windgrams")
    print(f"{'='*60}\n", flush=True)

    finest_wrfout = str(wrfout_files[-1])
    print(f"  Source: {finest_wrfout}")

    sites = _load_sites(sites_csv) if sites_csv else []
    if not sites:
        print("  No sites provided — skipping windgram rendering")
        print(f"  Render manually: python -m rasp.windgram {finest_wrfout} --lat LAT --lon LON --site NAME")
        return

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    rendered = 0
    for name, lat, lon in sites:
        try:
            render_windgram(finest_wrfout, lat, lon, name, str(output_path),
                            utc_offset=utc_offset, start_hour=start_hour)
            rendered += 1
        except Exception as e:
            print(f"  WARNING: {name} failed: {e}")

    print(f"\n{'='*60}")
    print(f"  Pipeline complete!")
    print(f"  Rendered {rendered}/{len(sites)} windgrams to {output_path}/")
    print(f"{'='*60}\n")


def _load_sites(csv_path):
    """Load site definitions from a CSV file."""
    if csv_path is None:
        return []
    path = Path(csv_path)
    if not path.exists():
        print(f"WARNING: Sites file not found: {csv_path}")
        return []
    sites = []
    for line in path.read_text().strip().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.replace(",", " ").split()
        if len(parts) >= 3:
            try:
                sites.append((parts[0], float(parts[1]), float(parts[2])))
            except ValueError:
                print(f"WARNING: Skipping invalid site: {line}")
    return sites


def main():
    parser = argparse.ArgumentParser(
        description="Run the full RASP forecast pipeline"
    )
    parser.add_argument("config", help="Path to domain.yaml")
    parser.add_argument("--date", help="Forecast date YYYY-MM-DD (default: auto-detect)")
    parser.add_argument("--cycle", help="Model cycle HH (default: auto-detect latest)")
    parser.add_argument("--sites", help="CSV file with sites (name lat lon)")
    parser.add_argument("--output-dir", default="./output", help="Output directory")
    parser.add_argument("--grib-dir", help="Directory with GRIB2 files")
    parser.add_argument("--geog-path", default="/mnt/geog", help="GEOG data path")
    parser.add_argument("--num-procs", type=int, default=1, help="MPI processes")
    parser.add_argument("--utc-offset", type=int, help="UTC offset (default: auto from domain center)")
    parser.add_argument("--start-hour", type=int, default=8, help="Earliest local hour to show")
    args = parser.parse_args()

    run_pipeline(
        args.config,
        date=args.date,
        cycle=args.cycle,
        sites_csv=args.sites,
        output_dir=args.output_dir,
        grib_dir=args.grib_dir,
        geog_path=args.geog_path,
        num_procs=args.num_procs,
        utc_offset=args.utc_offset,
        start_hour=args.start_hour,
    )


if __name__ == "__main__":
    main()
