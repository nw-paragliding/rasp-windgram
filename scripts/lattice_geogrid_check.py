"""Check that shared-lattice tiles really share grid points after geogrid.

    # 1. write one domain YAML + namelist.wps per Washington tile
    python scripts/lattice_geogrid_check.py gen  work/  [--geog-res RES]
    # 2. run geogrid.exe in each work/<tile>/ (see the temporary CI workflow)
    # 3. compare XLAT_M/XLONG_M of every overlapping pair of geo_em.d02.nc
    python scripts/lattice_geogrid_check.py check work/

``gen`` records each tile's lattice placement in work/<tile>/lattice.json.
Mass point (i, j) (1-based) of a tile's dNN grid is lattice point
``(i, j) - origin_ij[NN-1]`` (the origin is lattice (0, 0)), so shared points
are found by index arithmetic, not by nearest-neighbour search. Both the 4 km
d01 and the 1.33 km d02 lattices are checked.
"""

import argparse
import itertools
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

LATTICE = {"truelat1": 46.0, "truelat2": 49.0, "stand_lon": -120.5,
           "ref_lat": 47.5, "ref_lon": -120.5}
TILES = {
    "issaquah": (47.22, -121.80),
    "wenatchee": (47.22, -120.59),
    "skykomish": (48.03, -121.80),
    "chelan": (48.03, -120.59),
    "baker": (48.84, -121.80),
    "methow": (48.84, -120.59),
    "waterville": (47.72, -119.45),
}


def gen(work, geog_res):
    from rasp.namelist_generator import generate_namelists
    for name, (lat, lon) in TILES.items():
        d = Path(work) / name
        d.mkdir(parents=True, exist_ok=True)
        lines = [f"name: {name}", "model: nam", f"center_lat: {lat}",
                 f"center_lon: {lon}", "outer_dx_km: 4.0", "target_dx_km: 1.33",
                 "inner_extent_km: 120", "nest_ratio: 3",
                 f"geog_data_res: {geog_res}", "lattice:"]
        lines += [f"  {k}: {v}" for k, v in LATTICE.items()]
        (d / "domain.yaml").write_text("\n".join(lines) + "\n")
        r = generate_namelists(d / "domain.yaml", "2026-10-21", "12",
                               output_dir=d, geog_path="/mnt/geog")
        lp = r["lattice"]
        (d / "lattice.json").write_text(json.dumps({
            k: lp[k] for k in ("ref_x", "ref_y", "origin_ij", "fine_offset",
                               "snapped_center", "fine_dx")}))


def check(work, tol):
    import numpy as np
    import xarray as xr

    worst = 0.0
    pairs = 0
    for dom in (1, 2):
        grids = {}
        for name in TILES:
            d = Path(work) / name
            ds = xr.open_dataset(d / f"geo_em.d{dom:02d}.nc")
            lp = json.loads((d / "lattice.json").read_text())
            oi, oj = lp["origin_ij"][dom - 1]
            # mass point (1, 1) of this grid is lattice point (1 - oi, 1 - oj)
            grids[name] = (ds["XLAT_M"][0].values.astype("f8"),
                           ds["XLONG_M"][0].values.astype("f8"), (1 - oi, 1 - oj))
            ds.close()
        print(f"\nd{dom:02d}  {'pair':24s} {'shared pts':>10s} {'max|dlat|':>10s} {'max|dlon|':>10s}")
        for a, b in itertools.combinations(TILES, 2):
            la, oa, (ia, ja) = grids[a]
            lb, ob, (ib, jb) = grids[b]
            # lattice index ranges [offset, offset + n - 1] (arrays are [j, i])
            i0, i1 = max(ia, ib), min(ia + la.shape[1], ib + lb.shape[1]) - 1
            j0, j1 = max(ja, jb), min(ja + la.shape[0], jb + lb.shape[0]) - 1
            if i0 > i1 or j0 > j1:
                continue
            pairs += 1
            sa = np.s_[j0 - ja:j1 - ja + 1, i0 - ia:i1 - ia + 1]
            sb = np.s_[j0 - jb:j1 - jb + 1, i0 - ib:i1 - ib + 1]
            dlat = np.abs(la[sa] - lb[sb]).max()
            dlon = np.abs(oa[sa] - ob[sb]).max()
            worst = max(worst, dlat, dlon)
            print(f"     {a + '/' + b:24s} {la[sa].size:10d} {dlat:10.2e} {dlon:10.2e}")
            # Control: B shifted by one cell must NOT match.
            if i1 - ib + 2 <= lb.shape[1]:
                sb1 = np.s_[j0 - jb:j1 - jb + 1, i0 - ib + 1:i1 - ib + 2]
                assert np.abs(oa[sa] - ob[sb1]).max() > 10 * tol, "control failed"
    print(f"\n{pairs} overlapping pairs (d01 + d02); worst |dlat|,|dlon| = "
          f"{worst:.2e} deg (tolerance {tol:g})")
    if pairs == 0 or worst > tol:
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen")
    g.add_argument("work")
    g.add_argument("--geog-res", default="gmted2010_30s+modis_30s_lake+lowres")
    c = sub.add_parser("check")
    c.add_argument("work")
    c.add_argument("--tol", type=float, default=1e-4)
    a = ap.parse_args()
    if a.cmd == "gen":
        gen(a.work, a.geog_res)
    else:
        check(a.work, a.tol)


if __name__ == "__main__":
    main()
