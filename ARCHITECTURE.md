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
Multi-arch (arm64 + amd64). Rebuilt only when the WRF version or the build
itself changes; each such change gets a new tag (`WRF_TAG` in
`build-images.yml`), because `check-wrf` skips the compile when the tag exists.

| Tag | FCOPTIM | Used by |
|---|---|---|
| `v4.5.2-o2` | `-O2 -ftree-vectorize -funroll-loops -ffp-contract=off` (WRF's stock gfortran flags + no FMA contraction) | 0.7.4+ |
| `v4.5.2` | `-O1 -fno-tree-vectorize -ffp-contract=off -fno-fast-math` | 0.5.x-0.7.3 (kept for A/B) |

**Why -O1 is gone.** PR #15 (July 2026) dropped to -O1 because the 1 km nest
went NaN after some hours and an -O1 rebuild made it stop, at ~1.6x the WRF
wall time. The real cause (PR #22, 0.7.3) was a weakly damped acoustic mode of
WRF's vertically implicit solver over steep terrain, fixed by
`dynamics: {epssm: 0.5}` at no cost; runs sitting at that stability limit were
merely sensitive to the rounding differences between builds. With epssm the
stock -O2 build is stable on the steepest production tile (`ab/baker.yaml`,
PR for 0.7.4).

**Why `-ffp-contract=off` stays.** gfortran on aarch64 defaults to
`-ffp-contract=fast` (fuses `a*b+c` into FMA); the x86_64 baseline has no FMA.
Without it the arm64 image (production + A/B runners) and the amd64 image
round differently at every multiply-add. WRF's own aarch64 GCC stanza
suppresses the fusion for the same reason. It does not block vectorisation.

A/B a base image against another: arm `<model>@<wrf-tag>` in `test-ab.yml`,
e.g. `[ab baker 2026-10-22 12 2026-10-22 o1=nam@v4.5.2 o2=nam@v4.5.2-o2]`.

### `ghcr.io/nw-paragliding/windgram:{version}`

User-facing image. FROM wrf-compiled — no WRF compilation.
Adds Python (rasp-windgram package), scripts, entrypoint.
Tagged with semver from `VERSION` file: `0.1.0`, `latest`.

### CI

- **ci.yml**: runs on every PR and push to main — Python import tests,
  namelist generation test, Docker build test
- **build-images.yml**: runs on `v*` tags — builds and publishes multi-arch
  images to GHCR. Skips WRF compile if `wrf-compiled:${WRF_TAG}` already exists.
  `workflow_dispatch` with `target=wrf` (any branch) builds and pushes only the
  base image under `WRF_TAG`, never `windgram:*`.
  arm64 on `ubuntu-24.04-arm`, amd64 on `ubuntu-24.04` (both native, no QEMU).

### Building Locally

```bash
# User-facing image (fast, ~2 min)
docker buildx build -f docker/Dockerfile.windgram \
  --build-arg WRF_IMAGE=ghcr.io/nw-paragliding/wrf-compiled:v4.5.2-o2 \
  -t ghcr.io/nw-paragliding/windgram:latest .

# Base WRF image (slow — only when WRF or its build flags change; new WRF_TAG)
docker buildx build -f docker/Dockerfile.wrf \
  -t ghcr.io/nw-paragliding/wrf-compiled:v4.5.2-o2 .
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


### Dynamics overrides (`dynamics:`, 0.7.3)

**Why.** Four of the seven 120 km Washington tiles (issaquah with Rainier in
its nest, chelan, baker, methow) produced NaN within minutes on every run while
the 150 km Cascades nest (no Rainier/Baker) stayed stable with identical
physics. The issaquah rsl (rank 0, NAM 2026-10-22 00z, start 15:00) shows the
signature 2 min 56 s in: `29 points exceeded v_cfl = 2 in domain d02`,
`Max W: 45 13 6 W: -14.82 w-cfl: 5.49`, then `W: 42.08 w-cfl: 5.75` and
`WARN5: NaN temperature` -- on the south flank of Rainier, at an 8 s nest step.
WRF then integrates NaNs to the end (`SUCCESS COMPLETE WRF`), so the job takes
its usual time and the windgrams show the 9.8 fill value.

**Root cause (A/B, same cycle, six arms).** Not the 6*dx time step: a fixed
16 s step (5.3 s nest) and the adaptive step (down to 3 s on d01 / 1 s on d02)
both stay below w-cfl 2 and still produce NaN (15:03:17 and 15:18:04). Every arm
with `epssm: 0.5` is clean, including the unchanged 24 s step. The instability
is the weakly damped vertically propagating acoustic mode of the split-explicit
solver over very steep sigma-coordinate terrain (99.9th-percentile slope
0.45-0.47 in the failing nests vs 0.31-0.41 in the healthy ones); the large w
and the v_cfl messages are its symptom. `epssm` off-centres the vertically
implicit acoustic step (WRF default 0.1) and damps that mode; raising it to 0.5 is the standard WRF remedy for
steep-terrain instability.

**Cost.** `epssm` is free (WRF 24.2 vs 23.7 min); 16 s costs about 1.5x
(35.8 min); adaptive + epssm 24.2 min. 16 s + epssm vs 24 s + epssm differ by
1 fpm median w* and 0 ft median soaring ceiling (`scripts/ab_compare.py`), so
the step size does not change the forecast.

**Defaults unchanged.** The generator keeps `time_step = 6 * dx_km` and does
not write `epssm`; namelists without a `dynamics:` block are byte-identical
(`tests/golden/`). Tiles over the volcanoes opt in with `dynamics: {epssm: 0.5}`.

**Keys** (`DYNAMICS_KEYS` in `rasp/namelist_generator.py`; see README for
types): `time_step`, `epssm`, `w_damping`, `zadvect_implicit`,
`diff_6th_opt`, `diff_6th_factor`, `hybrid_opt`, and the adaptive-step set
`use_adaptive_time_step`, `step_to_output_time` (implied true), `target_cfl`,
`target_hcfl`, `max_step_increase_pct`, `starting/max/min_time_step`,
`adaptation_domain`. Scalar WRF options are written once, per-domain ones
repeated (or taken from a list with one value per domain). `epssm`,
`zadvect_implicit` and the adaptive keys are written only when set.
`smooth_cg_topo` is not offered: it only blends d01's outer boundary rows.
A/B arms: `ab/issaquah*.yaml`, `tests/test_dynamics.py`.

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
