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
model: nam              # NAM, GFS, or HRRR
center_lat: 47.6
center_lon: -121.4
target_dx_km: 1.33      # 12km → 4km → 1.33km (auto)
inner_extent_km: 150
```

See [examples/](examples/) for sample configs and site lists.

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
