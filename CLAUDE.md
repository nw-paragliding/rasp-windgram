# CLAUDE.md

## Project Overview

RASP Windgram — soaring forecast pipeline for paragliding. Downloads NWP model
data, runs WRF weather simulation, renders windgram PNG charts for flying sites.

## Key Commands

```bash
# Run full pipeline (auto-detects latest NAM cycle)
uv run rasp run examples/cascades.yaml --sites examples/issaquah-sites.csv --output-dir ./output

# Render windgrams from existing wrfout
uv run rasp-windgram wrfout_d03_*.nc --site Tiger --lat 47.503 --lon -121.975 --output-dir ./output

# Generate namelists only
uv run python -m rasp.namelist_generator examples/cascades.yaml --date 2026-04-06 --cycle 00

# Build Docker image locally
docker build -f docker/Dockerfile.windgram \
  --build-arg WRF_IMAGE=ghcr.io/nw-paragliding/wrf-compiled:v4.5.2-arm64 \
  -t ghcr.io/nw-paragliding/windgram:latest .

# Build Python wheel
uvx --from build pyproject-build --wheel
```

## Architecture

- `rasp/` — Python package: soaring indices, windgram renderer, namelist generator, pipeline orchestrator
- `scripts/` — Shell scripts for WPS/WRF execution and GRIB download (run inside Docker)
- `docker/` — Two Dockerfiles: `Dockerfile.wrf` (heavy compile, rarely changes) and `Dockerfile.windgram` (light, changes often)
- `examples/` — Domain configs (YAML) and site lists (CSV)

## Important Context

- **Docker context**: use `colima` (arm64 native), NOT `colima-x86`. Verify with `docker info --format '{{.Architecture}}'`
- **GEOG data**: must be on internal disk (not external/USB) for Docker volume mounts via Colima
- **wrf-python**: broken on Python 3.12/uv (numpy.distutils removed). Install with `--no-deps` in Docker only. Not a dependency for the Python package.
- **WRF nesting**: grid dimensions must satisfy `(e_we - 1) % parent_grid_ratio == 0`
- **gwd_opt**: cannot be per-domain in WRF 4.5 namelist — causes FATAL. Removed from generated namelists.
- **NAM GRIB download**: NOMADS requires `--http1.1` for curl (HTTP/2 causes protocol errors)
- **NAM retires 2026-11-03** (NCEP SCN 26-47/26-48); RRFS replaces it. Plan + decisions in `RRFS_MIGRATION.md`. RRFS feeds the *same* DrJack chain as NAM (`examples/cascades.yaml`); do NOT model new inputs on the HRRR 1km nest (unstable, worse forecasts).
- **RRFS input**: two files per fhr (`prslev` 3-D + `2dfld` surface/soil) linked into ONE ungrib pass with `vtables/Vtable.RRFS`; soil is 9 RUC levels like HRRR (real.exe interpolates to Noah). Only CONUS Lambert files — ungrib can't read the `.na.` rotated grid. `RASP_RRFS_ROOT` switches `rrfs/v1.0` (para) ↔ `rrfs/prod`.
- **.idx byte-range downloads**: `idx_subset`/`sfc_idx_subset` in the model registry; `RASP_IDX_SUBSET=0` forces full files. Uses a keep-alive `http.client` connection (curl's `--range` is global, not per-URL).
- **UTC offset heuristic adds a DST hour** (`_utc_offset_from_lon`); set `utc_offset:` in the domain YAML for zones without DST (Arizona) — the Phoenix A/B domain does.
- **A/B acceptance (NAM vs RRFS)**: `examples/phoenix-ab.yaml` + `phoenix-sites.csv`, `scripts/ab_compare.py`, `.github/workflows/test-ab.yml`. James accepts/rejects; never self-promote.
- **Soaring ceiling (hcrit)**: uses DrJack's nonlinear thermal penetration model from `rasp/soaring.py`, NOT the WRF W field (which doesn't resolve thermals at 1.33km)
- **Pressure conversion**: heights ASL must be converted to AGL before dividing by 32 to get pressure delta. The bug `sfc_p - height_ASL/32` was a major source of incorrect crescent placement.

## Branch Workflow

- `main` is protected: requires PR with 1 review (admin exempt)
- No force pushes to main
- CI runs on PRs: Python import tests, namelist generation, Docker build
- Release: tag `v*` triggers multi-arch image build + GHCR publish

## Testing

```bash
# Quick smoke test
uv run python -c "from rasp.soaring import calc_wstar; from rasp.windgram import render_windgram; print('OK')"

# Namelist generation test
uv run python -m rasp.namelist_generator examples/cascades.yaml --date 2026-04-06 --cycle 00 --output-dir /tmp/test
```
