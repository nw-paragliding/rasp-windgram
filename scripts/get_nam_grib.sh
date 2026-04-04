#!/bin/bash
# get_nam_grib.sh — Download NAM GRIB2 files from NCEP NOMADS for a given date/cycle.
#
# Usage:
#   ./get_nam_grib.sh [YYYYMMDD] [cycle_z] [dest_dir]
#
# Defaults:
#   YYYYMMDD  — today ($(date +%Y%m%d))
#   cycle_z   — 06  (06Z NAM run)
#   dest_dir  — $HOME/rasp-data/grib
#
# Downloads the six 3-hourly forecast files used by the RASP pipeline:
#   nam.tHHz.awip3d06.tm00.grib2  (valid HH+06)
#   nam.tHHz.awip3d09.tm00.grib2  (valid HH+09)
#   ...through awip3d21
#
# NOMADS keeps ~48h of rolling data. For older data use NCEI archive.

set -euo pipefail

DATE="${1:-$(date +%Y%m%d)}"
CYCLE="${2:-06}"
DEST_DIR="${3:-${HOME}/rasp-data/grib}"

NOMADS_BASE="https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod"
NAM_DIR="${NOMADS_BASE}/nam.${DATE}"

mkdir -p "${DEST_DIR}"

echo "=== NAM GRIB2 download ==="
echo "  Date:    ${DATE}"
echo "  Cycle:   ${CYCLE}Z"
echo "  Source:  ${NAM_DIR}"
echo "  Dest:    ${DEST_DIR}"
echo

FHOURS="06 09 12 15 18 21"
for FH in ${FHOURS}; do
    FNAME="nam.t${CYCLE}z.awip3d${FH}.tm00.grib2"
    DEST="${DEST_DIR}/${FNAME}"
    if [ -f "${DEST}" ]; then
        echo "  ${FNAME}: already exists ($(du -sh "${DEST}" | cut -f1))"
        continue
    fi
    echo "  Downloading ${FNAME}..."
    curl -fsSL --progress-bar "${NAM_DIR}/${FNAME}" -o "${DEST}" && \
        echo "  ${FNAME}: OK ($(du -sh "${DEST}" | cut -f1))" || \
        echo "  WARNING: ${FNAME} download failed — may not be available yet"
done

echo
echo "=== Done ==="
echo "Files in ${DEST_DIR}:"
ls -lh "${DEST_DIR}"/nam.t${CYCLE}z.awip3d*.grib2 2>/dev/null | sed 's/^/  /' || echo "  (none)"
