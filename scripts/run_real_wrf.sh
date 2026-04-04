#!/bin/bash
# run_real_wrf.sh — Run real.exe then wrf.exe for PNW d01 using WPS output.
#
# Must run after run_wps.sh has produced met_em.d01.*.nc files.
#
# Usage:
#   run_real_wrf.sh <wps_run_dir> <start_date> <end_date> <run_hours>
#
# Arguments:
#   wps_run_dir  Directory where met_em.d01.*.nc files live (output of run_wps.sh)
#   start_date   YYYY-MM-DD_HH  (WRF run start, e.g. 2026-03-30_12)
#   end_date     YYYY-MM-DD_HH  (WRF run end,   e.g. 2026-03-31_03)
#   run_hours    Total forecast hours (e.g. 15)
#
# Outputs written to $WRF_RUN_DIR (default /opt/rasp/WRF/WRFV2/RASP/PNW/):
#   wrfinput_d01, wrfbdy_d01  — from real.exe
#   wrfout_d01_YYYY-MM-DD_*   — from wrf.exe

set -euo pipefail

WPS_RUN_DIR="${1:?Usage: run_real_wrf.sh <wps_run_dir> <start_date> <end_date> <run_hours>}"
START_DATE="${2:?Missing start_date (YYYY-MM-DD_HH)}"
END_DATE="${3:?Missing end_date (YYYY-MM-DD_HH)}"
RUN_HOURS="${4:?Missing run_hours}"

BASEDIR="${BASEDIR:-/opt/rasp}"
WRF_DIR="${BASEDIR}/bin"
WRF_RUN_TABLES="${BASEDIR}/run"
WRF_RUN_DIR="${WRF_RUN_DIR:-${BASEDIR}/runs/PNW}"
WPS_DIR="${BASEDIR}/wps"
NL_TEMPLATE="${BASEDIR}/templates/namelist.input.PNW"
LOG_DIR="${WRF_RUN_DIR}/log"
# Also save logs to /mnt/wrfout/logs/ so they survive container exit (--rm)
PERSIST_LOG_DIR="/mnt/wrfout/logs"

mkdir -p "${WRF_RUN_DIR}" "${LOG_DIR}"
[ -w /mnt/wrfout ] && mkdir -p "${PERSIST_LOG_DIR}"
cd "${WRF_RUN_DIR}"

echo "=== real.exe + wrf.exe run ==="
echo "  WPS_RUN_DIR: ${WPS_RUN_DIR}"
echo "  START: ${START_DATE}  END: ${END_DATE}  HOURS: ${RUN_HOURS}"
echo "  WRF_RUN_DIR: ${WRF_RUN_DIR}"

# ── Parse date components ─────────────────────────────────────────────────────
START_YEAR=$(echo  "${START_DATE}" | cut -c1-4)
START_MONTH=$(echo "${START_DATE}" | cut -c6-7)
START_DAY=$(echo   "${START_DATE}" | cut -c9-10)
START_HOUR=$(echo  "${START_DATE}" | cut -c12-13)
END_YEAR=$(echo    "${END_DATE}"   | cut -c1-4)
END_MONTH=$(echo   "${END_DATE}"   | cut -c6-7)
END_DAY=$(echo     "${END_DATE}"   | cut -c9-10)
END_HOUR=$(echo    "${END_DATE}"   | cut -c12-13)

# ── Detect num_metgrid_levels from the actual met_em file ────────────────────
# NAM awip3d pressure-level files vary; don't hardcode — read from met_em header.
MET_EM_SAMPLE=$(ls "${WPS_RUN_DIR}"/met_em.d01.*.nc 2>/dev/null | head -1)
if [ -z "${MET_EM_SAMPLE}" ]; then
    echo "ERROR: no met_em.d01.*.nc in ${WPS_RUN_DIR}"
    exit 1
fi
NUM_METGRID_LEVELS=$(ncdump -h "${MET_EM_SAMPLE}" 2>/dev/null | \
    awk '/^\s+num_metgrid_levels = / {print $3+0; exit}' || echo "")
if [ -z "${NUM_METGRID_LEVELS}" ]; then
    # Fallback: count the pressure_levels variable dimension
    NUM_METGRID_LEVELS=$(ncdump -h "${MET_EM_SAMPLE}" | \
        grep "num_metgrid_levels" | head -1 | grep -o '[0-9]*' | head -1)
fi
echo "  num_metgrid_levels: ${NUM_METGRID_LEVELS} (from ${MET_EM_SAMPLE##*/})"

# ── Write namelist.input ──────────────────────────────────────────────────────
sed -e "s/__START_YEAR__/${START_YEAR}/g" \
    -e "s/__START_MONTH__/${START_MONTH}/g" \
    -e "s/__START_DAY__/${START_DAY}/g" \
    -e "s/__START_HOUR__/${START_HOUR}/g" \
    -e "s/__END_YEAR__/${END_YEAR}/g" \
    -e "s/__END_MONTH__/${END_MONTH}/g" \
    -e "s/__END_DAY__/${END_DAY}/g" \
    -e "s/__END_HOUR__/${END_HOUR}/g" \
    -e "s/__RUN_HOURS__/${RUN_HOURS}/g" \
    -e "s/__NUM_METGRID_LEVELS__/${NUM_METGRID_LEVELS}/g" \
    "${NL_TEMPLATE}" > namelist.input

echo "  namelist.input written"

# ── Link required WRF table files ────────────────────────────────────────────
# real.exe and wrf.exe need these in CWD.
# WRF binaries and run tables — set at top of script via BASEDIR
WRF_SRC="${WRF_DIR}"              # wrf.exe, real.exe live in $BASEDIR/bin/

for f in RRTM_DATA RRTMG_LW_DATA RRTMG_SW_DATA CAMtr_volume_mixing_ratio \
         ETAMPNEW_DATA ETAMPNEW_DATA.expanded_rain \
         LANDUSE.TBL SOILPARM.TBL VEGPARM.TBL GENPARM.TBL \
         URBPARM.TBL ozone.formatted ozone_lat.formatted ozone_plev.formatted \
         aerosol.formatted aerosol_lat.formatted aerosol_lon.formatted \
         aerosol_plev.formatted capacity.asc coeff_p.asc coeff_q.asc \
         constants.asc drain.asc MPTABLE.TBL tr49t67 tr49t85 tr67t85 \
         BROADBAND_CLOUD_GODDARD.bin wind-turbine-1.tbl; do
    src="${WRF_RUN_TABLES}/${f}"
    [ -f "${src}" ] && ln -sf "${src}" "${f}" 2>/dev/null || true
done

# Link real.exe and wrf.exe
ln -sf "${WRF_SRC}/real.exe" real.exe
ln -sf "${WRF_SRC}/wrf.exe"  wrf.exe

# ── Link met_em files from WPS run dir (all domains) ────────────────────────
ln -sf "${WPS_RUN_DIR}"/met_em.d0*.*.nc .

MET_COUNT=$(ls met_em.d0*.*.nc 2>/dev/null | wc -l)
DOMAIN_COUNT=$(ls met_em.d0*.*.nc 2>/dev/null | sed 's/.*met_em.\(d[0-9]*\).*/\1/' | sort -u | wc -l)
echo "  met_em files linked: ${MET_COUNT} (${DOMAIN_COUNT} domains)"

# ── Run real.exe ─────────────────────────────────────────────────────────────
echo "  Running real.exe..."
./real.exe >| "${LOG_DIR}/real.log" 2>&1
[ -w /mnt/wrfout ] && cp "${LOG_DIR}/real.log" "${PERSIST_LOG_DIR}/real.log"
if [ -f "wrfinput_d01" ] && [ -f "wrfbdy_d01" ]; then
    echo "  real.exe: OK — wrfinput_d01 ($(du -sh wrfinput_d01 | cut -f1)), wrfbdy_d01 ($(du -sh wrfbdy_d01 | cut -f1))"
else
    echo "ERROR: real.exe failed — see ${LOG_DIR}/real.log"
    tail -30 "${LOG_DIR}/real.log"
    exit 1
fi

# ── Run wrf.exe ───────────────────────────────────────────────────────────────
echo "  Running wrf.exe (${RUN_HOURS}h forecast)..."
./wrf.exe >| "${LOG_DIR}/wrf.log" 2>&1 &
WRF_PID=$!

# Monitor progress
while kill -0 "${WRF_PID}" 2>/dev/null; do
    WRFOUT_COUNT=$(ls wrfout_d01_* 2>/dev/null | wc -l)
    LAST_TIME=$(grep "Timing for main" "${LOG_DIR}/wrf.log" 2>/dev/null | tail -1 | \
                grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9:]*' | head -1 || echo "initializing")
    echo "  wrf.exe: ${WRFOUT_COUNT} wrfout files, last timestep: ${LAST_TIME}"
    sleep 60
done

[ -w /mnt/wrfout ] && cp "${LOG_DIR}/wrf.log" "${PERSIST_LOG_DIR}/wrf.log"

if ls wrfout_d01_* 2>/dev/null | grep -q .; then
    WRFOUT_COUNT=$(ls wrfout_d01_* | wc -l)
    echo "  wrf.exe: OK — ${WRFOUT_COUNT} wrfout files"
    ls -lh wrfout_d01_* | sed 's/^/    /'
else
    echo "ERROR: wrf.exe produced no output — see ${LOG_DIR}/wrf.log"
    tail -30 "${LOG_DIR}/wrf.log"
    exit 1
fi

echo
echo "=== real.exe + wrf.exe complete ==="
echo "  Output: ${WRF_RUN_DIR}/wrfout_d01_*"
