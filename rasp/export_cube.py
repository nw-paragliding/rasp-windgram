"""
Export a *soaring data cube* (Zarr v3) from a WRF wrfout file — the V2 data
product that serves both the map overlays (TOL / w* / BL-wind) and
click-anywhere windgrams in the browser from one chunked, edge-cacheable store
on R2.

Same soaring math as windgram._extract_site_data, computed over the WHOLE grid
instead of per site. Kept on the **native WRF Lambert Conformal grid** (no
resampling — @carbonplan/zarr-layer renders LCC directly), profiles capped to
the lowest LEVEL_CAP model levels (the soaring band, ~surface to ~6 km AGL).

Zarr v3 with **sharding**: few storage objects (good for R2) but fine-grained
range-readable inner chunks. 3D profile arrays are column-friendly (windgrams);
2D overlay arrays are plane-friendly (map layers).

Needs Python >= 3.11 (Zarr v3) and: numpy, netCDF4, zarr>=3, numcodecs, pyproj.

Usage:
    python3 -m rasp.export_cube wrfout_d02_... soaring.zarr --model hrrr --cycle 00
"""
import numpy as np
from netCDF4 import Dataset

from .soaring import calc_wstar, calc_hcrit, soaring_day_mask

LEVEL_CAP = 22          # lowest N model levels (~surface to ~6 km AGL / ~20,000 ft)
WRF_RADIUS = 6370000.0  # WRF spherical earth radius (m)


def _read_wrf(wrfout_path):
    """Read + derive soaring fields on the native WRF grid, plus projection."""
    nc = Dataset(wrfout_path)
    xlat = np.asarray(nc.variables["XLAT"][0])            # (Y, X)
    xlon = np.asarray(nc.variables["XLONG"][0])
    Y, X = xlat.shape
    times_raw = nc.variables["Times"][:]
    ntimes = times_raw.shape[0]
    hours = np.array([int("".join(c.decode() for c in times_raw[t])[11:13])
                      for t in range(ntimes)], dtype="f4")

    P = nc.variables["P"][:]; PB = nc.variables["PB"][:]
    ptot = (P + PB) / 100.0
    PH = nc.variables["PH"][:]; PHB = nc.variables["PHB"][:]
    z = 0.5 * (((PH + PHB) / 9.81)[:, :-1] + ((PH + PHB) / 9.81)[:, 1:])   # unstagger

    theta = nc.variables["T"][:] + 300.0
    tk = theta * (ptot / 1000.0) ** 0.286
    tc = tk - 273.15
    QV = nc.variables["QVAPOR"][:]
    es = 611.2 * np.exp(17.67 * tc / (tc + 243.5))
    e = np.maximum(QV * ptot * 100.0 / (0.622 + QV), 1e-10)
    td = 243.5 * np.log(e / 611.2) / (17.67 - np.log(e / 611.2))
    rh = np.clip(100.0 * e / es, 0, 100)

    U = nc.variables["U"][:]; V = nc.variables["V"][:]
    U = 0.5 * (U[:, :, :, :-1] + U[:, :, :, 1:])          # unstagger to mass points
    V = 0.5 * (V[:, :, :-1, :] + V[:, :, 1:, :])
    cosa = np.asarray(nc.variables["COSALPHA"][0]); sina = np.asarray(nc.variables["SINALPHA"][0])
    u_kt = (U * cosa - V * sina) * 1.94384
    v_kt = (U * sina + V * cosa) * 1.94384

    HFX = np.asarray(nc.variables["HFX"][:]); LH = np.asarray(nc.variables["LH"][:])
    PBLH = np.asarray(nc.variables["PBLH"][:]); T2 = np.asarray(nc.variables["T2"][:])
    ter = np.asarray(z[0, 0])

    wstar = np.stack([calc_wstar(HFX[t], LH[t], PBLH[t], T2[t]) for t in range(ntimes)])
    tol_ft = np.stack([calc_hcrit(wstar[t], ter, PBLH[t]) for t in range(ntimes)]) * 3.28084
    bl_idx = np.argmin(np.abs(z - (ter[None, None] + PBLH[:, None])), axis=1)   # (T,Y,X)
    ti, yy, xx = np.meshgrid(np.arange(ntimes), np.arange(Y), np.arange(X), indexing="ij")
    ubl = u_kt[ti, bl_idx, yy, xx]; vbl = v_kt[ti, bl_idx, yy, xx]

    proj = {k: float(nc.getncattr(k)) for k in
            ("DX", "DY", "TRUELAT1", "TRUELAT2", "STAND_LON", "MOAD_CEN_LAT")}
    nc.close()

    def f(a):
        return np.ma.filled(np.asarray(a), np.nan).astype("f4")

    d = {
        "xlat": f(xlat), "xlon": f(xlon), "hours": hours, "Y": Y, "X": X,
        "ntimes": ntimes, "nlev": ptot.shape[1], "proj": proj,
        "gh_ft": f(z * 3.28084), "tc": f(tc), "td": f(td), "rh": f(rh),
        "u_kt": f(u_kt), "v_kt": f(v_kt),
        "hfx": f(HFX), "lh": f(LH), "pblh_m": f(PBLH), "t2_k": f(T2),
        "sfcp_mb": f(ptot[:, 0]), "terrain_ft": f(ter * 3.28084),
        "tol_ft": f(tol_ft), "wstar_ms": f(wstar), "ubl_kt": f(ubl), "vbl_kt": f(vbl),
    }

    # Clip the cube to the target soaring day's daytime window (8a-8p local), so
    # v2's time slider + in-browser windgram don't include the previous evening
    # that a deep (e.g. 00z) cycle's lead-in hours would otherwise add. Mirrors
    # the windgram PNG renderer. Time-independent keys are left untouched.
    time_strings = ["".join(c.decode() for c in times_raw[t]) for t in range(ntimes)]
    keep = soaring_day_mask(time_strings)
    for k in ("hours", "gh_ft", "tc", "td", "rh", "u_kt", "v_kt", "hfx", "lh",
              "pblh_m", "t2_k", "sfcp_mb", "tol_ft", "wstar_ms", "ubl_kt", "vbl_kt"):
        d[k] = d[k][keep]
    d["ntimes"] = int(keep.sum())
    return d


def _projection(d):
    """1D projected x/y (m) + a pyproj CRS for the native WRF LCC grid."""
    import pyproj
    p = d["proj"]
    crs = pyproj.CRS.from_dict({
        "proj": "lcc", "lat_1": p["TRUELAT1"], "lat_2": p["TRUELAT2"],
        "lat_0": p["MOAD_CEN_LAT"], "lon_0": p["STAND_LON"], "R": WRF_RADIUS, "units": "m"})
    px, py = pyproj.Transformer.from_crs("EPSG:4326", crs, always_xy=True).transform(
        d["xlon"], d["xlat"])
    x = px[d["Y"] // 2, :].astype("f4")     # regular along a center row
    y = py[:, d["X"] // 2].astype("f4")     # regular along a center col
    return x, y, crs


def export_soaring_cube(wrfout_path, out_path, model="wrf", cycle="00", date=""):
    """Build a Zarr v3 (sharded, native LCC) soaring cube from a wrfout file."""
    import zarr

    d = _read_wrf(wrfout_path)
    x1d, y1d, crs = _projection(d)
    T, Y, X = d["ntimes"], d["Y"], d["X"]
    L = min(LEVEL_CAP, d["nlev"])
    zst = zarr.codecs.ZstdCodec(level=5)

    g = zarr.create_group(store=out_path, overwrite=True)

    def arr(name, data, dims, chunks, shards, attrs=None):
        a = g.create_array(name=name, shape=data.shape, dtype="f4",
                           chunks=chunks, shards=shards, compressors=[zst],
                           dimension_names=dims)
        a[:] = data
        if attrs:
            a.attrs.update(attrs)

    def coord(name, data, dims, attrs):
        a = g.create_array(name=name, shape=data.shape, dtype=str(data.dtype),
                           chunks=data.shape, dimension_names=dims)
        a[:] = data
        a.attrs.update(attrs)

    GM = {"grid_mapping": "spatial_ref", "coordinates": "lat lon"}
    p = d["proj"]
    cmi = g.create_array(name="spatial_ref", shape=(), dtype="i4")
    cmi.attrs.update({
        "grid_mapping_name": "lambert_conformal_conic",
        "standard_parallel": [p["TRUELAT1"], p["TRUELAT2"]],
        "longitude_of_central_meridian": p["STAND_LON"],
        "latitude_of_projection_origin": p["MOAD_CEN_LAT"],
        "false_easting": 0.0, "false_northing": 0.0,
        "semi_major_axis": WRF_RADIUS, "semi_minor_axis": WRF_RADIUS,
        "crs_wkt": crs.to_wkt()})

    # coords
    coord("x", x1d, ("x",), {"standard_name": "projection_x_coordinate", "units": "m", "axis": "X"})
    coord("y", y1d, ("y",), {"standard_name": "projection_y_coordinate", "units": "m", "axis": "Y"})
    coord("lon", d["xlon"], ("y", "x"), {"standard_name": "longitude", "units": "degrees_east"})
    coord("lat", d["xlat"], ("y", "x"), {"standard_name": "latitude", "units": "degrees_north"})
    coord("time", d["hours"], ("time",), {"standard_name": "time", "units": "hour (UTC) valid"})
    coord("level", np.arange(L, dtype="i4"), ("level",), {"long_name": "WRF model level (0=surface)"})

    coord("terrain_ft", d["terrain_ft"], ("y", "x"), {**GM, "units": "ft", "long_name": "terrain"})

    # 3D profiles (windgram columns) — sharded, column-friendly
    PROF_INNER, PROF_SHARD = (T, L, 4, 4), (T, L, 32, 32)
    for nm in ("gh_ft", "tc", "td", "rh", "u_kt", "v_kt"):
        arr(nm, d[nm][:, :L], ("time", "level", "y", "x"), PROF_INNER, PROF_SHARD, GM)
    # surface — sharded, column-friendly
    SFC_INNER, SFC_SHARD = (T, 4, 4), (T, 32, 32)
    for nm in ("hfx", "lh", "pblh_m", "t2_k", "sfcp_mb"):
        arr(nm, d[nm], ("time", "y", "x"), SFC_INNER, SFC_SHARD, GM)
    # 2D overlays (map layers) — sharded, plane-friendly (viewport tiles)
    OVR_INNER, OVR_SHARD = (1, 32, 32), (1, 128, 128)
    for nm in ("tol_ft", "wstar_ms", "ubl_kt", "vbl_kt"):
        arr(nm, d[nm], ("time", "y", "x"), OVR_INNER, OVR_SHARD, GM)

    g.attrs.update({"Conventions": "CF-1.8", "title": "PNW soaring data cube",
                    "model": model, "cycle": cycle, "date": date, "dx_km": p["DX"] / 1000.0})
    zarr.consolidate_metadata(g.store)
    return {"shape": {"time": T, "level": L, "y": Y, "x": X},
            "tol_ft_range": [float(np.nanmin(d["tol_ft"])), float(np.nanmax(d["tol_ft"]))]}


def main():
    import argparse, json
    ap = argparse.ArgumentParser(description="Export a Zarr v3 soaring cube from wrfout")
    ap.add_argument("wrfout"); ap.add_argument("out")
    ap.add_argument("--model", default="wrf"); ap.add_argument("--cycle", default="00")
    ap.add_argument("--date", default="")
    a = ap.parse_args()
    print(json.dumps(export_soaring_cube(a.wrfout, a.out, model=a.model,
                                         cycle=a.cycle, date=a.date)))


if __name__ == "__main__":
    main()
