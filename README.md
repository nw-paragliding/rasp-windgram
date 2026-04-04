# RASP Windgram

Generate paragliding soaring forecasts from WRF weather model output.

Produces windgrams — vertical time-series charts showing thermal strength,
wind, lapse rates, cloud base, and soaring ceiling for specific flying sites.

## Quick Start (pip)

```bash
pip install rasp-windgram

# Render a windgram from any WRF output file
rasp-windgram wrfout_d03_2026-04-04_12:00:00 \
  --lat 47.503 --lon -121.975 --site Tiger --output-dir ./output

# Batch render for multiple sites
rasp-windgram wrfout_d03_2026-04-04_12:00:00 \
  --sites examples/pnw-sites.csv --output-dir ./output
```

## Quick Start (Docker)

Run the full forecast pipeline — downloads weather data, runs WRF, renders windgrams:

```bash
docker pull ghcr.io/nw-paragliding/windgram:latest

# Define your region
cat > domain.yaml <<EOF
name: cascades
model: nam
center_lat: 47.6
center_lon: -121.4
target_dx_km: 1.33
inner_extent_km: 150
EOF

# Run forecast
docker run \
  -v ~/rasp-data/geog:/mnt/geog:ro \
  -v ~/output:/mnt/output \
  ghcr.io/nw-paragliding/windgram run domain.yaml \
    --date 2026-04-04 --cycle 06 --sites examples/pnw-sites.csv
```

First run requires a one-time GEOG data download (~3GB):
```bash
./scripts/setup_geog.sh ~/rasp-data/geog
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

## License

MIT
