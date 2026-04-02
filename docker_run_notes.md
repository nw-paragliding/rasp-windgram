# Running RASP/WXTOFLY Windgrams in Docker on Apple Silicon

## Goal

Generate a windgram PNG for the Tiger Mountain site (47.503°N, 121.975°W) using
March 30, 2026 6z NAM data, running the full RASP/WRF pipeline inside a Docker
container on an Apple Silicon (M-series) Mac.

---

## Environment

| Component | Detail |
|---|---|
| Host | Apple Silicon Mac (arm64) |
| Container runtime | Docker via Colima x86 QEMU profile |
| Colima profile | `colima start x86 --arch x86_64 --vm-type qemu --cpus 4 --memory 6` |
| Container base | `ubuntu:18.04` (x86_64) |
| QEMU emulation | TCG (full software emulation — no KVM available on macOS) |

---

## Pipeline Stages and Status

| Stage | Description | Status | Wall Time |
|---|---|---|---|
| 1a | NAM GRIB download | Skipped (host download) | — |
| 1b | grib_prep (6 files) | ✓ Complete | ~25 min |
| 1c | wrfprep.pl (hinterp/vinterp) | ✓ Complete | ~9 min |
| 1d | real.exe | ✓ Complete (after Intel fix) | ~3 min |
| 1e | wrf.exe (PNW outer domain) | ✓ Complete | ~5.5 hours |
| 2 | PNW-WINDOW ndown (wrfprep.pl) | ✗ Failing | — |
| 3 | TIGER-WINDOW WRF | Not reached | — |
| 4 | NCL windgram generation | Not reached | — |

---

## Challenges and Fixes

### 1. Ubuntu 18.04 base required
The pre-compiled `ncl_jack_fortran.so` and `wrf_user_fortran_util_0-64bit.so`
link against `libgfortran.so.3` (gcc 4.x ABI). Ubuntu 20.04+ dropped `libgfortran3`.
Ubuntu 18.04 is the newest LTS that ships it.

### 2. Intel ICC CPU vendor check (most significant blocker)
`real.exe`, `wrf.exe`, and `ndown.exe` were compiled with Intel ICC, which
embeds a runtime CPUID vendor check. The binary refuses to run unless
`vendor_id` reports `GenuineIntel`.

QEMU TCG defaults to `AuthenticAMD`, causing:
```
Fatal Error: This program was not built to run on the processor in your system.
The allowed processors are: Intel(R) processors with SSE4.2 and POPCNT instructions support.
```

**Fix:** Set `cpuType: "Cascadelake-Server"` in `~/.colima/x86/colima.yaml`.
Cascadelake-Server is an Intel CPU model that reports `GenuineIntel` and
includes SSE4.2 + POPCNT. Requires `colima stop x86 && colima start x86`.

### 3. Perl 5.26 `@INC` change
Perl 5.26 removed `.` from `@INC`, breaking `require "rasp.run.parameters.TIGER"`
in `rasp.pl` and `rasp2.pl` (which are run from the RASP/RUN directory).

**Fix:** `ENV PERL5LIB=/opt/rasp/RASP/RUN` in Dockerfile.

### 4. Missing execute permissions on binaries
Several files lacked execute permissions in the repo:
- `run.rasp`, `run.rasp2` (no file extension, missed by `*.sh` glob)
- `WRF/wrfsi/bin/*.exe` (32-bit grib_prep, hinterp, vinterp, etc.)
- `WRF/WRFV2/main/real.exe`, `wrf.exe`, `ndown.exe`
- `RASP/RUN/UTIL/*` (jdate2date, cnvgrib, rasp.multiftp — no extensions)

**Fix:** Explicit `chmod +x` and `find -exec chmod +x` calls added to Dockerfile.

### 5. curl not following HTTP→HTTPS redirects
The RASP `$BASEDIR/UTIL/curl` was a symlink to `/usr/bin/curl` with no `-L` flag.
NOMADS redirects `http://nomads.ncep.noaa.gov` → `https://`, resulting in 0-byte
GRIB downloads.

**Fix:** Replaced symlink with a wrapper script:
```sh
#!/bin/sh
exec /usr/bin/curl -L "$@"
```

### 6. Missing `siprd` and `log` directories under domain dirs
`wrfprep.pl` does `opendir/chdir` into `$MOAD_DATAROOT/siprd` and writes logs
to `$MOAD_DATAROOT/log/`. Neither directory exists in the repo and neither
is created by the scripts.

**Fix:** Added to Dockerfile:
```dockerfile
RUN find $BASEDIR/WRF/wrfsi/domains -mindepth 1 -maxdepth 1 -type d \
         -exec mkdir -p {}/siprd {}/log \;
```

### 7. Missing `RASP/RUN/OUT` and `RASP/HTML` directories
`run_cleanup.sh` and other scripts attempt to `find`/`cd` into these directories,
producing errors (non-fatal but noisy).

**Fix:** Added `mkdir -p` for both in the Dockerfile GRIB directory block.

### 8. QEMU container networking broken
Outbound TCP connections from containers hang indefinitely inside the Colima
x86 QEMU VM. DNS resolves but HTTP/HTTPS connections never complete.

**Workaround:** Download GRIB files on the host Mac and mount as a read-only
volume (`-v $HOME/rasp-data/grib:/mnt/grib:ro`). The GRIB download step in
`rasp.pnw.pl` is bypassed with the `-p` flag.

### 9. Currently failing: PNW-WINDOW wrfprep.pl
Stage 2 (PNW-WINDOW ndown run) fails at `wrfprep.pl` because the `log/`
directory fix above was not yet in the image when Stage 2 was first attempted.
Fix is in the current Dockerfile rebuild.

---

## Performance (QEMU TCG on Apple Silicon)

All timings are wall-clock inside the Colima x86 QEMU VM (4 vCPUs, 6 GB RAM,
full software x86 emulation):

| Step | Wall Time | Notes |
|---|---|---|
| `grib_prep.exe` × 6 | ~25 min total (~4 min each) | 32-bit x86 binary |
| `wrfprep.pl` (hinterp + vinterp) | ~9 min | PNW domain |
| `real.exe` | ~3 min | WRF preprocessor |
| `wrf.exe` (15h sim, 2 domains) | ~5.5 hours | 358% CPU utilization |
| Docker image build | ~5 min | Cached after first build |

**Memory:** `wrf.exe` peaked at ~535 MB RSS. Well within the 6 GB VM allocation.

**Disk:** wrfout files for PNW domain: ~640 MB (32 files, d01 + d02, hourly).

---

## Areas for Improvement

### A. wrfout persistence (implemented)
wrfout files are now saved to `~/rasp-data/wrfout/PNW/` on the host and
mounted read-only at `/mnt/wrfout`. `docker-run.sh` detects pre-computed
files and skips Stage 1 (saves ~6 hours on re-runs).

### B. QEMU networking
The broken container networking is a significant limitation — the pipeline
can't download GRIBs or upload results autonomously. Root cause unknown
(may be Colima sshfs + QEMU NAT interaction). Possible fixes to investigate:
- Switch Colima mount type to `9p` instead of `sshfs`
- Use `--network host` on the docker run command
- Investigate whether `colima start x86 --network-address` helps

### C. WRF execution time
~5.5 hours for a 15-hour simulation on QEMU TCG is impractical for daily
production use. On native x86_64 Linux hardware (or a cloud VM), the same
run takes 30–90 minutes. Options:
- Run on a small AWS/GCP x86 spot instance for the WRF step
- UWPNW shortcut path (UW pre-runs WRF daily — scripts not yet implemented)

### D. UWPNW shortcut path
`windgram_pipeline.md` describes a path that downloads pre-computed `wrfout`
files from the University of Washington, bypassing Stages 1–3 entirely.
The scripts (`run_uwpnw.sh`, `stage_uw_wrfout.sh`) do not yet exist in the
repo. This is a future research/implementation area.

### E. Daily automation
Once the pipeline runs end-to-end, automation would require:
- Fixing container networking (to download GRIBs and upload PNGs)
- A cron job or launchd plist to trigger the run after 6z NAM availability (~09 UTC)
- Deciding between full WRF run vs. UWPNW shortcut

---

*Last updated: 2026-03-31. Pipeline status: Stage 2 (PNW-WINDOW) fix in progress.*
