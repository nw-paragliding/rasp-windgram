#!/bin/bash
# docker-run.sh — RASP pipeline startup script for use inside the container.
# Pre-stages GRIB files from /mnt/grib and runs the full PNW → TIGER windgram pipeline.
#
# Volume mounts:
#   /mnt/grib            — NAM GRIB2 files (read-only)
#   /mnt/wrfout          — persistent cache: wrfout/ and extprd/ subdirs (read-write)
#   /opt/rasp/WXTOFLY/WINDGRAMS/OUT — PNG output destination
#
# Stage 1 acceleration tiers (checked in order):
#   Tier A: /mnt/wrfout/extprd/ has files  AND  /mnt/wrfout/PNW/ has ≥16 wrfout files
#           → restore both, skip grib_prep AND WRF entirely (~0 min)
#   Tier B: /mnt/wrfout/PNW/ has ≥16 wrfout files but no extprd
#           → run grib_prep only (~25 min), copy saved wrfout, skip WRF
#   Tier C: no pre-computed data
#           → full Stage 1: grib_prep + WRF (~6h)
#           → saves wrfout + extprd to /mnt/wrfout/ for future Tier A runs

set -e

source /opt/rasp/WXTOFLY/wxtofly.env
export WXTOFLY_DOWNLOAD_RUN_CONFIG=NO
export WXTOFLY_UPLOAD_ENABLED=NO
export PERL5LIB=/opt/rasp/RASP/RUN

INIT=6
INIT_PAD=$(printf "%02d" $INIT)   # zero-padded: 06

# March 30 2026 = Julian day 89 (Jan 31 + Feb 28 + Mar 30 = 89)
# Matches the nam.t06z.* files in /mnt/grib
GRIB_DATE=89_2026

echo "=== RASP/WXTOFLY Pipeline ==="
echo "INIT=${INIT}z  GRIB_DATE=${GRIB_DATE}"
echo "BASEDIR=${BASEDIR}"

# Cleanup old GRIB/output files
$WXTOFLY_RUN/run_cleanup.sh $INIT

# -------------------------------------------------------------------
# Helper: run grib_prep for all staged GRIB files without running WRF.
# Populates $BASEDIR/WRF/wrfsi/extdata/extprd/ETA:YYYY-MM-DD_HH files.
# Requires GRIB files already in $BASEDIR/RASP/RUN/ETA/GRIB/.
# -------------------------------------------------------------------
run_grib_prep_only() {
    echo "  Running cnvgrib + grib_prep.pl for each GRIB file..."

    local JULDAY YEAR BASE_DATE
    JULDAY=$(echo "$GRIB_DATE" | cut -d_ -f1)
    YEAR=$(echo "$GRIB_DATE" | cut -d_ -f2)
    BASE_DATE=$(date -d "${YEAR}-01-01 + $((JULDAY - 1)) days" +%Y%m%d)

    local GRIB_DIR="$BASEDIR/RASP/RUN/ETA/GRIB"
    local ETC_DIR="$BASEDIR/WRF/wrfsi/etc"
    local EXTPRD_LOG="$BASEDIR/WRF/wrfsi/extdata/log"
    mkdir -p "$EXTPRD_LOG"

    for fh in 06 09 12 15 18 21; do
        local fname="nam.t${INIT_PAD}z.awip3d${fh}.tm00.grib2"
        local total_hours=$(( INIT + 10#$fh ))
        local valid_dt
        valid_dt=$(date -d "${BASE_DATE} ${total_hours} hours" +%Y%m%d%H)

        echo "    grib_prep: ${fname} → valid ${valid_dt}"
        $BASEDIR/RASP/RUN/UTIL/cnvgrib -g21 -nv \
            "${GRIB_DIR}/${fname}" "${GRIB_DIR}/${fname}.cnvgrib.out" 2>/dev/null
        # grib_prep.exe resolves -f as a filename relative to SRCPATH (the GRIB dir),
        # so pass only the basename, not the full path.
        ( cd "$ETC_DIR" && ./grib_prep.pl \
            -f "${fname}.cnvgrib.out" \
            -l 0 -t 1 -s "${valid_dt}" ETA \
            >| "${EXTPRD_LOG}/grib_prep.ETA.${valid_dt}.stdout" 2>&1 )
        echo "    grib_prep done: ${valid_dt}"
    done

    echo "  extprd populated: $(ls $BASEDIR/WRF/wrfsi/extdata/extprd/ 2>/dev/null | wc -l) files"
}

# -------------------------------------------------------------------
# Stage 1: PNW outer domain
# -------------------------------------------------------------------
PNW_WRFOUT_COUNT=$(ls /mnt/wrfout/PNW/wrfout_d0* 2>/dev/null | wc -l || echo 0)
EXTPRD_COUNT=$(ls /mnt/wrfout/extprd/ETA:* 2>/dev/null | wc -l || echo 0)

if [ "$PNW_WRFOUT_COUNT" -ge 16 ] && [ "$EXTPRD_COUNT" -ge 6 ]; then
    echo
    echo "=== Stage 1 [Tier A]: Restoring $PNW_WRFOUT_COUNT wrfout + $EXTPRD_COUNT extprd files — skipping grib_prep and WRF ==="
    mkdir -p $BASEDIR/WRF/WRFV2/RASP/PNW
    cp /mnt/wrfout/PNW/wrfout_* $BASEDIR/WRF/WRFV2/RASP/PNW/
    mkdir -p $BASEDIR/WRF/wrfsi/extdata/extprd
    cp /mnt/wrfout/extprd/ETA:* $BASEDIR/WRF/wrfsi/extdata/extprd/
    echo "Stage 1 complete — $(ls $BASEDIR/WRF/WRFV2/RASP/PNW/wrfout_d0* | wc -l) wrfout, $(ls $BASEDIR/WRF/wrfsi/extdata/extprd/ | wc -l) extprd"

elif [ "$PNW_WRFOUT_COUNT" -ge 16 ]; then
    echo
    echo "=== Stage 1 [Tier B]: $PNW_WRFOUT_COUNT pre-computed wrfout files found — running grib_prep only, skipping WRF ==="
    mkdir -p $BASEDIR/RASP/RUN/ETA/GRIB
    cp /mnt/grib/*.grib2 $BASEDIR/RASP/RUN/ETA/GRIB/
    run_grib_prep_only
    mkdir -p $BASEDIR/WRF/WRFV2/RASP/PNW
    cp /mnt/wrfout/PNW/wrfout_* $BASEDIR/WRF/WRFV2/RASP/PNW/
    echo "Stage 1 complete — $(ls $BASEDIR/WRF/WRFV2/RASP/PNW/wrfout_d0* | wc -l) wrfout files in PNW/"

    # Save extprd for future Tier A runs
    if [ -w /mnt/wrfout ]; then
        echo "  Saving extprd to /mnt/wrfout/extprd/ for future runs..."
        mkdir -p /mnt/wrfout/extprd
        cp $BASEDIR/WRF/wrfsi/extdata/extprd/ETA:* /mnt/wrfout/extprd/ 2>/dev/null && \
            echo "  Saved $(ls /mnt/wrfout/extprd/ | wc -l) extprd files"
    fi

else
    echo
    echo "=== Stage 1 [Tier C]: Full run — grib_prep + WRF ==="
    mkdir -p $BASEDIR/RASP/RUN/ETA/GRIB
    cp /mnt/grib/*.grib2 $BASEDIR/RASP/RUN/ETA/GRIB/
    echo "GRIB files staged:"
    ls -lh $BASEDIR/RASP/RUN/ETA/GRIB/

    $WXTOFLY_RUN/run_rasp.sh \
        PNW \
        $WXTOFLY_RUN/PARAMETERS/rasp.run.parameters.PNW.6z.0 \
        -p $GRIB_DATE

    echo "Stage 1 complete — $(ls $BASEDIR/WRF/WRFV2/RASP/PNW/wrfout_d0* 2>/dev/null | wc -l) wrfout files in PNW/"

    # Save wrfout + extprd for future Tier A runs
    if [ -w /mnt/wrfout ]; then
        echo "  Saving wrfout + extprd to /mnt/wrfout/ for future runs..."
        mkdir -p /mnt/wrfout/PNW /mnt/wrfout/extprd
        cp $BASEDIR/WRF/WRFV2/RASP/PNW/wrfout_* /mnt/wrfout/PNW/ && \
            echo "  Saved $(ls /mnt/wrfout/PNW/ | wc -l) wrfout files"
        cp $BASEDIR/WRF/wrfsi/extdata/extprd/ETA:* /mnt/wrfout/extprd/ 2>/dev/null && \
            echo "  Saved $(ls /mnt/wrfout/extprd/ | wc -l) extprd files"
    fi
fi

# -------------------------------------------------------------------
# Stage 2: PNW window domain run (ndown → PNW-WINDOW wrfout)
#   -q  => skip grib_prep (extprd already populated by Stage 1)
# -------------------------------------------------------------------
echo
echo "=== Stage 2: PNW-WINDOW nested WRF (ndown) ==="
$WXTOFLY_RUN/run_rasp.sh \
    PNW \
    $WXTOFLY_RUN/PARAMETERS/rasp.run.parameters.PNW.6z.1 \
    -q $GRIB_DATE

echo "Stage 2 complete — $(ls $BASEDIR/WRF/WRFV2/RASP/PNW-WINDOW/wrfout_d0* 2>/dev/null | wc -l) wrfout files in PNW-WINDOW/"

# -------------------------------------------------------------------
# Stage 3: TIGER-WINDOW nested WRF run
#   run_rasp_nested.sh copies wrfout from PNW-WINDOW, runs rasp2.pl
# -------------------------------------------------------------------
echo
echo "=== Stage 3: TIGER-WINDOW nested WRF ==="
$WXTOFLY_RUN/run_rasp_nested.sh \
    PNW TIGER \
    $WXTOFLY_RUN/PARAMETERS/rasp.run.parameters.TIGER.6z

echo "Stage 3 complete — $(ls $BASEDIR/WRF/WRFV2/RASP/TIGER-WINDOW/wrfout_d0* 2>/dev/null | wc -l) wrfout files in TIGER-WINDOW/"

# -------------------------------------------------------------------
# Stage 4: Generate TIGER-WINDOW windgrams
# -------------------------------------------------------------------
echo
echo "=== Stage 4: Generate windgrams for TIGER-WINDOW ==="
$WXTOFLY_WINDGRAMS/get_windgrams.sh TIGER-WINDOW PNW TIGER-WINDOW

echo
echo "=== Pipeline finished ==="
echo "Windgram output:"
find $WXTOFLY_WINDGRAMS/OUT/TIGER-WINDOW -name "*.png" 2>/dev/null || echo "(no PNG files found)"
