"""
Namelist generator — produces namelist.wps and namelist.input from a domain config.

Takes a YAML domain definition (center lat/lon, target resolution, extent) and
generates all WRF/WPS namelists with auto-computed nesting chains, grid dimensions,
time steps, and physics selections.

Usage:
    python -m rasp.namelist_generator domain.yaml --date 2024-04-02 --cycle 06

    Or programmatically:
        from rasp.namelist_generator import generate_namelists
        generate_namelists("domain.yaml", date="2024-04-02", cycle="06")
"""

import argparse
import math
import sys
from datetime import datetime, timedelta
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Model registry — each supported NWP model and its properties
# ---------------------------------------------------------------------------
MODELS = {
    "nam": {
        "name": "NAM (North American Mesoscale)",
        "dx": 12000.0,
        "vtable": "Vtable.NAM",
        "interval_seconds": 10800,     # 3h
        "forecast_hours": list(range(6, 85, 3)),  # 6-84h, 3h steps
        "cycles": [0, 6, 12, 18],
        "coverage": "North America",
        "source": "nomads",
        "url_pattern": "https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.{date}/nam.t{cycle}z.awip3d{fhr:02d}.tm00.grib2",
    },
    "hrrr": {
        "name": "HRRR (High-Resolution Rapid Refresh)",
        "dx": 3000.0,
        "vtable": "Vtable.RAP.pressure.ncep",
        "interval_seconds": 3600,      # 1h
        "forecast_hours": list(range(0, 49)),  # 0-48h
        "cycles": [0, 6, 12, 18],      # major cycles only (go to 48h; others only 18h)
        "coverage": "CONUS",
        "source": "nomads",
        "url_pattern": "https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/hrrr.{date}/conus/hrrr.t{cycle}z.wrfprsf{fhr:02d}.grib2",
        # Direct reader: skip WPS/WRF, read HRRR GRIB output directly.
        # HRRR IS a WRF model at 3km — re-running WRF loses cloud state
        # and produces false soaring forecasts on cloudy days.
        "direct_reader": True,
        "sfc_url_pattern": "https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/hrrr.{date}/conus/hrrr.t{cycle}z.wrfsfcf{fhr:02d}.grib2",
        # WRF nesting path (direct_reader: false):
        # Pass 1: wrf_vtable extracts atmosphere (+ hydrometeors if using Vtable.HRRR.full)
        # Pass 2: sfc_vtable extracts soil (SOILT/SOILM) via Vtable.raphrrr
        # TODO: re-enable hydrometeors once WRF stability issue is resolved
        # "wrf_vtable": "Vtable.HRRR.full",
        "sfc_vtable": "Vtable.raphrrr",
    },
    "gfs": {
        "name": "GFS (Global Forecast System)",
        "dx": 25000.0,
        "vtable": "Vtable.GFS",
        "interval_seconds": 10800,     # 3h (1h for fhr 0-120)
        "forecast_hours": list(range(0, 121, 3)) + list(range(123, 385, 3)),
        "cycles": [0, 6, 12, 18],
        "coverage": "Global",
        "source": "nomads",
        "url_pattern": "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.{date}/{cycle}/atmos/gfs.t{cycle}z.pgrb2.0p25.f{fhr:03d}",
    },
    "hrdps": {
        "name": "HRDPS (High Resolution Deterministic Prediction System)",
        "dx": 2500.0,
        "vtable": "Vtable.HRDPS",      # TODO: create or find
        "interval_seconds": 3600,
        "forecast_hours": list(range(0, 49)),
        "cycles": [0, 6, 12, 18],
        "coverage": "Canada",
        "source": "msc_datamart",
        "url_pattern": "https://dd.weather.gc.ca/model_hrdps/continental/2.5km/{cycle}/{fhr:03d}/",
    },
}

# Convenience accessors for backward compat
MODEL_DX = {k: v["dx"] for k, v in MODELS.items()}
MODEL_FORECAST_HOURS = {k: v["forecast_hours"] for k, v in MODELS.items()}
MODEL_VTABLE = {k: v["vtable"] for k, v in MODELS.items()}


# ---------------------------------------------------------------------------
# Domain config parsing
# ---------------------------------------------------------------------------

def load_domain_config(config_path):
    """Load and validate a domain YAML config file.

    Expected format:
        name: cascades
        model: nam
        center_lat: 47.6
        center_lon: -121.4
        target_dx_km: 1.33
        inner_extent_km: 150
        outer_extent_km: 600    # optional, auto-sized if omitted
        nest_ratio: 3           # optional, default 3
        hrrr_levels: pressure   # optional, HRRR only: 'pressure' (default) or 'native'
        physics:                # optional overrides
          cu_physics: 0
          bl_pbl_physics: 2
    """
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Domain config not found: {config_path}")

    text = path.read_text()

    if yaml is not None:
        config = yaml.safe_load(text)
    else:
        # Minimal YAML-like parser for simple key: value files
        config = _parse_simple_yaml(text)

    # Validate required fields
    required = ["name", "model", "center_lat", "center_lon", "target_dx_km",
                "inner_extent_km"]
    for field in required:
        if field not in config:
            raise ValueError(f"Missing required field: {field}")

    # Defaults
    config.setdefault("nest_ratio", 3)
    config.setdefault("physics", {})

    # Type coercion
    config["center_lat"] = float(config["center_lat"])
    config["center_lon"] = float(config["center_lon"])
    config["target_dx_km"] = float(config["target_dx_km"])
    config["inner_extent_km"] = float(config["inner_extent_km"])
    config["nest_ratio"] = int(config["nest_ratio"])
    config["model"] = config["model"].lower()

    if config["model"] not in MODEL_DX:
        raise ValueError(
            f"Unknown model: {config['model']}. "
            f"Supported: {', '.join(MODEL_DX.keys())}"
        )

    return config


def _parse_simple_yaml(text):
    """Minimal parser for flat key: value YAML (no nested structures)."""
    result = {}
    for line in text.strip().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip()
        if val.startswith("#"):
            val = ""
        # Remove inline comments
        if " #" in val:
            val = val[:val.index(" #")].strip()
        # Try numeric conversion
        try:
            val = int(val)
        except ValueError:
            try:
                val = float(val)
            except ValueError:
                pass
        result[key] = val
    return result


# ---------------------------------------------------------------------------
# Nesting chain computation
# ---------------------------------------------------------------------------

def compute_nest_chain(config):
    """Build the nesting chain from outer domain down to target resolution.

    Returns a list of dicts, one per domain:
        [
            {"dx": 12000, "extent_km": 600, "e_we": 51, "e_sn": 51, ...},
            {"dx": 4000, "extent_km": 200, ...},
            {"dx": 1333, "extent_km": 150, ...},
        ]
    """
    model = config["model"]
    target_dx_m = config["target_dx_km"] * 1000.0
    ratio = config["nest_ratio"]
    outer_dx_m = MODEL_DX[model]

    # Build chain from outer to inner
    chain = []
    dx = outer_dx_m
    while dx > target_dx_m * 1.01:  # tolerance for floating point
        chain.append(dx)
        dx = dx / ratio

    # Add the target (or the last computed step if it matches)
    if not chain or abs(chain[-1] / ratio - target_dx_m) / target_dx_m < 0.1:
        chain.append(dx)
    else:
        chain.append(target_dx_m)

    # If outer is already at or below target, just one domain
    if len(chain) == 0:
        chain = [target_dx_m]

    ndomains = len(chain)
    inner_extent_m = config["inner_extent_km"] * 1000.0

    # Compute extent for each domain
    # Inner domain: user-specified extent
    # Outer domains: scale up to contain inner with padding
    extents = [0.0] * ndomains
    extents[-1] = inner_extent_m

    for i in range(ndomains - 2, -1, -1):
        # Parent must be larger than child + buffer for boundary relaxation
        # WRF needs at least 10 grid points of parent around the nest
        buffer_cells = 10
        child_extent = extents[i + 1]
        min_parent_extent = child_extent + 2 * buffer_cells * chain[i]
        extents[i] = max(min_parent_extent,
                         config.get("outer_extent_km", 0) * 1000.0)
        if extents[i] == 0:
            extents[i] = min_parent_extent

    # Compute grid dimensions.
    # WRF nesting requires: (e_we - 1) % parent_grid_ratio == 0 for child domains.
    domains = []
    for i, (dx, extent) in enumerate(zip(chain, extents)):
        n = int(math.ceil(extent / dx)) + 1
        n = max(n, 11)
        # For nested domains, ensure (n-1) is divisible by parent ratio
        if i > 0:
            while (n - 1) % ratio != 0:
                n += 1

        domains.append({
            "id": i + 1,
            "dx": dx,
            "dx_km": dx / 1000.0,
            "extent_km": extent / 1000.0,
            "e_we": n,
            "e_sn": n,  # square domain for simplicity
            "parent_id": max(i, 1),
            "parent_grid_ratio": 1 if i == 0 else ratio,
        })

    # Compute parent start indices (center the nest in the parent)
    for i in range(1, ndomains):
        parent = domains[i - 1]
        child = domains[i]
        # Child grid points in parent coordinates
        child_parent_cells = child["e_we"] // child["parent_grid_ratio"]
        i_start = (parent["e_we"] - child_parent_cells) // 2 + 1
        j_start = (parent["e_sn"] - child_parent_cells) // 2 + 1
        child["i_parent_start"] = max(i_start, 2)
        child["j_parent_start"] = max(j_start, 2)

    domains[0]["i_parent_start"] = 1
    domains[0]["j_parent_start"] = 1

    return domains


# ---------------------------------------------------------------------------
# Physics selection
# ---------------------------------------------------------------------------

def select_physics(dx_km, overrides=None, model=None, hrrr_levels="pressure"):
    """Select physics schemes appropriate for the grid resolution.

    Returns a dict of namelist physics options.
    """
    physics = {
        "mp_physics": 8,           # Thompson microphysics
        "ra_lw_physics": 4,        # RRTMG longwave
        "ra_sw_physics": 4,        # RRTMG shortwave
        "radt": 15,                # radiation call interval (min)
        "sf_sfclay_physics": 2,    # MYNN surface layer
        "sf_surface_physics": 2,   # Noah LSM
        "bl_pbl_physics": 5,       # MYNN 2.5 PBL
        "cu_physics": 0,           # off by default
        "num_land_cat": 21,        # MODIS 20-class + water
    }

    # Cumulus parameterization based on resolution
    if dx_km > 10:
        physics["cu_physics"] = 1  # Kain-Fritsch
    elif dx_km > 4:
        physics["cu_physics"] = 0  # off but borderline
    else:
        physics["cu_physics"] = 0  # must be off at convection-resolving scales

    # HRRR: Noah LSM works when surface files (wrfsfc) are downloaded alongside
    # pressure files. No physics override needed — default Noah is fine.

    # Apply user overrides
    if overrides:
        physics.update(overrides)

    return physics


# ---------------------------------------------------------------------------
# Warning system
# ---------------------------------------------------------------------------

def check_warnings(domains):
    """Emit warnings for non-standard configurations.

    Returns a list of warning strings.
    """
    warnings = []

    for d in domains:
        dx_km = d["dx_km"]
        total_points = d["e_we"] * d["e_sn"]

        if 1.0 < dx_km < 4.0:
            warnings.append(
                f"Domain d{d['id']:02d} ({dx_km:.2f}km): gray zone — "
                f"convective parameterization is off, this is reasonable "
                f"but results are experimental at this resolution."
            )
        elif 0.5 < dx_km <= 1.0:
            warnings.append(
                f"Domain d{d['id']:02d} ({dx_km:.2f}km): individual thermals "
                f"are approaching grid cell size. WRF PBL parameterizations "
                f"operate outside their design range. Results are exploratory."
            )
        elif dx_km <= 0.5:
            warnings.append(
                f"Domain d{d['id']:02d} ({dx_km*1000:.0f}m): LES territory — "
                f"standard PBL schemes are not designed for this resolution. "
                f"Compute cost will be very high."
            )

        if total_points > 500000:
            warnings.append(
                f"Domain d{d['id']:02d}: {total_points:,} grid points — "
                f"expect long run times."
            )

    return warnings


def estimate_runtime(domains, ncores=4):
    """Rough estimate of WRF wall-clock time.

    Based on ~1 second per 10,000 grid points per time step on a single core,
    scaled by core count and number of time steps.

    Returns estimated minutes.
    """
    total_cost = 0
    for d in domains:
        points = d["e_we"] * d["e_sn"]
        dt = max(6 * d["dx_km"], 1)  # time step in seconds
        # Assume 6-hour simulation, steps = 6*3600/dt
        steps = 6 * 3600 / dt
        cost = points * steps / 10000  # core-seconds
        total_cost += cost

    minutes = total_cost / ncores / 60
    return round(minutes, 1)


# ---------------------------------------------------------------------------
# Namelist generation
# ---------------------------------------------------------------------------

def generate_namelist_wps(config, domains, date, cycle, geog_path="/mnt/geog",
                          start_date=None, end_date=None):
    """Generate namelist.wps content.

    Args:
        config:    domain config dict
        domains:   list of domain dicts from compute_nest_chain
        date:      forecast date string "YYYY-MM-DD"
        cycle:     forecast cycle "HH"
        geog_path: path to WPS GEOG data

    Returns:
        namelist.wps content as string
    """
    model = config["model"]
    ndomains = len(domains)

    if start_date and end_date:
        start_str = f"{start_date}:00:00" if len(start_date) <= 13 else start_date
        end_str = f"{end_date}:00:00" if len(end_date) <= 13 else end_date
    else:
        fhours = MODEL_FORECAST_HOURS[model]
        start_dt = datetime.strptime(f"{date} {cycle}:00:00", "%Y-%m-%d %H:%M:%S")
        end_dt = start_dt + timedelta(hours=fhours[-1])
        start_str = start_dt.strftime("%Y-%m-%d_%H:%M:%S")
        end_str = end_dt.strftime("%Y-%m-%d_%H:%M:%S")

    # Repeated values for each domain
    def rep(val, n=ndomains):
        if isinstance(val, list):
            return ", ".join(str(v) for v in val)
        return ", ".join([str(val)] * n)

    dx = domains[0]["dx"]
    dy = domains[0]["dx"]

    # Determine GEOG resolution — configurable from domain YAML
    geog_res = config.get("geog_data_res")
    if not geog_res:
        finest_dx_km = domains[-1]["dx_km"]
        if finest_dx_km >= 4:
            geog_res = "lowres"
        else:
            geog_res = "default+lowres"

    lines = f"""\
&share
 wrf_core = 'ARW',
 max_dom = {ndomains},
 start_date = {rep(f"'{start_str}'")},
 end_date   = {rep(f"'{end_str}'")},
 interval_seconds = {MODELS[model]["interval_seconds"]},
 io_form_geogrid = 2,
/

&geogrid
 parent_id         = {rep([d['parent_id'] for d in domains])},
 parent_grid_ratio = {rep([d['parent_grid_ratio'] for d in domains])},
 i_parent_start    = {rep([d['i_parent_start'] for d in domains])},
 j_parent_start    = {rep([d['j_parent_start'] for d in domains])},
 e_we              = {rep([d['e_we'] for d in domains])},
 e_sn              = {rep([d['e_sn'] for d in domains])},
 geog_data_res     = {rep(f"'{geog_res}'")},
 dx = {dx:.1f},
 dy = {dy:.1f},
 map_proj = 'lambert',
 ref_lat  = {config['center_lat']:.4f},
 ref_lon  = {config['center_lon']:.4f},
 truelat1 = {config['center_lat']:.4f},
 truelat2 = {config['center_lat']:.4f},
 stand_lon = {config['center_lon']:.4f},
 geog_data_path = '{geog_path}',
/

&ungrib
 out_format = 'WPS',
 prefix = 'FILE',
/

&metgrid
 fg_name = 'FILE',
 io_form_metgrid = 2,
/
"""
    return lines


def generate_namelist_input(config, domains, date, cycle, num_metgrid_levels=40,
                            start_date=None, end_date=None, run_hours_override=None):
    """Generate namelist.input content.

    Args:
        config:              domain config dict
        domains:             list of domain dicts
        date:                forecast date "YYYY-MM-DD"
        cycle:               forecast cycle "HH"
        num_metgrid_levels:  number of vertical levels in met_em (auto-detect later)

    Returns:
        namelist.input content as string
    """
    model = config["model"]
    ndomains = len(domains)

    if start_date and end_date:
        start_dt = datetime.strptime(start_date.replace("_", " ") + ":00:00" if len(start_date) <= 13 else start_date.replace("_", " "), "%Y-%m-%d %H:%M:%S")
        end_dt = datetime.strptime(end_date.replace("_", " ") + ":00:00" if len(end_date) <= 13 else end_date.replace("_", " "), "%Y-%m-%d %H:%M:%S")
    else:
        fhours = MODEL_FORECAST_HOURS[model]
        start_dt = datetime.strptime(f"{date} {cycle}:00:00", "%Y-%m-%d %H:%M:%S")
        end_dt = start_dt + timedelta(hours=fhours[-1])

    def rep(val, n=ndomains):
        if isinstance(val, list):
            return ", ".join(str(v) for v in val)
        return ", ".join([str(val)] * n)

    # Time step: ~6 * dx_km for the outer domain
    dt = int(6 * domains[0]["dx_km"])

    # History output interval (minutes)
    hist_interval = 60

    # Physics
    hrrr_levels = config.get("hrrr_levels", "pressure") if model == "hrrr" else "pressure"
    physics = select_physics(domains[-1]["dx_km"], config.get("physics"),
                             model=model, hrrr_levels=hrrr_levels)

    # Per-domain physics (some must match, some can differ)
    # cu_physics should be 0 for fine nests
    cu_per_domain = []
    for d in domains:
        if d["dx_km"] > 10:
            cu_per_domain.append(physics.get("cu_physics", 1))
        else:
            cu_per_domain.append(0)

    lines = f"""\
&time_control
 run_days                 = 0,
 run_hours                = {run_hours_override if run_hours_override else int((end_dt - start_dt).total_seconds() // 3600)},
 run_minutes              = 0,
 run_seconds              = 0,
 start_year               = {rep(start_dt.year)},
 start_month              = {rep(f'{start_dt.month:02d}')},
 start_day                = {rep(f'{start_dt.day:02d}')},
 start_hour               = {rep(f'{start_dt.hour:02d}')},
 start_minute             = {rep('00')},
 start_second             = {rep('00')},
 end_year                 = {rep(end_dt.year)},
 end_month                = {rep(f'{end_dt.month:02d}')},
 end_day                  = {rep(f'{end_dt.day:02d}')},
 end_hour                 = {rep(f'{end_dt.hour:02d}')},
 end_minute               = {rep('00')},
 end_second               = {rep('00')},
 interval_seconds         = {MODELS[model]["interval_seconds"]},
 input_from_file          = {rep('.true.')},
 history_interval         = {rep(hist_interval)},
 frames_per_outfile       = {rep(1000)},
 restart                  = .false.,
 restart_interval         = 5000,
 io_form_history          = 2,
 io_form_restart          = 2,
 io_form_input            = 2,
 io_form_boundary         = 2,
/

&domains
 time_step                = {dt},
 time_step_fract_num      = 0,
 time_step_fract_den      = 1,
 max_dom                  = {ndomains},
 e_we                     = {rep([d['e_we'] for d in domains])},
 e_sn                     = {rep([d['e_sn'] for d in domains])},
 e_vert                   = {rep(45)},
 dzstretch_s              = 1.1,
 p_top_requested          = 5000,
 num_metgrid_levels       = {num_metgrid_levels},
 num_metgrid_soil_levels  = 4,
 dx                       = {rep([d['dx'] for d in domains])},
 dy                       = {rep([d['dx'] for d in domains])},
 grid_id                  = {rep(list(range(1, ndomains + 1)))},
 parent_id                = {rep([d['parent_id'] for d in domains])},
 i_parent_start           = {rep([d['i_parent_start'] for d in domains])},
 j_parent_start           = {rep([d['j_parent_start'] for d in domains])},
 parent_grid_ratio        = {rep([d['parent_grid_ratio'] for d in domains])},
 parent_time_step_ratio   = {rep([d['parent_grid_ratio'] for d in domains])},
 feedback                 = 1,
 smooth_option            = 0,
/

&physics
 mp_physics               = {rep(physics['mp_physics'])},
 ra_lw_physics            = {rep(physics['ra_lw_physics'])},
 ra_sw_physics            = {rep(physics['ra_sw_physics'])},
 radt                     = {rep(physics['radt'])},
 sf_sfclay_physics        = {rep(physics['sf_sfclay_physics'])},
 sf_surface_physics       = {rep(physics['sf_surface_physics'])},
 bl_pbl_physics           = {rep(physics['bl_pbl_physics'])},
 bldt                     = {rep(0)},
 cu_physics               = {rep(cu_per_domain)},
 cudt                     = {rep(5)},
 isfflx                   = 1,
 ifsnow                   = 1,
 icloud                   = 1,
 surface_input_source     = 3,
 num_soil_layers          = 4,
 num_land_cat             = {physics['num_land_cat']},
 sf_urban_physics         = 0,
/

&fdda
/

&dynamics
 hybrid_opt               = 2,
 w_damping                = 0,
 diff_opt                 = 1,
 km_opt                   = 4,
 diff_6th_opt             = {rep(0)},
 diff_6th_factor          = {rep(0.12)},
 base_temp                = 290.,
 damp_opt                 = 3,
 zdamp                    = {rep(5000.)},
 dampcoef                 = {rep(0.2)},
 khdif                    = {rep(0)},
 kvdif                    = {rep(0)},
 non_hydrostatic          = {rep('.true.')},
 moist_adv_opt            = {rep(1)},
 scalar_adv_opt           = {rep(1)},
/

&bdy_control
 spec_bdy_width           = 5,
 specified                = {rep(['.true.' if i == 0 else '.false.' for i in range(ndomains)])},
 nested                   = {rep(['.false.' if i == 0 else '.true.' for i in range(ndomains)])},
/

&namelist_quilt
 nio_tasks_per_group      = 0,
 nio_groups               = 1,
/
"""
    return lines


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def generate_namelists(config_path, date, cycle, output_dir=None,
                       geog_path="/mnt/geog", num_metgrid_levels=40,
                       start_date=None, end_date=None, run_hours=None,
                       interval_seconds_override=None):
    """Generate namelist.wps and namelist.input from a domain config.

    Args:
        config_path: path to domain.yaml
        date:        "YYYY-MM-DD"
        cycle:       "HH" (e.g. "06")
        output_dir:  where to write namelists (default: current directory)
        geog_path:   GEOG data path
        num_metgrid_levels: vertical levels in met_em (auto-detect if possible)
        start_date:  explicit start date "YYYY-MM-DD_HH" (overrides cycle+fhours)
        end_date:    explicit end date "YYYY-MM-DD_HH" (overrides cycle+fhours)
        run_hours:   explicit run hours (overrides fhours)

    Returns:
        dict with keys "namelist_wps", "namelist_input", "warnings", "domains"
    """
    config = load_domain_config(config_path)

    # HRRR level type: 'pressure' (default, smaller) or 'native' (larger, better soil)
    if config["model"] == "hrrr":
        hrrr_levels = config.get("hrrr_levels", "pressure")
        if hrrr_levels == "native":
            MODELS["hrrr"]["vtable"] = "Vtable.raphrrr"
            MODELS["hrrr"]["url_pattern"] = (
                "https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/"
                "hrrr.{date}/conus/hrrr.t{cycle}z.wrfnatf{fhr:02d}.grib2"
            )

    domains = compute_nest_chain(config)
    warnings = check_warnings(domains)
    est_minutes = estimate_runtime(domains)

    # Print domain summary
    print(f"\n{'='*60}")
    print(f"  Domain: {config['name']}")
    print(f"  Model:  {config['model'].upper()}")
    print(f"  Center: {config['center_lat']:.3f}, {config['center_lon']:.3f}")
    print(f"  Date:   {date} {cycle}z")
    print(f"{'='*60}")
    print(f"\n  Nesting chain ({len(domains)} domains):\n")
    for d in domains:
        print(f"    d{d['id']:02d}: {d['dx_km']:>8.2f} km  "
              f"{d['e_we']:>4d} x {d['e_sn']:<4d}  "
              f"({d['extent_km']:.0f} km)")
    print(f"\n  Estimated runtime: ~{est_minutes} min on 4 cores")

    if warnings:
        print(f"\n  Warnings:")
        for w in warnings:
            print(f"    WARNING: {w}")

    print()

    # Override interval_seconds if caller specifies (e.g. 3h for HRRR downloads)
    if interval_seconds_override:
        MODELS[config["model"]]["interval_seconds"] = interval_seconds_override

    # Generate namelists
    wps_content = generate_namelist_wps(config, domains, date, cycle, geog_path,
                                        start_date=start_date, end_date=end_date)
    input_content = generate_namelist_input(config, domains, date, cycle,
                                            num_metgrid_levels,
                                            start_date=start_date, end_date=end_date,
                                            run_hours_override=run_hours)

    # Write files
    out = Path(output_dir) if output_dir else Path.cwd()
    out.mkdir(parents=True, exist_ok=True)

    wps_path = out / "namelist.wps"
    input_path = out / "namelist.input"

    wps_path.write_text(wps_content)
    input_path.write_text(input_content)

    print(f"  Written: {wps_path}")
    print(f"  Written: {input_path}")

    return {
        "namelist_wps": str(wps_path),
        "namelist_input": str(input_path),
        "warnings": warnings,
        "domains": domains,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Generate WRF/WPS namelists from a domain config"
    )
    parser.add_argument("config", help="Path to domain.yaml")
    parser.add_argument("--date", required=True, help="Forecast date (YYYY-MM-DD)")
    parser.add_argument("--cycle", required=True, help="Forecast cycle (HH)")
    parser.add_argument("--output-dir", default=".", help="Output directory")
    parser.add_argument("--geog-path", default="/mnt/geog", help="GEOG data path")
    parser.add_argument("--num-metgrid-levels", type=int, default=40,
                        help="Number of metgrid vertical levels")
    args = parser.parse_args()

    generate_namelists(
        args.config, args.date, args.cycle,
        output_dir=args.output_dir,
        geog_path=args.geog_path,
        num_metgrid_levels=args.num_metgrid_levels,
    )


if __name__ == "__main__":
    main()
