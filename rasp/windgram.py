"""
Windgram renderer — Python replacement for windgrams.ncl.

Produces a vertical time-series chart for a single lat/lon point showing:
- Lapse rate background (smooth filled contours, C/1000ft)
- Wind barbs colored by speed
- PBL top line (cyan)
- w* labels at top
- Paraglider wing markers for max soaring height (min of hcrit, LCL)
- Snowflake markers at freezing level
- Cloud markers where RH > 99%
- Condensation cross-hatching where RH > 95%

Usage:
    python -m rasp.windgram wrfout_d02_2026-04-01_12:00:00 \\
        --lat 47.503 --lon -121.975 --site Tiger --output-dir ./output

    Or programmatically:
        from rasp.windgram import render_windgram
        render_windgram("wrfout_d02_...", 47.503, -121.975, "Tiger", "./output")
"""

import argparse
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm
from matplotlib.path import Path
from matplotlib.markers import MarkerStyle
from pathlib import Path as FilePath
from scipy.interpolate import griddata


# ---------------------------------------------------------------------------
# Custom paraglider wing marker
# ---------------------------------------------------------------------------
_WING_VERTS = [
    (-1.0, 0.0), (-0.7, 0.6), (-0.3, 0.85), (0.0, 0.9),
    (0.3, 0.85), (0.7, 0.6), (1.0, 0.0),
    (0.7, 0.2), (0.3, 0.35), (0.0, 0.38),
    (-0.3, 0.35), (-0.7, 0.2), (-1.0, 0.0),
]
_WING_CODES = [
    Path.MOVETO, Path.CURVE4, Path.CURVE4, Path.CURVE4,
    Path.CURVE4, Path.CURVE4, Path.CURVE4,
    Path.CURVE4, Path.CURVE4, Path.CURVE4,
    Path.CURVE4, Path.CURVE4, Path.CLOSEPOLY,
]
WING_MARKER = MarkerStyle(Path(_WING_VERTS, _WING_CODES))

# ---------------------------------------------------------------------------
# NCL-matching lapse rate colormap
# ---------------------------------------------------------------------------
# NCL convention: lapse = (T_above - T_below) / (dz in 1000ft)
# Negative values = temperature decreasing with height = normal/unstable
# NCL levels: -3, -2.5, -2.0, -1.5, -1.2, -0.5, 0, 0.5
# NCL color indices: 11(red), 10(orange), 7(pink), 8(purple), 3(cream), -1(bg), -1(bg), 13(grey), 14(dk grey)
BG_COLOR = (0.5, 0.5, 0.9)  # deep purple-blue background

LAPSE_LEVELS = [-3.0, -2.5, -2.0, -1.5, -1.2, -0.5, 0.0, 0.5]
LAPSE_COLORS = [
    (1.00, 0.24, 0.24),   # < -3: red — very unstable (superadiabatic)
    (1.00, 0.60, 0.00),   # -3 to -2.5: orange
    (1.00, 0.73, 1.00),   # -2.5 to -2: pink
    (0.80, 0.75, 1.00),   # -2 to -1.5: purple
    (0.98, 0.94, 0.90),   # -1.5 to -1.2: cream
    BG_COLOR,              # -1.2 to -0.5: background (normal atmosphere)
    BG_COLOR,              # -0.5 to 0: background
    (0.80, 0.80, 0.80),   # 0 to 0.5: grey — weak inversion
    (0.60, 0.60, 0.60),   # > 0.5: dark grey — strong inversion
]


def _extract_site_data(wrfout_path, lat, lon):
    """Extract all needed fields from wrfout at a single lat/lon point.

    Uses raw netCDF4 reads (no wrf-python dependency for extraction).
    """
    from netCDF4 import Dataset

    nc = Dataset(wrfout_path)

    # Find nearest grid point
    xlat = nc.variables["XLAT"][0, :, :]
    xlon = nc.variables["XLONG"][0, :, :]
    dist = (xlat - lat)**2 + (xlon - lon)**2
    iy, ix = np.unravel_index(np.argmin(dist), dist.shape)

    ntimes = nc.variables["Times"].shape[0]

    # Parse time strings
    times_raw = nc.variables["Times"][:]
    time_strings = []
    hours_utc = []
    for t in range(ntimes):
        s = "".join([c.decode() for c in times_raw[t]])
        time_strings.append(s)
        hours_utc.append(int(s[11:13]))

    # 3D fields at (iy, ix) — shape: (time, levels)
    P = nc.variables["P"][:, :, iy, ix]
    PB = nc.variables["PB"][:, :, iy, ix]
    ptot = (P + PB) / 100.0  # total pressure in mb

    PH = nc.variables["PH"][:, :, iy, ix]
    PHB = nc.variables["PHB"][:, :, iy, ix]
    z_stag = (PH + PHB) / 9.81  # height on staggered levels (m)
    z = 0.5 * (z_stag[:, :-1] + z_stag[:, 1:])  # unstagger
    z_ft = z * 3.28084

    T = nc.variables["T"][:, :, iy, ix]  # perturbation potential temp
    theta = T + 300.0
    tk = theta * (ptot / 1000.0) ** 0.286  # temperature (K)
    tc = tk - 273.15  # temperature (C)

    # Dewpoint from vapor pressure
    QVAPOR = nc.variables["QVAPOR"][:, :, iy, ix]
    es = 611.2 * np.exp(17.67 * tc / (tc + 243.5))
    e = np.maximum(QVAPOR * ptot * 100.0 / (0.622 + QVAPOR), 1e-10)
    td = 243.5 * np.log(e / 611.2) / (17.67 - np.log(e / 611.2))
    rh = np.clip(100.0 * e / es, 0, 100)

    # Wind — rotate to earth coordinates
    U = nc.variables["U"][:, :, iy, ix]
    V = nc.variables["V"][:, :, iy, ix]
    cosalpha = float(nc.variables["COSALPHA"][0, iy, ix])
    sinalpha = float(nc.variables["SINALPHA"][0, iy, ix])
    u_kts = (U * cosalpha - V * sinalpha) * 1.94384
    v_kts = (U * sinalpha + V * cosalpha) * 1.94384

    # Surface / BL fields
    HFX = nc.variables["HFX"][:, iy, ix]
    LH = nc.variables["LH"][:, iy, ix]
    PBLH = nc.variables["PBLH"][:, iy, ix]
    T2 = nc.variables["T2"][:, iy, ix]
    ter = z[0, 0]
    ter_ft = ter * 3.28084

    # w* (Deardorff, with virtual heat flux)
    vhf = np.maximum(HFX + 0.000245268 * T2 * np.maximum(LH, 0.0), 0.0)
    buoy = (9.81 / T2) * (vhf / 1200.0)
    wstar = np.where(buoy > 0, (buoy * PBLH) ** (1.0 / 3.0), 0.0)

    # hcrit and LCL
    hcrit_ft = (ter + PBLH * np.where(wstar > 1, 1 - 1/wstar, 0)) * 3.28084
    spread = np.maximum(tc[:, 0] - td[:, 0], 0)
    lcl_ft = (ter + 125.0 * spread) * 3.28084
    hglider_ft = np.minimum(hcrit_ft, lcl_ft)

    # Pressure coordinates for markers
    sfc_p = ptot[:, 0]
    pbl_p = sfc_p - (PBLH * 3.28084) / 32.0
    hglider_p = sfc_p - hglider_ft / 32.0

    # Lapse rate: (T_above - T_below) / (dz in 1000ft)
    dz = np.maximum(np.diff(z_ft, axis=1) / 1000.0, 0.01)
    lapse = np.diff(tk, axis=1) / dz
    p_mid = 0.5 * (ptot[:, :-1] + ptot[:, 1:])

    # Freezing level
    freeze_p = np.full(ntimes, np.nan)
    for t in range(ntimes):
        for k in range(ptot.shape[1]):
            if tk[t, k] < 273.15:
                freeze_p[t] = ptot[t, k]
                break

    nc.close()

    return {
        "time_strings": time_strings,
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
        "lat": xlat[iy, ix],
        "lon": xlon[iy, ix],
    }


def render_windgram(wrfout_path, lat, lon, site_name, output_dir,
                    p_top_mb=620.0, utc_offset=-7, dpi=100):
    """Render a windgram PNG for a single site.

    Args:
        wrfout_path: path to wrfout NetCDF file
        lat, lon:    site latitude and longitude
        site_name:   name for the output file and title
        output_dir:  directory to write PNG to
        p_top_mb:    top of chart in millibars (default 620)
        utc_offset:  hours to add to UTC for local time labels (default -7 PDT)
        dpi:         output resolution

    Returns:
        Path to the output PNG file.
    """
    d = _extract_site_data(wrfout_path, lat, lon)

    ntimes = d["ntimes"]
    ptot = d["ptot"]
    ptop_idx = max(np.searchsorted(-ptot[0, :], -p_top_mb), 10)
    taus = np.arange(ntimes)

    # Local time labels (12-hour)
    local = (d["hours_utc"] + utc_offset) % 24
    l12 = local.copy()
    l12[l12 > 12] -= 12
    l12[l12 == 0] = 12

    # --- Figure setup ---
    fig, ax = plt.subplots(figsize=(8, 8))
    fig.patch.set_facecolor(BG_COLOR)
    ax.set_facecolor(BG_COLOR)

    # --- Lapse rate background (smooth contourf) ---
    cmap = ListedColormap(LAPSE_COLORS)
    norm = BoundaryNorm(LAPSE_LEVELS, cmap.N)

    # Interpolate lapse rate onto a fine grid for smooth contours
    p_fine = np.linspace(ptot[0, 0], p_top_mb, 200)
    t_fine = np.linspace(0, ntimes - 1, ntimes * 4)
    T_grid, P_grid = np.meshgrid(t_fine, p_fine)

    pts, vals = [], []
    for t in range(ntimes):
        for k in range(min(ptop_idx - 1, d["lapse"].shape[1])):
            pts.append([taus[t], d["p_mid"][t, k]])
            vals.append(d["lapse"][t, k])

    lapse_interp = griddata(np.array(pts), np.array(vals),
                            (T_grid, P_grid), method="linear")
    lapse_interp = np.where(np.isnan(lapse_interp), 0, lapse_interp)
    ax.contourf(t_fine, p_fine, lapse_interp,
                levels=LAPSE_LEVELS, colors=LAPSE_COLORS, extend="both")

    # --- Condensation cross-hatching (RH > 95%) ---
    rh = d["rh"]
    for t in range(ntimes):
        for k in range(ptop_idx):
            if ptot[t, k] < p_top_mb:
                break
            if rh[t, k] > 95:
                ax.plot(taus[t], ptot[t, k], "x", color="white",
                        markersize=3, alpha=0.4, zorder=2)

    # --- Cloud markers (RH > 99%) ---
    for t in range(ntimes):
        for k in range(ptop_idx):
            if ptot[t, k] < p_top_mb:
                break
            if rh[t, k] > 99:
                ax.text(taus[t], ptot[t, k], "\u2601", fontsize=8,
                        ha="center", va="center", color="white",
                        alpha=0.5, zorder=2)

    # --- Wind barbs ---
    wspeed = np.sqrt(d["u_kts"]**2 + d["v_kts"]**2)
    for t in range(ntimes):
        for k in range(ptop_idx):
            if ptot[t, k] < p_top_mb:
                break
            c = plt.cm.cool_r(min(wspeed[t, k] / 50.0, 1.0))
            ax.barbs(taus[t], ptot[t, k],
                     d["u_kts"][t, k], d["v_kts"][t, k],
                     length=5, linewidth=0.5, color=c,
                     barb_increments=dict(half=5, full=10, flag=50))

    # --- PBL top line ---
    ax.plot(taus, d["pbl_p"], color="cyan", linewidth=2.5, alpha=0.9)

    # --- Freezing level with snowflakes ---
    freeze = d["freeze_p"]
    valid_f = ~np.isnan(freeze) & (freeze > p_top_mb)
    if np.any(valid_f):
        ax.plot(taus[valid_f], freeze[valid_f], "--",
                color="lightblue", linewidth=1, alpha=0.5)
        for t in range(ntimes):
            if valid_f[t]:
                ax.text(taus[t], freeze[t], "\u2744", fontsize=12,
                        ha="center", va="center", color="lightblue",
                        alpha=0.8, zorder=4)

    # --- Paraglider wing markers (soaring ceiling) ---
    hglider_p = d["hglider_p"]
    valid_h = hglider_p > p_top_mb
    ax.scatter(taus[valid_h], hglider_p[valid_h], s=400, color="blue",
               marker=WING_MARKER, zorder=5, edgecolors="darkblue",
               linewidths=0.8)

    # --- w* labels at top ---
    for t in range(ntimes):
        txt = f"{d['wstar'][t]:.1f}" if d["wstar"][t] > 0.1 else ""
        ax.text(taus[t], p_top_mb + 3, txt, ha="center", va="top",
                fontsize=7, color="yellow", fontweight="bold")

    # --- Axis formatting ---
    ax.set_ylim(ptot[0, 0] + 5, p_top_mb)
    ax.set_xlim(-0.5, ntimes - 0.5)
    ax.set_xticks(taus)
    ax.set_xticklabels([str(h) for h in l12], fontsize=8, color="white")
    ax.set_xlabel("Time (local)", color="white", fontsize=10)
    ax.set_ylabel("Pressure (mb)", color="white", fontsize=10)
    ax.tick_params(colors="white", labelsize=8)

    # Right Y axis: altitude (feet ASL)
    ax2 = ax.twinx()
    ax2.set_ylim(ax.get_ylim())
    ft_vals = np.arange(0, 18001, 2000)
    p_ft = d["sfc_p"][0] - ft_vals / 32.0
    valid_ft = (p_ft > p_top_mb) & (p_ft < ptot[0, 0] + 5)
    ax2.set_yticks(p_ft[valid_ft])
    ax2.set_yticklabels([f"{int(f + d['ter_ft'])}'" for f in ft_vals[valid_ft]],
                        fontsize=8, color="white")
    ax2.tick_params(colors="white")

    # Title
    date_str = d["time_strings"][0][:10]
    ax.set_title(
        f"{date_str} / {site_name}\n"
        f"Base: {int(d['ter_ft'])}ft  |  w*(m/s) along top",
        color="white", fontsize=11, fontweight="bold",
    )

    # --- Save ---
    output_dir = FilePath(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    out_path = output_dir / f"{date_str}_{site_name}_windgram.png"
    fig.savefig(out_path, dpi=dpi, bbox_inches="tight",
                facecolor=fig.get_facecolor())
    plt.close(fig)

    print(f"Saved: {out_path}")
    return str(out_path)


def main():
    parser = argparse.ArgumentParser(description="Render a windgram from WRF output")
    parser.add_argument("wrfout", help="Path to wrfout NetCDF file")
    parser.add_argument("--lat", type=float, required=True, help="Site latitude")
    parser.add_argument("--lon", type=float, required=True, help="Site longitude")
    parser.add_argument("--site", required=True, help="Site name")
    parser.add_argument("--output-dir", default=".", help="Output directory")
    parser.add_argument("--p-top", type=float, default=620.0, help="Top pressure (mb)")
    parser.add_argument("--utc-offset", type=int, default=-7, help="UTC offset for local time")
    parser.add_argument("--dpi", type=int, default=100, help="Output DPI")
    args = parser.parse_args()

    render_windgram(args.wrfout, args.lat, args.lon, args.site,
                    args.output_dir, p_top_mb=args.p_top,
                    utc_offset=args.utc_offset, dpi=args.dpi)


if __name__ == "__main__":
    main()
