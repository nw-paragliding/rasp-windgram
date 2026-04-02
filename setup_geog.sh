#!/bin/bash
# setup_geog.sh — One-time download of WPS geographic static data (GEOG).
#
# Downloads the mandatory low/medium resolution GEOG package from NCAR (~3 GB)
# to a host directory that is volume-mounted as /mnt/geog in the container.
#
# Usage:
#   ./setup_geog.sh [dest_dir]
#
# dest_dir defaults to $HOME/rasp-data/wps-geog
#
# After this runs, mount in docker run:
#   -v $HOME/rasp-data/wps-geog:/mnt/geog:ro
#
# geogrid.exe only needs to run once per domain set (it reads GEOG, writes
# geo_em.d0*.nc). The geo_em files are cached in /mnt/wrfout/geo_em/ so
# subsequent container runs skip geogrid entirely.

set -euo pipefail

DEST_DIR="${1:-${HOME}/rasp-data/wps-geog}"
NCAR_BASE="https://www2.mmm.ucar.edu/wrf/src/wps_files"

# Mandatory dataset covering all standard WRF physics options at low/med resolution.
# ~3 GB download, ~8 GB unpacked.
TARBALL="geog_low_res_mandatory.tar.gz"

echo "=== WPS GEOG static data setup ==="
echo "  Destination: ${DEST_DIR}"
echo "  Source:      ${NCAR_BASE}/${TARBALL}"
echo

mkdir -p "${DEST_DIR}"

if [ -d "${DEST_DIR}/orogw" ] && [ -d "${DEST_DIR}/modis_landuse_20class_30s" ]; then
    echo "GEOG data already present in ${DEST_DIR} — nothing to do."
    echo "(Delete the directory to re-download.)"
    exit 0
fi

TMP_TAR="${DEST_DIR}/${TARBALL}"

if [ ! -f "${TMP_TAR}" ]; then
    echo "Downloading ${TARBALL} (~3 GB, this will take a while)..."
    curl -L --progress-bar "${NCAR_BASE}/${TARBALL}" -o "${TMP_TAR}"
else
    echo "Tarball already downloaded: ${TMP_TAR}"
fi

echo "Extracting..."
# The tarball extracts into a subdirectory called 'geog/'.
# We extract to a temp location then merge into DEST_DIR so the path is flat
# (i.e. $DEST_DIR/modis_landuse_20class_30s/..., not $DEST_DIR/geog/modis.../...)
TMP_EXTRACT=$(mktemp -d "${DEST_DIR}/.extract_XXXXXX")
tar -xzf "${TMP_TAR}" -C "${TMP_EXTRACT}"

# Move contents of the extracted geog/ subdir up into DEST_DIR
EXTRACTED_GEOG=$(find "${TMP_EXTRACT}" -maxdepth 1 -type d -name 'geog*' | head -1)
if [ -z "${EXTRACTED_GEOG}" ]; then
    # Some packages extract directly without a geog/ wrapper
    EXTRACTED_GEOG="${TMP_EXTRACT}"
fi

echo "Moving data into ${DEST_DIR}..."
mv "${EXTRACTED_GEOG}"/* "${DEST_DIR}/"
rm -rf "${TMP_EXTRACT}" "${TMP_TAR}"

echo
echo "=== Done ==="
echo "GEOG datasets in ${DEST_DIR}:"
ls "${DEST_DIR}/" | sed 's/^/  /'
echo
echo "Mount in docker run with:"
echo "  -v ${DEST_DIR}:/mnt/geog:ro"
