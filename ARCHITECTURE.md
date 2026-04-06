# RASP Architecture

## What This Is

A pipeline for generating paragliding soaring forecasts (windgrams) from
publicly available NWP model data. Runs natively on arm64 (Apple Silicon) and
amd64.

### Pipeline

```
domain.yaml + sites.csv
  → auto-detect latest NAM cycle from NOMADS
  → download GRIB2 data (forecast hours covering 8am-8pm local)
  → WPS (geogrid + ungrib + metgrid)
  → WRF (real.exe + wrf.exe, MPI parallel)
  → Python windgram renderer
  → PNG windgrams per site
```

### Performance

| Config | Time |
|---|---|
| Native arm64, d01 only (12km, serial) | ~2 min |
| Native arm64, d01+d02+d03 (12km+4km+1.33km, 4 MPI cores) | ~45 min |
| Native arm64, d01+d02+d03, 8 MPI cores | ~25 min |

---

## Repository Structure

```
rasp/           Python package (pip install rasp-windgram)
  cli.py          Host-side CLI (wraps Docker)
  soaring.py      Soaring index calculations (w*, hcrit, BL diagnostics)
  windgram.py     Windgram renderer (matplotlib)
  namelist_generator.py   domain.yaml → namelist.wps + namelist.input
  pipeline.py     Full pipeline orchestrator (drives WPS + WRF directly)

scripts/        Shell scripts (used inside Docker container)
  run_wps.sh      Runs geogrid → ungrib → metgrid
  run_real_wrf.sh Runs real.exe → wrf.exe
  get_nam_grib.sh Downloads NAM GRIB2 from NOMADS (with retry)
  setup_geog.sh   One-time WPS GEOG data download
  entrypoint.sh   Docker entrypoint (run, windgram, bash)
  build-images.sh Docker image build script

docker/         Dockerfile.wrf (heavy compile), Dockerfile.windgram (light)
examples/       Domain configs (YAML) and site lists (CSV)
.github/        CI (tests + multi-arch image builds)
```

---

## Docker Images

Two-layer architecture. Users pull `windgram`, never compile WRF.

### `ghcr.io/nw-paragliding/wrf-compiled:{version}`

Heavy compile layer. WRF 4.5.2 + WPS 4.5 with MPI support.
Multi-arch (arm64 + amd64). Rebuilt only when WRF version changes.
Tagged by WRF version: `v4.5.2`.

### `ghcr.io/nw-paragliding/windgram:{version}`

User-facing image. FROM wrf-compiled — no WRF compilation.
Adds Python (rasp-windgram package), scripts, entrypoint.
Tagged with semver from `VERSION` file: `0.1.0`, `latest`.

### CI

- **ci.yml**: runs on every PR and push to main — Python import tests,
  namelist generation test, Docker build test
- **build-images.yml**: runs on `v*` tags — builds and publishes multi-arch
  images to GHCR. Skips WRF compile if image already exists.
  arm64 on `ubuntu-24.04-arm`, amd64 on `ubuntu-24.04` (both native, no QEMU).

### Building Locally

```bash
# User-facing image (fast, ~2 min)
docker buildx build -f docker/Dockerfile.windgram \
  --build-arg WRF_IMAGE=ghcr.io/nw-paragliding/wrf-compiled:v4.5.2 \
  -t ghcr.io/nw-paragliding/windgram:latest .

# Base WRF image (slow, ~30 min — only when WRF version changes)
docker buildx build -f docker/Dockerfile.wrf \
  -t ghcr.io/nw-paragliding/wrf-compiled:v4.5.2 .
```

---

## Domain Configuration

Users define forecast regions in YAML. The namelist generator auto-computes
nesting chains, grid dimensions, time steps, and physics selection.

```yaml
name: cascades
model: nam
center_lat: 47.6
center_lon: -121.4
target_dx_km: 1.33       # system builds: 12km → 4km → 1.33km
inner_extent_km: 150
nest_ratio: 3
```

Grid dimensions are automatically adjusted to satisfy WRF's nesting
requirement: `(e_we - 1) % parent_grid_ratio == 0`.

Warnings emitted for:
- 1-4km: gray zone (convective parameterization disabled)
- <1km: LES territory (PBL schemes outside design range)
- <500m: extreme compute cost

---

## Pipeline Intelligence

The pipeline auto-detects several parameters:

- **Latest cycle**: queries NOMADS for the newest available NAM cycle
- **UTC offset**: computed from domain center longitude (with DST)
- **Forecast hours**: computed to cover 8am-8pm local soaring window
- **CPU count**: auto-caps MPI processes at container's available cores
- **num_metgrid_levels**: read from met_em files after WPS runs

---

## Supported Models

### NAM (working)
- 12km, North America, 4 cycles/day, 84h forecast
- Source: NOMADS
- Auto-download with retry, smart forecast hour selection

### HRRR (config ready, needs testing)
- 3km, CONUS, hourly updates, 18h forecast
- Vtable: `Vtable.RAP.pressure.ncep`
- Nest directly to 1km (no intermediate 4km domain needed)

### GFS (config only)
- 25km, global, 4 cycles/day, 384h forecast
- Vtable: `Vtable.GFS`

### HRDPS (config only)
- 2.5km, Canada, 4 cycles/day, 48h forecast
- Vtable: TBD

---

## Soaring Index Functions

Python reimplementations of DrJack's `ncl_jack_fortran.so` Fortran library
(all in `rasp/soaring.py`). Uses the nonlinear thermal penetration model
with empirical coefficients decoded from the compiled binary.

| Function | Purpose |
|---|---|
| `calc_wstar` | Convective velocity scale (Deardorff 1970, with virtual heat flux) |
| `calc_hcrit` | Max soaring height (DrJack nonlinear model, 225 fpm threshold) |
| `calc_hlift` | Max soaring height for arbitrary sink rate |
| `calc_blavg` | Boundary layer average of a 3D field |
| `calc_blmax` | Boundary layer maximum |
| `calc_wblmaxmin` | BL max/min vertical velocity |
| `calc_sfclclheight` | Surface LCL height (Bolton approximation) |
| `calc_blclheight` | BL cloud layer height |
| `calc_cloudbase` | Cloud base from cloud water mixing ratio |
| `calc_blcloudbase` | Cloud base within BL |
| `calc_blwinddiff` | Wind shear across BL |
| `calc_bltop_pottemp_variability` | Inversion strength indicator |
| `calc_blinteg_mixratio` | BL-integrated cloud water |
| `calc_aboveblinteg_mixratio` | Above-BL integrated cloud water |
| `calc_sfcsunpct` | Surface sunshine percentage |
| `calc_subgrid_blcloudpct` | Sub-grid BL cloud fraction |
| `calc_qcblhf` | Cloud base height factor |

---

## Windgram Rendering

Visual elements per
[TJ Olney's windgram documentation](http://wxtofly.net/windgramexplain.html):

- Lapse rate filled contours (NCL-matching colormap)
- Wind barbs (green < 9kts, white ≥ 9kts)
- Paraglider crescent markers at soaring ceiling (min of hcrit, LCL)
- LCL cloud markers (bottom of cloud anchored at LCL height)
- Diagonal hatching for moisture (RH > 94%, denser > 97%)
- Temperature isolines (°F) with prominent 32°F freezing line
- w* climb rate labels above chart
- Auto chart ceiling from max PBL height + headroom
- Auto time range from 8am to 8pm local

---

## Adding a New Model

1. **Find or create a Vtable** — check `Variable_Tables/` in the WPS distribution.

2. **Add to model registry** in `rasp/namelist_generator.py`:
   ```python
   MODELS["mymodel"] = {
       "name": "My Model",
       "dx": 3000.0,
       "vtable": "Vtable.MyModel",
       "interval_seconds": 3600,
       "forecast_hours": [...],
       "cycles": [0, 6, 12, 18],
       "coverage": "Region",
       "source": "nomads",
       "url_pattern": "https://...",
   }
   ```

3. **Add a download adapter** if the source uses non-standard URLs or auth.

4. **Test with a real run** — download files, run ungrib, check num_metgrid_levels.

5. **Domain config** — outer domain `dx` should match model resolution.

---

## References

- **[simonbesters/icon-d2-pipeline](https://github.com/simonbesters/icon-d2-pipeline)** — reverse-engineered DrJack Fortran routines
- **[CazYokoyama/wrfv3](https://github.com/CazYokoyama/wrfv3)** — most complete RASP distribution
- **[wargoth/rasp-gm](https://github.com/wargoth/rasp-gm)** — DrJack's GM subsystem
- **[oriolcervello/raspuri](https://github.com/oriolcervello/raspuri)** — Python/Bash RASP rewrite for WRF v4
- **[TJ Olney's windgram docs](http://wxtofly.net/windgramexplain.html)** — windgram visual design reference
- **[DrJack's RASP](http://www.drjack.info/)** — original RASP/BLIPMAP project

---

## Future Work

- **HRRR support**: test end-to-end with pressure-level files
- **UW WRF support**: direct wrfout → windgram path (no WRF run needed)
- **Map layers**: rain overlay, top-of-lift contours, wind maps
- **Legend bar**: color scale on windgram for self-explanatory charts
- **PyPI publishing**: `pip install rasp-windgram` from PyPI
