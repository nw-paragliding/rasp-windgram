# RASP Windgram

Generate paragliding soaring forecasts from WRF weather model output.

Produces windgrams — vertical time-series charts showing thermal strength,
wind, lapse rates, cloud base, and soaring ceiling for specific flying sites.

## Quick Start

```bash
pip install rasp-windgram

# One-time: download WPS geographic data (high-res, ~2.6 GB)
rasp setup-geog

# Run a full forecast for tomorrow
rasp run examples/cascades.yaml \
  --date 2026-04-04 --cycle 06 \
  --sites examples/pnw-sites.csv

# Preview what Docker will run without executing
rasp --dry-run run examples/cascades.yaml \
  --date 2026-04-04 --cycle 06 \
  --sites examples/pnw-sites.csv

# Render windgrams from existing WRF output
rasp windgram wrfout_d03_*.nc --sites examples/pnw-sites.csv

# Single site
rasp windgram wrfout_d03_*.nc \
  --site Tiger --lat 47.503 --lon -121.975
```

### GEOG Data Setup

The WRF Preprocessing System requires static geographic data. Download it once:

```bash
# High-res (default) — ~2.6 GB download, ~29 GB unpacked
rasp setup-geog

# Low-res (for testing) — ~0.4 GB download, ~3 GB unpacked
rasp setup-geog --low-res

# Custom destination
rasp setup-geog --dest /data/wps-geog
```

Subsequent runs skip the download if data is already present.

### CLI Reference

| Command | Description |
|---|---|
| `rasp run <domain.yaml>` | Full pipeline: WPS → WRF → windgrams |
| `rasp windgram <wrfout...>` | Render windgrams from existing WRF output |
| `rasp setup-geog` | Download WPS GEOG static data |
| `rasp --dry-run <cmd>` | Print the Docker command without executing |

Configuration via environment variables:

| Variable | Default | Description |
|---|---|---|
| `RASP_IMAGE` | `ghcr.io/nw-paragliding/windgram:latest` | Docker image to use |
| `RASP_GEOG_DIR` | `~/rasp-data/geog` | WPS GEOG data directory |

## Docker

The CLI wraps these Docker images. You can also use them directly.

### Images

| Image | Description | Size |
|---|---|---|
| `ghcr.io/nw-paragliding/windgram:latest` | Full pipeline (WPS + WRF + renderer) | ~2 GB |
| `ghcr.io/nw-paragliding/wrf-compiled:v4.5.2` | Pre-compiled WRF 4.5.2 + WPS 4.5 (base layer) | ~1.5 GB |

Both images support `linux/arm64` and `linux/amd64`.

### Running Directly

```bash
docker pull ghcr.io/nw-paragliding/windgram:latest

# Full pipeline
docker run --rm \
  -v ~/rasp-data/geog:/mnt/geog:ro \
  -v ~/output:/mnt/output \
  ghcr.io/nw-paragliding/windgram run domain.yaml \
    --date 2026-04-04 --cycle 06 --sites examples/pnw-sites.csv

# Render from existing wrfout
docker run --rm \
  -v ~/output:/mnt/output \
  -v ./wrfout_d03_2026-04-04_12:00:00:/mnt/wrfout/wrfout:ro \
  ghcr.io/nw-paragliding/windgram windgram /mnt/wrfout/wrfout \
    --sites examples/pnw-sites.csv --output-dir /mnt/output

# Interactive shell
docker run --rm -it ghcr.io/nw-paragliding/windgram bash
```

### Container Volumes

| Mount | Purpose |
|---|---|
| `/mnt/geog` | WPS GEOG static data (read-only) |
| `/mnt/grib` | GRIB input files (read-only, optional) |
| `/mnt/output` | Windgram PNG output |

### Building

```bash
# User-facing image (fast, ~2 min — no WRF compilation)
docker buildx build -f docker/Dockerfile.windgram \
  -t ghcr.io/nw-paragliding/windgram:latest .

# Base WRF image (slow, ~30 min — only rebuild when WRF version changes)
docker buildx build -f docker/Dockerfile.wrf \
  --platform linux/arm64,linux/amd64 \
  -t ghcr.io/nw-paragliding/wrf-compiled:v4.5.2 .
```

## Python Library

The windgram renderer can be used as a standalone Python library without Docker,
for rendering windgrams from WRF output files you already have.

### Install

```bash
pip install rasp-windgram

# With WRF-Python support (optional)
pip install rasp-windgram[all]
```

### Rendering Windgrams

```bash
# Single site
rasp-windgram wrfout_d03_2026-04-04_12:00:00 \
  --lat 47.503 --lon -121.975 --site Tiger --output-dir ./output

# Batch render from site list
rasp-windgram wrfout_d03_2026-04-04_12:00:00 \
  --sites examples/pnw-sites.csv --output-dir ./output
```

```python
from rasp.windgram import render_windgram

render_windgram(
    "wrfout_d03_2026-04-04_12:00:00",
    lat=47.503, lon=-121.975,
    site_name="Tiger",
    output_dir="./output",
)
```

### Generating Namelists

```bash
rasp-namelist examples/cascades.yaml --date 2026-04-04 --cycle 06
```

## What's in a Windgram

| Element | Meaning |
|---|---|
| Background colors | Lapse rate (red/orange = unstable thermals, purple = moderate, grey = inversion) |
| Wind barbs | Wind speed and direction (green < 9kts, white >= 9kts) |
| Paraglider crescents | Max soaring height (225 fpm sink rate) |
| Cloud symbols | Potential cloud base (LCL) |
| Diagonal hatching | High humidity / actual clouds |
| Numbers at top | Thermal climb rate (m/s) |
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

## Architecture

See [docs/architecture.md](docs/architecture.md) for:
- Repository structure
- Docker image layers
- Supported weather models
- Soaring index function reference
- Windgram rendering details
- Future work

## Acknowledgments

Soaring parameter calculations in `rasp/soaring.py` are Python reimplementations
of Dr. Jack Glendening's Fortran routines (`ncl_jack_fortran.so`). The nonlinear
thermal penetration model constants and cloud fraction formula were decoded from the
compiled Fortran binary by the
[simonbesters/icon-d2-pipeline](https://github.com/simonbesters/icon-d2-pipeline)
project — without that reverse-engineering work, faithful reproduction of DrJack's
algorithms would not have been possible.

Windgram design follows TJ Olney's original NCL implementation
([windgramtj.ncl](http://wxtofly.net/rasp_scripts/windgramtj.ncl),
[documentation](http://wxtofly.net/windgramexplain.html)).

## License

MIT
