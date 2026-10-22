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

### Shared lattice (`lattice:`)

**Why.** The production site runs several 120 km tiles over Washington as
separate WRF runs (4 km → 1.33 km, ratio 3). v2 wants to write all tiles into a
single statewide Icechunk/zarr store, chunk-aligned, with no regridding. That
needs every tile to be an offset window on ONE 1.33 km lattice: same
projection, grid points coincident where tiles overlap. Centre-based domains
(the default) each have their own projection, so they never align.

**YAML.** `lattice: {truelat1, truelat2, stand_lon, ref_lat, ref_lon}` -- all
five keys required, unknown keys rejected (`rasp.lattice.parse_lattice`). The
fallback YAML parser (`_parse_simple_yaml`, used only without PyYAML) now
reads one level of nested blocks, so `physics:` and `lattice:` work there too.

**Placement** (`rasp/lattice.py`, pure Python, no new dependency):

1. Projection: spherical Lambert conformal conic, earth radius 6370 km, cone
   factor computed exactly as WPS `lc_cone` does (checked against pyproj in
   `tests/test_lattice.py`). x/y are metres from the lattice origin.
2. d01: with the requested centre at (xc, yc), the origin's mass index is
   `e_we/2 - xc/dx` (WPS places the domain centre at mass coordinate
   `e_we/2`). It is rounded to the nearest integer `ref_x` (same for y), which
   moves the domain by at most dx/2. `namelist.wps` gets
   `ref_lat/ref_lon` = the origin, `ref_x/ref_y` = those integers.
3. Nests: unchanged. WPS puts nest mass point k at parent mass coordinate
   `i_parent_start + (k - (r+1)/2)/r` (`find_known_latlon`), i.e. at parent
   point + `(k - (r+1)/2)·dx/r`. With an odd ratio, every nest mass point is
   on the parent lattice refined by r, and so is the origin. By induction the
   finest grid of every tile is `origin + m·dx_finest`.

**ref_x/ref_y convention** (WPS v4.5 geogrid source): they are coordinates on
the mass (unstaggered) grid. Mass point (i, j) is at exactly (i, j)
(`llxy_module.F: xytoll` shifts only U/V/corner points by -0.5); the default
is `(e_we/2, e_sn/2)`, the centre of mass points 1..e_we-1
(`gridinfo_module.F`). `map_set`/`set_lc` only use them to place the
projection pole (`polei = knowni - rsw·sin(...)`) and do not range-check them.
So the generator uses the origin as the reference point for every tile
(identical `ref_lat/ref_lon`, integer `ref_x/ref_y` that may be outside the
domain, e.g. `ref_y = -12` for the Baker tile). No tile depends on a lat/lon
round-trip through our projection code: WPS's own Lambert maths places every
tile relative to the same point.

**Log / API.** `generate_namelists()` prints the nominal vs snapped centre
and the origin's (i, j) in every grid, and returns the placement under
`"lattice"`. `origin_ij[-1]` gives the tile's position on the statewide fine
lattice: finest mass point (i, j) = lattice point `(i, j) - origin_ij[-1]`.

**Tests.** `tests/test_lattice.py`: namelists for every `examples/*.yaml` and
`ab/phoenix.yaml` are byte-identical to the 0.6.1 output (`tests/golden/`);
for the seven Washington tiles, every overlapping pair has fine-grid offsets
that are integer multiples of dx/3 (within 1e-6) and each snapped centre is
within dx/2 of the request. `scripts/lattice_geogrid_check.py` repeats the
check on real `geo_em` files after geogrid.

**For v2.** `rasp.export_cube` currently builds its pyproj CRS with
`lat_0 = MOAD_CEN_LAT`, which is each tile's own d01 centre. For a shared store
use the lattice origin (`ref_lat`) as `lat_0` (or index by `origin_ij`), so x/y
are comparable across tiles.

### HRRR-specific options

```yaml
hrrr_levels: pressure   # default — smaller files (437MB), slab land surface
hrrr_levels: native     # larger files (763MB), full Noah LSM, needs ≥16GB RAM
```

Pressure-level files omit soil data, so the pipeline auto-selects a simpler
land surface scheme (slab). BL/thermal physics (MYNN PBL, which drives w*)
are identical. Native-level files preserve the full vertical structure and
include soil data for the Noah LSM — better surface heat flux accuracy but
requires more RAM for ungrib processing.

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

### RRFS (NAM replacement — see RRFS_MIGRATION.md)
- 3km FV3-LAM, CONUS subset on the HRRR Lambert grid; hourly cycles, 00/06/12/18z to 84h
- Source: NOMADS `rrfs/v1.0` (parallel feed) → `rrfs/prod` from 2026-11-03; `RASP_RRFS_ROOT` overrides
- Two files per forecast hour: `prslev` (isobaric 3-D) + `2dfld` (surface, soil, fluxes), both linked
  into one ungrib pass with the custom `vtables/Vtable.RRFS` (NAM rows + RAP/HRRR 9-level soil)
- Byte-range subsetting via `.grib2.idx` (`idx_subset` / `sfc_idx_subset` in the registry)
- Same DrJack WRF chain as NAM (3km parent → 4km → 1.33km); hydrometeor init off

### NAM (working; retired by NCEP 2026-11-03)
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
