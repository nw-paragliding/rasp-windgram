#!/bin/bash
# Docker entrypoint for rasp/windgram image.
#
# Usage:
#   docker run rasp/windgram run domain.yaml --date 2026-04-04 --cycle 06 --sites sites.csv
#   docker run rasp/windgram windgram wrfout.nc --sites sites.csv --output-dir /mnt/output
#   docker run rasp/windgram bash   (interactive shell)

set -euo pipefail

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    run)
        # Full pipeline: domain.yaml → WPS → WRF → windgrams
        exec python3 -m rasp.pipeline "$@"
        ;;
    windgram)
        # Render windgrams from existing wrfout files
        exec python3 -m rasp.windgram "$@"
        ;;
    namelist)
        # Generate namelists only
        exec python3 -m rasp.namelist_generator "$@"
        ;;
    bash|sh)
        # Interactive shell
        exec /bin/bash "$@"
        ;;
    help|--help|-h)
        cat <<EOF
RASP Windgram Generator

Commands:
  run       domain.yaml --date YYYY-MM-DD --cycle HH [--sites sites.csv]
            Full pipeline: generate namelists, run WPS+WRF, render windgrams

  windgram  wrfout.nc --sites sites.csv --output-dir ./output
            Render windgrams from existing WRF output

  namelist  domain.yaml --date YYYY-MM-DD --cycle HH
            Generate WPS/WRF namelists from domain config

  bash      Interactive shell

Volumes:
  /mnt/geog     WPS GEOG static data (read-only)
  /mnt/grib     GRIB input files (read-only)
  /mnt/output   Windgram PNG output

Example:
  docker run -v ~/geog:/mnt/geog:ro -v ~/output:/mnt/output \\
    rasp/windgram run domain.yaml --date 2026-04-04 --cycle 06
EOF
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Run with 'help' for usage."
        exit 1
        ;;
esac
