"""A tiny synthetic wrfout for tests: 3x3 flat-terrain grid, 24 levels, one
local day (05:00-19:00 PDT, hourly) with a textbook convective cycle —
cold stable night, a mixed layer growing to ~1.4 km by mid-afternoon, a
morning stratus deck, two hours of light rain at the end of the afternoon.

Every field rasp.windgram._extract_site_data reads is present (P, PB, PH,
PHB, T, QVAPOR, U, V, W, HFX, LH, PBLH, T2, U10, V10, Q2, PSFC, RAINC,
RAINNC, HGT, COSALPHA, SINALPHA, XLAT, XLONG, Times, DX), with values from the
simple formulas below so tests can check the table against them.
"""
import numpy as np
from netCDF4 import Dataset, stringtochar

SITE_LAT, SITE_LON = 47.5, -121.9
TER_M = 400.0                  # flat terrain, m ASL
PSFC_PA = 96700.0              # surface pressure at 400 m
NZ = 24
NT = 16                        # 12z 27th .. 03z 28th = 05:00 .. 20:00 PDT
UTC_OFFSET = -7
DATE0 = "2026-10-27"
G = 9.81
RD = 287.05
QV_ML = 0.0065                 # mixed-layer mixing ratio (kg/kg)


def local_hours():
    return [(12 + t + UTC_OFFSET) % 24 for t in range(NT)]


def sfc_temp_c(hl):
    """2 m temperature (C) by local hour: 9 C at night, 17 C mid-afternoon."""
    return 9.0 + 8.0 * max(0.0, np.sin(np.pi * (hl - 7) / 13.0))


def pblh_m(hl):
    """Mixed-layer depth (m AGL): 50 m at night, ~1400 m by 14:00."""
    return 50.0 + 1400.0 * max(0.0, np.sin(np.pi * (hl - 8) / 12.0))


def hfx_wm2(hl):
    """Sensible heat flux (W/m2): -20 at night, 330 at midday."""
    return -20.0 + 350.0 * max(0.0, np.sin(np.pi * (hl - 7) / 13.0))


def rain_rate_mm(hl):
    """Rain over the previous hour (mm): 0.6 mm/h at 16:00 and 17:00 local."""
    return 0.6 if hl in (16, 17) else 0.0


def profiles(hl):
    """Return (p_mb, z_m, tc, td, u_ms, v_ms, w_ms_stag, z_stag) for one hour."""
    p_stag = 967.0 - 14.0 * np.arange(NZ + 1)
    p_mb = 960.0 - 14.0 * np.arange(NZ)
    t_mean = 278.0
    z_stag = TER_M + (RD * t_mean / G) * np.log(PSFC_PA / 100.0 / p_stag)
    z_m = TER_M + (RD * t_mean / G) * np.log(PSFC_PA / 100.0 / p_mb)
    zagl = z_m - TER_M
    pbl = pblh_m(hl)
    theta_sfc = (sfc_temp_c(hl) + 273.15) * (1000.0 / p_mb[0]) ** 0.286
    theta = np.where(zagl <= pbl, theta_sfc, theta_sfc + 0.0035 * (zagl - pbl))
    tk = theta * (p_mb / 1000.0) ** 0.286
    tc = tk - 273.15
    spread = np.where(zagl <= pbl, 4.0, 8.0)          # RH ~77% in the mixed layer
    if hl <= 10:                                   # morning stratus 300-700 m AGL
        spread = np.where((zagl >= 300) & (zagl <= 700), 0.5, spread)
    td = tc - spread
    u = 2.0 + 9.0 * np.clip(zagl / 3000.0, 0, 1)
    v = np.full(NZ, 1.5)
    w_stag = np.where(((z_stag - TER_M) <= pbl) & (11 <= hl <= 16), 0.15, 0.0)
    return p_mb, z_m, tc, td, u, v, w_stag, z_stag


def qvapor_from_td(td_c, p_mb):
    e = 6.112 * np.exp(17.67 * td_c / (td_c + 243.5))
    return 0.622 * e / np.maximum(p_mb - e, 0.1)


def write_synthetic_wrfout(path):
    """Write the synthetic wrfout to ``path`` and return the path as a str."""
    ny = nx = 3
    nc = Dataset(str(path), "w", format="NETCDF4")
    nc.createDimension("Time", NT)
    nc.createDimension("DateStrLen", 19)
    nc.createDimension("bottom_top", NZ)
    nc.createDimension("bottom_top_stag", NZ + 1)
    nc.createDimension("south_north", ny)
    nc.createDimension("south_north_stag", ny + 1)
    nc.createDimension("west_east", nx)
    nc.createDimension("west_east_stag", nx + 1)
    nc.setncattr("DX", 1333.33)
    nc.setncattr("DY", 1333.33)

    def var(name, dims):
        return nc.createVariable(name, "f4", dims)

    times = []
    for t in range(NT):
        hutc = 12 + t
        day = DATE0 if hutc < 24 else "2026-10-28"
        times.append(f"{day}_{hutc % 24:02d}:00:00")
    tv = nc.createVariable("Times", "S1", ("Time", "DateStrLen"))
    tv[:] = np.array([list(s) for s in times], dtype="S1")

    lat = SITE_LAT + 0.012 * (np.arange(ny) - 1)[:, None] + 0 * np.arange(nx)[None, :]
    lon = SITE_LON + 0.012 * (np.arange(nx) - 1)[None, :] + 0 * np.arange(ny)[:, None]
    for name, val in (("XLAT", lat), ("XLONG", lon), ("COSALPHA", np.ones((ny, nx))),
                      ("SINALPHA", np.zeros((ny, nx))), ("HGT", np.full((ny, nx), TER_M))):
        v = var(name, ("Time", "south_north", "west_east"))
        v[:] = np.broadcast_to(val, (NT, ny, nx))

    P = var("P", ("Time", "bottom_top", "south_north", "west_east"))
    PB = var("PB", ("Time", "bottom_top", "south_north", "west_east"))
    T = var("T", ("Time", "bottom_top", "south_north", "west_east"))
    QV = var("QVAPOR", ("Time", "bottom_top", "south_north", "west_east"))
    PH = var("PH", ("Time", "bottom_top_stag", "south_north", "west_east"))
    PHB = var("PHB", ("Time", "bottom_top_stag", "south_north", "west_east"))
    U = var("U", ("Time", "bottom_top", "south_north", "west_east_stag"))
    V = var("V", ("Time", "bottom_top", "south_north_stag", "west_east"))
    W = var("W", ("Time", "bottom_top_stag", "south_north", "west_east"))
    sfc = {n: var(n, ("Time", "south_north", "west_east"))
           for n in ("HFX", "LH", "PBLH", "T2", "U10", "V10", "Q2", "PSFC", "RAINC", "RAINNC")}

    rain_acc = 0.0
    for t, hl in enumerate(local_hours()):
        p_mb, z_m, tc, td, u, v, w_stag, z_stag = profiles(hl)
        theta = (tc + 273.15) * (1000.0 / p_mb) ** 0.286
        qv = qvapor_from_td(td, p_mb)
        P[t] = 0.0
        PB[t] = (p_mb * 100.0)[:, None, None]
        T[t] = (theta - 300.0)[:, None, None]
        QV[t] = qv[:, None, None]
        PH[t] = 0.0
        PHB[t] = (G * z_stag)[:, None, None]
        U[t] = u[:, None, None]
        V[t] = v[:, None, None]
        W[t] = w_stag[:, None, None]
        hfx = hfx_wm2(hl)
        sfc["HFX"][t] = hfx
        sfc["LH"][t] = 0.4 * max(hfx, 0.0)
        sfc["PBLH"][t] = pblh_m(hl)
        sfc["T2"][t] = sfc_temp_c(hl) + 273.15
        sfc["U10"][t] = 0.8 * u[0]
        sfc["V10"][t] = 0.8 * v[0]
        sfc["Q2"][t] = qv[0]
        sfc["PSFC"][t] = PSFC_PA
        rain_acc += rain_rate_mm(hl)
        sfc["RAINC"][t] = 0.0
        sfc["RAINNC"][t] = rain_acc
    nc.close()
    return str(path)
