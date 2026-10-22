#!/usr/bin/env python3
"""
ab_compare.py — compare two pipeline runs (A vs B) of the SAME domain, sites and
cycle that differ only in the input model (RRFS_MIGRATION.md, section 5).

Reads each run's soaring cube (output/soaring.zarr) and windgram PNGs and writes
    <out>/compare.md          per-site + pooled tables (also printed to stdout)
    <out>/montage_<site>.png  A and B windgrams side by side
    <out>/diffmap_tol.png     A, B and B-A maps of the soaring ceiling at peak hour
    <out>/summary.json        machine-readable numbers

Usage:
    python3 scripts/ab_compare.py --a out/nam --b out/rrfs --labels NAM RRFS \
        --sites examples/phoenix-sites.csv --utc-offset -7 --out compare/

The numbers are an aid to a human review, not an automatic verdict.
Needs numpy, zarr>=3 (the "cube" extra) and matplotlib.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

AFTERNOON = range(12, 18)        # local hours of the thermal peak (12:00-17:59)
METRICS = [
    # key            label                 unit    circular
    ("bl_top_ft",    "BL top (AGL)",       "ft",   False),
    ("wstar_fpm",    "w*",                 "fpm",  False),
    ("tol_ft",       "Soaring ceiling",    "ft",   False),
    ("blwind_kt",    "BL wind speed",      "kt",   False),
    ("blwind_dir",   "BL wind dir",        "deg",  True),
    ("t2_f",         "2 m temperature",    "F",    False),
    ("lcl_ft",       "Sfc LCL (AGL)",      "ft",   False),
    ("hfx",          "Sensible heat flux", "W/m2", False),
]


# ── loading ──────────────────────────────────────────────────────────────────

def load_sites(path):
    sites = []
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.replace(",", " ").split()
        if len(parts) >= 3:
            sites.append((parts[0], float(parts[1]), float(parts[2])))
    return sites


def find_cube(run_dir):
    p = Path(run_dir)
    for cand in (p, p / "soaring.zarr"):
        if (cand / "zarr.json").exists():
            return cand
    hits = sorted(p.rglob("zarr.json"))
    return hits[0].parent if hits else None


def open_cube(run_dir):
    path = find_cube(run_dir)
    if path is None:
        return None
    import zarr
    return zarr.open_group(str(path), mode="r")


def nearest(g, lat, lon):
    lat2 = np.asarray(g["lat"][:])
    lon2 = np.asarray(g["lon"][:])
    d = (lat2 - lat) ** 2 + ((lon2 - lon) * np.cos(np.radians(lat))) ** 2
    iy, ix = np.unravel_index(int(np.argmin(d)), d.shape)
    return int(iy), int(ix), float(lat2[iy, ix]), float(lon2[iy, ix])


def site_series(g, iy, ix):
    ubl = np.asarray(g["ubl_kt"][:, iy, ix])
    vbl = np.asarray(g["vbl_kt"][:, iy, ix])
    tc0 = np.asarray(g["tc"][:, 0, iy, ix])
    td0 = np.asarray(g["td"][:, 0, iy, ix])
    return {
        "time": np.asarray(g["time"][:]),                                  # hours UTC
        "bl_top_ft": np.asarray(g["pblh_m"][:, iy, ix]) * 3.28084,
        "wstar_fpm": np.asarray(g["wstar_ms"][:, iy, ix]) * 196.85,
        "tol_ft": np.asarray(g["tol_ft"][:, iy, ix]),
        "blwind_kt": np.hypot(ubl, vbl),
        "blwind_dir": (np.degrees(np.arctan2(-ubl, -vbl)) + 360.0) % 360.0,  # from-direction
        "t2_f": np.asarray(g["t2_k"][:, iy, ix]) * 9.0 / 5.0 - 459.67,
        "lcl_ft": np.maximum(tc0 - td0, 0.0) * 125.0 * 3.28084,            # Espy approximation
        "hfx": np.asarray(g["hfx"][:, iy, ix]),
        "terrain_ft": float(g["terrain_ft"][iy, ix]),
    }


# ── statistics ───────────────────────────────────────────────────────────────

def delta(a, b, circular):
    d = b - a
    if circular:
        d = (d + 180.0) % 360.0 - 180.0
    return d


def stats(d):
    d = d[np.isfinite(d)]
    if d.size == 0:
        return {"n": 0, "median_abs": None, "p90_abs": None, "bias": None}
    return {"n": int(d.size),
            "median_abs": float(np.median(np.abs(d))),
            "p90_abs": float(np.percentile(np.abs(d), 90)),
            "bias": float(np.mean(d))}


def fmt(x, nd=0):
    if x is None or (isinstance(x, float) and not np.isfinite(x)):
        return "—"
    return f"{x:.{nd}f}"


def fmt_signed(x, nd=0):
    if x is None or (isinstance(x, float) and not np.isfinite(x)):
        return "—"
    return f"{x:+.{nd}f}"


# ── figures ──────────────────────────────────────────────────────────────────

def montage(a_dir, b_dir, site, labels, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import matplotlib.image as mpimg
    pa = sorted(Path(a_dir).rglob(f"*_{site}_windgram.png"))
    pb = sorted(Path(b_dir).rglob(f"*_{site}_windgram.png"))
    if not pa or not pb:
        return None
    ia, ib = mpimg.imread(pa[-1]), mpimg.imread(pb[-1])
    h = max(ia.shape[0], ib.shape[0])
    fig, axes = plt.subplots(1, 2, figsize=(2 * ia.shape[1] / 100.0, h / 100.0 + 0.5), dpi=100)
    for ax, img, lab in zip(axes, (ia, ib), labels):
        ax.imshow(img)
        ax.set_title(f"{lab} — {site}", fontsize=12)
        ax.axis("off")
    fig.tight_layout()
    path = Path(out) / f"montage_{site}.png"
    fig.savefig(path)
    plt.close(fig)
    return path


def diffmap(ga, gb, labels, utc_offset, out, peak_local=14):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    ta = np.asarray(ga["time"][:]); tb = np.asarray(gb["time"][:])
    common = np.intersect1d(ta, tb)
    if common.size == 0:
        return None, None
    local = (common + utc_offset) % 24
    k = int(np.argmin(np.abs(local - peak_local)))
    hour = common[k]
    ia = int(np.where(ta == hour)[0][0]); ib = int(np.where(tb == hour)[0][0])
    A = np.asarray(ga["tol_ft"][ia]); B = np.asarray(gb["tol_ft"][ib])
    if A.shape != B.shape:
        return None, None
    D = B - A
    vmax = float(np.nanpercentile(np.abs(D), 98)) or 1.0
    lo = float(np.nanpercentile(np.concatenate([A.ravel(), B.ravel()]), 2))
    hi = float(np.nanpercentile(np.concatenate([A.ravel(), B.ravel()]), 98))
    fig, axes = plt.subplots(1, 3, figsize=(15, 4.6), dpi=100)
    for ax, fld, lab in zip(axes[:2], (A, B), labels):
        im = ax.imshow(fld, origin="lower", vmin=lo, vmax=hi, cmap="viridis")
        ax.set_title(f"{lab}: soaring ceiling (ft) @ {int(local[k]):02d}:00 local")
        ax.axis("off")
    fig.colorbar(im, ax=axes[:2].tolist(), shrink=0.8, label="ft MSL")
    im2 = axes[2].imshow(D, origin="lower", vmin=-vmax, vmax=vmax, cmap="RdBu_r")
    axes[2].set_title(f"{labels[1]} − {labels[0]} (ft)")
    axes[2].axis("off")
    fig.colorbar(im2, ax=axes[2], shrink=0.8, label="ft")
    path = Path(out) / "diffmap_tol.png"
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    grid = {"hour_local": int(local[k]),
            "tol_ft": stats(D.ravel()),
            "wstar_fpm": stats((np.asarray(gb["wstar_ms"][ib]) - np.asarray(ga["wstar_ms"][ia])).ravel() * 196.85)}
    return path, grid


# ── main ─────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Compare two windgram pipeline runs (A vs B)")
    ap.add_argument("--a", required=True, help="run A output dir (contains soaring.zarr + PNGs)")
    ap.add_argument("--b", required=True, help="run B output dir")
    ap.add_argument("--labels", nargs=2, default=["A", "B"])
    ap.add_argument("--sites", required=True, help="sites CSV (name lat lon)")
    ap.add_argument("--utc-offset", type=int, default=-7)
    ap.add_argument("--out", default="compare")
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    la, lb = args.labels
    sites = load_sites(args.sites)
    ga, gb = open_cube(args.a), open_cube(args.b)

    md = [f"# A/B comparison: {la} vs {lb}", ""]
    summary = {"labels": args.labels, "sites": {}, "pooled": {}, "grid": None}

    for lab, g, d in ((la, ga, args.a), (lb, gb, args.b)):
        if g is None:
            md.append(f"- **{lab}**: `{d}` — no soaring cube found (PNG montages only)")
        else:
            at = dict(g.attrs)
            shp = {k: int(g[k].shape[0]) for k in ("time",)}
            md.append(f"- **{lab}**: `{d}` — model `{at.get('model')}`, cycle `{at.get('date')} {at.get('cycle')}z`, "
                      f"dx {at.get('dx_km')} km, {shp['time']} hours, grid {g['lat'].shape[0]}×{g['lat'].shape[1]}")
    md.append("")

    pooled = {m[0]: [] for m in METRICS}
    if ga is not None and gb is not None:
        same_grid = ga["lat"].shape == gb["lat"].shape
        md.append(f"Grids {'identical' if same_grid else 'DIFFER'}; afternoon = {AFTERNOON.start}:00–{AFTERNOON.stop - 1}:59 local "
                  f"(UTC{args.utc_offset:+d}). Δ = {lb} − {la}.")
        md.append("")
        md.append("## Afternoon summary per site")
        md.append("")
        hdr = "| Site | terrain ft | " + " | ".join(f"{lab} med\\|Δ\\| / bias ({u})" for _, lab, u, _ in METRICS) + " |"
        md.append(hdr)
        md.append("|" + "---|" * (2 + len(METRICS)))
        hourly_blocks = []
        for name, lat, lon in sites:
            iya, ixa, plat, plon = nearest(ga, lat, lon)
            iyb, ixb, _, _ = nearest(gb, lat, lon)
            sa, sb = site_series(ga, iya, ixa), site_series(gb, iyb, ixb)
            common, ia, ib = np.intersect1d(sa["time"], sb["time"], return_indices=True)
            local = (common + args.utc_offset) % 24
            aft = np.isin(local, list(AFTERNOON))
            row = [name, f"{sa['terrain_ft']:.0f}"]
            site_stats = {}
            for key, lab, unit, circ in METRICS:
                d = delta(sa[key][ia], sb[key][ib], circ)
                s = stats(d[aft])
                site_stats[key] = s
                pooled[key].append(d[aft])
                row.append(f"{fmt(s['median_abs'])} / {fmt_signed(s['bias'])}")
            md.append("| " + " | ".join(row) + " |")
            summary["sites"][name] = {"grid_point": [plat, plon], "afternoon": site_stats}

            # hourly table
            blk = [f"### {name} ({lat:.3f}, {lon:.3f}; grid point {plat:.3f}, {plon:.3f}; terrain {sa['terrain_ft']:.0f} ft)", ""]
            blk.append(f"| local | BL top {la}/{lb} ft | w* {la}/{lb} fpm | ceiling {la}/{lb} ft | BL wind {la}/{lb} | T2 {la}/{lb} F | HFX {la}/{lb} |")
            blk.append("|---|---|---|---|---|---|---|")
            for k in range(common.size):
                a_, b_ = ia[k], ib[k]
                blk.append(
                    f"| {int(local[k]):02d}:00 | {sa['bl_top_ft'][a_]:.0f} / {sb['bl_top_ft'][b_]:.0f} "
                    f"| {sa['wstar_fpm'][a_]:.0f} / {sb['wstar_fpm'][b_]:.0f} "
                    f"| {sa['tol_ft'][a_]:.0f} / {sb['tol_ft'][b_]:.0f} "
                    f"| {sa['blwind_kt'][a_]:.0f}kt@{sa['blwind_dir'][a_]:03.0f} / {sb['blwind_kt'][b_]:.0f}kt@{sb['blwind_dir'][b_]:03.0f} "
                    f"| {sa['t2_f'][a_]:.0f} / {sb['t2_f'][b_]:.0f} "
                    f"| {sa['hfx'][a_]:.0f} / {sb['hfx'][b_]:.0f} |")
            blk.append("")
            hourly_blocks.append("\n".join(blk))

        md.append("")
        md.append("## Pooled over all sites (afternoon)")
        md.append("")
        md.append("| Metric | n | median \\|Δ\\| | p90 \\|Δ\\| | bias |")
        md.append("|---|---|---|---|---|")
        for key, lab, unit, _ in METRICS:
            s = stats(np.concatenate(pooled[key])) if pooled[key] else stats(np.array([]))
            summary["pooled"][key] = s
            md.append(f"| {lab} ({unit}) | {s['n']} | {fmt(s['median_abs'])} | {fmt(s['p90_abs'])} | {fmt_signed(s['bias'])} |")
        md.append("")

        if same_grid:
            path, grid = diffmap(ga, gb, args.labels, args.utc_offset, out)
            if grid:
                summary["grid"] = grid
                md.append(f"## Whole inner grid at {grid['hour_local']:02d}:00 local")
                md.append("")
                md.append(f"- soaring ceiling: median |Δ| {fmt(grid['tol_ft']['median_abs'])} ft, bias {fmt_signed(grid['tol_ft']['bias'])} ft")
                md.append(f"- w*: median |Δ| {fmt(grid['wstar_fpm']['median_abs'])} fpm, bias {fmt_signed(grid['wstar_fpm']['bias'])} fpm")
                md.append(f"- map: `{path.name}`")
                md.append("")

        md.append("## Hourly detail")
        md.append("")
        md.extend(hourly_blocks)

    md.append("## Windgram montages")
    md.append("")
    for name, _, _ in sites:
        p = montage(args.a, args.b, name, args.labels, out)
        md.append(f"- {name}: `{p.name}`" if p else f"- {name}: (PNG missing in one run)")
    md.append("")

    text = "\n".join(md)
    (out / "compare.md").write_text(text)
    (out / "summary.json").write_text(json.dumps(summary, indent=2, default=float))
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
