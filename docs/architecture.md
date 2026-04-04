# RASP Architecture

## What This Is

A pipeline for generating paragliding soaring forecasts (windgrams) from
publicly available NWP model data. Runs natively on arm64 (Apple Silicon) and
amd64.

### Pipeline

```
NAM/GFS/HRRR GRIB2 data
  → WPS (ungrib + geogrid + metgrid)
  → WRF (real.exe + wrf.exe)
  → Python windgram renderer
  → PNG windgrams per site
```

### Performance

| Config | Time |
|---|---|
| Native arm64, d01 only (12km, serial) | ~2 min |
| Native arm64, d01+d02+d03 (12km+4km+1.33km, 8 MPI cores) | ~45 min |

---

## Repository Structure

```
rasp/           Python package (pip install rasp-windgram)
  cli.py          Host-side CLI (wraps Docker)
  soaring.py      Soaring index calculations (w*, hcrit, BL diagnostics)
  windgram.py     Windgram renderer (matplotlib)
  namelist_generator.py   domain.yaml → namelist.wps + namelist.input
  pipeline.py     Full pipeline orchestrator

scripts/        Shell scripts
  run_wps.sh      Runs geogrid → ungrib → metgrid
  run_real_wrf.sh Runs real.exe → wrf.exe
  get_nam_grib.sh Downloads NAM GRIB2 from NOMADS
  setup_geog.sh   One-time WPS GEOG data download
  entrypoint.sh   Docker entrypoint (run, windgram, namelist, bash)
  build-images.sh Docker image build script

templates/      WRF/WPS namelist templates
docker/         Dockerfile.wrf (heavy compile), Dockerfile.windgram (light)
examples/       Domain configs (YAML) and site lists (CSV)
.github/        CI workflow for multi-arch image builds
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

### Building

```bash
# Local (single arch, for development)
./scripts/build-images.sh

# Push to GHCR (multi-arch, for release)
./scripts/build-images.sh --push
```

CI builds trigger on `v*` tags via GitHub Actions. arm64 builds on
`ubuntu-24.04-arm`, amd64 on `ubuntu-24.04` — both native.

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

Warnings emitted for:
- 1-4km: gray zone (convective parameterization disabled)
- <1km: LES territory (PBL schemes outside design range)
- <500m: extreme compute cost

---

## Supported Models

### NAM (working)
- 12km, CONUS, 4 cycles/day, 84h forecast
- Source: NOMADS (nomads.ncep.noaa.gov)
- Pipeline: GRIB2 → WPS → WRF → windgrams

### HRRR (future)
- 3km, CONUS, hourly updates, 18h forecast
- Use as WRF boundary conditions for 1km nest (not direct post-processing)
- Needs: Vtable validation, sigma-level num_metgrid_levels

### UW WRF (future)
- 1.33km, PNW only, pre-computed wrfout
- Skip WRF entirely — download wrfout → windgrams directly
- Needs: data access URL confirmation

---

## Soaring Index Functions

Python replacements for the legacy `ncl_jack_fortran.so` Fortran library
(all in `rasp/soaring.py`):

| Function | Purpose |
|---|---|
| `calc_wstar` | Convective velocity scale (Deardorff 1970, with virtual heat flux) |
| `calc_hcrit` | Max soaring height for 225 fpm (1.14 m/s) sink rate |
| `calc_hlift` | Max soaring height for arbitrary sink rate |
| `calc_blavg` | Boundary layer average of a 3D field |
| `calc_blmax` | Boundary layer maximum |
| `calc_wblmaxmin` | BL max/min vertical velocity (modes 0-3) |
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

All take NumPy arrays, no Fortran dependency.

---

## Windgram Rendering

Python replacement for `windgrams.ncl`. Visual elements per
[TJ Olney's windgram documentation](http://wxtofly.net/windgramexplain.html):

- Lapse rate filled contours (NCL-matching colormap)
- Wind barbs (green < 9kts, white ≥ 9kts)
- Paraglider crescent markers at soaring ceiling (min of hcrit, LCL)
- LCL cloud markers (potential cloudbase)
- Diagonal hatching for moisture (RH > 94%, denser > 97%)
- Temperature isolines (°F) with prominent 32°F freezing line
- w* climb rate labels
- Auto chart ceiling from max PBL height + headroom

---

## Future Work

- **HRRR support**: Vtable validation, sigma-level namelist settings
- **UW WRF support**: data access, direct wrfout → windgram path
- **Map layers**: rain overlay, top-of-lift contours, wind maps
- **Numerical validation**: compare soaring indices against legacy NCL + pilot reports
