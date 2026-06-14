"""
Direct HRRR reader — compute soaring indices from HRRR GRIB2 output.

Reads HRRR wrfprs (atmosphere profiles on pressure levels) and wrfsfc
(surface fields: HFX, LH, PBLH) directly, skipping WPS/WRF entirely.
HRRR is already a WRF model at 3km — re-running WRF loses the cloud
state and produces false soaring forecasts on cloudy days.

Returns the same data dict as windgram._extract_site_data() so the
windgram renderer works with either WRF output or direct HRRR GRIB.

Reading is batched across sites: each GRIB message is decoded ONCE
(codes_get_values returns the full grid anyway) and every site's nearest
grid point is plucked from it. Decoding the same ~12GB of GRIB once per
site instead of once per (site, file) was the dominant cost — see
extract_hrrr_sites_data.

Usage:
    from rasp.hrrr_reader import extract_hrrr_sites_data, extract_hrrr_site_data
    # batch (preferred):
    for name, data in extract_hrrr_sites_data(prs_files, sfc_files, sites):
        render_windgram(None, lat, lon, name, "./output", data=data)
    # single site (thin wrapper):
    data = extract_hrrr_site_data(prs_files, sfc_files, lat, lon)
"""

import eccodes
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path

from .soaring import calc_hcrit


def _find_nearest_multi(grib_path, sites):
    """Find the nearest HRRR grid point for each site.

    Decodes the grid lat/lon arrays once (not once per site).

    Args:
        grib_path: any GRIB file from the run (for the grid definition)
        sites: list of (name, lat, lon)

    Returns:
        (nearest, nx) where nearest is a list of
        (iy, ix, actual_lat, actual_lon), one per site, and nx is the
        grid width (for flat indexing iy*nx + ix).
    """
    with open(grib_path, "rb") as f:
        msgid = eccodes.codes_grib_new_from_file(f)
        nx = eccodes.codes_get(msgid, "Nx")
        eccodes.codes_get(msgid, "Ny")

        # Get lat/lon for every grid point (once for all sites)
        lats = eccodes.codes_get_array(msgid, "latitudes")
        lons = eccodes.codes_get_array(msgid, "longitudes")
        eccodes.codes_release(msgid)

    # Adjust longitudes to match (HRRR uses 0-360, we use -180 to 180)
    lons = np.where(lons > 180, lons - 360, lons)

    nearest = []
    for name, lat, lon in sites:
        dist = (lats - lat) ** 2 + (lons - lon) ** 2
        idx = int(np.argmin(dist))
        nearest.append((idx // nx, idx % nx, float(lats[idx]), float(lons[idx])))

    return nearest, nx


def _read_prs_profile_multi(grib_path, flat_indices):
    """Read atmospheric profiles from one wrfprs GRIB2 file for many points.

    Decodes each matching message's full grid once, then indexes every
    site. Returns (levels_list, surface_list), one entry per flat index:
      levels_list[i]  -> {pressure_mb: {field: value}}
      surface_list[i] -> {name: value}
    """
    n = len(flat_indices)
    fi = np.asarray(flat_indices, dtype=np.intp)

    # Fields we need from pressure levels
    prs_fields = {"t", "gh", "r", "dpt", "u", "v"}
    # Surface/near-surface fields
    sfc_names = {
        ("t", "heightAboveGround", 2): "t2m",
        ("sp", "surface", 0): "sp",
        ("orog", "surface", 0): "orog",
        ("pres", "surface", 0): "sp",  # alternate name
    }

    levels = [dict() for _ in range(n)]
    surface = [dict() for _ in range(n)]

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
                    pts = eccodes.codes_get_values(msgid)[fi]
                    for i in range(n):
                        if lev not in levels[i]:
                            levels[i][lev] = {}
                        levels[i][lev][sn] = pts[i]

                elif (sn, tol, lev) in sfc_names:
                    pts = eccodes.codes_get_values(msgid)[fi]
                    key = sfc_names[(sn, tol, lev)]
                    for i in range(n):
                        surface[i][key] = pts[i]

                elif tol == "surface" and sn in ("sp", "pres", "orog"):
                    pts = eccodes.codes_get_values(msgid)[fi]
                    for i in range(n):
                        if sn in ("sp", "pres"):
                            surface[i]["sp"] = pts[i]
                        elif sn == "orog":
                            surface[i]["orog"] = pts[i]

                elif tol == "heightAboveGround" and lev == 2 and sn in ("t", "2t"):
                    pts = eccodes.codes_get_values(msgid)[fi]
                    for i in range(n):
                        surface[i]["t2m"] = pts[i]

            finally:
                eccodes.codes_release(msgid)

    return levels, surface


def _read_sfc_fields_multi(grib_path, flat_indices):
    """Read surface fields from one wrfsfc GRIB2 file for many points.

    Returns a list of dicts (HFX, LH, PBLH, ...), one per flat index.
    """
    n = len(flat_indices)
    fi = np.asarray(flat_indices, dtype=np.intp)
    result = [dict() for _ in range(n)]

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
                    pts = eccodes.codes_get_values(msgid)[fi]
                    for i in range(n):
                        result[i][wanted[sn]] = pts[i]
                elif sn in ncep_wanted:
                    pts = eccodes.codes_get_values(msgid)[fi]
                    for i in range(n):
                        result[i][ncep_wanted[sn]] = pts[i]
                # Also check by discipline/category/number for NCEP-specific fields
                elif tol == "surface":
                    try:
                        disc = eccodes.codes_get(msgid, "discipline")
                        cat = eccodes.codes_get(msgid, "parameterCategory")
                        num = eccodes.codes_get(msgid, "parameterNumber")
                        # SHTFL: disc=0, cat=0, num=11
                        if disc == 0 and cat == 0 and num == 11:
                            pts = eccodes.codes_get_values(msgid)[fi]
                            for i in range(n):
                                result[i].setdefault("hfx", pts[i])
                        # LHTFL: disc=0, cat=0, num=10
                        elif disc == 0 and cat == 0 and num == 10:
                            pts = eccodes.codes_get_values(msgid)[fi]
                            for i in range(n):
                                result[i].setdefault("lh", pts[i])
                        # HPBL: disc=0, cat=3, num=18
                        elif disc == 0 and cat == 3 and num == 18:
                            pts = eccodes.codes_get_values(msgid)[fi]
                            for i in range(n):
                                result[i].setdefault("pblh", pts[i])
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
            eccodes.codes_get(msgid, "stepUnits")  # 1=hours
        finally:
            eccodes.codes_release(msgid)

    base_dt = datetime.strptime(f"{date}{time:04d}", "%Y%m%d%H%M")
    valid_dt = base_dt + timedelta(hours=step)
    return valid_dt


def _build_site_dict(all_prs, all_sfc, valid_times, actual_lat, actual_lon):
    """Assemble the render_windgram data dict for one site from its
    per-forecast-hour (levels, surface) and sfc readings.

    Pure numpy/bookkeeping — no GRIB I/O. Same output as the original
    single-site extractor.
    """
    ntimes = len(all_prs)

    # Build sorted pressure level array (descending = surface first)
    all_pressure_levels = set()
    for prs_levels, _ in all_prs:
        all_pressure_levels.update(prs_levels.keys())
    pressure_levels = sorted(all_pressure_levels, reverse=True)  # surface first

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


def extract_hrrr_sites_data(prs_paths, sfc_paths, sites):
    """Extract windgram data for many sites in a SINGLE pass over the GRIB files.

    Each GRIB message is decoded once and every site's nearest grid point
    is plucked from the decoded grid, instead of re-reading every file
    once per site.

    Args:
        prs_paths: sorted list of wrfprs GRIB2 file paths (one per forecast hour)
        sfc_paths: sorted list of wrfsfc GRIB2 file paths (same forecast hours)
        sites: list of (name, lat, lon)

    Returns:
        list of (name, data_dict) in the same order as `sites`. data_dict is
        None for a site whose data could not be assembled.
    """
    ntimes = len(prs_paths)
    if ntimes == 0:
        raise ValueError("No wrfprs files provided")
    if len(sfc_paths) != ntimes:
        raise ValueError(
            f"Mismatched file counts: {ntimes} wrfprs vs {len(sfc_paths)} wrfsfc"
        )
    if not sites:
        return []

    # Find nearest grid point for every site (once, from first file)
    nearest, nx = _find_nearest_multi(prs_paths[0], sites)
    flat_indices = [iy * nx + ix for (iy, ix, _, _) in nearest]
    for (name, lat, lon), (iy, ix, alat, alon) in zip(sites, nearest):
        print(f"  {name}: nearest grid point ({alat:.3f}, {alon:.3f}) "
              f"for ({lat:.3f}, {lon:.3f})")

    # One pass over the forecast hours, collecting all sites at each step
    per_site_prs = [[] for _ in sites]   # per site: list over time of (levels, surface)
    per_site_sfc = [[] for _ in sites]   # per site: list over time of sfc dict
    valid_times = []

    for i, (prs_path, sfc_path) in enumerate(zip(prs_paths, sfc_paths)):
        vt = _parse_valid_time(prs_path)
        valid_times.append(vt)
        print(f"  Reading fhr {i}: {vt.strftime('%Y-%m-%d_%H')}z", flush=True)

        levels_list, surface_list = _read_prs_profile_multi(prs_path, flat_indices)
        sfc_list = _read_sfc_fields_multi(sfc_path, flat_indices)

        for s in range(len(sites)):
            per_site_prs[s].append((levels_list[s], surface_list[s]))
            per_site_sfc[s].append(sfc_list[s])

    # Assemble each site's data dict (cheap numpy, no I/O)
    results = []
    for s, (name, lat, lon) in enumerate(sites):
        _, _, alat, alon = nearest[s]
        try:
            data = _build_site_dict(
                per_site_prs[s], per_site_sfc[s], valid_times, alat, alon
            )
            results.append((name, data))
        except Exception as e:
            print(f"  WARNING: {name} site-data build failed: {e}")
            results.append((name, None))

    return results


def extract_hrrr_site_data(prs_paths, sfc_paths, lat, lon):
    """Extract windgram data from HRRR GRIB2 files for a single site.

    Thin wrapper over extract_hrrr_sites_data (batched reader). Kept for
    backward compatibility and single-site use.

    Returns:
        Data dict compatible with render_windgram, same keys as _extract_site_data.
    """
    results = extract_hrrr_sites_data(prs_paths, sfc_paths, [("site", lat, lon)])
    _, data = results[0]
    if data is None:
        raise ValueError("Failed to extract HRRR site data")
    return data
