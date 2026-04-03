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

    Or inside Docker:
    docker run -v ./domain.yaml:/domain.yaml:ro \\
        -v ~/rasp-data/geog:/mnt/geog:ro \\
        -v ~/output:/mnt/output \\
        rasp/windgram run /domain.yaml --date 2026-04-01 --cycle 06
"""

import argparse
import subprocess
import sys
from pathlib import Path

from .namelist_generator import generate_namelists, load_domain_config, MODEL_FORECAST_HOURS
from .windgram import render_windgram


def _run(cmd, desc, cwd=None):
    """Run a shell command, stream output, raise on failure."""
    print(f"\n{'='*60}")
    print(f"  {desc}")
    print(f"{'='*60}\n")
    result = subprocess.run(
        cmd, shell=True, cwd=cwd,
        stdout=sys.stdout, stderr=sys.stderr,
    )
    if result.returncode != 0:
        print(f"\nERROR: {desc} failed (exit {result.returncode})")
        sys.exit(result.returncode)


def run_pipeline(config_path, date, cycle, sites_csv=None, output_dir="./output",
                 grib_dir=None, geog_path="/mnt/geog", basedir="/opt/rasp",
                 num_procs=1, utc_offset=-7, start_hour=8):
    """Run the full forecast pipeline.

    Args:
        config_path: path to domain.yaml
        date:        "YYYY-MM-DD"
        cycle:       "HH" (e.g. "06")
        sites_csv:   path to CSV with site definitions (name lat lon)
        output_dir:  where to write windgram PNGs
        grib_dir:    directory with GRIB2 files (None = download)
        geog_path:   path to WPS GEOG data
        basedir:     RASP base directory
        num_procs:   number of MPI processes for wrf.exe
        utc_offset:  UTC offset for windgram time labels
        start_hour:  earliest local hour to show on windgrams
    """
    config = load_domain_config(config_path)
    model = config["model"]
    fhours = MODEL_FORECAST_HOURS[model]

    # Compute valid time range from cycle + forecast hours
    start_valid = f"{date}_{int(cycle) + fhours[0]:02d}"
    end_valid_h = int(cycle) + fhours[-1]
    if end_valid_h >= 24:
        # Rolls into next day — simplified, assumes single day rollover
        from datetime import datetime, timedelta
        d = datetime.strptime(date, "%Y-%m-%d") + timedelta(days=1)
        end_valid = f"{d.strftime('%Y-%m-%d')}_{end_valid_h - 24:02d}"
    else:
        end_valid = f"{date}_{end_valid_h:02d}"

    run_hours = fhours[-1] - fhours[0]

    wps_dir = f"{basedir}/WRF/WPS"
    wrf_dir = f"{basedir}/WRF/WRFV2"
    run_dir = f"{wrf_dir}/RASP/{config['name']}"

    print(f"\n  Pipeline: {config['name']}")
    print(f"  Model: {model.upper()}, Date: {date} {cycle}z")
    print(f"  Valid: {start_valid} to {end_valid} ({run_hours}h)")

    # --- Step 1: Generate namelists ---
    result = generate_namelists(
        config_path, date, cycle,
        output_dir=wps_dir,
        geog_path=geog_path,
    )

    # --- Step 2: Download GRIB (if not provided) ---
    if grib_dir is None:
        grib_dir = f"{basedir}/grib"
        _run(f"bash {basedir}/get_nam_grib.sh {date} {cycle} {grib_dir}",
             "Downloading GRIB data")

    # --- Step 3: Run WPS ---
    _run(f"bash {wps_dir}/run_wps.sh {grib_dir} {start_valid} {end_valid}",
         "Running WPS (ungrib + geogrid + metgrid)")

    # --- Step 4: Run WRF ---
    _run(f"bash {wps_dir}/run_real_wrf.sh {wps_dir} {start_valid} {end_valid} {run_hours}",
         f"Running real.exe + wrf.exe ({run_hours}h, {num_procs} procs)")

    # --- Step 5: Render windgrams ---
    # Find wrfout files
    run_path = Path(run_dir)
    wrfout_files = sorted(run_path.glob("wrfout_d*"))
    if not wrfout_files:
        # Check WPS dir as fallback
        wrfout_files = sorted(Path(wps_dir).parent.glob("**/wrfout_d*"))

    if not wrfout_files:
        print("WARNING: No wrfout files found — skipping windgram rendering")
        return

    # Use the finest domain wrfout
    finest_wrfout = str(wrfout_files[-1])
    print(f"\n  Rendering windgrams from: {finest_wrfout}")

    # Load sites
    sites = _load_sites(sites_csv) if sites_csv else []
    if not sites:
        print("  No sites CSV provided — skipping windgram rendering")
        print(f"  You can render manually:")
        print(f"    python -m rasp.windgram {finest_wrfout} --lat LAT --lon LON --site NAME")
        return

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    for name, lat, lon in sites:
        try:
            render_windgram(finest_wrfout, lat, lon, name, str(output_path),
                            utc_offset=utc_offset, start_hour=start_hour)
        except Exception as e:
            print(f"  WARNING: Failed to render windgram for {name}: {e}")

    print(f"\n{'='*60}")
    print(f"  Pipeline complete!")
    print(f"  Windgrams: {output_path}/")
    print(f"{'='*60}\n")


def _load_sites(csv_path):
    """Load site definitions from a CSV file.

    Format: name lat lon (space or comma separated)
    Lines starting with # are comments.

    Returns list of (name, lat, lon) tuples.
    """
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
        # Try comma-separated first, then space
        if "," in line:
            parts = [p.strip() for p in line.split(",")]
        else:
            parts = line.split()

        if len(parts) >= 3:
            name = parts[0]
            try:
                lat = float(parts[1])
                lon = float(parts[2])
                sites.append((name, lat, lon))
            except ValueError:
                print(f"WARNING: Skipping invalid site line: {line}")

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
