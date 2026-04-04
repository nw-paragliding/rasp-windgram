# RASP/WXTOFLY Pipeline Modernization Plan

## Background

The current pipeline runs inside a single `ubuntu:18.04` x86_64 Docker container,
emulated via QEMU TCG on an Apple Silicon (arm64) Mac using Colima. This means
every instruction passes through software x86 emulation, making compute-intensive
steps extremely slow:

- `wrf.exe` (PNW domain, 15h simulation): ~5.5 hours wall time
- `wrf.exe` (PNW-WINDOW, 12h simulation): ~3-4 hours wall time
- `grib_prep.exe` × 6 GRIB files: ~25 minutes

On native hardware (or a native arm64 build), WRF typically runs in 20-60 minutes
for comparable domains.

The pipeline also depends on pre-compiled 32-bit x86 wrfsi binaries
(`grib_prep.exe`, `hinterp.exe`, `vinterp.exe`, etc.) that are tied to an
obsolete WRF initialization system (WRFSi, superseded ~2009 by WPS).

---

## Phase 1 — Two-Image Split: Fast Modern + Legacy Slow

### Goal

Split the pipeline into two Docker images:

1. **`rasp-modern`** — native arm64, no emulation, handles WRF + NCL
2. **`rasp-legacy`** — x86_64 QEMU, handles wrfsi 32-bit GRIB preprocessing only

This eliminates emulation overhead for the most expensive steps (WRF) while
keeping the legacy image narrowly scoped to the 25-minute grib_prep step.

---

### 1A — Recompile WRF Natively (Biggest Win)

**What:** Recompile `wrf.exe`, `real.exe`, `ndown.exe` for arm64 (or x86_64
native Linux) using gfortran instead of Intel ICC.

**Expected speedup:** 10-20x over QEMU TCG emulation. WRF on a 4-core arm64
Mac for the PNW domain should run in 20-40 minutes instead of 5.5 hours.

**WRF version choices — critical constraint discovered during implementation:**

WRF 3.0+ `real.exe` reads **WPS metgrid format** (`met_em.d01.*` files). The
current wrfsi preprocessing chain (hinterp.exe → vinterp.exe) produces
**WRF-SI intermediate format**, which WRF 3.0+ `real.exe` cannot read.

This means WRF 4.x cannot be used as a drop-in binary replacement without also
migrating to WPS (Phase 2). The viable options are:

**Option A (recommended first attempt): Compile WRF 2.2 on arm64**
- Same version as existing binaries — fully compatible with wrfsi output
- Drop-in replacement: no changes to wrfprep.pl, namelists, or preprocessing
- Risk: WRF 2.2 is old Fortran 77/90 code; may not compile cleanly on gfortran 11
- WRF 2.2 source: https://www2.mmm.ucar.edu/wrf/src/WRFV2.2.TAR.gz
- If this works, it delivers the full Phase 1 speedup with minimal risk

**Option B: WRF 4.x + WPS (Phase 1 + Phase 2 combined)**
- Eliminates legacy image entirely; one native arm64 image does everything
- More work: requires WPS domain setup, namelist.wps for each domain, GEOG data
- WRF 4.5 builds cleanly on arm64 (confirmed: Dockerfile.modern builder stage works)
- See Phase 2 section for WPS migration details

**Option C: WRF 3.9.1 + WPS**
- Middle ground: WPS required (same constraint as 4.x), but namelists closer to v2.x
- Probably not worth the extra complexity vs. going straight to 4.x

**Current status:** Option A attempted and abandoned. WRF 2.2 has no aarch64
support in its build system (configure.defaults was written ~2005, predates
64-bit ARM Linux). Adding arm64 support would require patching the configure
script and configure.defaults, plus unknown Fortran code issues on top.

**Decision: proceed with Option B (WRF 4.5 + WPS).** WRF 4.5 already builds
cleanly on arm64 (confirmed). WPS migration is the additional work, but it is
well-documented and eliminates the legacy image entirely.

**WRF 4.5 build status:** Successfully compiled on arm64 (Dockerfile.modern,
builder stage `wrf-builder`). HDF5 library naming fix required for ubuntu 22.04:
ubuntu names the HL Fortran lib `libhdf5hl_fortran` (no underscore) while WRF
links against `-lhdf5_hl_fortran`. Fixed via symlink in Dockerfile.modern.

**Build dependencies for `rasp-modern` image:**
```
gfortran
netcdf-c + netcdf-fortran
hdf5 (with libhdf5_hl_fortran symlink fix for ubuntu 22.04)
libpng
zlib
```

**Uncertainties:**
- WRF v2.2 with gfortran on arm64: likely Fortran 77 argument mismatch errors.
  Try `-fallow-argument-mismatch` and `-fallow-invalid-boz`. netCDF3 (not netCDF4)
  API used — WRF 2.2 predates netCDF4, so link against `-lnetcdf` only, not
  `-lnetcdff` (the Fortran-specific netCDF4 lib).
- WRF 2.2 source may require netCDF3-compatible headers; ubuntu 22.04 ships
  netCDF 4.8 which includes the netCDF3 API but the Fortran include paths differ.

**Things to try:**
1. ~~Start with WRF 4.5~~ → Done: builds cleanly but incompatible with wrfsi output
2. Try WRF 2.2 on ubuntu:22.04 arm64 with `-fallow-argument-mismatch`
3. If WRF 2.2 gfortran compile fails, try ubuntu:20.04 (gfortran 9, more tolerant)
4. If all arm64 WRF 2.2 attempts fail, proceed to Option B (WPS + WRF 4.5)

---

### 1B — Recompile NCL Libraries Natively

**What:** Build `ncl_jack_fortran.so` and `wrf_user_fortran_util_0-64bit.so`
for arm64.

**ncl_jack_fortran.so:**
- DrJack's atmosphere calculation library, written in Fortran 90
- Source: likely available in the RASP distribution or from drjack.info
- Build: `gfortran -shared -fPIC -o ncl_jack_fortran.so *.f90`
- Uncertainty: source may not be publicly available; check `model/INSTALL/` for
  any source archives

**wrf_user_fortran_util_0-64bit.so:**
- Part of WRF's NCL utility package
- Source: in the WRF distribution at `WRF/var/graphics/ncl/` or the WRF NCL
  scripts package available from NCAR
- Build: standard gfortran shared library compile

**NCL itself:**
- Install via conda: `conda install -c conda-forge ncl`
- Available for both arm64 (Apple Silicon) and x86_64
- No compilation needed

---

### 1C — Keep wrfsi in Legacy Image (Narrowly Scoped)

**What:** The existing `ubuntu:18.04` x86_64 image, but stripped down to only
run the grib_prep stage. It mounts GRIB files and writes `extdata/extprd/` files
to a shared volume.

**Pipeline flow with two images:**
```
[host] download NAM GRIBs
    ↓
[rasp-legacy, QEMU x86] grib_prep × 6 files (~25 min)
    writes → /mnt/extprd/ETA:*
    ↓
[rasp-modern, native arm64] wrfprep.pl + real.exe + wrf.exe + NCL (~30-60 min)
    reads ← /mnt/extprd/ETA:*
    writes → windgram PNGs
```

**Uncertainty:** `wrfprep.pl` (Perl, 32-bit wrfsi support tools) still lives in
the wrfsi ecosystem. The question is whether `hinterp.exe` and `vinterp.exe`
(also 32-bit wrfsi binaries) need to run in the legacy container too. Most likely
yes — they process the extprd files into WRF-readable initial conditions, and
they're part of the same 32-bit binary set. So the legacy container scope
is: cnvgrib → grib_prep.exe → hinterp.exe → vinterp.exe.

---

## Phase 2 — Migrate wrfsi → WPS, Unified Modern Image

### Goal

Replace the 32-bit wrfsi preprocessing chain with WPS (WRF Preprocessing System),
eliminating the legacy image entirely. Single `rasp-modern` arm64 image runs
the full pipeline natively.

### What WPS Replaces

| wrfsi binary | WPS equivalent | Notes |
|---|---|---|
| `grib_prep.exe` | `ungrib.exe` | Extracts fields from GRIB/GRIB2, writes intermediate format |
| `hinterp.exe` | `geogrid.exe` + `metgrid.exe` | Horizontal interpolation to WRF grid |
| `vinterp.exe` | handled internally by WRF `real.exe` | Vertical interpolation now done by real.exe |
| `staticpost.exe` | `geogrid.exe` | Static geographic data processing |
| `gridgen_model.exe` | `geogrid.exe` | Domain grid generation |

### WPS Migration Steps

1. **Install WPS** (same version as WRF, e.g., WPS 4.5 with WRF 4.5)
2. **Create `namelist.wps`** for each domain (PNW, PNW-WINDOW, TIGER-WINDOW)
   - Domain parameters (dx, dy, grid dimensions, projection) come from the
     existing wrfsi domain configs in `model/WRF/wrfsi/domains/*/static/`
   - NAM Vtable: use `Vtable.NAM` from the WPS distribution
3. **Replace `grib_prep.pl` calls** in `rasp.pl` with `ungrib.exe` calls
4. **Replace `wrfprep.pl`** with `geogrid.exe` + `metgrid.exe` calls
   (or write a wrapper that presents the same interface to `rasp.pl`)
5. **Download static geographic data** (GEOG) in WPS format — different from
   wrfsi's extdata/GEOG format

### Key Uncertainties

- **Domain projection**: wrfsi and WPS use the same Lambert Conformal projection
  parameters, but verify that `TRUELAT1`, `TRUELAT2`, `STAND_LON`, `REF_LAT`,
  `REF_LON` map correctly between wrfsi's `wrfsi.nl` and WPS's `namelist.wps`
- **GEOG data**: wrfsi uses its own static geographic dataset. WPS GEOG data
  is available from NCAR. **Current approach**: use mandatory low/medium
  resolution package (~3 GB, ~8 GB unpacked) via `setup_geog.sh`, mounted as
  `/mnt/geog` volume. `geo_em.d0*.nc` output cached in `/mnt/wrfout/geo_em/`
  so geogrid.exe runs only once. **Future improvement**: for better forecast
  quality (higher-res terrain/land-use), replace with 30-arcsecond datasets or
  domain-specific tile downloads. Also consider baking the PNW tiles into the
  image once domains are stable (eliminates the volume mount, faster cold starts).
  See: Phase 3 / productionization notes below.
  The domains are
  already defined so only the relevant tiles are needed.
- **rasp.pl orchestration**: `rasp.pl` has deep wrfsi assumptions (directory
  structure, file naming, log parsing). Either patch rasp.pl or write a WPS
  wrapper that mimics wrfsi's output structure. The wrapper approach is less
  invasive.
- **ndown.exe**: WPS doesn't replace ndown. The nested domain approach
  (PNW → PNW-WINDOW → TIGER-WINDOW) still uses ndown.exe, which is part of
  WRF itself and will be recompiled natively in Phase 1.

### Things to Try

1. Start with just the PNW outer domain — get `ungrib.exe` + `metgrid.exe` →
   `real.exe` → `wrf.exe` working end-to-end before tackling nested domains
2. Use `nccmp` or `ncview` to compare wrfout fields between the wrfsi-based
   and WPS-based runs to verify they're producing equivalent output
3. The RASP community (drjack.info forums) may have notes on WPS migration;
   some RASP operators have made this transition

---

## Summary: Effort vs. Impact

| Task | Effort | Impact |
|---|---|---|
| Recompile WRF natively (arm64) | Medium | ★★★★★ — eliminates 5.5h WRF step |
| Recompile NCL libs natively | Low | ★★★ — NCL runs faster natively |
| Wrfsi → WPS migration | High | ★★★ — eliminates legacy image |
| WRF v2.2 → WRF 4.x upgrade | Medium | ★★ — better long-term maintainability |

**Recommended Phase 1 starting point:** Recompile WRF 4.x on arm64 inside a
clean `ubuntu:22.04` container. If WRF 4.x runs correctly with the existing
domain configs and produces usable windgrams, that's the majority of the value
with a fraction of the Phase 2 effort.

---

## Docker Build Strategy

Use a **multi-stage build** to keep the final image lean and the build fully
reproducible. The implementing agent should never leave manually-compiled
binaries committed to the repo.

```dockerfile
# syntax=docker/dockerfile:1

# ── Stage 1: build WRF + NCL libraries ───────────────────────────────────────
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    gfortran libnetcdf-dev libnetcdff-dev \
    libhdf5-dev zlib1g-dev libpng-dev \
    openmpi-bin libopenmpi-dev \
    wget git m4 perl csh

# Download WRF source at a pinned version (no large tarballs in the repo)
ARG WRF_VERSION=v4.5.2
RUN git clone --depth 1 --branch ${WRF_VERSION} \
    https://github.com/wrf-model/WRF /build/WRF

# Configure and compile WRF (serial or dmpar)
WORKDIR /build/WRF
RUN echo 34 | ./configure   # option 34 = gfortran + dmpar (adjust per platform)
RUN ./compile em_real 2>&1 | tee compile.log
RUN test -f main/wrf.exe && test -f main/real.exe && test -f main/ndown.exe

# Compile ncl_jack_fortran.so from source (if source is available)
# COPY model/INSTALL/SRC/ncl_jack_fortran/ /build/ncl_jack/
# RUN cd /build/ncl_jack && gfortran -shared -fPIC -o ncl_jack_fortran.so *.f90

# ── Stage 2: runtime image ────────────────────────────────────────────────────
FROM ubuntu:22.04

# Copy only the compiled binaries from builder — no compilers in final image
COPY --from=builder /build/WRF/main/wrf.exe    /opt/rasp/WRF/WRFV2/main/
COPY --from=builder /build/WRF/main/real.exe   /opt/rasp/WRF/WRFV2/main/
COPY --from=builder /build/WRF/main/ndown.exe  /opt/rasp/WRF/WRFV2/main/

# Install runtime libs only (not compilers)
RUN apt-get install -y libnetcdf-dev libhdf5-dev openmpi-bin ...

COPY model/ /opt/rasp/
```

**Source code strategy:**
- WRF: `git clone` at a pinned tag during build (internet required at build time)
- NCL: install via conda or download binary from NCAR (no compilation needed)
- `ncl_jack_fortran.so`: compile from source in builder stage IF source is
  available; otherwise treat as a repo asset in `model/INSTALL/SRC/`
- `wrf_user_fortran_util`: compile from WRF's own source tree in builder stage

**What NOT to do:**
- Don't commit compiled `.exe` or `.so` files to the repo
- Don't require manual steps outside of `docker build`
- Don't use `ubuntu:18.04` or any image that requires libgfortran3

---

## Relevant Files in This Repo

| File | Purpose |
|---|---|
| `model/WRF/WRFV2/main/wrf.exe` | Pre-compiled Intel ICC binary (replace) |
| `model/WRF/WRFV2/main/real.exe` | Pre-compiled Intel ICC binary (replace) |
| `model/WRF/WRFV2/main/ndown.exe` | Pre-compiled Intel ICC binary (replace) |
| `model/WRF/wrfsi/domains/PNW/static/wrfsi.nl` | Domain config (reference for WPS namelist) |
| `model/WRF/wrfsi/domains/PNW/static/wrf.nl` | WRF namelist template (reference) |
| `model/WRF/NCL/windgrams.ncl` | NCL windgram script (reads wrfout, no changes needed) |
| `model/WRF/NCL/rasp.ncl` | NCL RASP post-processing script |
| `model/INSTALL/LIB/NCL/ncl_jack_fortran.so` | Pre-compiled Fortran lib (recompile for arm64) |
| `model/RASP/RUN/rasp.pl` | Pipeline orchestrator (wrfsi-specific, needs WPS wrapper in Ph2) |
| `Dockerfile` | Current ubuntu:18.04 x86 image |
| `Dockerfile.modern` | New arm64 image: WRF 4.5.2 + WPS 4.5 (Phase 1/2) |
| `docker_run_notes.md` | Session notes: what worked, timings, issues encountered |
| `setup_geog.sh` | One-time GEOG download to `$HOME/rasp-data/wps-geog` |
| `model/WRF/WPS/namelist.wps.PNW` | WPS namelist template (dates/geog_path filled at runtime) |
| `model/WRF/WPS/run_wps.sh` | Runs ungrib+geogrid+metgrid for a forecast cycle |

---

## Phase 3 — Productionization and Forecast Quality

These are deferred until Phase 2 WPS migration is working end-to-end.

### GEOG data resolution
- **Current**: mandatory low/medium resolution package, mounted as `/mnt/geog` volume
- **Improvement**: download 30-arcsecond terrain (`topo_30s`), 30-arcsecond land use
  (`modis_landuse_20class_30s`), and 30-arcsecond soil type for PNW domain bounds only
  — roughly 1/5th the size, much higher quality for soaring terrain
- **Productionization**: once domains are stable, bake the PNW-only GEOG tiles directly
  into the image (eliminates the volume mount, avoids a cold-start download step)

### GEOG tile bounds for PNW domain
Approximate bounding box to subset the full GEOG datasets:
- Lat: 40°N – 54°N
- Lon: 133°W – 110°W
The `geogrid.exe` already subsets by domain; downloading the full global dataset is
just wasteful at build time. NCAR provides per-tile downloads for most high-res datasets.

### Vtable selection
- Current: `Vtable.NAMb` (NAM GRIB2 on pressure levels — awip3d files)
- If switching to NAM on native eta/sigma levels (awip3d1 files): use `Vtable.NAM`
- Pressure-level input works fine for RASP use; eta-level may give slightly better
  initial conditions for planetary boundary layer fields

### Colima / container runtime
- Current: single `rasp-modern` container on `colima default` (arm64 native)
- Future: consider running on a cloud arm64 instance for fully headless daily runs
  (AWS Graviton, Hetzner ARM) to eliminate the Mac dependency entirely
