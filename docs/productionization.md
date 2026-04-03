# Productionization Plan

## Goal

Distribute RASP as public Docker images that any programmer can use to generate
windgrams for their own region, on their own hardware, using publicly available
NWP model data. Supports arm64 (Apple Silicon) and amd64 natively — no QEMU.

---

## User Experience

End users never build Docker images or compile anything:

```bash
# Pull the image (one time)
docker pull rasp/windgram:latest

# Define your region (see: Domain Configuration below)
nano ~/my-domain.yaml

# Run a forecast
docker run \
  -v ~/my-domain.yaml:/domain.yaml:ro \
  -v ~/rasp-data/geog:/mnt/geog:ro \
  -v ~/output:/mnt/output \
  rasp/windgram \
  --model nam --date 2024-04-02 --cycle 06
```

Output lands in `~/output/{region}/{date}/` as windgram PNGs.

**Future work**: A thin CLI wrapper (`rasp run ...`) that manages the Docker
invocation, volume mounts, and one-time GEOG setup automatically — collapsing
these steps into a single command. See: Future Work section.

---

## Supported Models

### NAM (North American Mesoscale, 12km)
- Source: NOMADS (nomads.ncep.noaa.gov)
- Pipeline: GRIB2 → WPS → WRF → NCL/Python → windgrams
- Forecast range: 84h, 4 cycles/day (00/06/12/18z)
- Best for: day 1-3 forecasts, full CONUS coverage

### HRRR (High-Resolution Rapid Refresh, 3km)
- Source: NOMADS or AWS S3 (noaa-hrrr-bdp-pds)
- Pipeline: GRIB2 → WPS → WRF 1km nest → NCL/Python → windgrams
- Forecast range: 18h (48h for 00/06/12/18z runs), hourly updates
- Best for: same-day short-range, leverages radar data assimilation
- Note: 3km HRRR used as WRF boundary conditions, not post-processed directly
  (3km terrain smoothing is insufficient for complex terrain windgrams)
- Status: **future work** — Vtable and sigma-level namelist settings need validation

### UW WRF (University of Washington 1.33km)
- Source: UW Atmospheric Sciences public output server
- Pipeline: download wrfout NetCDF → NCL/Python directly → windgrams
- No WRF run needed — UW provides pre-computed wrfout files
- Best for: PNW region, highest terrain resolution, 1-2 updates/day
- Status: **future work** — data access URL and terms need confirmation

---

## Model Pipeline Paths

```
NAM / HRRR (GRIB2)                  UW WRF (pre-computed)
  ↓                                   ↓
  WPS (ungrib + metgrid)              download wrfout files
  ↓                                   ↓
  WRF (real + wrf)                    ↓
  ↓                                   ↓
  NCL/Python post-processing  ←───────┘
  ↓
  windgram PNGs
```

---

## Domain Configuration

Users define their forecast region in a YAML file. The system generates all
WRF namelists automatically — users never write namelists.

```yaml
# my-domain.yaml
name: cascades
model: nam

center_lat: 47.6
center_lon: -121.4

# Finest resolution desired — system builds the nest chain automatically
# NAM outer (12km) → 4km → 1.33km
target_dx_km: 1.33

# Physical extent at finest resolution
inner_extent_km: 150

# Physics overrides (optional — auto-selected by resolution if omitted)
# physics:
#   cu_physics: 0
#   bl_pbl_physics: 2
```

### Resolution Warnings

The namelist generator emits warnings for non-standard configurations:

- **1–4km grid**: gray zone — convective parameterization disabled, results
  are experimental
- **< 1km grid**: individual thermals approach grid cell size; WRF PBL
  parameterizations operate outside their design range; results are
  exploratory; significant compute cost

Warnings are informational — the system never blocks a configuration.

### GEOG Data Resolution

The namelist generator selects GEOG terrain resolution based on the finest
nest in the chain:

| Finest nest | Recommended GEOG | Notes |
|---|---|---|
| ≥ 4km | low-res (5-arcmin) | ~3GB download |
| 1–4km | high-res (30-arcsec) | ~30GB download |
| < 1km | high-res (30-arcsec) | 30-arcsec is the limit of public data |

If the recommended resolution isn't present in `/mnt/geog`, the system
prompts to download it.

---

## Image Layer Architecture

Pre-compiled binary layers live on Docker Hub. End users never compile WRF.

```
rasp/build-base:{version}
  ubuntu 22.04 + apt packages (gfortran, netcdf, hdf5, libpng, cmake)
  + jasper 2.0.33 compiled from source (GRIB2 support)
  Rebuilt: only when OS or compiler version changes (rare)

rasp/wrf-compiled:{wrf_version}
  FROM rasp/build-base
  WRF 4.5.2 + WPS 4.5 compiled natively
  Vtables, GEOGRID.TBL, METGRID.TBL, WRF run/ support files
  Multi-arch manifest: linux/arm64 + linux/amd64
  Rebuilt: only when WRF or WPS version changes (rare, ~30min build)

rasp/windgram:{version}
  FROM rasp/wrf-compiled:{wrf_version}   ← pulls pre-built, no recompile
  + post-processing (NCL short-term; Python/wrf-python long-term)
  + namelist generator (Python)
  + RASP model scripts (Perl, NCL/Python)
  + entrypoint
  Rebuilt: when scripts or interface change (~2min, no compile)
```

Contributors build and push `rasp/wrf-compiled` and `rasp/windgram`.
End users only ever `docker pull rasp/windgram`.

### Multi-Arch Build (contributor workflow)

```bash
# Build and push wrf-compiled for both architectures
docker buildx build \
  --platform linux/arm64,linux/amd64 \
  --push \
  -t rasp/wrf-compiled:4.5.2 \
  -f Dockerfile.wrf-compiled .

# Build windgram image on top (fast — no WRF compile)
docker buildx build \
  --platform linux/arm64,linux/amd64 \
  --push \
  -t rasp/windgram:latest \
  -f Dockerfile.windgram .
```

Docker Hub serves the correct architecture automatically via manifest list.

---

## Post-Processing: NCL → Python Migration

The current NCL post-processing pipeline depends on two pre-compiled x86_64
Fortran libraries (`ncl_jack_fortran.so`, `wrf_user_fortran_util_0-64bit.so`)
that cannot run on arm64.

**Short-term**: run NCL in the x86_64 container for post-processing only.
WRF runs natively on arm64 (the large speedup). NCL post-processing is
~5 minutes — tolerable emulated.

**Long-term**: replace NCL with wrf-python + matplotlib. NCAR has deprecated
NCL. The unique functions in `ncl_jack_fortran.so` are DrJack's soaring index
calculations (~12 functions, ~300 lines to reimplement in Python using
published equations). Everything else is already in wrf-python.

See: [NCL Rewrite Plan](ncl-rewrite-plan.md)

---

## Future Work

- **Unified CLI**: wrap Docker invocation, volume mounts, and GEOG setup into
  a single `rasp run` command. Users install the CLI once and never interact
  with Docker directly.

- **HRRR → 1km WRF nesting**: validate Vtable.HRRR, sigma-level
  `num_metgrid_levels` settings, and 3:1 nesting from 3km → 1km.

- **UW WRF 1.33km support**: confirm data access URL and terms, implement
  wrfout download and direct NCL/Python post-processing path.

- **GEOG tile subsetting**: for baked-in GEOG at build time, download only
  the tiles covering the domain bbox rather than the full global dataset.
  NCAR provides per-tile downloads for high-res datasets.
