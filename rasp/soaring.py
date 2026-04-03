"""
Soaring index calculations — Python replacements for ncl_jack_fortran.so.

Each function takes NumPy arrays from wrf-python and returns the computed
soaring parameter. Array shapes follow WRF conventions: (south_north, west_east)
for 2D, (bottom_top, south_north, west_east) for 3D.

References:
    Deardorff (1970) — convective velocity scale (w*)
    Bolton (1980) — lifted condensation level
    Stull, "Meteorology for Scientists and Engineers" — BL diagnostics
    DrJack BLIPMAP documentation (drjack.info) — soaring parameter definitions
"""

import numpy as np


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
G = 9.81          # gravitational acceleration (m/s^2)
RHO_CP = 1200.0   # approximate rho * Cp for surface air (J/m^3/K)
RD = 287.05        # dry air gas constant (J/kg/K)
CP = 1004.0        # specific heat at constant pressure (J/kg/K)
LV = 2.501e6       # latent heat of vaporization (J/kg)
EPS = 0.622        # Rd/Rv


# ---------------------------------------------------------------------------
# Core soaring indices
# ---------------------------------------------------------------------------

def calc_wstar(hfx, lh, pblh, t2):
    """Convective velocity scale w* (Deardorff 1970).

    Includes virtual heat flux contribution from latent heat, matching
    DrJack's vhf approach: vhf = hfx + 0.61 * (Cp/Lv) * T * LH

    Args:
        hfx:  surface sensible heat flux (W/m^2), 2D
        lh:   surface latent heat flux (W/m^2), 2D
        pblh: PBL height (m), 2D
        t2:   2m temperature (K), 2D

    Returns:
        w* (m/s), 2D. Zero where buoyancy flux is non-positive.
    """
    # Virtual heat flux (sensible + moisture buoyancy contribution)
    vhf = np.maximum(hfx + 0.000245268 * t2 * np.maximum(lh, 0.0), 0.0)
    buoyancy_flux = (G / t2) * (vhf / RHO_CP)
    wstar = np.where(
        buoyancy_flux > 0,
        (buoyancy_flux * pblh) ** (1.0 / 3.0),
        0.0,
    )
    return wstar.astype(np.float32)


def calc_hcrit(wstar, ter, pblh):
    """Critical height for soaring (m ASL).

    Height at which the expected thermal updraft velocity equals a
    typical paraglider sink rate (~1 m/s). Below this height a pilot
    can sustain flight in thermals; above it thermals are too weak.

    Approximation: hcrit = ter + pblh * (1 - sink_rate / wstar)
    Clamped to terrain height when wstar <= sink_rate.

    Args:
        wstar: convective velocity scale (m/s), 2D
        ter:   terrain height (m ASL), 2D
        pblh:  PBL height (m AGL), 2D

    Returns:
        hcrit (m ASL), 2D
    """
    sink_rate = 1.0  # m/s, typical PG sink rate
    ratio = np.where(wstar > sink_rate, 1.0 - sink_rate / wstar, 0.0)
    hcrit = ter + pblh * ratio
    return hcrit.astype(np.float32)


def calc_hlift(sink_rate, wstar, ter, pblh):
    """Max soaring height for a given sink rate (m ASL).

    Same as hcrit but with an arbitrary sink rate threshold.

    Args:
        sink_rate: aircraft/glider sink rate (m/s), scalar
        wstar: convective velocity scale (m/s), 2D
        ter:   terrain height (m ASL), 2D
        pblh:  PBL height (m AGL), 2D

    Returns:
        hlift (m ASL), 2D
    """
    ratio = np.where(wstar > sink_rate, 1.0 - sink_rate / wstar, 0.0)
    hlift = ter + pblh * ratio
    return hlift.astype(np.float32)


def calc_blavg(field3d, z, ter, pblh):
    """Boundary layer average of a 3D field.

    Vertically averages *field3d* from terrain to BL top using
    trapezoidal integration weighted by layer thickness.

    Args:
        field3d: 3D field (bottom_top, south_north, west_east)
        z:       height AGL or ASL (same shape as field3d)
        ter:     terrain height (m ASL), 2D
        pblh:    PBL height (m AGL), 2D

    Returns:
        BL-averaged field, 2D
    """
    nz = field3d.shape[0]
    bl_top = ter + pblh  # ASL
    result = np.zeros_like(ter, dtype=np.float64)
    total_dz = np.zeros_like(ter, dtype=np.float64)

    for k in range(nz - 1):
        z_lo = z[k]
        z_hi = z[k + 1]
        # Skip levels entirely above BL top or below terrain
        in_bl = (z_lo < bl_top) & (z_lo >= ter)
        if not np.any(in_bl):
            continue
        # Clamp top of layer to BL top
        z_top = np.minimum(z_hi, bl_top)
        dz = np.maximum(z_top - z_lo, 0.0)
        avg_val = 0.5 * (field3d[k] + field3d[k + 1])
        result += np.where(in_bl, avg_val * dz, 0.0)
        total_dz += np.where(in_bl, dz, 0.0)

    total_dz = np.maximum(total_dz, 1.0)  # avoid division by zero
    return (result / total_dz).astype(np.float32)


def calc_blmax(field3d, z, ter, pblh):
    """Maximum value of a 3D field within the boundary layer.

    Args:
        field3d: 3D field (bottom_top, south_north, west_east)
        z:       height ASL (same shape), meters
        ter:     terrain height ASL, 2D
        pblh:    PBL height AGL, 2D

    Returns:
        BL maximum, 2D
    """
    bl_top = ter + pblh
    nz = field3d.shape[0]
    result = np.full_like(ter, -np.inf, dtype=np.float64)

    for k in range(nz):
        in_bl = (z[k] >= ter) & (z[k] <= bl_top)
        result = np.where(in_bl, np.maximum(result, field3d[k]), result)

    result = np.where(np.isinf(result), 0.0, result)
    return result.astype(np.float32)


def calc_wblmaxmin(mode, wa, z, ter, pblh):
    """BL max/min vertical velocity.

    Args:
        mode: 0 = BL max updraft, 1 = BL min (max downdraft),
              2 = BL max absolute, 3 = BL average vertical velocity
        wa:   vertical velocity (m/s), 3D
        z:    height ASL (m), 3D
        ter:  terrain height ASL, 2D
        pblh: PBL height AGL, 2D

    Returns:
        Result field, 2D
    """
    if mode == 0:
        return calc_blmax(wa, z, ter, pblh)
    elif mode == 1:
        return -calc_blmax(-wa, z, ter, pblh)
    elif mode == 2:
        return calc_blmax(np.abs(wa), z, ter, pblh)
    elif mode == 3:
        return calc_blavg(wa, z, ter, pblh)
    else:
        raise ValueError(f"Unknown mode: {mode}")


def calc_sfclclheight(pmb, tc, td, z, ter, pblh):
    """Surface-based lifted condensation level height (m ASL).

    Uses Bolton (1980) formula for LCL temperature, then finds the
    height where the parcel temperature profile crosses the LCL
    temperature.

    Simplified approach: uses the surface T-Td spread.
        LCL_height_AGL ≈ 125 * (T_sfc - Td_sfc)   [Bolton approximation]

    Args:
        pmb:  pressure (mb), 3D
        tc:   temperature (C), 3D
        td:   dewpoint temperature (C), 3D
        z:    height ASL (m), 3D
        ter:  terrain height ASL (m), 2D
        pblh: PBL height AGL (m), 2D

    Returns:
        LCL height (m ASL), 2D
    """
    # Surface values (lowest model level)
    t_sfc = tc[0]   # C
    td_sfc = td[0]  # C
    spread = np.maximum(t_sfc - td_sfc, 0.0)
    lcl_agl = 125.0 * spread  # meters AGL (Bolton approximation)
    lcl_asl = ter + lcl_agl
    return lcl_asl.astype(np.float32)


def calc_blclheight(pmb, tc, qvapor_blavg, z, ter, pblh):
    """BL cloud layer height (m ASL).

    Height at which the BL-averaged mixing ratio would produce
    saturation, accounting for the temperature lapse within the BL.

    Simplified: uses the BL-averaged dewpoint depression to estimate
    the height at which condensation occurs within the BL.

    Args:
        pmb:           pressure (mb), 3D
        tc:            temperature (C), 3D
        qvapor_blavg:  BL-averaged water vapor mixing ratio (kg/kg), 2D
        z:             height ASL (m), 3D
        ter:           terrain height ASL (m), 2D
        pblh:          PBL height AGL (m), 2D

    Returns:
        BL cloud layer height (m ASL), 2D
    """
    bl_top = ter + pblh
    nz = tc.shape[0]
    result = np.full_like(ter, np.nan, dtype=np.float32)

    for k in range(nz):
        in_bl = (z[k] >= ter) & (z[k] <= bl_top) & np.isnan(result)
        if not np.any(in_bl):
            continue
        # Saturation mixing ratio at this level
        t_k = tc[k] + 273.15
        p_pa = pmb[k] * 100.0
        es = 611.2 * np.exp(17.67 * tc[k] / (tc[k] + 243.5))
        qsat = EPS * es / (p_pa - es)
        # Where BL-averaged qvapor >= saturation, cloud forms
        cloud_here = in_bl & (qvapor_blavg >= qsat)
        result = np.where(cloud_here, z[k], result)

    # Where no cloud found, return BL top (no cloud)
    result = np.where(np.isnan(result), bl_top, result)
    return result


def calc_cloudbase(qcloud, z, ter, crit, max_ht, lag):
    """Cloud base height from cloud water mixing ratio.

    Finds the lowest level where qcloud exceeds a threshold.

    Args:
        qcloud: cloud water mixing ratio (kg/kg), 3D
        z:      height ASL (m), 3D
        ter:    terrain height ASL (m), 2D
        crit:   threshold for cloud detection (kg/kg)
        max_ht: maximum height to search (m ASL)
        lag:    number of levels below cloud base to report

    Returns:
        Cloud base height (m ASL), 2D
    """
    nz = qcloud.shape[0]
    result = np.full_like(ter, np.nan, dtype=np.float32)

    for k in range(lag, nz):
        not_found = np.isnan(result)
        below_max = z[k] <= max_ht
        has_cloud = qcloud[k] > crit
        above_ter = z[k] > ter
        found = not_found & below_max & has_cloud & above_ter
        # Report the height 'lag' levels below
        result = np.where(found, z[k - lag], result)

    # No cloud found → set to max_ht
    result = np.where(np.isnan(result), max_ht, result)
    return result


def calc_blcloudbase(qcloud, z, ter, pblh, crit, max_ht, lag):
    """Cloud base height within the boundary layer.

    Same as calc_cloudbase but limited to within the BL.
    """
    bl_top = ter + pblh
    nz = qcloud.shape[0]
    result = np.full_like(ter, np.nan, dtype=np.float32)

    for k in range(lag, nz):
        not_found = np.isnan(result)
        in_bl = (z[k] >= ter) & (z[k] <= bl_top)
        below_max = z[k] <= max_ht
        has_cloud = qcloud[k] > crit
        found = not_found & in_bl & below_max & has_cloud
        result = np.where(found, z[k - lag], result)

    result = np.where(np.isnan(result), max_ht, result)
    return result


def calc_blwinddiff(ua, va, z, ter, pblh):
    """Wind speed difference between BL top and surface.

    Magnitude of the vector wind difference between the wind at the
    top of the BL and the surface wind.

    Args:
        ua, va: u and v wind components (m/s), 3D
        z:      height ASL (m), 3D
        ter:    terrain height ASL (m), 2D
        pblh:   PBL height AGL (m), 2D

    Returns:
        Wind speed difference (m/s), 2D
    """
    # Surface wind (lowest level)
    u_sfc = ua[0]
    v_sfc = va[0]

    # Find wind at BL top by interpolation
    bl_top = ter + pblh
    nz = ua.shape[0]
    u_bltop = np.copy(ua[0])
    v_bltop = np.copy(va[0])

    for k in range(nz - 1):
        crosses = (z[k] <= bl_top) & (z[k + 1] > bl_top)
        if not np.any(crosses):
            continue
        # Linear interpolation weight
        dz = z[k + 1] - z[k]
        dz = np.maximum(dz, 1.0)
        w = (bl_top - z[k]) / dz
        w = np.clip(w, 0.0, 1.0)
        u_bltop = np.where(crosses, ua[k] + w * (ua[k + 1] - ua[k]), u_bltop)
        v_bltop = np.where(crosses, va[k] + w * (va[k + 1] - va[k]), v_bltop)

    du = u_bltop - u_sfc
    dv = v_bltop - v_sfc
    return np.sqrt(du**2 + dv**2).astype(np.float32)


def calc_bltop_pottemp_variability(theta, z, ter, pblh, criterion_degc):
    """Potential temperature variability near BL top.

    Measures the temperature difference across the BL top — an
    indicator of inversion strength. Stronger inversions produce
    sharper BL tops with less overshooting.

    Args:
        theta:          potential temperature (K), 3D
        z:              height ASL (m), 3D
        ter:            terrain height ASL (m), 2D
        pblh:           PBL height AGL (m), 2D
        criterion_degc: thickness of layer to sample (degrees C/K)

    Returns:
        BL top potential temperature variability (K), 2D
    """
    bl_top = ter + pblh
    nz = theta.shape[0]

    # Find theta at BL top and just above
    theta_bl = np.copy(theta[0])
    theta_above = np.copy(theta[0])

    for k in range(nz - 1):
        crosses = (z[k] <= bl_top) & (z[k + 1] > bl_top)
        if not np.any(crosses):
            continue
        theta_bl = np.where(crosses, theta[k], theta_bl)
        if k + 2 < nz:
            theta_above = np.where(crosses, theta[k + 2], theta_above)
        else:
            theta_above = np.where(crosses, theta[k + 1], theta_above)

    variability = theta_above - theta_bl
    return np.maximum(variability, 0.0).astype(np.float32)


def calc_blinteg_mixratio(qfield, ptot, psfc, z, ter, pblh):
    """Pressure-weighted integral of a mixing ratio field within the BL.

    Used for BL-integrated cloud water content.

    Args:
        qfield: mixing ratio (kg/kg), 3D
        ptot:   total pressure (Pa), 3D
        psfc:   surface pressure (Pa), 2D
        z:      height ASL (m), 3D
        ter:    terrain height ASL (m), 2D
        pblh:   PBL height AGL (m), 2D

    Returns:
        Integrated mixing ratio (kg/m^2), 2D
    """
    bl_top = ter + pblh
    nz = qfield.shape[0]
    result = np.zeros_like(ter, dtype=np.float64)

    for k in range(nz - 1):
        in_bl = (z[k] >= ter) & (z[k] < bl_top)
        if not np.any(in_bl):
            continue
        dp = np.abs(ptot[k + 1] - ptot[k])
        avg_q = 0.5 * (qfield[k] + qfield[k + 1])
        result += np.where(in_bl, avg_q * dp / G, 0.0)

    return result.astype(np.float32)


def calc_aboveblinteg_mixratio(qfield, ptot, z, ter, pblh):
    """Pressure-weighted integral of mixing ratio above the BL.

    Args:
        qfield: mixing ratio (kg/kg), 3D
        ptot:   total pressure (Pa), 3D
        z:      height ASL (m), 3D
        ter:    terrain height ASL (m), 2D
        pblh:   PBL height AGL (m), 2D

    Returns:
        Integrated mixing ratio above BL (kg/m^2), 2D
    """
    bl_top = ter + pblh
    nz = qfield.shape[0]
    result = np.zeros_like(ter, dtype=np.float64)

    for k in range(nz - 1):
        above_bl = z[k] > bl_top
        if not np.any(above_bl):
            continue
        dp = np.abs(ptot[k + 1] - ptot[k])
        avg_q = 0.5 * (qfield[k] + qfield[k + 1])
        result += np.where(above_bl, avg_q * dp / G, 0.0)

    return result.astype(np.float32)


def calc_sfcsunpct(jday, gmthr, alat, alon, ter, z, pmb, tc, qvapor):
    """Surface sunshine percentage.

    Estimates the fraction of direct solar radiation reaching the
    surface based on solar zenith angle, atmospheric absorption
    (pressure, temperature, humidity path), and terrain shadowing.

    Simplified implementation: computes solar zenith angle and
    estimates attenuation from total column water vapor.

    Args:
        jday:    Julian day of year (scalar)
        gmthr:   GMT hour (scalar)
        alat:    latitude (degrees), 2D
        alon:    longitude (degrees), 2D
        ter:     terrain height (m ASL), 2D
        z:       height ASL (m), 3D
        pmb:     pressure (mb), 3D
        tc:      temperature (C), 3D
        qvapor:  water vapor mixing ratio (kg/kg), 3D

    Returns:
        Sunshine percentage (0-100), 2D
    """
    # Solar declination angle
    decl = 23.45 * np.sin(np.radians((284 + jday) * 360.0 / 365.0))
    decl_rad = np.radians(decl)

    # Hour angle
    solar_hour = gmthr + alon / 15.0  # approximate solar time
    ha_rad = np.radians((solar_hour - 12.0) * 15.0)

    # Solar zenith angle
    lat_rad = np.radians(alat)
    cos_zenith = (np.sin(lat_rad) * np.sin(decl_rad) +
                  np.cos(lat_rad) * np.cos(decl_rad) * np.cos(ha_rad))
    cos_zenith = np.clip(cos_zenith, 0.0, 1.0)

    # Simple attenuation from column water vapor
    nz = qvapor.shape[0]
    col_water = np.zeros_like(ter, dtype=np.float64)
    for k in range(nz - 1):
        dp = np.abs(pmb[k + 1] - pmb[k]) * 100.0  # Pa
        col_water += 0.5 * (qvapor[k] + qvapor[k + 1]) * dp / G

    # Transmittance (simple Beer-Lambert-ish)
    tau = np.exp(-0.1 * col_water)
    sunpct = 100.0 * cos_zenith * tau

    # Night = 0
    sunpct = np.where(cos_zenith <= 0, 0.0, sunpct)
    return np.clip(sunpct, 0.0, 100.0).astype(np.float32)


def calc_subgrid_blcloudpct(qvapor, qcloud, tc, pmb, z, ter, pblh, crit):
    """Sub-grid BL cloud fraction (GRADS method).

    Estimates the probability of cloud within each grid cell based on
    the proximity of mixing ratio to saturation within the BL.

    Args:
        qvapor: water vapor mixing ratio (kg/kg), 3D
        qcloud: cloud water mixing ratio (kg/kg), 3D
        tc:     temperature (C), 3D
        pmb:    pressure (mb), 3D
        z:      height ASL (m), 3D
        ter:    terrain height (m ASL), 2D
        pblh:   PBL height (m AGL), 2D
        crit:   cloud water threshold (kg/kg)

    Returns:
        Cloud fraction (0-100%), 2D
    """
    bl_top = ter + pblh
    nz = tc.shape[0]
    cloud_count = np.zeros_like(ter, dtype=np.float64)
    total_count = np.zeros_like(ter, dtype=np.float64)

    for k in range(nz):
        in_bl = (z[k] >= ter) & (z[k] <= bl_top)
        if not np.any(in_bl):
            continue
        # Saturation mixing ratio
        es = 611.2 * np.exp(17.67 * tc[k] / (tc[k] + 243.5))
        p_pa = pmb[k] * 100.0
        qsat = EPS * es / (p_pa - es)
        # RH proxy for sub-grid cloud probability
        rh = qvapor[k] / np.maximum(qsat, 1e-10)
        has_cloud = (qcloud[k] > crit) | (rh > 0.95)
        cloud_count += np.where(in_bl & has_cloud, 1.0, 0.0)
        total_count += np.where(in_bl, 1.0, 0.0)

    total_count = np.maximum(total_count, 1.0)
    return (100.0 * cloud_count / total_count).astype(np.float32)


def calc_qcblhf(rqcblten, mu, z, ter, pblh):
    """Cloud base height factor from BL cumulus tendency.

    Args:
        rqcblten: BL cloud water tendency (kg/kg/s), 3D
        mu:       dry air mass in column (Pa), 2D
        z:        height ASL (m), 3D
        ter:      terrain height ASL (m), 2D
        pblh:     PBL height AGL (m), 2D

    Returns:
        Cloud base height factor, 2D
    """
    bl_top = ter + pblh
    nz = rqcblten.shape[0]
    result = np.zeros_like(ter, dtype=np.float64)

    for k in range(nz):
        in_bl = (z[k] >= ter) & (z[k] <= bl_top)
        has_tendency = rqcblten[k] > 0
        found = in_bl & has_tendency
        # Report the height of the lowest level with positive tendency
        result = np.where(found & (result == 0), z[k], result)

    return result.astype(np.float32)


# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

def minlimit2d(field, limit):
    """Clamp a 2D field to a minimum value (in-place compatible)."""
    return np.maximum(field, limit).astype(np.float32)


def maxlimit2d(field, limit):
    """Clamp a 2D field to a maximum value (in-place compatible)."""
    return np.minimum(field, limit).astype(np.float32)


def min_2darrays(a, b):
    """Element-wise minimum of two 2D arrays."""
    return np.minimum(a, b).astype(np.float32)


def trunc_2darray_min(field, minval):
    """Truncate 2D array values below a minimum."""
    return np.maximum(field, minval).astype(np.float32)
