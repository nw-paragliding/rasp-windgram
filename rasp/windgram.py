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
import matplotlib.patheffects
from matplotlib.colors import ListedColormap, BoundaryNorm
from matplotlib.path import Path
from matplotlib.markers import MarkerStyle
from pathlib import Path as FilePath


# ---------------------------------------------------------------------------
# Paraglider crescent marker — simple wing shape like the NCL prod version
# ---------------------------------------------------------------------------
# Wide flat crescent — like a paraglider wing seen from below
_WING_VERTS = [
    (-1.2, -0.1),                       # left tip
    (-0.6, 0.7), (0.6, 0.7),           # top arc (high, wide)
    (1.2, -0.1),                        # right tip
    (0.6, 0.25), (-0.6, 0.25),         # bottom arc (shallower)
    (-1.2, -0.1),                       # close
]
_WING_CODES = [
    Path.MOVETO,
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

    # hcrit: max soaring height based on thermal strength (w*) and BL depth.
    # DrJack's formula: hcrit = ter + PBLH * (1 - sink_rate/wstar)
    # This represents the height where the thermal updraft velocity profile
    # drops below the glider's sink rate. w* is the convective velocity scale
    # (not WRF's grid-scale W field, which doesn't resolve thermals).
    SINK_RATE = 1.14  # m/s — 225 fpm, standard PG sink rate per TJ Olney
    wstar_safe = np.maximum(wstar, 0.01)
    hcrit_ft = (ter + PBLH * np.where(wstar > SINK_RATE,
                1 - SINK_RATE / wstar_safe, 0)) * 3.28084

    spread = np.maximum(tc[:, 0] - td[:, 0], 0)
    lcl_ft = (ter + 125.0 * spread) * 3.28084
    hglider_ft = np.minimum(hcrit_ft, lcl_ft)

    # Pressure coordinates for markers
    # Convert feet ASL to pressure using: p = sfc_p - (ft_AGL / 32)
    ter_ft = ter * 3.28084
    sfc_p = ptot[:, 0]
    pbl_p = sfc_p - (PBLH * 3.28084) / 32.0  # PBLH is already AGL
    hglider_p = sfc_p - (hglider_ft - ter_ft) / 32.0  # convert ASL to AGL first

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
                    p_top_mb=None, headroom_ft=4000, utc_offset=-7,
                    start_hour=8, dpi=100):
    """Render a windgram PNG for a single site.

    Args:
        wrfout_path: path to wrfout NetCDF file
        lat, lon:    site latitude and longitude
        site_name:   name for the output file and title
        output_dir:  directory to write PNG to
        p_top_mb:    top of chart in millibars (None = auto from max PBL + headroom)
        headroom_ft: feet above max PBL top for chart ceiling (default 4000)
        utc_offset:  hours to add to UTC for local time labels (default -7 PDT)
        start_hour:  earliest local hour to show (default 8, skips pre-dawn)
        dpi:         output resolution

    Returns:
        Path to the output PNG file.
    """
    d = _extract_site_data(wrfout_path, lat, lon)

    # Filter to local hours >= start_hour (skip pre-dawn)
    local_all = (d["hours_utc"] + utc_offset) % 24
    keep = local_all >= start_hour
    if not np.any(keep):
        keep = np.ones(len(local_all), dtype=bool)  # fallback: keep all

    # Slice all time-dependent arrays
    for key in ["ptot", "p_mid", "z_ft", "tk", "tc", "td", "rh",
                "u_kts", "v_kts", "lapse", "wstar", "hglider_p",
                "pbl_p", "freeze_p", "sfc_p", "hours_utc", "time_strings"]:
        val = d[key]
        if isinstance(val, np.ndarray) and val.shape[0] == d["ntimes"]:
            d[key] = val[keep]
        elif isinstance(val, list) and len(val) == d["ntimes"]:
            d[key] = [v for v, k in zip(val, keep) if k]
    d["ntimes"] = int(np.sum(keep))

    ntimes = d["ntimes"]
    ptot = d["ptot"]

    # Auto-compute chart ceiling from max PBL height + headroom
    if p_top_mb is None:
        max_pbl_p = np.min(d["pbl_p"])  # lowest pressure = highest PBL
        # Convert headroom from feet to pressure delta
        headroom_p = headroom_ft / 32.0
        p_top_mb = max_pbl_p - headroom_p
        # Clamp to reasonable range (don't go above ~500mb / ~18,000ft)
        p_top_mb = max(p_top_mb, 500.0)
        # Round to nearest 10mb
        p_top_mb = round(p_top_mb / 10) * 10

    ptop_idx = max(np.searchsorted(-ptot[0, :], -p_top_mb), 10)
    # Actual pressure bounds from data (midpoints where lapse data exists)
    p_top_actual = 0.5 * (ptot[0, ptop_idx - 2] + ptot[0, ptop_idx - 1])
    p_bottom = 0.5 * (ptot[0, 0] + ptot[0, 1])
    taus = np.arange(ntimes)

    # Local time labels (12-hour with am/pm)
    local = (d["hours_utc"] + utc_offset) % 24
    l12 = local.copy()
    ampm = np.where(local < 12, "a", "p")
    l12[l12 > 12] -= 12
    l12[l12 == 0] = 12
    time_labels = [f"{h}{ap}" for h, ap in zip(l12, ampm)]

    # --- Figure setup ---
    fig, ax = plt.subplots(figsize=(8, 8))
    fig.patch.set_facecolor(BG_COLOR)
    ax.set_facecolor(BG_COLOR)

    # --- Lapse rate background (smooth contourf) ---
    cmap = ListedColormap(LAPSE_COLORS)
    norm = BoundaryNorm(LAPSE_LEVELS, cmap.N)

    # Use fixed pressure levels (from first time step) as Y axis.
    # Interpolate along time axis only (4x oversampling) for smooth
    # horizontal transitions without vertical waviness.
    from scipy.interpolate import interp1d
    p_levels_mid = d["p_mid"][0, :ptop_idx - 1]
    lapse_raw = d["lapse"][:, :ptop_idx - 1].T  # (levels, time)
    t_fine = np.linspace(0, ntimes - 1, ntimes * 4)
    lapse_smooth = np.zeros((lapse_raw.shape[0], len(t_fine)))
    for k in range(lapse_raw.shape[0]):
        f = interp1d(taus, lapse_raw[k, :], kind="cubic",
                     bounds_error=False, fill_value="extrapolate")
        lapse_smooth[k, :] = f(t_fine)

    ax.contourf(t_fine, p_levels_mid, lapse_smooth,
                levels=LAPSE_LEVELS, colors=LAPSE_COLORS, extend="both")

    # --- Condensation hatching (RH > 94%) — diagonal white lines ---
    rh = d["rh"]
    rh_grid = rh[:, :ptop_idx].T  # (levels, time)
    p_levels_full = ptot[0, :ptop_idx]

    # Smooth RH along time axis like lapse rate
    rh_smooth = np.zeros((rh_grid.shape[0], len(t_fine)))
    for k in range(rh_grid.shape[0]):
        f = interp1d(taus, rh_grid[k, :], kind="cubic",
                     bounds_error=False, fill_value="extrapolate")
        rh_smooth[k, :] = f(t_fine)

    # Light hatching at RH > 94%
    n_before = len(ax.collections)
    ax.contourf(t_fine, p_levels_full, rh_smooth, levels=[94, 100],
                colors="none", hatches=["//"], alpha=0)
    for c in ax.collections[n_before:]:
        c.set_edgecolor("white")
        c.set_linewidth(0.3)
    # Dense hatching at RH > 97%
    n_before2 = len(ax.collections)
    ax.contourf(t_fine, p_levels_full, rh_smooth, levels=[97, 100],
                colors="none", hatches=["////"], alpha=0)
    for c in ax.collections[n_before2:]:
        c.set_edgecolor("white")
        c.set_linewidth(0.5)

    # --- Cloud markers at LCL height (where cumulus would form) ---
    # Per TJ Olney: "Small clouds represent the expected LCL (lowest
    # cloudbase), but do not mean that there will be clouds."
    lcl_agl_ft = 125.0 * np.maximum(d["tc"][:, 0] - d["td"][:, 0], 0) * 3.28084
    lcl_p = d["sfc_p"] - lcl_agl_ft / 32.0
    for t in range(ntimes):
        if lcl_p[t] > p_top_actual and lcl_p[t] < d["sfc_p"][t]:
            # Grey shadow
            ax.text(taus[t] + 0.05, lcl_p[t] - 1.0, "\u2601",
                    fontsize=48, ha="center", va="center",
                    color="grey", alpha=0.5, zorder=3, clip_on=True)
            # White cloud
            ax.text(taus[t], lcl_p[t], "\u2601",
                    fontsize=48, ha="center", va="center",
                    color="white", alpha=0.85, zorder=3, clip_on=True)

    # --- Temperature contour lines (isotherms in F) ---
    tc = d["tc"]
    tc_f = tc * 9.0/5.0 + 32  # convert to Fahrenheit
    p_levels_full = ptot[0, :ptop_idx]
    tc_raw = tc_f[:, :ptop_idx].T  # (levels, time)
    tc_smooth = np.zeros((tc_raw.shape[0], len(t_fine)))
    for k in range(tc_raw.shape[0]):
        f = interp1d(taus, tc_raw[k, :], kind="cubic",
                     bounds_error=False, fill_value="extrapolate")
        tc_smooth[k, :] = f(t_fine)
    temp_levels = np.arange(-40, 120, 10)
    cs = ax.contour(t_fine, p_levels_full, tc_smooth, levels=temp_levels,
                    colors="white", linewidths=0.8, alpha=0.7)
    ax.clabel(cs, inline=True, fontsize=8, fmt="%d\u00b0F",
              colors="white")

    # --- Wind barbs (green < 9kts, white >= 9kts per TJ's docs) ---
    wspeed = np.sqrt(d["u_kts"]**2 + d["v_kts"]**2)
    for t in range(ntimes):
        for k in range(ptop_idx):
            if ptot[t, k] < p_top_actual:
                break
            c = "#00ff55" if wspeed[t, k] < 9 else "white"
            ax.barbs(taus[t], ptot[t, k],
                     d["u_kts"][t, k], d["v_kts"][t, k],
                     length=6, linewidth=0.6, color=c,
                     barb_increments=dict(half=5, full=10, flag=50))

    # PBL top: not drawn — the paraglider markers already show usable ceiling

    # --- Freezing level: prominent 32°F isotherm ---
    # Already drawn as part of the temperature contours, but make the
    # 32°F line stand out with a thicker, labeled line
    cs_freeze = ax.contour(t_fine, p_levels_full, tc_smooth, levels=[32],
                           colors="cyan", linewidths=1.5, alpha=0.8)
    ax.clabel(cs_freeze, inline=True, fontsize=9, fmt="32\u00b0F",
              colors="cyan")

    # --- Paraglider crescent markers (soaring ceiling) ---
    hglider_p = d["hglider_p"]
    valid_h = (hglider_p > p_top_actual) & (hglider_p < p_bottom)
    ax.scatter(taus[valid_h], hglider_p[valid_h], s=500, color="blue",
               marker=WING_MARKER, zorder=5, edgecolors="darkblue",
               linewidths=0.8)

    # --- w* labels above chart, below title ---
    ax.text(-0.06, 1.02, "Climb\nm/s", ha="right", va="bottom",
            transform=ax.transAxes, fontsize=9, color="yellow",
            fontweight="bold")
    for t in range(ntimes):
        txt = f"{d['wstar'][t]:.1f}"
        x_frac = t / max(ntimes - 1, 1)
        ax.text(x_frac, 1.02, txt, ha="center", va="bottom",
                transform=ax.transAxes,
                fontsize=13, color="yellow", fontweight="bold")

    # --- Axis formatting ---
    # Set Y limits to actual data extent (avoids lavender gaps)
    ax.set_ylim(p_bottom, p_top_actual)
    ax.set_xlim(0, ntimes - 1)
    ax.margins(0)
    ax.set_xticks(taus)
    ax.set_xticklabels(time_labels, fontsize=10, color="white")
    ax.set_xlabel("Time", color="white", fontsize=11)

    # Left Y axis: pressure at round values (mb)
    p_round = np.array([950, 900, 850, 800, 750, 700, 650])
    p_ylim = ax.get_ylim()
    p_valid = (p_round >= min(p_ylim)) & (p_round <= max(p_ylim))
    ax.set_yticks(p_round[p_valid])
    ax.set_yticklabels([f"{int(p)}mb" for p in p_round[p_valid]],
                       fontsize=10, color="white")
    ax.set_ylabel("Pressure (mb)", color="white", fontsize=11)
    ax.tick_params(colors="white", labelsize=10)

    # Right Y axis: altitude at round values (feet ASL)
    ax2 = ax.twinx()
    ax2.set_ylim(ax.get_ylim())
    # Round altitude ticks: terrain elevation + every 1000ft above
    ter_ft = d["ter_ft"]
    first_tick = int(np.ceil(ter_ft / 1000) * 1000)
    ft_asl = np.arange(first_tick, 18001, 1000)
    # Convert feet ASL to pressure using surface reference
    p_for_ft = d["sfc_p"][0] - (ft_asl - ter_ft) / 32.0
    valid_ft = (p_for_ft >= min(p_ylim)) & (p_for_ft <= max(p_ylim))
    # Add terrain as the bottom tick
    ticks = np.concatenate([[d["sfc_p"][0]], p_for_ft[valid_ft]])
    labels = [f"{int(ter_ft)}'"] + [f"{int(f)}'" for f in ft_asl[valid_ft]]
    ax2.set_yticks(ticks)
    ax2.set_yticklabels(labels, fontsize=10, color="white")
    ax2.tick_params(colors="white", labelsize=10)

    # Title
    date_str = d["time_strings"][0][:10]
    from datetime import datetime as dt
    day_of_week = dt.strptime(date_str, "%Y-%m-%d").strftime("%a")
    ax.set_title(f"{day_of_week} {date_str} / {site_name}",
                 color="white", fontsize=12, fontweight="bold", pad=35)

    # --- Save ---
    output_dir = FilePath(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    out_path = output_dir / f"{date_str}_{site_name}_windgram.png"
    fig.savefig(out_path, dpi=dpi, bbox_inches="tight",
                facecolor=fig.get_facecolor())
    plt.close(fig)

    print(f"Saved: {out_path}")
    return str(out_path)


def render_batch(wrfout_path, sites_csv, output_dir=".", **kwargs):
    """Render windgrams for all sites in a CSV file.

    CSV format: name lat lon (space or comma separated, # for comments)
    """
    from pathlib import Path as P
    sites = P(sites_csv).read_text().strip().splitlines()
    count = 0
    for line in sites:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.replace(",", " ").split()
        if len(parts) >= 3:
            name, lat, lon = parts[0], float(parts[1]), float(parts[2])
            try:
                render_windgram(wrfout_path, lat, lon, name, output_dir, **kwargs)
                count += 1
            except Exception as e:
                print(f"WARNING: {name} failed: {e}")
    print(f"\nRendered {count} windgrams to {output_dir}/")


def main():
    parser = argparse.ArgumentParser(description="Render windgrams from WRF output")
    parser.add_argument("wrfout", help="Path to wrfout NetCDF file")

    # Single site mode
    parser.add_argument("--lat", type=float, help="Site latitude")
    parser.add_argument("--lon", type=float, help="Site longitude")
    parser.add_argument("--site", help="Site name")

    # Batch mode
    parser.add_argument("--sites", help="CSV file with sites (name lat lon)")

    parser.add_argument("--output-dir", default=".", help="Output directory")
    parser.add_argument("--p-top", type=float, default=None, help="Top pressure (mb)")
    parser.add_argument("--utc-offset", type=int, default=-7, help="UTC offset for local time")
    parser.add_argument("--start-hour", type=int, default=8, help="Earliest local hour")
    parser.add_argument("--dpi", type=int, default=100, help="Output DPI")
    args = parser.parse_args()

    kwargs = dict(p_top_mb=args.p_top, utc_offset=args.utc_offset,
                  start_hour=args.start_hour, dpi=args.dpi)

    if args.sites:
        render_batch(args.wrfout, args.sites, args.output_dir, **kwargs)
    elif args.lat and args.lon and args.site:
        render_windgram(args.wrfout, args.lat, args.lon, args.site,
                        args.output_dir, **kwargs)
    else:
        parser.error("Provide --sites CSV or --lat/--lon/--site")


if __name__ == "__main__":
    main()
