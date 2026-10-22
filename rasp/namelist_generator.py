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

from .lattice import lattice_placement, parse_lattice

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
        # Retired by NCEP 2026-11-03 (replaced by "rrfs" below). NOTE: the awip3d
        # product this entry downloads is NCEP grid 212 = 40.6 km (Lambert
        # 185x129), not the 12 km grid 218 (awphys/awip12). "dx" is left at the
        # nominal 12 km so existing nest chains (outer_dx_km) don't change.
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
        # {root}: RASP_HRRR_ROOT env var, else "root" below. NOAA's Open Data
        # mirror https://noaa-hrrr-bdp-pds.s3.amazonaws.com has the same layout.
        "root": "https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod",
        "url_pattern": "{root}/hrrr.{date}/conus/hrrr.t{cycle}z.wrfprsf{fhr:02d}.grib2",
        # Direct reader: skip WPS/WRF, read HRRR GRIB output directly.
        # HRRR IS a WRF model at 3km — re-running WRF loses cloud state
        # and produces false soaring forecasts on cloudy days.
        "direct_reader": True,
        "sfc_url_pattern": "{root}/hrrr.{date}/conus/hrrr.t{cycle}z.wrfsfcf{fhr:02d}.grib2",
        # WRF nesting path (direct_reader: false):
        # Pass 1: wrf_vtable extracts atmosphere + hydrometeors (QC/QR/QI/QS/QG)
        #   for cloud state initialization (avoids cloud spin-up on cloudy days)
        # Pass 2: sfc_vtable extracts soil (SOILT/SOILM) via Vtable.raphrrr
        "wrf_vtable": "Vtable.HRRR.full",
        "sfc_vtable": "Vtable.raphrrr",
    },
    "rrfs": {
        # NAM's replacement (NAM retires 2026-11-03, SCN 26-47/26-48). Used as
        # the boundary/initial-condition source for the SAME DrJack WRF chain
        # as NAM (4 km -> 1.33 km, see examples/cascades.yaml); RRFS is a 3 km
        # FV3-LAM, so a 3 km parent feeds the 4 km outer domain. See
        # RRFS_MIGRATION.md.
        "name": "RRFS (Rapid Refresh Forecast System)",
        "dx": 3000.0,
        # Custom Vtable: Vtable.NAM atmosphere/surface rows + RAP/HRRR-style
        # 9-level RUC soil (RRFS encodes soil like HRRR, not like NAM).
        # Atmosphere lives in the prslev file, everything 2-D in the 2dfld file;
        # both are linked into one ungrib pass (ungrib merges by valid time).
        "vtable": "Vtable.RRFS",
        "interval_seconds": 10800,     # 3h boundaries like NAM (hourly output exists)
        "forecast_hours": list(range(0, 85)),   # 00/06/12/18z reach 84h; others 18h
        "cycles": [0, 6, 12, 18],
        "coverage": "CONUS subset (3 km Lambert, same grid as HRRR) of the NA domain",
        "source": "nomads",
        # {root} is resolved at run time: RASP_RRFS_ROOT env var, else "root"
        # below. Pre-cutover parallel feed is rrfs/v1.0 (also rrfs/para);
        # from 2026-11-03 the documented production path is rrfs/prod.
        "root": "https://nomads.ncep.noaa.gov/pub/data/nccf/com/rrfs/v1.0",
        "url_pattern": "{root}/rrfs.{date}/{cycle}/rrfs.t{cycle}z.prslev.3km.f{fhr:03d}.conus.grib2",
        "sfc_url_pattern": "{root}/rrfs.{date}/{cycle}/rrfs.t{cycle}z.2dfld.3km.f{fhr:03d}.conus.grib2",
        # Byte-range subsetting via the .grib2.idx sidecar (no NOMADS grib
        # filter exists for RRFS). Patterns are fnmatch'd against "VAR:LEVEL"
        # from the .idx. Measured on a live file: with gaps <= 2 MB merged,
        # prslev 558 MB -> ~305 MB in ~51 ranges, 2dfld 334 MB -> ~55 MB in
        # ~7 ranges (vs 90+17 ranges unmerged; NOMADS rate-limits hits).
        # Keep in sync with Vtable.RRFS.
        "idx_max_gap_mb": 2,
        "idx_subset": [
            "TMP:* mb", "UGRD:* mb", "VGRD:* mb", "RH:* mb", "HGT:* mb",
        ],
        "sfc_idx_subset": [
            "TMP:2 m above ground", "RH:2 m above ground",
            "UGRD:10 m above ground", "VGRD:10 m above ground",
            "PRES:surface", "MSLET:mean sea level", "HGT:surface",
            "TMP:surface", "WEASD:surface", "SNOD:surface", "CNWAT:surface",
            "LAND:surface", "ICEC:surface",
            "TSOIL:*", "SOILW:*",
        ],
        # Direct reader (fallback, like HRRR): profiles from prslev, surface
        # fields from 2dfld.
        "prs_glob": "*prslev*.grib2",
        "sfc_glob": "*2dfld*.grib2",
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
        utc_offset: -7          # optional; default is estimated from center_lon
                                # (+1 for DST). Set for zones without DST (Arizona).
        physics:                # optional overrides
          cu_physics: 0
          bl_pbl_physics: 2
        lattice:                # optional shared projection + grid lattice
          truelat1: 46.0        # (rasp.lattice); tiles with the same block
          truelat2: 49.0        # get coincident grid points where they overlap
          stand_lon: -120.5
          ref_lat: 47.5         # lattice origin: a mass point of every
          ref_lon: -120.5       # tile's finest grid
        # Optional overrides of the model-registry entry (rasp.pipeline
        # DOMAIN_MODEL_OVERRIDES); absent keys keep the registry behaviour:
        direct_reader: false            # force WPS/WRF (HRRR defaults to the direct reader)
        vtable: Vtable.RAP.pressure.ncep  # ungrib Vtable for the atmosphere pass
        sfc_vtable: Vtable.raphrrr      # soil pass Vtable; null skips the pass
        idx_subset: ["TMP:* mb", ...]   # .idx byte-range patterns (main / surface file)
        sfc_idx_subset: [...]
        idx_max_gap_mb: 2
        dynamics:               # optional WRF stability overrides (DYNAMICS_KEYS);
          time_step: 16         # absent keys keep the generator defaults
          epssm: 0.5
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
    if config.get("utc_offset") is not None:
        config["utc_offset"] = int(config["utc_offset"])

    # Registry overrides (see rasp.pipeline DOMAIN_MODEL_OVERRIDES)
    for key in ("vtable", "sfc_vtable"):
        v = config.get(key)
        if v is not None and (not isinstance(v, str) or not v.strip() or "/" in v):
            raise ValueError(f"{key}: expected a Vtable file name (no path), got {v!r}")
    for key in ("idx_subset", "sfc_idx_subset"):
        v = config.get(key)
        if v is not None and (not isinstance(v, list) or not v
                              or not all(isinstance(p, str) and p for p in v)):
            raise ValueError(f"{key}: expected a non-empty list of 'VAR:LEVEL' patterns")
    if config.get("idx_max_gap_mb") is not None:
        config["idx_max_gap_mb"] = float(config["idx_max_gap_mb"])

    # Shared lattice (rasp.lattice). Absent / null -> centre-based grid, unchanged.
    if config.get("lattice") is not None:
        config["lattice"] = parse_lattice(config["lattice"])
        if config["nest_ratio"] % 2 == 0:
            raise ValueError("lattice: nest_ratio must be odd so nest mass points "
                             "stay on the lattice")
    else:
        config.pop("lattice", None)

    # WRF dynamics / stability overrides. Absent / null -> generator defaults.
    if config.get("dynamics") is not None:
        config["dynamics"] = parse_dynamics(config["dynamics"])
    else:
        config.pop("dynamics", None)

    if config["model"] not in MODEL_DX:
        raise ValueError(
            f"Unknown model: {config['model']}. "
            f"Supported: {', '.join(MODEL_DX.keys())}"
        )

    return config


# Keys of the optional ``dynamics:`` block -> (namelist group, kind, default).
# Only options WRF 4.5 honours and that bear on stability over steep terrain.
# ``default`` is what the generator emits when the key is absent (None = the
# key is not written, i.e. WRF's own default applies). Per-domain kinds accept a
# scalar (all domains) or a list with one value per domain.
DYNAMICS_KEYS = {
    # Outer-domain step (s); nests divide it by parent_time_step_ratio.
    # Default 6 * outer dx_km.
    "time_step":        ("domains",  "pos_int",     None),
    # Sound-wave off-centering (WRF default 0.1); 0.5 damps the vertically
    # propagating acoustic modes that steep terrain excites.
    "epssm":            ("dynamics", "frac_dom",    None),
    # Vertical-velocity damping where the vertical Courant number nears 1.
    "w_damping":        ("dynamics", "flag",        1),
    # Adaptive implicit vertical advection (IEVA, WRF >= 4.3): removes the
    # vertical-advection CFL limit; WRF guidance pairs it with w_damping.
    "zadvect_implicit": ("dynamics", "flag",        None),
    # 6th-order horizontal numerical diffusion (2 = monotonic, no up-gradient).
    "diff_6th_opt":     ("dynamics", "diff6_dom",   0),
    "diff_6th_factor":  ("dynamics", "frac_dom",    0.12),
    # Hybrid sigma-pressure vertical coordinate (2): terrain influence on the
    # coordinate surfaces decays with height instead of reaching the model top.
    "hybrid_opt":       ("dynamics", "hybrid",      0),
    # Adaptive time step (&domains): WRF picks each step from the measured
    # horizontal and vertical Courant numbers. step_to_output_time keeps
    # history times on the hour; it is written as .true. whenever
    # use_adaptive_time_step is on unless set explicitly. Time steps are integer
    # seconds per domain (-1 = WRF's dx-based default).
    "use_adaptive_time_step": ("domains", "logical", None),
    "step_to_output_time":    ("domains", "logical", None),
    "target_cfl":             ("domains", "pos_dom", None),
    "target_hcfl":            ("domains", "pos_dom", None),
    "max_step_increase_pct":  ("domains", "pct_dom", None),
    "starting_time_step":     ("domains", "step_dom", None),
    "max_time_step":          ("domains", "step_dom", None),
    "min_time_step":          ("domains", "step_dom", None),
    "adaptation_domain":      ("domains", "pos_int", None),
}

# Optional lines (written only when set, so namelists without a dynamics
# block stay byte-identical), in WRF Registry order.
_OPTIONAL_DOMAINS = ("use_adaptive_time_step", "step_to_output_time", "target_cfl",
                     "target_hcfl", "max_step_increase_pct", "starting_time_step",
                     "max_time_step", "min_time_step", "adaptation_domain")
_OPTIONAL_DYNAMICS = ("epssm", "zadvect_implicit")


def parse_dynamics(block):
    """Validate a ``dynamics:`` block; returns {key: value} with WRF types."""
    if not isinstance(block, dict):
        raise ValueError("dynamics: expected a mapping of WRF dynamics options")
    unknown = sorted(set(block) - set(DYNAMICS_KEYS))
    if unknown:
        raise ValueError(f"dynamics: unknown key(s) {', '.join(unknown)}; "
                         f"supported: {', '.join(DYNAMICS_KEYS)}")
    out = {}
    for key, val in block.items():
        if val is None:
            continue
        kind = DYNAMICS_KEYS[key][1]
        vals = val if isinstance(val, list) else [val]
        if not vals or (isinstance(val, list) and not kind.endswith("_dom")):
            raise ValueError(f"dynamics.{key}: expected a single value, got {val!r}")
        checked = []
        for v in vals:
            if kind == "logical":
                if isinstance(v, str) and v.lower() in ("true", "false"):
                    v = v.lower() == "true"     # _parse_simple_yaml fallback
                if not isinstance(v, bool):
                    raise ValueError(f"dynamics.{key}: expected true/false, got {v!r}")
                checked.append(v)
                continue
            if isinstance(v, bool) and kind != "flag":
                raise ValueError(f"dynamics.{key}: expected a number, got {v!r}")
            if kind == "pos_int":
                if not isinstance(v, int) or v <= 0:
                    raise ValueError(f"dynamics.{key}: expected a positive integer "
                                     f"(seconds), got {v!r}")
            elif kind == "flag":
                if isinstance(v, str) and v.lower() in ("true", "false"):
                    v = v.lower() == "true"     # _parse_simple_yaml fallback
                if isinstance(v, bool):
                    v = int(v)
                if v not in (0, 1):
                    raise ValueError(f"dynamics.{key}: expected 0/1 (or true/false), got {v!r}")
            elif kind == "hybrid":
                if isinstance(v, bool) or v not in (0, 2):
                    raise ValueError(f"dynamics.{key}: expected 0 (terrain-following) "
                                     f"or 2 (hybrid), got {v!r}")
            elif kind == "diff6_dom":
                if isinstance(v, bool) or v not in (0, 1, 2):
                    raise ValueError(f"dynamics.{key}: expected 0, 1 or 2, got {v!r}")
            elif kind == "pos_dom":
                if not isinstance(v, (int, float)) or v <= 0:
                    raise ValueError(f"dynamics.{key}: expected a positive number, got {v!r}")
                v = float(v)
            elif kind == "pct_dom":
                if not isinstance(v, int) or v <= 0:
                    raise ValueError(f"dynamics.{key}: expected a positive integer "
                                     f"(percent), got {v!r}")
            elif kind == "step_dom":
                if not isinstance(v, int) or (v <= 0 and v != -1):
                    raise ValueError(f"dynamics.{key}: expected a positive integer "
                                     f"(seconds) or -1 (WRF default), got {v!r}")
            elif kind == "frac_dom":
                if not isinstance(v, (int, float)) or not 0 <= v <= 1:
                    raise ValueError(f"dynamics.{key}: expected a number in [0, 1], got {v!r}")
                v = float(v)
            checked.append(v)
        out[key] = checked if isinstance(val, list) else checked[0]
    adaptive_only = [k for k in out if k in _OPTIONAL_DOMAINS[1:]]
    if adaptive_only and not out.get("use_adaptive_time_step"):
        raise ValueError(f"dynamics: {', '.join(adaptive_only)} only apply with "
                         f"use_adaptive_time_step: true")
    if out.get("use_adaptive_time_step"):
        out.setdefault("step_to_output_time", True)
    return out


def _parse_simple_yaml(text):
    """Minimal parser for key: value YAML with one level of nested blocks.

    A key with no value followed by indented ``key: value`` lines becomes a
    dict (``physics:``, ``lattice:``). Lists and deeper nesting are not
    supported; PyYAML (a dependency) is the normal path.
    """
    result = {}
    block = None            # dict of the open nested block, if any
    for raw in text.strip().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        indented = raw[:1] in (" ", "\t")
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
        if indented and block is not None:
            block[key] = val
            continue
        if val == "":
            block = result[key] = {}
            continue
        block = None
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
    # outer_dx_km lets the domain YAML skip the coarsest WRF step.
    # E.g. for NAM (12km native), setting outer_dx_km=4 means WRF interpolates
    # NAM 12km directly into a 4km outer domain, skipping the 12km WRF integration.
    # Matches DrJack RASP convention for higher-quality fine-nest forcing.
    outer_dx_m = float(config.get("outer_dx_km", MODEL_DX[model] / 1000.0)) * 1000.0

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


def outer_time_step(config, domains):
    """Outer-domain WRF time step (s): ``dynamics.time_step`` or 6 * dx_km."""
    dt = (config.get("dynamics") or {}).get("time_step")
    return dt if dt is not None else int(6 * domains[0]["dx_km"])


def estimate_runtime(domains, ncores=4, time_step=None):
    """Rough estimate of WRF wall-clock time.

    Based on ~1 second per 10,000 grid points per time step on a single core,
    scaled by core count and number of time steps.

    Returns estimated minutes.
    """
    total_cost = 0
    # Nest steps follow parent_time_step_ratio (= parent_grid_ratio), so a
    # custom outer step scales every domain by the same factor.
    scale = time_step / (6 * domains[0]["dx_km"]) if time_step else 1.0
    for d in domains:
        points = d["e_we"] * d["e_sn"]
        dt = max(6 * d["dx_km"] * scale, 1)  # time step in seconds
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

    if config.get("lattice"):
        # Shared lattice: one projection for every tile, d01 placed so the
        # lattice origin is its mass point (ref_x, ref_y) -- see rasp.lattice.
        lp = lattice_placement(config, domains)
        proj_lines = (
            f" map_proj = 'lambert',\n"
            f" ref_lat  = {lp['ref_lat']:.6f},\n"
            f" ref_lon  = {lp['ref_lon']:.6f},\n"
            f" ref_x    = {lp['ref_x']:.1f},\n"
            f" ref_y    = {lp['ref_y']:.1f},\n"
            f" truelat1 = {lp['truelat1']:.6f},\n"
            f" truelat2 = {lp['truelat2']:.6f},\n"
            f" stand_lon = {lp['stand_lon']:.6f},\n")
    else:
        proj_lines = (
            f" map_proj = 'lambert',\n"
            f" ref_lat  = {config['center_lat']:.4f},\n"
            f" ref_lon  = {config['center_lon']:.4f},\n"
            f" truelat1 = {config['center_lat']:.4f},\n"
            f" truelat2 = {config['center_lat']:.4f},\n"
            f" stand_lon = {config['center_lon']:.4f},\n")

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
{proj_lines} geog_data_path = '{geog_path}',
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

    # Time step: ~6 * dx_km for the outer domain unless dynamics.time_step
    dt = outer_time_step(config, domains)
    dyn = config.get("dynamics") or {}

    def dyn_val(key):
        """Override if given, else the generator default (both per-domain-repped)."""
        v = dyn.get(key, DYNAMICS_KEYS[key][2])
        # Per-domain WRF options are repeated per domain; the others are single.
        if isinstance(v, bool) or (isinstance(v, list) and v and isinstance(v[0], bool)):
            v = [(".true." if x else ".false.") for x in v] if isinstance(v, list) \
                else (".true." if v else ".false.")
        return rep(v) if DYNAMICS_KEYS[key][1].endswith("_dom") else str(v)

    # Optional lines: only written when overridden, so namelists of domains
    # without a dynamics block stay byte-identical.
    for k, v in dyn.items():
        if isinstance(v, list) and len(v) != ndomains:
            raise ValueError(f"dynamics.{k}: {len(v)} values for {ndomains} domains")
    extra = "".join(f" {k:<24} = {dyn_val(k)},\n"
                    for k in _OPTIONAL_DYNAMICS if k in dyn)
    extra_domains = "".join(f" {k:<24} = {dyn_val(k)},\n"
                            for k in _OPTIONAL_DOMAINS if k in dyn)
    if dyn.get("adaptation_domain", 1) > ndomains:
        raise ValueError(f"dynamics.adaptation_domain: only {ndomains} domains")

    # Vertical levels (e_vert) — configurable via domain YAML, default 45
    e_vert = int(config.get("e_vert", 45))

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
 e_vert                   = {rep(e_vert)},
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
 feedback                 = 0,
 smooth_option            = 0,
{extra_domains}/

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
 hybrid_opt               = {dyn_val('hybrid_opt')},
 w_damping                = {dyn_val('w_damping')},
 diff_opt                 = 1,
 km_opt                   = 4,
 diff_6th_opt             = {dyn_val('diff_6th_opt')},
 diff_6th_factor          = {dyn_val('diff_6th_factor')},
 base_temp                = 290.,
 damp_opt                 = 3,
 zdamp                    = {rep(5000.)},
 dampcoef                 = {rep(0.2)},
 khdif                    = {rep(0)},
 kvdif                    = {rep(0)},
 non_hydrostatic          = {rep('.true.')},
 moist_adv_opt            = {rep(1)},
 scalar_adv_opt           = {rep(1)},
{extra}/

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
                "{root}/hrrr.{date}/conus/hrrr.t{cycle}z.wrfnatf{fhr:02d}.grib2"
            )

    domains = compute_nest_chain(config)
    warnings = check_warnings(domains)
    est_minutes = estimate_runtime(domains, time_step=outer_time_step(config, domains))

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

    lattice = None
    if config.get("lattice"):
        lattice = lattice_placement(config, domains)
        print_lattice_summary(lattice)

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
        "lattice": lattice,
    }


def print_lattice_summary(lp):
    """Log the lattice snap so the pipeline output shows where the tile landed."""
    (nlat, nlon), (slat, slon) = lp["nominal_center"], lp["snapped_center"]
    sx, sy = lp["center_shift_m"]
    print(f"\n  Shared lattice: lambert truelat1={lp['truelat1']} "
          f"truelat2={lp['truelat2']} stand_lon={lp['stand_lon']}, "
          f"origin {lp['ref_lat']}, {lp['ref_lon']}")
    print(f"    Nominal center: {nlat:.5f}, {nlon:.5f}")
    print(f"    Snapped center: {slat:.5f}, {slon:.5f}  "
          f"(shift {sx:+.0f} m E, {sy:+.0f} m N)")
    for n, (i, j) in enumerate(lp["origin_ij"], start=1):
        print(f"    Origin at d{n:02d} mass (i, j) = ({i}, {j})")
    fi, fj = lp["fine_offset"]
    print(f"    Finest grid (dx {lp['fine_dx']:.2f} m): mass point (1, 1) = "
          f"lattice ({fi}, {fj})")


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
