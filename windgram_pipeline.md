# Windgram Generation Pipeline

This document describes the end-to-end pipeline for generating windgram images, and the runtime environment requirements for each stage. It is intended to support work on making windgrams easier to produce on Ubuntu and/or macOS.

---

## Overview

A windgram is a PNG image showing forecast atmospheric conditions (wind, temperature, humidity, soaring indices) at a specific lat/lon site across forecast hours. Generating one requires:

1. Obtaining model input data (NAM or HRRR GRIB files, or pre-staged UW WRF output)
2. Running WRF to produce gridded atmospheric output — **or** using pre-computed WRF output (UWPNW path)
3. Running an NCL plotting script against the WRF output to produce a PNG

---

## Pipeline Stages

### Stage 1 — Obtain Model Input Data

**What happens:** GRIB2 files are downloaded from NOAA/NOMADS for the NAM (North American Mesoscale) or HRRR (High-Resolution Rapid Refresh) model. For the UWPNW domain, pre-staged `wrfout` files from the University of Washington are used instead, skipping stages 2–3.

**Scripts involved:**
- `model/WXTOFLY/UTIL/fetch_hrrr.sh` — downloads HRRR GRIB2 files
- Stage-specific parameter files in `model/WXTOFLY/RUN/PARAMETERS/` define which model, which hours, and how many GRIB files to fetch

**Inputs:** NOMADS HTTP endpoint, forecast initialization time, region name

**Outputs:** GRIB/GRIB2 files in a working directory under `$BASEDIR`

**Runtime requirements:**
| Requirement | Notes |
|---|---|
| OS | Linux or macOS |
| Shell | bash |
| `curl` or `wget` | HTTP download of GRIB files |
| `wgrib2` | Verifying/inspecting GRIB2 files (optional but common) |
| Internet access | NOMADS or equivalent GRIB source |
| Disk space | ~500 MB per model run |

---

### Stage 2 — GRIB Preprocessing (`grib_prep`)

**What happens:** Raw GRIB files are processed into the format expected by WRF's input pre-processor (WPS/SI). This involves field extraction, unit conversion, and writing intermediate binary format files.

**Scripts/executables involved:**
- `model/WRF/wrfsi/bin/grib_prep.exe` — **pre-compiled 32-bit x86 binary**
- Called by `model/RASP/RUN/rasp.pl`

**Inputs:** GRIB files from Stage 1, static domain configuration in `model/WRF/wrfsi/domains/`

**Outputs:** WPS intermediate format files in a working directory

**Runtime requirements:**
| Requirement | Notes |
|---|---|
| OS | Linux (32-bit x86 binary; requires 32-bit compatibility layer on 64-bit Linux; **not natively supported on macOS**) |
| 32-bit libs | `libc6:i386`, `libgcc-s1:i386` (Ubuntu: `dpkg --add-architecture i386`) |
| `model/INSTALL/UTIL/enable_32_bit_support.sh` | Install script for 32-bit support |
| Disk space | ~200 MB per run |

> **Note:** `grib_prep.exe`, `gridgen_model.exe`, `hinterp.exe`, `staticpost.exe`, and `vinterp.exe` are all pre-compiled 32-bit binaries in `model/WRF/wrfsi/bin/`. This is a key portability constraint.

---

### Stage 3 — WRF Model Run

**What happens:** WRF (Weather Research and Forecasting) model is initialized and run, producing gridded atmospheric output at high resolution (1.3–12 km). This is the most computationally expensive step.

**Scripts/executables involved:**
- `wrfprep.pl` — generates WRF namelists and prepares input
- `wrf.exe` — WRF model executable (compiled for the target platform)
- Called by `model/RASP/RUN/rasp.pl`

**Inputs:** WPS intermediate files from Stage 2, static geographic data in `model/WRF/wrfsi/extdata/GEOG/`

**Outputs:** `wrfout_d01_*` and `wrfout_d02_*` NetCDF files in `$BASEDIR/WRF/WRFV2/RASP/<DOMAIN>/`

**Runtime requirements:**
| Requirement | Notes |
|---|---|
| OS | Linux (WRF is compiled from source for the target platform) |
| CPU | 2–4 cores recommended; WRF is MPI-parallelizable |
| RAM | 1–2 GB minimum for typical PNW domain sizes |
| NetCDF | Required by WRF; version 3.6+ |
| HDF5 | Required by NetCDF4 |
| MPI | OpenMPI or MPICH for parallel runs |
| Fortran compiler | gfortran (for compiling WRF from source) |
| Disk space | 1–2 GB per run (wrfout files are large) |
| Time | 30–90 minutes depending on domain size and CPU count |

> **Skipped for UWPNW:** The UWPNW path (`model/WXTOFLY/UTIL/stage_uw_wrfout.sh`) downloads pre-computed `wrfout` files from the University of Washington, bypassing Stages 1–3 entirely.

---

### Stage 4 — RASP Post-processing (NCL/Fortran)

**What happens:** RASP-specific parameters (thermal strength, BL height, cloud base, soaring indices) are computed from WRF output using NCL scripts and a custom Fortran shared library. Results are written to ASCII `.data` files used by the blipspot extractor.

**Scripts/executables involved:**
- `model/RASP/RUN/rasp.pl` — orchestrates all post-processing
- NCL scripts in `$BASEDIR/WRF/NCL/`
- `$BASEDIR/WRF/NCL/ncl_jack_fortran.so` — **DrJack's custom Fortran shared library**, compiled for the target platform

**Inputs:** `wrfout_d02_*` NetCDF files, RASP parameter lists from parameter files

**Outputs:** ASCII forecast data files in `$BASEDIR/RASP/HTML/<REGION>/FCST/*.data`

**Runtime requirements:**
| Requirement | Notes |
|---|---|
| OS | Linux (library is compiled from Fortran source) |
| NCL | NCAR Command Language 5.1.1+; NCARG_ROOT env var must be set |
| NCARG | NCAR graphics library (part of NCL distribution) |
| Fortran | gfortran needed to compile `ncl_jack_fortran.so` |
| Perl | perl 5.x + `Proc::Background` module |
| `ncl_jack_fortran.so` | Must be compiled for the target OS/arch |
| Time | 20–40 minutes per domain |

---

### Stage 5 — Windgram Image Generation (NCL)

**What happens:** This is the windgram-specific step. NCL reads `wrfout` NetCDF files directly, extracts variables at the nearest grid point to each site, performs atmospheric calculations, and plots the windgram panel as a PNG.

**Scripts involved:**
- `model/WXTOFLY/WINDGRAMS/get_windgrams.sh` — wrapper that filters sites and invokes NCL
- `model/WXTOFLY/WINDGRAMS/windgrams.ncl` — 1971-line NCL plotting script

**Key parameters set by `get_windgrams.sh`:**
| Parameter | Description | Example values |
|---|---|---|
| `outputDir` | Where PNGs are written | `$WXTOFLY_WINDGRAMS/OUT/PNW/d2/` |
| `siteListCsv` | Filtered list of sites (name, lat, lon) | temp file from `sites.csv` |
| `wrfDomain` | WRF domain subfolder name | `PNW`, `WAHRRR` |
| `grid` | Resolution grid identifier | `d2`, `w2` |
| `ptop` | Pressure ceiling for y-axis | `30` (PNW), `28` (windows) |
| `rhcut` | RH threshold for humidity shading | `94` |
| `type` | Output format | `png` |

**WRF variables read by `windgrams.ncl`:**
- `P`, `PB` — pressure (perturbation + base)
- `T` — potential temperature (perturbation)
- `U`, `V`, `W` — wind components (destaggered)
- `QVAPOR` — water vapor mixing ratio
- `PBLH` — planetary boundary layer height
- `HGT` — terrain height
- `PSFC` — surface pressure
- `PH`, `PHB` — geopotential height
- `CLDFRA` — cloud fraction (optional)
- `XLAT`, `XLONG`, `Times` — grid coordinates and time

**Inputs:** `wrfout_d02_*` NetCDF files (from Stage 3 or UWPNW), filtered `site_list.csv`

**Outputs:** `<YYYYMMDD>_<SITENAME>_windgram.png` in output directory

**Runtime requirements:**
| Requirement | Notes |
|---|---|
| OS | Linux or macOS (NCL is available for both) |
| NCL | 6.2+ recommended (`fileexists()` used); NCARG_ROOT must be set |
| NCARG | NCAR graphics library |
| `ncl_jack_fortran.so` | Must be compiled and loadable by NCL |
| `WRFUserARW.ncl` | WRF NCL utility library (included with WRF or NCL) |
| Fortran compiler | gfortran (to compile `ncl_jack_fortran.so`) |
| NetCDF | For reading `wrfout` files |
| RAM | ~500 MB per NCL invocation |
| Time | 5–20 minutes for a full site list |

> **macOS note:** NCL can be installed via conda (`conda install -c conda-forge ncl`). The `ncl_jack_fortran.so` Fortran library must be recompiled for macOS (arm64 or x86_64). This is currently the primary portability barrier for windgrams on macOS.

---

### Stage 6 — PNG Optimization

**What happens:** ImageMagick reduces the bit depth of generated PNGs to decrease file size before upload.

**Command:**
```bash
convert FILE -depth 4 TEMPFILE && convert TEMPFILE FILE
```

**Inputs:** Raw PNG from Stage 5

**Outputs:** Compressed PNG (same path)

**Runtime requirements:**
| Requirement | Notes |
|---|---|
| OS | Linux or macOS |
| `convert` (ImageMagick) | Any recent version |

---

### Stage 7 — Upload

**What happens:** Optimized PNGs are queued and transferred to wxtofly.net via FTP.

**Scripts involved:**
- `model/WXTOFLY/UTIL/upload_queue_add.sh` — atomically stages files for upload
- `model/WXTOFLY/UTIL/upload_start.sh` / `upload_all.sh` — transfers queued files

**Runtime requirements:**
| Requirement | Notes |
|---|---|
| OS | Linux or macOS |
| `ftp` or `lftp` | For FTP transfer |
| FTP credentials | Set in `model/WXTOFLY/wxtofly.env` |
| Outbound FTP access | Port 21 |

---

## Summary: Requirements by Stage

| Stage | Key Binaries | OS | Blocking Constraint |
|---|---|---|---|
| 1. Fetch GRIB | `curl`, `wgrib2` | Linux / macOS | None |
| 2. GRIB prep | `grib_prep.exe` | **Linux x86 only** | 32-bit pre-compiled binary |
| 3. WRF model | `wrf.exe` | Linux (compiled) | Must compile WRF from source |
| 4. RASP post-proc | `ncl`, `ncl_jack_fortran.so` | Linux | Fortran lib must be compiled |
| 5. Windgram plot | `ncl`, `ncl_jack_fortran.so` | Linux / macOS* | Fortran lib must be recompiled for macOS |
| 6. PNG optimize | `convert` | Linux / macOS | None |
| 7. Upload | `ftp` / `lftp` | Linux / macOS | Credentials required |

\* macOS requires recompiling `ncl_jack_fortran.so` and installing NCL via conda.

---

## Shortcut: UWPNW Path (Skip Stages 1–4)

The UWPNW path (`model/WXTOFLY/RUN/run_uwpnw.sh`) downloads pre-staged `wrfout` NetCDF files from the University of Washington rather than running WRF locally. This reduces the pipeline to:

```
fetch UW wrfout files  →  windgrams.ncl  →  PNG optimize  →  upload
```

This is the most practical path for testing windgram generation on a new platform, since it eliminates the 32-bit binary and WRF compilation dependencies.

---

## Key Environment Variables

Set in `model/WXTOFLY/wxtofly.env`:

```bash
BASEDIR                # Root installation directory
NCARG_ROOT             # NCL/NCAR graphics installation root
WXTOFLY_WINDGRAMS      # Path to WINDGRAMS/ directory
WXTOFLY_CONFIG         # Path to CONFIG/ (sites.csv, run.conf)
WXTOFLY_TEMP           # Temporary files
WXTOFLY_LOG            # Log output
WXTOFLY_UPLOAD_ROOT    # Upload staging directory
```
