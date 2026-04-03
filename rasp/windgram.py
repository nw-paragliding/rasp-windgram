"""
Windgram renderer — Python replacement for windgrams.ncl.

Produces a vertical time-series chart for a single lat/lon point showing:
- Lapse rate background (filled contour, C/1000ft)
- Wind barbs colored by speed
- PBL top line
- w* labels at top
- hcrit / LCL markers (paraglider wing symbols)
- Freezing level line
- Condensation zones (cross-hatching where T ≈ Td)

Usage:
    from rasp.windgram import render_windgram
    render_windgram(wrfout_path, lat, lon, site_name, output_dir)
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm
from matplotlib.path import Path
from matplotlib.markers import MarkerStyle
from pathlib import Path as FilePath

from . import soaring


# ---------------------------------------------------------------------------
# Custom paraglider wing marker
# ---------------------------------------------------------------------------
_WING_VERTS = [
    (-1.0, 0.0), (-0.8, 0.5), (-0.4, 0.8), (0.0, 0.9),
    (0.4, 0.8), (0.8, 0.5), (1.0, 0.0),
    (0.8, 0.15), (0.4, 0.3), (0.0, 0.35),
    (-0.4, 0.3), (-0.8, 0.15), (-1.0, 0.0),
]
_WING_CODES = [
    Path.MOVETO, Path.CURVE4, Path.CURVE4, Path.CURVE4,
    Path.CURVE4, Path.CURVE4, Path.CURVE4,
    Path.CURVE4, Path.CURVE4, Path.CURVE4,
    Path.CURVE4, Path.CURVE4, Path.CLOSEPOLY,
]
WING_MARKER = MarkerStyle(Path(_WING_VERTS, _WING_CODES))


# ---------------------------------------------------------------------------
# Color map matching the NCL windgram palette
# ---------------------------------------------------------------------------

# Lapse rate color levels (C/1000ft)
# Negative = inversion, 0 = isothermal, positive = unstable
LAPSE_LEVELS = [-4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7]

# Colors from windgrams.ncl updcolors, mapped to lapse rate bins
LAPSE_COLORS = [
    (0.60, 0.60, 0.60),  # strong inversion — dark grey
    (0.80, 0.80, 0.80),  # moderate inversion — light grey
    (0.90, 0.90, 0.90),  # weak inversion — near white
    (0.98, 0.94, 0.90),  # isothermal — cream
    (0.78, 1.00, 0.78),  # weak lapse — light green
    (0.47, 1.00, 0.47),  # moderate lapse — green
    (0.08, 1.00, 0.08),  # good lapse — bright green
    (1.00, 0.73, 1.00),  # strong lapse — pink
    (0.80, 0.75, 1.00),  # very strong — purple
    (1.00, 0.80, 0.00),  # excellent — gold
    (1.00, 0.60, 0.00),  # extreme — orange
    (1.00, 0.24, 0.24),  # severe — red
]

WIND_CMAP = plt.cm.cool_r  # blue → pink for wind speed


def _extract_site_data(wrfout_path, lat, lon):
    """Extract all needed fields from wrfout at a single lat/lon point.

    Returns a dict with time series of pressure levels, temperature,
    wind, moisture, terrain, PBL height, and derived quantities.
    """
    try:
        import wrf
        from netCDF4 import Dataset
    except ImportError as e:
        raise ImportError(
            "wrf-python and netCDF4 are required: pip install wrf-python netCDF4"
        ) from e

    nc = Dataset(wrfout_path)

    # Find grid point closest to requested lat/lon
    xy = wrf.ll_to_xy(nc, lat, lon)
    ix, iy = int(xy[0]), int(xy[1])

    # Time info
    times = wrf.extract_times(nc, timeidx=wrf.ALL_TIMES)
    ntimes = len(times)

    # 3D fields at this point — shape: (time, levels)
    p = wrf.getvar(nc, "pressure", timeidx=wrf.ALL_TIMES)  # mb
    z = wrf.getvar(nc, "z", timeidx=wrf.ALL_TIMES)          # m ASL
    tk = wrf.getvar(nc, "tk", timeidx=wrf.ALL_TIMES)        # K
    tc_full = wrf.getvar(nc, "tc", timeidx=wrf.ALL_TIMES)   # C
    td = wrf.getvar(nc, "td", timeidx=wrf.ALL_TIMES)        # C
    ua = wrf.getvar(nc, "ua", timeidx=wrf.ALL_TIMES)        # m/s
    va = wrf.getvar(nc, "va", timeidx=wrf.ALL_TIMES)        # m/s
    qv = nc.variables["QVAPOR"][:, :, iy, ix]

    # Extract at point
    p_pt = np.array(p[:, :, iy, ix])       # (time, levels)
    z_pt = np.array(z[:, :, iy, ix])       # m ASL
    tk_pt = np.array(tk[:, :, iy, ix])     # K
    tc_pt = np.array(tc_full[:, :, iy, ix])  # C
    td_pt = np.array(td[:, :, iy, ix])     # C
    u_pt = np.array(ua[:, :, iy, ix])      # m/s
    v_pt = np.array(va[:, :, iy, ix])      # m/s

    # 2D fields — need whole domain for soaring calcs then extract point
    ter_full = np.array(wrf.getvar(nc, "ter", timeidx=0))  # m ASL, 2D
    pblh_full = np.array(nc.variables["PBLH"][:, iy, ix])  # m AGL, (time,)
    hfx_full = np.array(nc.variables["HFX"][:, iy, ix])    # W/m^2
    lh_full = np.array(nc.variables["LH"][:, iy, ix])      # W/m^2
    t2_full = np.array(nc.variables["T2"][:, iy, ix])      # K

    ter_pt = float(ter_full[iy, ix])

    # Compute soaring indices at this point for each time
    wstar_ts = np.zeros(ntimes)
    hcrit_ts = np.zeros(ntimes)
    lcl_ts = np.zeros(ntimes)

    for t in range(ntimes):
        # Wrap scalars as 1-element arrays for soaring functions
        hfx_1 = np.array([[hfx_full[t]]])
        lh_1 = np.array([[lh_full[t]]])
        pblh_1 = np.array([[pblh_full[t]]])
        t2_1 = np.array([[t2_full[t]]])
        ter_1 = np.array([[ter_pt]])

        ws = soaring.calc_wstar(hfx_1, lh_1, pblh_1, t2_1)
        wstar_ts[t] = ws[0, 0]

        hc = soaring.calc_hcrit(ws, ter_1, pblh_1)
        hcrit_ts[t] = hc[0, 0]

        # LCL from surface spread
        spread = max(tc_pt[t, 0] - td_pt[t, 0], 0.0)
        lcl_ts[t] = ter_pt + 125.0 * spread

    # Wind rotation to earth-relative coordinates
    cosalpha = float(nc.variables["COSALPHA"][0, iy, ix])
    sinalpha = float(nc.variables["SINALPHA"][0, iy, ix])
    u_earth = u_pt * cosalpha - v_pt * sinalpha
    v_earth = u_pt * sinalpha + v_pt * cosalpha

    # Convert wind to knots
    u_kts = u_earth * 1.94384
    v_kts = v_earth * 1.94384

    # Compute lapse rate (C/1000ft)
    z_ft = z_pt * 3.28084
    dz_ft = np.diff(z_ft, axis=1) / 1000.0  # thousands of feet
    dz_ft = np.maximum(dz_ft, 0.01)
    dt = np.diff(tk_pt, axis=1)  # K (same magnitude as C)
    lapse = dt / dz_ft  # C/1000ft

    # PBL height in pressure coordinates (approx)
    mslp = p_pt[:, 0]  # surface pressure
    pbl_ft = pblh_full * 3.28084
    pbl_p = mslp - pbl_ft / 32.0  # rough mb conversion

    # hcrit / hglider in pressure coordinates
    hcrit_ft = hcrit_ts * 3.28084
    lcl_ft = lcl_ts * 3.28084
    # Soaring ceiling = min(hcrit, lcl)
    hglider_ft = np.minimum(hcrit_ft, lcl_ft)
    hglider_p = mslp - hglider_ft / 32.0
    lcl_p = mslp - lcl_ft / 32.0

    # Freezing level (pressure at which T crosses 273.15K)
    freeze_p = np.full(ntimes, np.nan)
    for t in range(ntimes):
        for k in range(p_pt.shape[1]):
            if tk_pt[t, k] < 273.15:
                freeze_p[t] = p_pt[t, k]
                break

    # Condensation zones (where T ≈ Td within 2C)
    condense = np.abs(tc_pt - td_pt) < 2.0

    nc.close()

    return {
        "times": times,
        "ntimes": ntimes,
        "p": p_pt,             # (time, levels) mb
        "z_ft": z_ft,          # (time, levels) feet ASL
        "tc": tc_pt,           # (time, levels) C
        "td": td_pt,           # (time, levels) C
        "tk": tk_pt,           # (time, levels) K
        "u_kts": u_kts,        # (time, levels) knots
        "v_kts": v_kts,        # (time, levels) knots
        "lapse": lapse,        # (time, levels-1) C/1000ft
        "plevels": p_pt[0, :], # pressure levels from first time
        "wstar": wstar_ts,     # (time,) m/s
        "hcrit_ft": hcrit_ft,  # (time,) feet ASL
        "lcl_ft": lcl_ft,      # (time,) feet ASL
        "hglider_p": hglider_p, # (time,) mb
        "lcl_p": lcl_p,        # (time,) mb
        "pbl_p": pbl_p,        # (time,) mb
        "pbl_ft": pbl_ft,      # (time,) feet AGL
        "freeze_p": freeze_p,  # (time,) mb
        "condense": condense,  # (time, levels) bool
        "ter_ft": ter_pt * 3.28084,
        "ter_m": ter_pt,
        "lat": lat,
        "lon": lon,
    }


def render_windgram(wrfout_path, lat, lon, site_name, output_dir,
                    ptop=30, utc_offset=-7, dpi=100):
    """Render a windgram PNG for a single site.

    Args:
        wrfout_path: path to wrfout NetCDF file(s)
        lat, lon:    site latitude and longitude
        site_name:   name for the output file and title
        output_dir:  directory to write PNG to
        ptop:        number of pressure levels to plot (from surface up)
        utc_offset:  hours to add to UTC for local time labels
        dpi:         output resolution

    Returns:
        Path to the output PNG file.
    """
    data = _extract_site_data(wrfout_path, lat, lon)

    ntimes = data["ntimes"]
    p = data["p"]
    nlevels = min(ptop, p.shape[1] - 1)

    # Pressure levels for Y axis
    plevels = p[0, :nlevels]

    # Time axis
    taus = np.arange(ntimes)

    # Local time labels
    hours_utc = np.array([t.astype("datetime64[h]").astype(int) % 24
                          for t in data["times"]])
    hours_local = (hours_utc + utc_offset) % 24
    # Convert to 12-hour
    hours_12 = hours_local.copy()
    hours_12[hours_12 > 12] -= 12
    hours_12[hours_12 == 0] = 12

    # --- Build the figure ---
    fig, ax = plt.subplots(figsize=(8, 8))

    # Background color
    fig.patch.set_facecolor((0.5, 0.5, 0.9))
    ax.set_facecolor((0.5, 0.5, 0.9))

    # Lapse rate filled contour
    lapse_grid = data["lapse"][:, :nlevels].T  # (levels, time)
    p_mid = 0.5 * (p[:, :nlevels] + p[:, 1:nlevels + 1]).T  # midpoint pressures

    cmap = ListedColormap(LAPSE_COLORS)
    norm = BoundaryNorm(LAPSE_LEVELS, cmap.N)

    # Use pcolormesh for the lapse rate background
    ax.pcolormesh(taus, plevels, lapse_grid[:len(plevels), :],
                  cmap=cmap, norm=norm, shading="auto")

    # Wind barbs
    wind_speed = np.sqrt(data["u_kts"]**2 + data["v_kts"]**2)
    for t in range(ntimes):
        for k in range(nlevels):
            speed = wind_speed[t, k]
            color = WIND_CMAP(min(speed / 50.0, 1.0))
            ax.barbs(taus[t], p[t, k], data["u_kts"][t, k], data["v_kts"][t, k],
                     length=5, linewidth=0.5, color=color,
                     barb_increments=dict(half=5, full=10, flag=50))

    # PBL top line
    ax.plot(taus, data["pbl_p"], color="cyan", linewidth=2, alpha=0.8,
            label="PBL top")

    # Freezing level
    freeze = data["freeze_p"]
    valid = ~np.isnan(freeze)
    if np.any(valid):
        ax.plot(taus[valid], freeze[valid], color="white", linewidth=1.5,
                linestyle="--", alpha=0.7, label="Freezing level")

    # Paraglider wing markers (hglider = min of hcrit, LCL)
    ax.scatter(taus, data["hglider_p"], marker=WING_MARKER, s=200,
               color="blue", zorder=5, label="Max soaring height")

    # LCL markers
    ax.scatter(taus, data["lcl_p"], marker="^", s=40,
               color="lightblue", zorder=4, alpha=0.7, label="LCL")

    # w* labels along the top
    for t in range(ntimes):
        ws = data["wstar"][t]
        if ws > 0.1:
            label = f"{ws:.1f}m/s"
        else:
            label = ""
        ax.text(taus[t], plevels[0] * 0.995, label,
                ha="center", va="bottom", fontsize=6, color="yellow",
                fontweight="bold")

    # Condensation cross-hatching
    for t in range(ntimes):
        for k in range(nlevels):
            if data["condense"][t, k]:
                ax.plot(taus[t], p[t, k], "x", color="white",
                        markersize=3, alpha=0.3)

    # Axis formatting
    ax.invert_yaxis()  # pressure decreases upward
    ax.set_xlim(-0.5, ntimes - 0.5)
    ax.set_xticks(taus)
    ax.set_xticklabels([str(h) for h in hours_12], fontsize=8, color="white")
    ax.set_xlabel("Time (local)", color="white", fontsize=10)

    # Left Y axis: pressure (mb)
    ax.set_ylabel("Pressure (mb)", color="white", fontsize=10)
    ax.tick_params(axis="y", colors="white", labelsize=8)

    # Right Y axis: altitude (feet)
    ax2 = ax.twinx()
    ax2.set_ylim(ax.get_ylim())
    ax2.invert_yaxis()
    # Approximate feet from pressure
    p_range = ax.get_ylim()
    ft_ticks = np.arange(0, 20000, 2000)
    p_ticks = p[0, 0] - ft_ticks / 32.0
    valid_ticks = (p_ticks >= min(p_range)) & (p_ticks <= max(p_range))
    ax2.set_yticks(p_ticks[valid_ticks])
    ax2.set_yticklabels([f"{int(f)}'" for f in ft_ticks[valid_ticks]],
                        fontsize=8, color="white")
    ax2.tick_params(axis="y", colors="white")

    # Title
    date_str = str(data["times"][0])[:10]
    ax.set_title(
        f"{date_str} / {site_name} ({data['lat']:.3f}, {data['lon']:.3f})\n"
        f"Base: {int(data['ter_ft'])}ft",
        color="white", fontsize=12, fontweight="bold",
    )

    # Bottom annotation
    ax.text(0.5, -0.08,
            f"Wind(knots)  Lapse rate(C/1000ft)\n"
            f"Location = {data['lat']:.3f}  {data['lon']:.3f}  "
            f"Base = {int(data['ter_ft'])}ft",
            transform=ax.transAxes, ha="center", va="top",
            fontsize=7, color="white")

    # Save
    output_dir = FilePath(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    out_path = output_dir / f"{date_str}_{site_name}_windgram.png"
    fig.savefig(out_path, dpi=dpi, bbox_inches="tight",
                facecolor=fig.get_facecolor())
    plt.close(fig)

    return str(out_path)
