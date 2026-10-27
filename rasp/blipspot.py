"""
Blipspot — the hourly table behind each windgram.

wxtofly.net showed this when you clicked a windgram: DrJack's "BLIPSPOT"
point extraction of the RASP parameters for one site, one column per hour,
grouped into wind / thermal / clouds. This module rebuilds that table from
the same data dict the windgram is drawn from and writes it next to the PNG
as ``<date>_<site>_blipspot.json`` (render_windgram does this by default).

What is in it, and where each number comes from:

* **Wind** (kt, direction the wind blows *from*): the lowest three model
  levels (DrJack's sfcwind0 / "tree-top" / "level above"; their heights above
  the real ground, HGT, are reported in ``levels_agl_ft``), the 10 m wind, the
  vector-averaged BL wind (soaring.calc_blavg), the wind at the BL top
  (linear interpolation), the BL wind shear (magnitude of the vector
  difference between BL top and the lowest level) and the BL convergence
  (soaring.calc_wblmaxmin: the largest vertical motion in the BL, cm/s).
* **Thermal**: W* (soaring's Deardorff w*, ft/min), the buoyancy/shear ratio
  (``wstar / sqrt(cdbl * blwind^2)`` exactly as rasp.bparam_calc.ncl computes
  it in its "american" units — wind in knots, cdbl 0.003, capped at 20), the
  three max-soar heights the chart's markers use (hcrit from
  soaring.calc_hcrit, hcrit AGL, and hcrit limited by the Espy LCL), BL top
  and depth from PBLH, BL-top variability
  (soaring.calc_bltop_pottemp_variability, 1 °C criterion), surface heating
  (HFX) and sea-level pressure.
* **Clouds & moisture**: BL cloud cover % (soaring.calc_subgrid_blcloudpct,
  DrJack's 400·RH−300 mapping, max over the BL), rain over the last hour
  (RAINC+RAINNC increments), 2 m dewpoint, the surface LCL (the same Espy
  estimate as the chart's cumulus marker), the BL condensation level
  (soaring.calc_blclheight, "OD base") and the OD potential (BL top minus
  that level), and 2 m temperature.

Units follow DrJack's PNW configuration (feet, knots, ft/min, °F, mm, mb) so
the numbers read like the old wxtofly table. CAPE and sunshine % are not
produced (neither is computed anywhere in this package).

Fields the data dict may lack (the HRRR direct reader has no 10 m wind, rain,
W column, HFX or PSFC) simply leave their rows out; the table never fails the
windgram. The frontend (pnw-soaring site/index.html) owns titles,
descriptions and colours — this file owns the numbers and their units.
"""
import json
import math
from pathlib import Path

import numpy as np

from .soaring import (
    calc_blavg,
    calc_blclheight,
    calc_bltop_pottemp_variability,
    calc_hcrit,
    calc_subgrid_blcloudpct,
    calc_wblmaxmin,
)

SCHEMA = 1

M_TO_FT = 3.28084
MS_TO_FPM = 196.85

# rasp.ncl: "at present use constant value for bl drag coefficient"
CDBL = 0.003
# rasp.ncl: limitbsratio — display cap for the ratio in light winds
BSRATIO_LIMIT = 20.0
# rasp.bparam_calc.ncl: criteriondegc for calc_bltop_pottemp_variability
BLTOP_VARIAB_CRITERION_C = 1.0
# rasp.ncl: cwbasecriteria (cloud-water threshold; the GrADS cloud-% formula
# itself only uses RH, so this just has to be the value DrJack passed)
CWBASE_CRITERIA = 0.000010

#: Every parameter the table can hold, in display order, with its unit.
UNITS = {
    # wind
    "sfc_wind_kt": "kt", "sfc_wind_dir": "deg",
    "wind10m_kt": "kt", "wind10m_dir": "deg",
    "treetop_wind_kt": "kt", "treetop_wind_dir": "deg",
    "above_treetop_wind_kt": "kt", "above_treetop_wind_dir": "deg",
    "bl_wind_kt": "kt", "bl_wind_dir": "deg",
    "bltop_wind_kt": "kt", "bltop_wind_dir": "deg",
    "bl_shear_kt": "kt",
    "bl_convergence_cms": "cm/s",
    # thermal
    "bs_ratio": "",
    "wstar_fpm": "ft/min",
    "hcrit_agl_ft": "ft",
    "hcrit_ft": "ft",
    "hglider_ft": "ft",
    "bl_top_ft": "ft",
    "bl_depth_ft": "ft",
    "bl_top_variability_ft": "ft",
    "sfc_heating_wm2": "W/m2",
    "mslp_mb": "mb",
    # clouds & moisture
    "bl_cloud_pct": "%",
    "rain_1h_mm": "mm",
    "td2_f": "F",
    "lcl_ft": "ft",
    "od_potential_ft": "ft",
    "od_base_ft": "ft",
    "t2_f": "F",
}


# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------

def _finite(x):
    try:
        return x is not None and math.isfinite(float(x))
    except (TypeError, ValueError):
        return False


def _num(x, ndigits=0):
    """Round for display; None where the value is missing or not finite."""
    if not _finite(x):
        return None
    x = float(x)
    return int(round(x)) if ndigits == 0 else round(x, ndigits)


def _col3(a):
    """(nz,) column -> (nz, 1, 1) so the 2-D soaring routines accept it."""
    return np.asarray(a, dtype=np.float64).reshape(-1, 1, 1)


def _pt(x):
    """scalar -> (1, 1)."""
    return np.array([[float(x)]], dtype=np.float64)


def _speed_dir(u, v):
    """Earth-relative u, v -> (speed, meteorological direction the wind is FROM)."""
    spd = math.hypot(float(u), float(v))
    direction = (270.0 - math.degrees(math.atan2(float(v), float(u)))) % 360.0
    return spd, direction


def _qvapor_from_td(td_c, p_mb):
    """Water-vapour mixing ratio (kg/kg) from dewpoint (C) and pressure (mb)."""
    e = 6.112 * np.exp(17.67 * td_c / (td_c + 243.5))
    return 0.622 * e / np.maximum(p_mb - e, 0.1)


def _td_from_q(q, p_pa):
    """Dewpoint (C) from mixing ratio (kg/kg) and pressure (Pa)."""
    e = max(q * p_pa / (0.622 + q), 1e-6)
    log_e = math.log(e / 611.2)
    return 243.5 * log_e / (17.67 - log_e)


def _mslp_mb(p_mb, t_k, z_m):
    """Reduce a pressure at height z (m) to mean sea level (standard lapse)."""
    return p_mb * (1.0 - 0.0065 * z_m / (t_k + 0.0065 * z_m)) ** -5.257


def _c_to_f(c):
    return c * 1.8 + 32.0


# ---------------------------------------------------------------------------
# builder
# ---------------------------------------------------------------------------

def build_blipspot(d, site_name, model_name=None, utc_offset=-7):
    """Build the blipspot dict from a windgram data dict.

    ``d`` is the dict render_windgram works from (see
    windgram._extract_site_data) *after* its soaring-day slice, so the table
    has exactly the chart's hours. Optional keys (``pblh_m``, ``hfx``, ``t2_k``,
    ``u10_kts``/``v10_kts``, ``q2``, ``psfc_mb``, ``rain_1h_mm``, ``w_ms``) add
    rows when present; without ``pblh_m`` the BL depth is backed out of the
    chart's pressure marker (32 ft/mb), as the HRRR direct reader provides
    only that.
    """
    ntimes = int(d["ntimes"])
    ter_ft = float(d["ter_ft"])
    ter_m = ter_ft / M_TO_FT
    # The chart's "terrain" is the first mass level (what every BL height is
    # measured from, so the table agrees with the chart); the level labels want
    # heights above the real ground, so use HGT for those when the file has it.
    hgt_m = d.get("hgt_m")
    ground_m = float(hgt_m) if _finite(hgt_m) else ter_m
    hours_local = ((np.asarray(d["hours_utc"]) + utc_offset) % 24).astype(int).tolist()

    pblh_m = d.get("pblh_m")
    if pblh_m is None:
        pblh_m = (np.asarray(d["sfc_p"]) - np.asarray(d["pbl_p"])) * 32.0 / M_TO_FT
    t2_k = d.get("t2_k")
    if t2_k is None:
        t2_k = d["tk"][:, 0]
    u10, v10 = d.get("u10_kts"), d.get("v10_kts")
    hfx, psfc_mb, q2 = d.get("hfx"), d.get("psfc_mb"), d.get("q2")
    rain, w_ms = d.get("rain_1h_mm"), d.get("w_ms")

    rows = {k: [None] * ntimes for k in UNITS}
    level_agl_ft = np.full((ntimes, 3), np.nan)

    for t in range(ntimes):
        pblh = float(pblh_m[t]) if _finite(pblh_m[t]) else float("nan")
        if not (_finite(ter_ft) and _finite(pblh)):
            continue                      # nothing sensible to say for this hour
        pblh = max(pblh, 0.0)
        z_m = np.asarray(d["z_ft"][t], dtype=np.float64) / M_TO_FT
        nz = z_m.size
        u = np.asarray(d["u_kts"][t], dtype=np.float64)
        v = np.asarray(d["v_kts"][t], dtype=np.float64)
        p = np.asarray(d["ptot"][t], dtype=np.float64)
        tc = np.asarray(d["tc"][t], dtype=np.float64)
        td = np.asarray(d["td"][t], dtype=np.float64)
        tk = np.asarray(d["tk"][t], dtype=np.float64)
        bl_args = (_col3(z_m), _pt(ter_m), _pt(pblh))
        bl_top_m = ter_m + pblh
        level_agl_ft[t, :min(3, nz)] = (z_m[:3] - ground_m) * M_TO_FT

        # --- wind -----------------------------------------------------------
        for k, key in enumerate(("sfc_wind", "treetop_wind", "above_treetop_wind")):
            if k < nz:
                spd, drn = _speed_dir(u[k], v[k])
                rows[key + "_kt"][t] = _num(spd)
                rows[key + "_dir"][t] = _num(drn)
        if u10 is not None and v10 is not None and _finite(u10[t]) and _finite(v10[t]):
            spd, drn = _speed_dir(u10[t], v10[t])
            rows["wind10m_kt"][t] = _num(spd)
            rows["wind10m_dir"][t] = _num(drn)
        u_bl = float(calc_blavg(_col3(u), *bl_args)[0, 0])
        v_bl = float(calc_blavg(_col3(v), *bl_args)[0, 0])
        spd_bl, dir_bl = _speed_dir(u_bl, v_bl)
        rows["bl_wind_kt"][t] = _num(spd_bl)
        rows["bl_wind_dir"][t] = _num(dir_bl)
        u_top = float(np.interp(bl_top_m, z_m, u))     # clamps to the ends
        v_top = float(np.interp(bl_top_m, z_m, v))
        spd_top, dir_top = _speed_dir(u_top, v_top)
        rows["bltop_wind_kt"][t] = _num(spd_top)
        rows["bltop_wind_dir"][t] = _num(dir_top)
        rows["bl_shear_kt"][t] = _num(math.hypot(u_top - u[0], v_top - v[0]))
        if w_ms is not None:
            w_col = np.asarray(w_ms[t], dtype=np.float64)
            if w_col.size == nz and np.all(np.isfinite(w_col)):
                rows["bl_convergence_cms"][t] = _num(float(calc_wblmaxmin(0, _col3(w_col), *bl_args)[0, 0]))

        # --- thermal --------------------------------------------------------
        wstar = float(d["wstar"][t]) if _finite(d["wstar"][t]) else float("nan")
        if _finite(wstar):
            rows["wstar_fpm"][t] = _num(wstar * MS_TO_FPM)
            if wstar <= 0.0:
                bs = 0.0
            elif spd_bl <= 0.0:
                bs = BSRATIO_LIMIT
            else:
                # DrJack's american-units ratio: W* in m/s over the BL wind in knots.
                bs = min(wstar / math.sqrt(CDBL * spd_bl * spd_bl), BSRATIO_LIMIT)
            rows["bs_ratio"][t] = _num(bs, 1)
            hcrit_ft = float(calc_hcrit(_pt(wstar), _pt(ter_m), _pt(pblh))[0, 0]) * M_TO_FT
        else:
            hcrit_ft = float("nan")
        lcl_ft = ter_ft + 125.0 * max(float(tc[0] - td[0]), 0.0) * M_TO_FT   # Espy, as the chart
        rows["hcrit_ft"][t] = _num(hcrit_ft)
        rows["hcrit_agl_ft"][t] = _num(hcrit_ft - ter_ft)
        rows["hglider_ft"][t] = _num(min(hcrit_ft, lcl_ft)) if _finite(hcrit_ft) else None
        rows["lcl_ft"][t] = _num(lcl_ft)
        rows["bl_top_ft"][t] = _num(bl_top_m * M_TO_FT)
        rows["bl_depth_ft"][t] = _num(pblh * M_TO_FT)
        theta = tk * (1000.0 / p) ** 0.286
        variab_m = float(calc_bltop_pottemp_variability(_col3(theta), *bl_args, BLTOP_VARIAB_CRITERION_C)[0, 0])
        rows["bl_top_variability_ft"][t] = _num(variab_m * M_TO_FT)
        if hfx is not None:
            rows["sfc_heating_wm2"][t] = _num(hfx[t])
        if psfc_mb is not None and _finite(psfc_mb[t]) and _finite(t2_k[t]):
            rows["mslp_mb"][t] = _num(_mslp_mb(float(psfc_mb[t]), float(t2_k[t]), ter_m))
        else:
            rows["mslp_mb"][t] = _num(_mslp_mb(float(p[0]), float(tk[0]), float(z_m[0])))

        # --- clouds & moisture ---------------------------------------------
        qv = _qvapor_from_td(td, p)
        cloud = calc_subgrid_blcloudpct(_col3(qv), _col3(np.zeros(nz)), _col3(tc), _col3(p),
                                        *bl_args, CWBASE_CRITERIA)
        rows["bl_cloud_pct"][t] = _num(float(cloud[0, 0]))
        qv_bl = calc_blavg(_col3(qv), *bl_args)
        od_base_m = float(calc_blclheight(_col3(p), _col3(tc), qv_bl, *bl_args)[0, 0])
        rows["od_base_ft"][t] = _num(od_base_m * M_TO_FT)
        rows["od_potential_ft"][t] = _num((bl_top_m - od_base_m) * M_TO_FT)
        if rain is not None:
            rows["rain_1h_mm"][t] = _num(rain[t], 1)
        if _finite(t2_k[t]):
            rows["t2_f"][t] = _num(_c_to_f(float(t2_k[t]) - 273.15))
        if q2 is not None and psfc_mb is not None and _finite(q2[t]) and _finite(psfc_mb[t]):
            td2_c = _td_from_q(float(q2[t]), float(psfc_mb[t]) * 100.0)
        else:
            td2_c = float(td[0])
        rows["td2_f"][t] = _num(_c_to_f(td2_c))

    # Rows that never got a value (field absent for this model) are left out,
    # so the table only lists what this forecast actually has.
    params = {k: v for k, v in rows.items() if any(x is not None for x in v)}

    with np.errstate(all="ignore"):
        agl = np.nanmean(level_agl_ft, axis=0) if np.any(np.isfinite(level_agl_ft)) else [np.nan] * 3

    time_strings = list(d.get("time_strings") or [])
    return {
        "schema": SCHEMA,
        "site": site_name,
        "lat": _num(d.get("lat"), 4),
        "lon": _num(d.get("lon"), 4),
        "terrain_ft": _num(ter_ft),
        "model": model_name.lower() if model_name else None,
        "dx_km": _num(d.get("dx_km"), 2),
        "date": time_strings[0][:10] if time_strings else None,
        "utc_offset": int(utc_offset),
        "hours_local": hours_local,
        "valid_utc": time_strings,
        "levels_agl_ft": {"sfc": _num(agl[0]), "treetop": _num(agl[1]), "above_treetop": _num(agl[2])},
        "units": {k: UNITS[k] for k in params},
        "params": params,
    }


def write_blipspot(d, site_name, output_dir, model_name=None, utc_offset=-7):
    """Write ``<date>_<site>_blipspot.json`` into output_dir; returns its path."""
    blip = build_blipspot(d, site_name, model_name=model_name, utc_offset=utc_offset)
    date_str = blip["date"] or "undated"
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{date_str}_{site_name}_blipspot.json"
    with open(out_path, "w") as fh:
        json.dump(blip, fh, separators=(",", ":"), allow_nan=False)
    return str(out_path)
