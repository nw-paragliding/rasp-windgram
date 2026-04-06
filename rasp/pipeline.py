"""
Full RASP pipeline — domain.yaml → WPS → WRF → windgrams.

Single entry point that runs the entire forecast pipeline:
1. Generate namelists from domain config
2. Download GRIB data (or use pre-provided)
3. Run WPS (geogrid, ungrib, metgrid)
4. Run WRF (real.exe, wrf.exe)
5. Render windgrams for all sites

Usage:
    python -m rasp.pipeline domain.yaml --date 2026-04-01 --cycle 06 \\
        --sites sites.csv --output-dir ./output
"""

import argparse
import os
import shutil
import subprocess
import sys
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


def run_pipeline(config_path, date, cycle, sites_csv=None, output_dir="./output",
                 grib_dir=None, geog_path="/mnt/geog", basedir="/opt/rasp",
                 num_procs=1, utc_offset=-7, start_hour=8):
    """Run the full forecast pipeline."""
    config = load_domain_config(config_path)
    model = config["model"]
    model_cfg = MODELS[model]

    # Compute forecast hours needed to cover the soaring window.
    # Target: 15z-03z (8am-8pm PDT) on the day AFTER the cycle date.
    # This adapts to whichever cycle you use.
    base_dt = datetime.strptime(f"{date}_{cycle}", "%Y-%m-%d_%H")
    cycle_hour = int(cycle)

    # Soaring window: 15z to 03z next day (8am-8pm PDT)
    target_start_utc = 15  # 8am PDT
    target_end_utc = 27    # 8pm PDT = 03z next day

    # Forecast hours needed
    interval_hours = model_cfg["interval_seconds"] // 3600
    fhr_start = target_start_utc - cycle_hour
    fhr_end = target_end_utc - cycle_hour
    if fhr_start < 0:
        fhr_start += 24
        fhr_end += 24
    # Ensure minimum 3h lead time (models need spin-up)
    fhr_start = max(fhr_start, 3)
    download_fhours = list(range(fhr_start, fhr_end + 1, interval_hours))

    start_dt = base_dt + timedelta(hours=download_fhours[0])
    end_dt = base_dt + timedelta(hours=download_fhours[-1])
    start_valid = start_dt.strftime("%Y-%m-%d_%H")
    end_valid = end_dt.strftime("%Y-%m-%d_%H")
    run_hours = download_fhours[-1] - download_fhours[0]
    interval_seconds = model_cfg["interval_seconds"]

    # Directories
    wps_dir = f"{basedir}/wps"       # WPS executables + working dir
    run_dir = f"{basedir}/runs/{config['name']}"  # WRF working dir
    scripts_dir = f"{basedir}/scripts"

    # Resolve paths before any chdir
    if sites_csv:
        sites_csv = str(Path(sites_csv).resolve())
    config_path = str(Path(config_path).resolve())
    output_dir = str(Path(output_dir).resolve())

    print(f"\n  Pipeline: {config['name']}")
    print(f"  Model: {model.upper()}, Date: {date} {cycle}z")
    print(f"  Valid: {start_valid} to {end_valid} ({run_hours}h)")
    print(f"  WPS dir: {wps_dir}")
    print(f"  Run dir: {run_dir}", flush=True)

    # ── Step 1: Generate namelists ──────────────────────────────────────
    result = generate_namelists(
        config_path, date, cycle,
        output_dir=wps_dir,  # Write namelist.wps directly to WPS working dir
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
        date_compact = date.replace("-", "")
        fhours_str = " ".join(f"{h:02d}" for h in download_fhours)
        _run(f'bash {scripts_dir}/get_nam_grib.sh {date_compact} {cycle} {grib_dir} "{fhours_str}"',
             "Downloading GRIB data")

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

    # namelist.input is already in run_dir from Step 1

    # Auto-detect num_metgrid_levels from met_em
    met_sample = met_files[0] if met_files else None
    if met_sample:
        try:
            r = subprocess.run(
                f"ncdump -h {met_sample} | awk '/num_metgrid_levels =/ {{print $3+0; exit}}'",
                shell=True, capture_output=True, text=True
            )
            nml = int(r.stdout.strip())
            # Patch namelist.input with correct num_metgrid_levels
            nl_path = run_path / "namelist.input"
            nl_text = nl_path.read_text()
            import re
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

    # Check real.exe output
    if not (run_path / "wrfinput_d01").exists():
        print("  ERROR: real.exe failed — no wrfinput_d01")
        # Try to show error
        rsl = run_path / "rsl.error.0000"
        if rsl.exists():
            print(rsl.read_text()[-500:])
        sys.exit(1)
    print(f"  real.exe: OK")

    # 4b. wrf.exe — cap procs at available CPUs inside container
    import time
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

    # Use the finest domain wrfout
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
    parser.add_argument("--date", required=True, help="Forecast date (YYYY-MM-DD)")
    parser.add_argument("--cycle", required=True, help="Forecast cycle (HH)")
    parser.add_argument("--sites", help="CSV file with sites (name lat lon)")
    parser.add_argument("--output-dir", default="./output", help="Output directory")
    parser.add_argument("--grib-dir", help="Directory with GRIB2 files")
    parser.add_argument("--geog-path", default="/mnt/geog", help="GEOG data path")
    parser.add_argument("--num-procs", type=int, default=1, help="MPI processes")
    parser.add_argument("--utc-offset", type=int, default=-7, help="UTC offset")
    parser.add_argument("--start-hour", type=int, default=8, help="Earliest hour to show")
    args = parser.parse_args()

    run_pipeline(
        args.config, args.date, args.cycle,
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
