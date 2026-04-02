#!/bin/bash
# run_wps.sh — Run WPS (ungrib + geogrid + metgrid) for a single forecast cycle.
#
# Usage:
#   run_wps.sh <grib_dir> <start_date> <end_date> [geog_path]
#
# Arguments:
#   grib_dir    Directory containing NAM GRIB2 files (*.grib2, already cnvgrib'd to GRIB1)
#   start_date  WRF run start: YYYY-MM-DD_HH (e.g. 2026-03-30_12)
#   end_date    WRF run end:   YYYY-MM-DD_HH (e.g. 2026-03-31_03)
#   geog_path   Path to WPS GEOG static data directory (default: $WPS_DIR/geog)
#
# Outputs written to $WPS_RUN_DIR (default: $WPS_DIR, i.e. /opt/rasp/WRF/WPS/):
#   geo_em.d01.nc, geo_em.d02.nc  — static geo fields (created once; skip if exist)
#   FILE:YYYY-MM-DD_HH             — ungrib intermediate files
#   met_em.d01.YYYY-MM-DD_HH:00:00.nc, met_em.d02.*  — metgrid output
#
# Environment:
#   BASEDIR     — /opt/rasp (set by Docker image)
#   WPS_DIR     — defaults to $BASEDIR/WRF/WPS
#   WPS_RUN_DIR — working directory for WPS (defaults to $WPS_DIR)

set -euo pipefail

GRIB_DIR="${1:?Usage: run_wps.sh <grib_dir> <start_date> <end_date> [geog_path]}"
START_DATE="${2:?Missing start_date (YYYY-MM-DD_HH)}"
END_DATE="${3:?Missing end_date (YYYY-MM-DD_HH)}"

BASEDIR="${BASEDIR:-/opt/rasp}"
WPS_DIR="${WPS_DIR:-${BASEDIR}/WRF/WPS}"
WPS_RUN_DIR="${WPS_RUN_DIR:-${WPS_DIR}}"

# /mnt/geog is volume-mounted from $HOME/rasp-data/wps-geog on the host.
# Download once with setup_geog.sh; never baked into the image.
# The tarball may extract into a subdirectory (e.g. WPS_GEOG_LOW_RES/);
# auto-detect if not explicitly provided.
_resolve_geog_path() {
    local base="${1}"
    # If it already looks like a GEOG root (contains landuse data), use it directly.
    if ls "${base}"/modis_landuse* "${base}"/albedo_* "${base}"/orogwd* 2>/dev/null | grep -q .; then
        echo "${base}"
        return
    fi
    # Look one level deep for a subdirectory that IS a GEOG root.
    local sub
    sub=$(find "${base}" -maxdepth 1 -mindepth 1 -type d | while read -r d; do
        ls "${d}"/modis_landuse* "${d}"/albedo_* "${d}"/orogwd* 2>/dev/null | grep -q . && echo "${d}" && break
    done | head -1)
    if [ -n "${sub}" ]; then
        echo "${sub}"
    else
        echo "${base}"
    fi
}

GEOG_PATH="${4:-$(_resolve_geog_path /mnt/geog)}"
NAMELIST_TEMPLATE="${WPS_DIR}/namelist.wps.PNW"
LOG_DIR="${WPS_RUN_DIR}/log"

mkdir -p "${WPS_RUN_DIR}" "${LOG_DIR}"
cd "${WPS_RUN_DIR}"

echo "=== WPS run ==="
echo "  GRIB_DIR:   ${GRIB_DIR}"
echo "  START_DATE: ${START_DATE}"
echo "  END_DATE:   ${END_DATE}"
echo "  GEOG_PATH:  ${GEOG_PATH}"
echo "  WPS_RUN_DIR: ${WPS_RUN_DIR}"

# ── 1. Write namelist.wps from template ──────────────────────────────────────
START_NL="${START_DATE}:00:00"
END_NL="${END_DATE}:00:00"

sed -e "s|__START_DATE__|${START_NL}|g" \
    -e "s|__END_DATE__|${END_NL}|g" \
    -e "s|__GEOG_PATH__|${GEOG_PATH}|g" \
    "${NAMELIST_TEMPLATE}" > namelist.wps

echo "  namelist.wps written (start=${START_NL}, end=${END_NL})"

# ── 2. geogrid — run once; skip if geo_em files already exist ────────────────
# geo_em files are static (depend only on domain config, not forecast date).
# Cache them in /mnt/wrfout/geo_em/ so geogrid only runs once even across
# container restarts. On first run they're computed and saved; after that restored.
GEO_EM_CACHE="/mnt/wrfout/geo_em"

if [ -f "geo_em.d01.nc" ] && [ -f "geo_em.d02.nc" ]; then
    echo "  geogrid: geo_em files in WPS run dir — skipping"
elif [ -f "${GEO_EM_CACHE}/geo_em.d01.nc" ] && [ -f "${GEO_EM_CACHE}/geo_em.d02.nc" ]; then
    echo "  geogrid: restoring cached geo_em files from ${GEO_EM_CACHE}"
    cp "${GEO_EM_CACHE}"/geo_em.d0*.nc .
else
    echo "  Running geogrid.exe (one-time static step)..."
    echo "  GEOG_PATH = ${GEOG_PATH}"
    if [ ! -d "${GEOG_PATH}" ]; then
        echo "ERROR: GEOG_PATH does not exist: ${GEOG_PATH}"
        echo "  Mount the WPS GEOG static data at /mnt/geog (run setup_geog.sh on the host)"
        exit 1
    fi
    "${WPS_DIR}/geogrid.exe" >| "${LOG_DIR}/geogrid.log" 2>&1
    GEO_EM_COUNT=$(ls geo_em.d0*.nc 2>/dev/null | wc -l)
    if [ "${GEO_EM_COUNT}" -eq 0 ]; then
        echo "ERROR: geogrid.exe ran but produced no geo_em files — see ${LOG_DIR}/geogrid.log"
        tail -30 "${LOG_DIR}/geogrid.log"
        exit 1
    fi
    echo "  geogrid.exe: OK (${GEO_EM_COUNT} domains)"
    # Save to persistent cache for future container runs
    if [ -w /mnt/wrfout ]; then
        mkdir -p "${GEO_EM_CACHE}"
        cp geo_em.d0*.nc "${GEO_EM_CACHE}/"
        echo "  geo_em files cached to ${GEO_EM_CACHE}"
    fi
fi

# ── 3. ungrib — link GRIB files and extract fields ───────────────────────────
# Remove old FILE: intermediates from a previous run.
rm -f FILE:*

# Link the Vtable for NAM GRIB2 (pressure-level awip3d files).
# Vtable.NAMb is for NAM GRIB2 on pressure levels (awip3d / awp212 files).
ln -sf "${WPS_DIR}/Variable_Tables/Vtable.NAMb" Vtable

# Link GRIB files using link_grib.csh (creates GRIBFILE.AA, GRIBFILE.AB, ...)
rm -f GRIBFILE.*
csh "${WPS_DIR}/link_grib.csh" "${GRIB_DIR}"/*.grib2

echo "  Running ungrib.exe..."
"${WPS_DIR}/ungrib.exe" >| "${LOG_DIR}/ungrib.log" 2>&1 && \
    echo "  ungrib.exe: OK ($(ls FILE:* 2>/dev/null | wc -l) intermediate files)" || {
    echo "ERROR: ungrib.exe failed — see ${LOG_DIR}/ungrib.log"
    tail -20 "${LOG_DIR}/ungrib.log"
    exit 1
}

# ── 4. metgrid — interpolate to WRF grid ─────────────────────────────────────
# Remove old met_em files from a previous run.
rm -f met_em.d0*.nc

echo "  Running metgrid.exe..."
"${WPS_DIR}/metgrid.exe" >| "${LOG_DIR}/metgrid.log" 2>&1 && \
    echo "  metgrid.exe: OK ($(ls met_em.d0*.nc 2>/dev/null | wc -l) met_em files)" || {
    echo "ERROR: metgrid.exe failed — see ${LOG_DIR}/metgrid.log"
    tail -20 "${LOG_DIR}/metgrid.log"
    exit 1
}

echo
echo "=== WPS complete ==="
echo "  geo_em files: $(ls geo_em.d0*.nc 2>/dev/null | tr '\n' ' ')"
echo "  met_em files:"
ls met_em.d0*.nc 2>/dev/null | sed 's/^/    /'
