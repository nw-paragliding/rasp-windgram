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
    simonbesters/icon-d2-pipeline — reverse-engineered Fortran constants
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
RDCP = 0.286       # Rd/Cp (Poisson constant)

# DrJack's empirical thermal penetration model coefficients
# (from .rodata section of libncl_drjack.avx512.nocuda.so)
_MS_TO_FPM = 196.85       # m/s to ft/min conversion
_HCRIT_THRESHOLD = 225.0   # ft/min threshold for hcrit
_ALPHA1 = 0.463            # ratio scaling coefficient
_ALPHA2 = 0.4549           # linear offset
_ALPHA3 = 1.3674           # quadratic scaling
_ALPHA4 = 0.01267          # sqrt argument offset
_ALPHA5 = 0.1126           # base height fraction offset


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
    arg = (G / t2) * pblh * (vhf / RHO_CP)
    wstar = np.where(
        arg > 0,
        np.cbrt(arg),
        0.0,
    )
    return wstar.astype(np.float32)


def _drjack_height_frac(threshold_fpm, wstar_fpm):
    """DrJack's empirical nonlinear thermal penetration model.

    Reconstructed from calc_hcrit_/calc_hlift_ in libncl_drjack.so.
    Returns the fraction of BL depth that thermals can usefully penetrate.

    The model:
        ratio = threshold / wstar_fpm
        height_frac = sqrt(alpha3 * (alpha2 - alpha1 * ratio) + alpha4) + alpha5
    """
    ratio = threshold_fpm / wstar_fpm
    inner = _ALPHA3 * (_ALPHA2 - _ALPHA1 * ratio) + _ALPHA4
    height_frac = np.sqrt(np.maximum(inner, 0.0)) + _ALPHA5
    return height_frac


def calc_hcrit(wstar, ter, pblh):
    """Critical height for soaring (m ASL).

    Height at which the expected thermal updraft velocity equals 225 fpm
    (~1.14 m/s, a typical paraglider sink rate). Below this height a pilot
    can sustain flight in thermals; above it thermals are too weak.

    Uses DrJack's empirical nonlinear thermal penetration model
    (reconstructed from Fortran binary).

    Args:
        wstar: convective velocity scale (m/s), 2D
        ter:   terrain height (m ASL), 2D
        pblh:  PBL height (m AGL), 2D

    Returns:
        hcrit (m ASL), 2D
    """
    wstar_fpm = wstar * _MS_TO_FPM
    valid = wstar_fpm > _HCRIT_THRESHOLD
    height_frac = np.where(
        valid, _drjack_height_frac(_HCRIT_THRESHOLD, wstar_fpm), 0.0
    )
    hcrit = np.where(valid, ter + height_frac * pblh, ter)
    return np.maximum(hcrit, 0.0).astype(np.float32)


def calc_hlift(criteria_fpm, wstar, ter, pblh):
    """Max soaring height for a given sink rate (m ASL).

    Same model as hcrit but with a variable threshold.

    Args:
        criteria_fpm: updraft criteria (ft/min), scalar
        wstar: convective velocity scale (m/s), 2D
        ter:   terrain height (m ASL), 2D
        pblh:  PBL height (m AGL), 2D

    Returns:
        hlift (m ASL), 2D
    """
    wstar_fpm = wstar * _MS_TO_FPM
    valid = wstar_fpm > criteria_fpm
    height_frac = np.where(
        valid, _drjack_height_frac(criteria_fpm, wstar_fpm), 0.0
    )
    hlift = np.where(valid, ter + height_frac * pblh, ter)
    return np.maximum(hlift, 0.0).astype(np.float32)


def calc_blavg(field3d, z, ter, pblh):
    """Boundary layer average of a 3D field.

    Vertically averages *field3d* from terrain to BL top using
    trapezoidal integration weighted by layer thickness.

    Args:
        field3d: 3D field (bottom_top, south_north, west_east)
        z:       height ASL (same shape as field3d)
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
        in_bl = z_lo < bl_top
        if not np.any(in_bl):
            continue
        # Clamp top of layer to BL top
        z_top = np.minimum(z_hi, bl_top)
        dz = np.maximum(z_top - z_lo, 0.0)
        avg_val = 0.5 * (field3d[k] + field3d[k + 1])
        result += np.where(in_bl, avg_val * dz, 0.0)
        total_dz += np.where(in_bl, dz, 0.0)

    valid = total_dz > 0.0
    out = np.where(valid, result / np.maximum(total_dz, 1.0), field3d[0])
    return out.astype(np.float32)


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
        in_bl = z[k] <= bl_top
        result = np.where(in_bl, np.maximum(result, field3d[k]), result)

    # Fallback to surface value where no valid data
    no_data = np.isinf(result)
    result = np.where(no_data, field3d[0], result)
    return result.astype(np.float32)


def calc_wblmaxmin(mode, wa, z, ter, pblh):
    """BL max vertical velocity or its height.

    Args:
        mode: 0 = max |W| in cm/s, 1 = height MSL of max |W| in m
        wa:   vertical velocity (m/s), 3D
        z:    height ASL (m), 3D
        ter:  terrain height ASL, 2D
        pblh: PBL height AGL, 2D

    Returns:
        Result field, 2D
    """
    nz = wa.shape[0]
    bl_top = ter + pblh

    max_w = np.zeros_like(ter, dtype=np.float32)
    z_maxw = np.copy(ter).astype(np.float32)

    for k in range(nz):
        in_bl = z[k] <= bl_top
        abs_w = np.abs(wa[k])
        update = in_bl & (abs_w > np.abs(max_w))
        max_w = np.where(update, wa[k], max_w)
        z_maxw = np.where(update, z[k], z_maxw)

    if mode == 0:
        return (max_w * 100.0).astype(np.float32)  # m/s -> cm/s
    elif mode == 1:
        return z_maxw
    else:
        raise ValueError(f"Unknown mode: {mode}")


def calc_sfclclheight(pmb, tc, td, z, ter, pblh):
    """Surface-based lifted condensation level height (m ASL).

    Lifts a surface parcel dry-adiabatically and conserves mixing ratio
    to find the height where T_parcel <= Td_parcel. Falls back to the
    Espy/Bolton approximation (125 m/K) if no condensation found in profile.

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
    nz = pmb.shape[0]

    # Surface values (lowest model level)
    t_sfc_k = tc[0] + 273.15
    td_sfc = td[0]
    p_sfc = pmb[0]

    # Mixing ratio at surface (conserved during dry ascent)
    e_sfc = 6.112 * np.exp(17.67 * td_sfc / (td_sfc + 243.5))
    w_sfc = EPS * e_sfc / np.maximum(p_sfc - e_sfc, 0.1)

    result = np.full_like(ter, np.nan, dtype=np.float32)
    found = np.zeros_like(ter, dtype=bool)

    for k in range(1, nz):
        # Parcel T at this level (dry adiabat): T = T_sfc * (p/p_sfc)^(Rd/Cp)
        t_parcel_k = t_sfc_k * (pmb[k] / np.maximum(p_sfc, 0.1)) ** RDCP
        # Parcel dewpoint from conserved mixing ratio at this pressure
        e_parcel = w_sfc * pmb[k] / (EPS + w_sfc)
        e_parcel = np.maximum(e_parcel, 0.001)
        log_e = np.log(e_parcel / 6.112)
        td_parcel = 243.5 * log_e / (17.67 - log_e)
        t_parcel_c = t_parcel_k - 273.15

        condensed = (~found) & (t_parcel_c <= td_parcel)
        result = np.where(condensed, z[k], result)
        found = found | condensed

    # Espy/Bolton fallback where no condensation found in profile
    espy_lcl = ter + 125.0 * np.maximum(tc[0] - td[0], 0.0)
    result = np.where(found, result, espy_lcl)
    return result.astype(np.float32)


def calc_blclheight(pmb, tc, qvapor_blavg, z, ter, pblh):
    """BL cloud layer height (m ASL).

    Height at which the BL-averaged mixing ratio would produce
    saturation. Computes dewpoint from BL-average qvapor at each
    level's pressure, then finds where environmental T drops below it.

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
    nz = tc.shape[0]
    result = np.full_like(ter, np.nan, dtype=np.float32)
    found = np.zeros_like(ter, dtype=bool)

    for k in range(nz):
        # Dewpoint from BL-average qvapor at this level's pressure
        e = qvapor_blavg * pmb[k] / (EPS + qvapor_blavg)
        e = np.maximum(e, 0.001)
        log_e = np.log(e / 6.112)
        td_bl = 243.5 * log_e / (17.67 - log_e)

        # Where environmental temp drops below this dewpoint = condensation
        condenses = (~found) & (tc[k] <= td_bl)
        result = np.where(condenses, z[k], result)
        found = found | condenses

    # Where no cloud found, set to BL top
    bl_top = ter + pblh
    result = np.where(found, result, bl_top)
    return result.astype(np.float32)


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

    Scalar speed difference: |speed_top - speed_sfc|.

    Args:
        ua, va: u and v wind components (m/s), 3D
        z:      height ASL (m), 3D
        ter:    terrain height ASL (m), 2D
        pblh:   PBL height AGL (m), 2D

    Returns:
        Wind speed difference (m/s), 2D
    """
    # Surface wind speed (lowest level)
    spd_sfc = np.sqrt(ua[0] ** 2 + va[0] ** 2)

    # Find wind at BL top by interpolation
    bl_top = ter + pblh
    nz = ua.shape[0]
    u_bltop = np.copy(ua[0])
    v_bltop = np.copy(va[0])
    found = np.zeros_like(ter, dtype=bool)

    for k in range(nz - 1):
        crosses = (~found) & (z[k] <= bl_top) & (z[k + 1] > bl_top)
        if not np.any(crosses):
            continue
        # Linear interpolation weight
        dz = np.maximum(z[k + 1] - z[k], 1.0)
        w = np.clip((bl_top - z[k]) / dz, 0.0, 1.0)
        u_bltop = np.where(crosses, ua[k] + w * (ua[k + 1] - ua[k]), u_bltop)
        v_bltop = np.where(crosses, va[k] + w * (va[k + 1] - va[k]), v_bltop)
        found = found | crosses

    spd_top = np.sqrt(u_bltop ** 2 + v_bltop ** 2)
    return np.abs(spd_top - spd_sfc).astype(np.float32)


def calc_bltop_pottemp_variability(theta, z, ter, pblh, criterion_degc):
    """Potential temperature variability near BL top.

    Finds the height range around BL top where theta stays within
    +/- criterion of the BL-top theta value. Returns the depth of
    this zone in meters — an indicator of inversion sharpness.
    Thinner zones = sharper inversions = less overshooting.

    Args:
        theta:          potential temperature (K), 3D
        z:              height ASL (m), 3D
        ter:            terrain height ASL (m), 2D
        pblh:           PBL height AGL (m), 2D
        criterion_degc: temperature range to sample (K)

    Returns:
        BL top potential temperature variability depth (m), 2D
    """
    bl_top = ter + pblh
    nz = theta.shape[0]

    # Interpolate theta to exact BL top
    theta_bltop = np.copy(theta[0]).astype(np.float64)
    for k in range(nz - 1):
        at_bltop = (z[k] <= bl_top) & (z[k + 1] > bl_top)
        if not np.any(at_bltop):
            continue
        frac = np.clip(
            (bl_top - z[k]) / np.maximum(z[k + 1] - z[k], 1.0), 0.0, 1.0
        )
        theta_bltop = np.where(
            at_bltop, theta[k] + frac * (theta[k + 1] - theta[k]), theta_bltop
        )

    # Find height range where theta is within +/- criterion of BL top theta
    z_low = np.copy(bl_top).astype(np.float64)
    z_high = np.copy(bl_top).astype(np.float64)

    for k in range(nz):
        in_range = np.abs(theta[k] - theta_bltop) < criterion_degc
        near_bltop = np.abs(z[k] - bl_top) < pblh
        update = in_range & near_bltop
        z_low = np.where(update & (z[k] < z_low), z[k], z_low)
        z_high = np.where(update & (z[k] > z_high), z[k], z_high)

    variability = z_high - z_low
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


def calc_sfcsunpct(swdown, jday, gmthr, alat, alon, ter, z, pmb, tc, qvapor):
    """Surface sunshine percentage.

    Ratio of actual downward shortwave (from WRF) to computed clear-sky
    maximum. Solar geometry matches DrJack's radconst_ routine (solar
    constant 1370, axial tilt 23.5 deg, equinox offset day 80).

    Args:
        swdown:  actual downward shortwave radiation (W/m^2), 2D
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
        Sunshine percentage (0-100), 2D. -999 where sun is below horizon.
    """
    # Solar declination (DrJack radconst_ constants)
    day_angle = 2.0 * np.pi * (jday - 80) / 365.0
    declination = 23.5 * np.sin(day_angle)
    decl_rad = np.radians(declination)

    # Hour angle
    solar_hour = gmthr + alon / 15.0
    ha_rad = np.radians(15.0 * (solar_hour - 12.0))

    # Solar zenith angle
    lat_rad = np.radians(alat)
    cos_zenith = (np.sin(lat_rad) * np.sin(decl_rad) +
                  np.cos(lat_rad) * np.cos(decl_rad) * np.cos(ha_rad))
    sun_up = cos_zenith > 1e-9
    cos_z = np.maximum(cos_zenith, 1e-9)

    # Air mass
    airmass = np.where(sun_up, 1.0 / cos_z, 40.0)
    airmass = np.minimum(airmass, 40.0)

    # Precipitable water from column qvapor
    nz = qvapor.shape[0]
    pw = np.zeros_like(ter, dtype=np.float64)
    for k in range(1, nz):
        dp = np.abs(pmb[k - 1] - pmb[k]) * 100.0  # mb -> Pa
        qv_avg = 0.5 * (qvapor[k - 1] + qvapor[k])
        pw += qv_avg * dp / G

    # Kasten clear-sky transmittance with precipitable water correction
    transmittance = np.exp(-0.09 * airmass ** 0.75 * (1.0 + 0.012 * pw))

    # Clear-sky radiation (DrJack solar constant = 1370 W/m^2)
    clear_sky = 1370.0 * cos_z * transmittance

    # Sunshine % = actual / clear-sky
    sunpct = np.where(
        ~sun_up, -999.0,
        np.where(clear_sky > 10.0,
                 np.clip(100.0 * swdown / np.maximum(clear_sky, 1.0), 0.0, 100.0),
                 50.0)
    )
    return sunpct.astype(np.float32)


def calc_subgrid_blcloudpct(qvapor, qcloud, tc, pmb, z, ter, pblh, crit):
    """Sub-grid BL cloud fraction (DrJack GrADS method).

    Per-level cloud fraction from a linear RH mapping, taking the
    maximum over all BL levels. From the reverse-engineered Fortran:
        cloud_frac = clamp(400 * RH - 300, 0, 95)
    This gives 0% at RH=75% and linearly increases to a 95% cap.

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
        Cloud fraction (0-95%), 2D
    """
    bl_top = ter + pblh
    nz = tc.shape[0]
    cloud_max = np.zeros_like(ter, dtype=np.float32)

    for k in range(nz):
        in_bl = z[k] <= bl_top
        if not np.any(in_bl):
            continue
        # Saturation mixing ratio (Magnus formula, DrJack constants)
        es = 6.112 * np.exp(17.67 * tc[k] / (tc[k] + 243.5))
        qs = EPS * es / np.maximum(pmb[k] - 0.378 * es, 0.1)
        # Relative humidity (fractional)
        rh = np.clip(qvapor[k] / np.maximum(qs, 1e-10), 0.0, 1.0)
        # DrJack linear RH -> cloud mapping
        cf_layer = np.clip(400.0 * rh - 300.0, 0.0, 95.0)
        # Take maximum over all BL levels
        cloud_max = np.where(in_bl, np.maximum(cloud_max, cf_layer), cloud_max)

    return cloud_max.astype(np.float32)


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
