"""
Host-side CLI for generating windgrams via Docker.

Wraps `docker run` with the correct volume mounts so you don't have to
remember the incantation every time.

Usage:
    rasp run examples/cascades.yaml --date 2026-04-04 --cycle 06 --sites examples/pnw-sites.csv
    rasp windgram wrfout_d03_*.nc --sites sites.csv --output-dir ./output
    rasp windgram wrfout_d03_*.nc --site Tiger --lat 47.503 --lon -121.975
    rasp setup-geog
    rasp setup-geog --low-res --dest ~/rasp-data/geog

Configuration (env vars):
    RASP_IMAGE       Docker image  (default: ghcr.io/nw-paragliding/windgram:latest)
    RASP_GEOG_DIR    WPS GEOG data (default: ~/rasp-data/geog)
    RASP_OUTPUT_DIR  Output dir    (default: ./output)
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

DEFAULT_IMAGE = "ghcr.io/nw-paragliding/windgram:latest"
DEFAULT_GEOG = os.path.expanduser("~/rasp-data/geog")

NCAR_BASE = "https://www2.mmm.ucar.edu/wrf/src/wps_files"
GEOG_HIGH_RES = "geog_high_res_mandatory.tar.gz"   # ~2.6 GB download, ~29 GB unpacked
GEOG_LOW_RES = "geog_low_res_mandatory.tar.gz"      # ~0.4 GB download, ~3 GB unpacked

# Directories that indicate GEOG data is already present
GEOG_MARKER_DIRS = ["topo_gmted2010_30s", "modis_landuse_20class_30s"]
GEOG_MARKER_DIRS_LOW = ["topo_2m", "modis_landuse_20class_15s_with_lakes"]


def _image():
    return os.environ.get("RASP_IMAGE", DEFAULT_IMAGE)


def _geog_dir(args_geog):
    return args_geog or os.environ.get("RASP_GEOG_DIR", DEFAULT_GEOG)


def _check_docker():
    if not shutil.which("docker"):
        print("Error: docker not found on PATH", file=sys.stderr)
        sys.exit(1)


def _resolve(p):
    """Resolve a path to absolute for Docker volume mounting."""
    return str(Path(p).resolve())


def _build_docker_cmd(volumes, container_args, extra_flags=None):
    """Build the full docker run command."""
    cmd = ["docker", "run", "--rm"]
    if extra_flags:
        cmd.extend(extra_flags)
    for host, container, mode in volumes:
        cmd.extend(["-v", f"{host}:{container}:{mode}"])
    cmd.append(_image())
    cmd.extend(container_args)
    return cmd


def _format_cmd(cmd):
    """Format a command list as a readable shell command string."""
    parts = []
    i = 0
    while i < len(cmd):
        if cmd[i] == "-v" and i + 1 < len(cmd):
            parts.append(f"  -v {cmd[i+1]}")
            i += 2
        elif i == 0:
            parts.append(cmd[i])
            i += 1
        else:
            parts.append("  " + " ".join(cmd[i:]))
            break
    return " \\\n".join(parts)


def _print_cmd(cmd):
    """Print the docker command for transparency."""
    print(f"\n{'─'*60}", file=sys.stderr)
    print(_format_cmd(cmd), file=sys.stderr)
    print(f"{'─'*60}\n", file=sys.stderr)


def _run_or_dry(cmd, dry_run):
    """Print command, then execute it unless --dry-run."""
    _print_cmd(cmd)
    if dry_run:
        print("[dry-run] Would execute the above command.", file=sys.stderr)
        return 0
    return subprocess.call(cmd)


def cmd_run(args):
    """Full pipeline: domain.yaml -> WPS -> WRF -> windgrams."""
    _check_docker()

    config_path = _resolve(args.config)
    if not Path(config_path).exists():
        print(f"Error: domain config not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    output_dir = _resolve(args.output_dir)
    geog_dir = _resolve(_geog_dir(args.geog_dir))

    if not args.dry_run:
        Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Volume mounts
    config_name = Path(config_path).name
    volumes = [
        (geog_dir, "/mnt/geog", "ro"),
        (output_dir, "/mnt/output", "rw"),
        (config_path, f"/opt/rasp/{config_name}", "ro"),
    ]

    container_args = ["run", config_name, "--date", args.date, "--cycle", args.cycle]
    container_args.extend(["--output-dir", "/mnt/output"])

    if args.sites:
        sites_path = _resolve(args.sites)
        if not Path(sites_path).exists():
            print(f"Error: sites file not found: {sites_path}", file=sys.stderr)
            sys.exit(1)
        sites_name = Path(sites_path).name
        volumes.append((sites_path, f"/opt/rasp/{sites_name}", "ro"))
        container_args.extend(["--sites", sites_name])

    if args.grib_dir:
        grib_path = _resolve(args.grib_dir)
        volumes.append((grib_path, "/mnt/grib", "ro"))
        container_args.extend(["--grib-dir", "/mnt/grib"])

    num_procs = args.num_procs or os.cpu_count() or 4
    container_args.extend(["--num-procs", str(num_procs)])
    if args.utc_offset is not None:
        container_args.extend(["--utc-offset", str(args.utc_offset)])
    if args.start_hour is not None:
        container_args.extend(["--start-hour", str(args.start_hour)])

    cmd = _build_docker_cmd(volumes, container_args)
    sys.exit(_run_or_dry(cmd, args.dry_run))


def cmd_windgram(args):
    """Render windgrams from existing wrfout files."""
    _check_docker()

    output_dir = _resolve(args.output_dir)

    if not args.dry_run:
        Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Collect wrfout files — could be multiple via glob on the host
    wrfout_paths = [_resolve(f) for f in args.wrfout]
    for p in wrfout_paths:
        if not Path(p).exists():
            print(f"Error: wrfout file not found: {p}", file=sys.stderr)
            sys.exit(1)

    # Mount each wrfout file individually
    volumes = [
        (output_dir, "/mnt/output", "rw"),
    ]
    container_wrfout_args = []
    for p in wrfout_paths:
        name = Path(p).name
        container_path = f"/mnt/wrfout/{name}"
        volumes.append((p, container_path, "ro"))
        container_wrfout_args.append(container_path)

    container_args = ["windgram"] + container_wrfout_args
    container_args.extend(["--output-dir", "/mnt/output"])

    # Site args — either --sites CSV or --site/--lat/--lon
    if args.sites:
        sites_path = _resolve(args.sites)
        if not Path(sites_path).exists():
            print(f"Error: sites file not found: {sites_path}", file=sys.stderr)
            sys.exit(1)
        sites_name = Path(sites_path).name
        volumes.append((sites_path, f"/opt/rasp/{sites_name}", "ro"))
        container_args.extend(["--sites", f"/opt/rasp/{sites_name}"])
    elif args.site and args.lat is not None and args.lon is not None:
        container_args.extend(["--site", args.site])
        container_args.extend(["--lat", str(args.lat)])
        container_args.extend(["--lon", str(args.lon)])
    else:
        print("Error: provide --sites CSV or --site NAME --lat LAT --lon LON",
              file=sys.stderr)
        sys.exit(1)

    if args.utc_offset is not None:
        container_args.extend(["--utc-offset", str(args.utc_offset)])
    if args.start_hour is not None:
        container_args.extend(["--start-hour", str(args.start_hour)])
    if args.p_top is not None:
        container_args.extend(["--p-top", str(args.p_top)])
    if args.dpi is not None:
        container_args.extend(["--dpi", str(args.dpi)])

    cmd = _build_docker_cmd(volumes, container_args)
    sys.exit(_run_or_dry(cmd, args.dry_run))


def _geog_is_present(dest_dir):
    """Check if GEOG data is already downloaded."""
    dest = Path(dest_dir)
    if not dest.exists():
        return False
    # Check for marker directories (either high-res or low-res)
    for marker in GEOG_MARKER_DIRS + GEOG_MARKER_DIRS_LOW:
        # Check top-level and one level deep (some tarballs nest under WPS_GEOG/)
        if (dest / marker).is_dir():
            return True
        for child in dest.iterdir():
            if child.is_dir() and (child / marker).is_dir():
                return True
    return False


def cmd_setup_geog(args):
    """Download WPS GEOG static data (one-time setup)."""
    dest_dir = _resolve(args.dest)

    if _geog_is_present(dest_dir):
        print(f"GEOG data already present in {dest_dir} — nothing to do.")
        print("(Delete the directory to re-download.)")
        return

    if args.low_res:
        tarball = GEOG_LOW_RES
        label = "low-res (~0.4 GB download, ~3 GB unpacked)"
    else:
        tarball = GEOG_HIGH_RES
        label = "high-res (~2.6 GB download, ~29 GB unpacked)"

    url = f"{NCAR_BASE}/{tarball}"

    print(f"=== WPS GEOG static data setup ===")
    print(f"  Resolution: {label}")
    print(f"  Destination: {dest_dir}")
    print(f"  Source: {url}")
    print()

    if args.dry_run:
        print("[dry-run] Would download and extract GEOG data.")
        return

    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)
    tmp_tar = dest / tarball

    # Download
    if not tmp_tar.exists():
        print(f"Downloading {tarball} ...")
        rc = subprocess.call(["curl", "-L", "--progress-bar", url, "-o", str(tmp_tar)])
        if rc != 0:
            print("Error: download failed", file=sys.stderr)
            sys.exit(rc)
    else:
        print(f"Tarball already downloaded: {tmp_tar}")

    # Extract
    print("Extracting (this may take a while)...")
    rc = subprocess.call(["tar", "-xzf", str(tmp_tar), "-C", str(dest)])
    if rc != 0:
        print("Error: extraction failed", file=sys.stderr)
        sys.exit(rc)

    # The tarball typically extracts into a subdirectory (WPS_GEOG/ or geog/).
    # Flatten it so dest_dir is the data root.
    for child in dest.iterdir():
        if child.is_dir() and child.name.startswith(("WPS_GEOG", "geog")):
            for item in child.iterdir():
                item.rename(dest / item.name)
            child.rmdir()
            break

    # Clean up tarball
    tmp_tar.unlink()

    print()
    print(f"=== Done ===")
    print(f"GEOG data root: {dest_dir}")
    print(f"Use with: rasp run --geog-dir {dest_dir} ...")
    print(f"  or set: export RASP_GEOG_DIR={dest_dir}")


def main():
    parser = argparse.ArgumentParser(
        prog="rasp",
        description="Generate soaring forecast windgrams via Docker",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print the Docker command without executing it",
    )
    sub = parser.add_subparsers(dest="command")
    sub.required = True

    # ── rasp run ──────────────────────────────────────────────────────────
    p_run = sub.add_parser("run", help="Full pipeline: domain.yaml → WPS → WRF → windgrams")
    p_run.add_argument("config", help="Path to domain.yaml")
    p_run.add_argument("--date", required=True, help="Forecast date (YYYY-MM-DD)")
    p_run.add_argument("--cycle", required=True, help="Model cycle (HH, e.g. 06)")
    p_run.add_argument("--sites", help="CSV file with sites (name lat lon)")
    p_run.add_argument("--output-dir", default="./output", help="Output directory (default: ./output)")
    p_run.add_argument("--geog-dir", help=f"WPS GEOG data path (default: $RASP_GEOG_DIR or {DEFAULT_GEOG})")
    p_run.add_argument("--grib-dir", help="Pre-downloaded GRIB directory (default: auto-download)")
    p_run.add_argument("--num-procs", type=int, help="MPI processes for WRF")
    p_run.add_argument("--utc-offset", type=int, help="UTC offset for time labels (default: -7)")
    p_run.add_argument("--start-hour", type=int, help="Earliest local hour to show (default: 8)")
    p_run.set_defaults(func=cmd_run)

    # ── rasp windgram ─────────────────────────────────────────────────────
    p_wg = sub.add_parser("windgram", help="Render windgrams from existing wrfout files")
    p_wg.add_argument("wrfout", nargs="+", help="wrfout file(s)")
    p_wg.add_argument("--sites", help="CSV file with sites (name lat lon)")
    p_wg.add_argument("--site", help="Single site name")
    p_wg.add_argument("--lat", type=float, help="Site latitude")
    p_wg.add_argument("--lon", type=float, help="Site longitude")
    p_wg.add_argument("--output-dir", default="./output", help="Output directory (default: ./output)")
    p_wg.add_argument("--utc-offset", type=int, help="UTC offset for time labels (default: -7)")
    p_wg.add_argument("--start-hour", type=int, help="Earliest local hour to show (default: 8)")
    p_wg.add_argument("--p-top", type=float, help="Chart ceiling in mb")
    p_wg.add_argument("--dpi", type=int, help="Output resolution (default: 100)")
    p_wg.set_defaults(func=cmd_windgram)

    # ── rasp setup-geog ───────────────────────────────────────────────────
    p_geog = sub.add_parser("setup-geog", help="Download WPS GEOG static data (one-time)")
    p_geog.add_argument("--dest", default=DEFAULT_GEOG,
                        help=f"Destination directory (default: {DEFAULT_GEOG})")
    p_geog.add_argument("--low-res", action="store_true",
                        help="Download low-res data (~0.4 GB) instead of high-res (~2.6 GB)")
    p_geog.set_defaults(func=cmd_setup_geog)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
