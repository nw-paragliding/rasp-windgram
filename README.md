# RASP Windgram

Generate paragliding soaring forecasts from WRF weather model output.

Produces windgrams — vertical time-series charts showing thermal strength,
wind, lapse rates, cloud base, and soaring ceiling for specific flying sites.

## Quick Start

```bash
pip install rasp-windgram

# One-time: download WPS geographic data
rasp setup-geog              # high-res (~2.6 GB download, ~29 GB unpacked)
rasp setup-geog --low-res    # or low-res (~0.4 GB download, ~3 GB unpacked)

# Run a full forecast (auto-detects latest NAM cycle)
rasp run examples/cascades.yaml \
  --sites examples/pnw-sites.csv

# Or specify date/cycle explicitly
rasp run examples/cascades.yaml \
  --date 2026-04-06 --cycle 00 \
  --sites examples/issaquah-sites.csv

# Render windgrams from existing WRF output
rasp windgram wrfout_d03_*.nc --sites examples/pnw-sites.csv

# Single site
rasp windgram wrfout_d03_*.nc \
  --site Tiger --lat 47.503 --lon -121.975

# Preview Docker command without executing
rasp --dry-run run examples/cascades.yaml --sites sites.csv
```

### CLI Reference

| Command | Description |
|---|---|
| `rasp run <domain.yaml>` | Full pipeline: download → WPS → WRF → windgrams |
| `rasp windgram <wrfout...>` | Render windgrams from existing WRF output |
| `rasp setup-geog` | Download WPS GEOG static data |
| `rasp --dry-run <cmd>` | Print the Docker command without executing |

The pipeline auto-detects:
- **Latest NAM cycle** from NOMADS (no `--date`/`--cycle` needed)
- **UTC offset** from domain center longitude
- **Forecast hours** to cover 8am-8pm local soaring window
- **CPU count** for MPI parallelism

Configuration via environment variables:

| Variable | Default | Description |
|---|---|---|
| `RASP_IMAGE` | `ghcr.io/nw-paragliding/windgram:latest` | Docker image |
| `RASP_GEOG_DIR` | `~/rasp-data/geog` | WPS GEOG data directory |

## What's in a Windgram

| Element | Meaning |
|---|---|
| Background colors | Lapse rate (red/orange = unstable thermals, pink = moderate, grey = inversion) |
| Wind barbs | Wind speed and direction (green < 9kts, white >= 9kts) |
| Paraglider crescents | Max soaring height (225 fpm sink rate, DrJack nonlinear model) |
| Cloud symbols | Potential cloud base (LCL), bottom of cloud at LCL height |
| Diagonal hatching | High humidity / actual clouds (RH > 94%) |
| Numbers at top | Thermal climb rate w* (m/s) |
| Cyan 32°F line | Freezing level |

## Domain Configuration

Specify a center point and target resolution. The system auto-generates the
WRF nesting chain:

```yaml
name: cascades
model: rrfs             # RRFS, NAM (retires 2026-11-03), HRRR, or GFS
center_lat: 47.6
center_lon: -121.4
target_dx_km: 1.33      # parent → 4km → 1.33km (auto)
inner_extent_km: 150
utc_offset: -8          # optional; default guessed from longitude (+1 for DST)
```

See [examples/](examples/) for sample configs and site lists.

**RRFS** (the 3 km FV3 model replacing NAM on 2026-11-03) is read from the
`prslev` + `2dfld` CONUS files with a custom `Vtable.RRFS`, subset by byte
range through the `.grib2.idx` sidecar (~850 MB → ~360 MB per forecast hour).
Set `RASP_RRFS_ROOT` to move between the parallel feed (`…/rrfs/v1.0`, the
default) and production (`…/rrfs/prod`). See [RRFS_MIGRATION.md](RRFS_MIGRATION.md)
for the migration plan and the NAM-vs-RRFS A/B tooling (`scripts/ab_compare.py`,
`.github/workflows/test-ab.yml`).

**HRRR** can feed the same DrJack chain instead of the 3 km → 1 km nest:
`examples/cascades-hrrr-drjack.yaml` is `cascades.yaml` with `model: hrrr`, initialised
NAM-like (no hydrometeors) through the domain-level `vtable:` / `sfc_vtable:` overrides and
`.idx`-subset downloads. See [HRRR_DRJACK_AB.md](HRRR_DRJACK_AB.md) for the NAM-chain vs
HRRR-chain pairs on the production grid.

### Shared lattice (several tiles, one grid)

By default every domain gets its own Lambert projection centred on
`center_lat/center_lon`, so two domains never share grid points. Add a
`lattice:` block to make independent runs ("tiles") offset windows on one
common grid:

```yaml
lattice:            # optional; all tiles with the same block share one grid
  truelat1: 46.0
  truelat2: 49.0
  stand_lon: -120.5
  ref_lat: 47.5     # lattice origin: a mass point of every tile's finest grid
  ref_lon: -120.5
```

With the block present:

- every domain uses `truelat1/truelat2/stand_lon` from the block
  (`map_proj = 'lambert'`) instead of the centre-based values;
- the outermost domain is moved by at most `dx/2` in x and y (in the shared
  projection) so the lattice origin lands exactly on one of its mass points.
  `namelist.wps` then gets `ref_lat/ref_lon` = the origin and integer
  `ref_x/ref_y` = the origin's mass-grid index, which may lie outside the
  domain (WPS accepts that);
- nests are placed as before (integer `i/j_parent_start`,
  `(e_we-1) % nest_ratio == 0`), which puts their mass points on the parent
  lattice refined by the ratio. `nest_ratio` must be odd.

Tiles with the same block and the same finest `dx` therefore have coincident
finest-grid mass points wherever they overlap. The generator logs the nominal
and snapped centre and the origin's (i, j) in each grid; `generate_namelists()`
returns them under `"lattice"`. `namelist.input` is not affected (WRF takes the
projection from `met_em`). Without the block, namelists are byte-identical to
0.6.x (`tests/golden/`). Details: [ARCHITECTURE.md](ARCHITECTURE.md#shared-lattice-lattice).

Note: 0.6.x ignores an unknown `lattice:` key silently and produces unaligned
centre-based grids, so domain files using it need rasp-windgram >= 0.7.0.

## Docker

The CLI wraps Docker. Images support `linux/arm64` and `linux/amd64`.

| Image | Description |
|---|---|
| `ghcr.io/nw-paragliding/windgram:latest` | Full pipeline (WPS + WRF + renderer) |
| `ghcr.io/nw-paragliding/wrf-compiled:v4.5.2` | Pre-compiled WRF + WPS (base layer) |

```bash
# Direct Docker usage (without the rasp CLI)
docker run --rm \
  -v ~/rasp-data/geog:/mnt/geog:ro \
  -v ~/output:/mnt/output \
  ghcr.io/nw-paragliding/windgram run domain.yaml \
    --sites sites.csv --output-dir /mnt/output
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for:
- Repository structure
- Docker image layers and CI
- Supported weather models and how to add new ones
- Soaring index function reference
- Windgram rendering details

## Acknowledgments

Soaring parameter calculations in `rasp/soaring.py` are Python reimplementations
of Dr. Jack Glendening's Fortran routines (`ncl_jack_fortran.so`). The nonlinear
thermal penetration model constants were decoded from the compiled Fortran binary
by the [simonbesters/icon-d2-pipeline](https://github.com/simonbesters/icon-d2-pipeline)
project.

Windgram design follows TJ Olney's original NCL implementation
([documentation](http://wxtofly.net/windgramexplain.html)).

## License

MIT
