"""
Direct HRRR reader — compute soaring indices from HRRR GRIB2 output.

Reads HRRR wrfprs (atmosphere profiles on pressure levels) and wrfsfc
(surface fields: HFX, LH, PBLH) directly, skipping WPS/WRF entirely.
HRRR is already a WRF model at 3km — re-running WRF loses the cloud
state and produces false soaring forecasts on cloudy days.

Returns the same data dict as windgram._extract_site_data() so the
windgram renderer works with either WRF output or direct HRRR GRIB.

Usage:
    from rasp.hrrr_reader import extract_hrrr_site_data
    data = extract_hrrr_site_data(prs_files, sfc_files, lat, lon)
    render_windgram(None, lat, lon, "Tiger", "./output", data=data)
"""

import eccodes
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path

from .soaring import calc_hcrit


def _find_nearest(grib_path, target_lat, target_lon):
    """Find nearest HRRR grid point for a lat/lon.

    Returns (iy, ix, actual_lat, actual_lon, nx).
    """
    with open(grib_path, "rb") as f:
        msgid = eccodes.codes_grib_new_from_file(f)
        nx = eccodes.codes_get(msgid, "Nx")
        ny = eccodes.codes_get(msgid, "Ny")

        # Get lat/lon for every grid point
        lats = eccodes.codes_get_array(msgid, "latitudes")
        lons = eccodes.codes_get_array(msgid, "longitudes")
        eccodes.codes_release(msgid)

    # Adjust longitudes to match (HRRR uses 0-360, we use -180 to 180)
    lons = np.where(lons > 180, lons - 360, lons)

    dist = (lats - target_lat) ** 2 + (lons - target_lon) ** 2
    idx = np.argmin(dist)
    iy = idx // nx
    ix = idx % nx

    return iy, ix, float(lats[idx]), float(lons[idx]), nx


def _read_prs_profile(grib_path, iy, ix, nx):
    """Read atmospheric profile from a wrfprs GRIB2 file at one grid point.

    Returns dict with arrays keyed by (shortName, level).
    """
    flat_idx = iy * nx + ix

    # Fields we need from pressure levels
    prs_fields = {"t", "gh", "r", "dpt", "u", "v"}
    # Surface/near-surface fields
    sfc_names = {
        ("t", "heightAboveGround", 2): "t2m",
        ("sp", "surface", 0): "sp",
        ("orog", "surface", 0): "orog",
        ("pres", "surface", 0): "sp",  # alternate name
    }

    levels = {}  # {pressure_mb: {field: value}}
    surface = {}  # {name: value}

    with open(grib_path, "rb") as f:
        while True:
            try:
                msgid = eccodes.codes_grib_new_from_file(f)
            except Exception:
                break
            if msgid is None:
                break
            try:
                sn = eccodes.codes_get(msgid, "shortName")
                tol = eccodes.codes_get(msgid, "typeOfLevel")
                lev = eccodes.codes_get(msgid, "level")

                if tol == "isobaricInhPa" and sn in prs_fields:
                    vals = eccodes.codes_get_values(msgid)
                    if lev not in levels:
                        levels[lev] = {}
                    levels[lev][sn] = vals[flat_idx]

                elif (sn, tol, lev) in sfc_names:
                    vals = eccodes.codes_get_values(msgid)
                    surface[sfc_names[(sn, tol, lev)]] = vals[flat_idx]

                elif tol == "surface" and sn in ("sp", "pres", "orog"):
                    vals = eccodes.codes_get_values(msgid)
                    if sn in ("sp", "pres"):
                        surface["sp"] = vals[flat_idx]
                    elif sn == "orog":
                        surface["orog"] = vals[flat_idx]

                elif tol == "heightAboveGround" and lev == 2 and sn in ("t", "2t"):
                    vals = eccodes.codes_get_values(msgid)
                    surface["t2m"] = vals[flat_idx]

            finally:
                eccodes.codes_release(msgid)

    return levels, surface


def _read_sfc_fields(grib_path, iy, ix, nx):
    """Read surface fields from a wrfsfc GRIB2 file at one grid point.

    Returns dict with scalar values for HFX, LH, PBLH, etc.
    """
    flat_idx = iy * nx + ix
    result = {}

    # Map GRIB shortNames to our field names
    wanted = {
        "sshf": "hfx",     # sensible heat flux
        "slhf": "lh",      # latent heat flux
        "blh": "pblh",     # PBL height
    }
    # NCEP GRIB2 uses different shortNames than ECMWF
    ncep_wanted = {
        "shtfl": "hfx",
        "lhtfl": "lh",
        "hpbl": "pblh",
    }

    with open(grib_path, "rb") as f:
        while True:
            try:
                msgid = eccodes.codes_grib_new_from_file(f)
            except Exception:
                break
            if msgid is None:
                break
            try:
                sn = eccodes.codes_get(msgid, "shortName").lower()
                tol = eccodes.codes_get(msgid, "typeOfLevel")

                if sn in wanted:
                    vals = eccodes.codes_get_values(msgid)
                    result[wanted[sn]] = vals[flat_idx]
                elif sn in ncep_wanted:
                    vals = eccodes.codes_get_values(msgid)
                    result[ncep_wanted[sn]] = vals[flat_idx]
                # Also check by paramId for NCEP-specific fields
                elif tol == "surface":
                    try:
                        pid = eccodes.codes_get(msgid, "paramId")
                        # NCEP HPBL paramId varies; also try discipline/category/number
                        disc = eccodes.codes_get(msgid, "discipline")
                        cat = eccodes.codes_get(msgid, "parameterCategory")
                        num = eccodes.codes_get(msgid, "parameterNumber")
                        # SHTFL: disc=0, cat=0, num=11
                        if disc == 0 and cat == 0 and num == 11 and "hfx" not in result:
                            vals = eccodes.codes_get_values(msgid)
                            result["hfx"] = vals[flat_idx]
                        # LHTFL: disc=0, cat=0, num=10
                        elif disc == 0 and cat == 0 and num == 10 and "lh" not in result:
                            vals = eccodes.codes_get_values(msgid)
                            result["lh"] = vals[flat_idx]
                        # HPBL: disc=0, cat=3, num=18
                        elif disc == 0 and cat == 3 and num == 18 and "pblh" not in result:
                            vals = eccodes.codes_get_values(msgid)
                            result["pblh"] = vals[flat_idx]
                    except Exception:
                        pass
            finally:
                eccodes.codes_release(msgid)

    return result


def _parse_valid_time(grib_path):
    """Extract the valid time from a GRIB file's first message."""
    with open(grib_path, "rb") as f:
        msgid = eccodes.codes_grib_new_from_file(f)
        try:
            date = eccodes.codes_get(msgid, "dataDate")  # YYYYMMDD
            time = eccodes.codes_get(msgid, "dataTime")  # HHMM
            step = eccodes.codes_get(msgid, "forecastTime")  # hours
            step_unit = eccodes.codes_get(msgid, "stepUnits")  # 1=hours
        finally:
            eccodes.codes_release(msgid)

    base_dt = datetime.strptime(f"{date}{time:04d}", "%Y%m%d%H%M")
    valid_dt = base_dt + timedelta(hours=step)
    return valid_dt


def extract_hrrr_site_data(prs_paths, sfc_paths, lat, lon):
    """Extract windgram data from HRRR GRIB2 files for a single site.

    Args:
        prs_paths: sorted list of wrfprs GRIB2 file paths (one per forecast hour)
        sfc_paths: sorted list of wrfsfc GRIB2 file paths (same forecast hours)
        lat: site latitude
        lon: site longitude

    Returns:
        Data dict compatible with render_windgram, same keys as _extract_site_data.
    """
    ntimes = len(prs_paths)
    if ntimes == 0:
        raise ValueError("No wrfprs files provided")
    if len(sfc_paths) != ntimes:
        raise ValueError(f"Mismatched file counts: {ntimes} wrfprs vs {len(sfc_paths)} wrfsfc")

    # Find nearest grid point (once, from first file)
    iy, ix, actual_lat, actual_lon, nx = _find_nearest(prs_paths[0], lat, lon)
    print(f"  HRRR nearest grid point: ({actual_lat:.3f}, {actual_lon:.3f}) "
          f"for ({lat:.3f}, {lon:.3f})")

    # Read all forecast hours
    all_prs = []
    all_sfc = []
    valid_times = []

    for i, (prs_path, sfc_path) in enumerate(zip(prs_paths, sfc_paths)):
        vt = _parse_valid_time(prs_path)
        valid_times.append(vt)
        print(f"  Reading fhr {i}: {vt.strftime('%Y-%m-%d_%H')}z", flush=True)

        prs_levels, prs_surface = _read_prs_profile(prs_path, iy, ix, nx)
        sfc_fields = _read_sfc_fields(sfc_path, iy, ix, nx)

        all_prs.append((prs_levels, prs_surface))
        all_sfc.append(sfc_fields)

    # Build sorted pressure level array (descending = surface first)
    all_pressure_levels = set()
    for prs_levels, _ in all_prs:
        all_pressure_levels.update(prs_levels.keys())
    pressure_levels = sorted(all_pressure_levels, reverse=True)  # surface first
    nlevels = len(pressure_levels)

    # Get terrain height (meters, constant across time)
    ter = all_prs[0][1].get("orog", 0.0)
    # Surface pressure from first time (used as reference)
    sfc_p_ref = all_prs[0][1].get("sp", 101325.0) / 100.0  # Pa → hPa

    # Filter levels: only keep levels above the surface (pressure <= sfc_p)
    keep = [p for p in pressure_levels if p <= sfc_p_ref]
    if not keep:
        keep = pressure_levels[:30]  # fallback: top 30 levels
    pressure_levels = keep
    nlevels = len(pressure_levels)

    # Build arrays
    ter_ft = ter * 3.28084
    ptot = np.zeros((ntimes, nlevels), dtype=np.float32)
    z_ft = np.zeros((ntimes, nlevels), dtype=np.float32)
    tk = np.zeros((ntimes, nlevels), dtype=np.float32)
    tc = np.zeros((ntimes, nlevels), dtype=np.float32)
    td = np.zeros((ntimes, nlevels), dtype=np.float32)
    rh = np.zeros((ntimes, nlevels), dtype=np.float32)
    u_kts = np.zeros((ntimes, nlevels), dtype=np.float32)
    v_kts = np.zeros((ntimes, nlevels), dtype=np.float32)
    sfc_p = np.zeros(ntimes, dtype=np.float32)
    wstar = np.zeros(ntimes, dtype=np.float32)
    hcrit_m = np.zeros(ntimes, dtype=np.float32)

    time_strings = []
    hours_utc = []

    for t in range(ntimes):
        prs_levels, prs_surface = all_prs[t]
        sfc_fields = all_sfc[t]
        vt = valid_times[t]

        time_strings.append(vt.strftime("%Y-%m-%d_%H:%M:%S"))
        hours_utc.append(vt.hour)

        sp = prs_surface.get("sp", 101325.0) / 100.0  # Pa → hPa
        sfc_p[t] = sp

        for k, plev in enumerate(pressure_levels):
            ptot[t, k] = plev
            ldata = prs_levels.get(plev, {})
            tk[t, k] = ldata.get("t", 273.15)
            z_ft[t, k] = ldata.get("gh", 0.0) * 3.28084  # m → ft
            rh[t, k] = ldata.get("r", 50.0)
            td[t, k] = ldata.get("dpt", 273.15) - 273.15  # K → C
            u_kts[t, k] = ldata.get("u", 0.0) * 1.94384   # m/s → kts
            v_kts[t, k] = ldata.get("v", 0.0) * 1.94384

        tc[t, :] = tk[t, :] - 273.15

        # w* from surface fluxes
        hfx = sfc_fields.get("hfx", 0.0)
        lh = sfc_fields.get("lh", 0.0)
        pblh = sfc_fields.get("pblh", 100.0)
        t2 = prs_surface.get("t2m", 288.0)

        vhf = max(hfx + 0.000245268 * t2 * max(lh, 0.0), 0.0)
        buoy = (9.81 / t2) * (vhf / 1200.0)
        wstar[t] = (buoy * pblh) ** (1.0 / 3.0) if buoy > 0 else 0.0

        # hcrit
        hc = calc_hcrit(
            np.array([[wstar[t]]]),
            np.array([[ter]]),
            np.array([[pblh]]),
        )
        hcrit_m[t] = hc[0, 0]

    hcrit_ft = hcrit_m * 3.28084

    # LCL from surface spread
    spread = np.maximum(tc[:, 0] - td[:, 0], 0)
    lcl_ft = (ter + 125.0 * spread) * 3.28084
    hglider_ft = np.minimum(hcrit_ft, lcl_ft)

    # Pressure coordinates for markers
    pbl_p = np.zeros(ntimes, dtype=np.float32)
    hglider_p = np.zeros(ntimes, dtype=np.float32)
    for t in range(ntimes):
        pblh = all_sfc[t].get("pblh", 100.0)
        pbl_p[t] = sfc_p[t] - (pblh * 3.28084) / 32.0
        hglider_p[t] = sfc_p[t] - (hglider_ft[t] - ter_ft) / 32.0

    # Lapse rate
    dz = np.maximum(np.diff(z_ft, axis=1) / 1000.0, 0.01)
    lapse = np.diff(tk, axis=1) / dz
    p_mid = 0.5 * (ptot[:, :-1] + ptot[:, 1:])

    # Freezing level
    freeze_p = np.full(ntimes, np.nan, dtype=np.float32)
    for t in range(ntimes):
        for k in range(nlevels):
            if tk[t, k] < 273.15:
                freeze_p[t] = ptot[t, k]
                break

    return {
        "time_strings": time_strings,
        "dx_km": 3.0,
        "hours_utc": np.array(hours_utc),
        "ntimes": ntimes,
        "ptot": ptot,
        "p_mid": p_mid,
        "z_ft": z_ft,
        "tk": tk,
        "tc": tc,
        "td": td,
        "rh": rh,
        "u_kts": u_kts,
        "v_kts": v_kts,
        "lapse": lapse,
        "wstar": wstar,
        "hglider_p": hglider_p,
        "pbl_p": pbl_p,
        "freeze_p": freeze_p,
        "sfc_p": sfc_p,
        "ter_ft": ter_ft,
        "lat": actual_lat,
        "lon": actual_lon,
    }
