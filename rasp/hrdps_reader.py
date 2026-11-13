"""HRDPS → WPS intermediate files, bypassing ungrib.

ECCC's HRDPS continental run comes on a rotated lat-lon grid (GRIB2 grid
template 3.1), which this WPS build's ungrib does not read ("GRIB2 Unknown
Projection: 1"; it knows 0, 10, 20, 30, 40). Rather than regrid with another
tool, this module reads the per-field GRIB2 files with eccodes, samples them
onto a plain lat-lon box around the tile, and writes the version-5 WPS
intermediate format that metgrid consumes, exactly as ungrib would have.

Sampling is cheap and exact: the HRDPS grid is REGULAR in rotated coordinates,
so each target lat/lon is turned into rotated coordinates (the inverse of the
grid's rotation) and bilinearly interpolated there. Winds in the files are
relative to the rotated grid; they are turned to earth-relative with the local
angle of the rotated east axis, so metgrid sees IS_WIND_EARTH_REL = true.

Field naming follows the Datamart file names (TMP_ISBL_0850, TMP_AGL-2m,
PRES_Sfc, SOILW_DBS-0-10cm ...) and maps onto metgrid's names (TT, UU, VV,
RH, HGT, PSFC, PMSL, SKINTEMP, SOILHGT, SNOW, SNOWH, SMtttbbb, STtttbbb).
Surface-type fields carry the WPS level 200100.
"""
import math
import re
import struct
from datetime import datetime
from pathlib import Path

import numpy as np

SURFACE = 200100.0
EARTH_RADIUS_KM = 6371.229

# Datamart field name -> (metgrid name, units, description). Isobaric fields are
# handled by prefix; the level comes from the file name.
ISBL = {"TMP": ("TT", "K", "Temperature"), "HGT": ("HGT", "m", "Height"),
        "RH": ("RH", "%", "Relative Humidity"), "UGRD": ("UU", "m s-1", "U"), "VGRD": ("VV", "m s-1", "V")}
SFC = {
    "TMP_AGL-2m": ("TT", "K", "Temperature at 2 m"),
    "RH_AGL-2m": ("RH", "%", "Relative Humidity at 2 m"),
    "UGRD_AGL-10m": ("UU", "m s-1", "U at 10 m"),
    "VGRD_AGL-10m": ("VV", "m s-1", "V at 10 m"),
    "PRES_Sfc": ("PSFC", "Pa", "Surface Pressure"),
    "PRMSL_MSL": ("PMSL", "Pa", "Sea-level Pressure"),
    "HGT_Sfc": ("SOILHGT", "m", "Terrain field of source analysis"),
    "SKINT_Sfc": ("SKINTEMP", "K", "Skin temperature"),
    "SDWE_Sfc": ("SNOW", "kg m-2", "Water equivalent snow depth"),
    "SNOD_Sfc": ("SNOWH", "m", "Physical Snow Depth"),
    "SOILW_DBS-0-10cm": ("SM000010", "fraction", "Soil Moist 0-10 cm below ground"),
    "TSOIL_DBS-0-10cm": ("ST000010", "K", "Soil Temp 0-10 cm below ground"),
}
# metgrid counts only the soil layers METGRID.TBL names (SM000010, SM010040, ...),
# and real.exe insists on at least two. HRDPS publishes one usable layer (0-10
# cm; the 0-1 cm moisture and the "surface" soil temperature have no standard
# name), so the 0-10 cm values are carried down into a 10-40 cm layer: a uniform
# profile real.exe can interpolate Noah's four layers from. WRF's deep-soil
# temperature comes from geogrid's TMN regardless.
DEEP_LAYERS = (("SM000010", "SM010040", "Soil Moist 10-40 cm (copied from 0-10 cm: HRDPS has no deeper layer)"),
               ("ST000010", "ST010040", "Soil Temp 10-40 cm (copied from 0-10 cm: HRDPS has no deeper layer)"))


def add_deep_soil_layers(fields):
    """Add the 10-40 cm layers to a {(name, level): (slab, units, desc)} dict, in place."""
    for src, dst, desc in DEEP_LAYERS:
        if (src, SURFACE) in fields and (dst, SURFACE) not in fields:
            slab, units, _ = fields[(src, SURFACE)]
            fields[(dst, SURFACE)] = (slab.copy(), units, desc)
    return fields
_FNAME = re.compile(r"(\d{8})T(\d{2})Z_MSC_HRDPS_(.+)_RLatLon[\d.]+_PT(\d{3})H\.grib2$")


def classify(path):
    """(valid time, metgrid name, level Pa or SURFACE, units, desc) for a Datamart file; None if unused."""
    m = _FNAME.search(Path(path).name)
    if not m:
        return None
    ymd, cyc, field, fhr = m.groups()
    valid = datetime(int(ymd[:4]), int(ymd[4:6]), int(ymd[6:]), int(cyc)) + __import__("datetime").timedelta(hours=int(fhr))
    if field in SFC:
        name, units, desc = SFC[field]
        return valid, name, SURFACE, units, desc
    im = re.match(r"([A-Z]+)_ISBL_(\d{4})$", field)
    if im and im.group(1) in ISBL:
        name, units, desc = ISBL[im.group(1)]
        return valid, name, float(im.group(2)) * 100.0, units, desc
    return None


# ── rotated lat-lon geometry ────────────────────────────────────────────────
class RotatedGrid:
    """The HRDPS grid as eccodes describes it: regular in rotated coordinates."""

    def __init__(self, ni, nj, la1, lo1, di, dj, sp_lat, sp_lon, angle=0.0, uv_relative=True):
        self.ni, self.nj, self.la1, self.lo1, self.di, self.dj = ni, nj, la1, lo1, di, dj
        self.sp_lat, self.sp_lon, self.angle, self.uv_relative = sp_lat, sp_lon, angle, uv_relative
        # the rotated frame's north pole, in geographic coordinates
        self.pole_lat, self.pole_lon = -sp_lat, sp_lon

    @classmethod
    def from_gid(cls, gid):
        import eccodes as ec
        g = lambda k: ec.codes_get(gid, k)
        dj = float(g("jDirectionIncrementInDegrees"))
        if not int(g("jScansPositively")):
            dj = -dj
        return cls(int(g("Ni")), int(g("Nj")),
                   float(g("latitudeOfFirstGridPointInDegrees")), float(g("longitudeOfFirstGridPointInDegrees")),
                   float(g("iDirectionIncrementInDegrees")), dj,
                   float(g("latitudeOfSouthernPoleInDegrees")), float(g("longitudeOfSouthernPoleInDegrees")),
                   float(g("angleOfRotationInDegrees")) if ec.codes_is_defined(gid, "angleOfRotationInDegrees") else 0.0,
                   bool(int(g("uvRelativeToGrid"))) if ec.codes_is_defined(gid, "uvRelativeToGrid") else True)

    def to_rotated(self, lat, lon):
        """Geographic (deg, arrays) -> rotated (deg): the inverse of the grid's rotation."""
        a = math.radians(90.0 - self.pole_lat)
        lam = np.radians(lon - self.pole_lon)
        phi = np.radians(lat)
        x, y, z = np.cos(phi) * np.cos(lam), np.cos(phi) * np.sin(lam), np.sin(phi)
        # undo the tilt about y: to_geographic rotates by -a, so rotate by +a here
        x2 = x * math.cos(a) + z * math.sin(a)
        z2 = -x * math.sin(a) + z * math.cos(a)
        rlat = np.degrees(np.arcsin(np.clip(z2, -1, 1)))
        rlon = np.degrees(np.arctan2(y, x2))
        if self.angle:
            rlon = rlon - self.angle
        return rlat, rlon

    def to_geographic(self, rlat, rlon):
        a = -math.radians(90.0 - self.pole_lat)
        lam = np.radians(rlon + self.angle)
        phi = np.radians(rlat)
        x, y, z = np.cos(phi) * np.cos(lam), np.cos(phi) * np.sin(lam), np.sin(phi)
        x2 = x * math.cos(a) + z * math.sin(a)
        z2 = -x * math.sin(a) + z * math.cos(a)
        lat = np.degrees(np.arcsin(np.clip(z2, -1, 1)))
        lon = (np.degrees(np.arctan2(y, x2)) + self.pole_lon + 180.0) % 360.0 - 180.0
        return lat, lon

    def fractional_index(self, lat, lon):
        """(j, i) fractional grid indices of geographic points; outside -> beyond the array."""
        rlat, rlon = self.to_rotated(lat, lon)
        dlon = (rlon - self.lo1 + 180.0) % 360.0 - 180.0
        return (rlat - self.la1) / self.dj, dlon / self.di

    def east_axis_angle(self, lat, lon):
        """Angle (radians, CCW from true east) of the rotated east axis at each point."""
        rlat, rlon = self.to_rotated(lat, lon)
        lat0, lon0 = self.to_geographic(rlat, rlon)
        lat1, lon1 = self.to_geographic(rlat, rlon + 0.01)
        de = ((lon1 - lon0 + 180.0) % 360.0 - 180.0) * np.cos(np.radians(lat0))
        dn = lat1 - lat0
        return np.arctan2(dn, de)


def target_box(center_lat, center_lon, half_km=180.0, step=0.025):
    """A lat-lon box around the tile: the 200 km parent plus margin, 0.025 deg (~native)."""
    dlat = half_km / 110.57
    dlon = half_km / (111.32 * math.cos(math.radians(center_lat)))
    lat0 = math.floor((center_lat - dlat) / step) * step
    lon0 = math.floor((center_lon - dlon) / step) * step
    ny = int(math.ceil(2 * dlat / step)) + 1
    nx = int(math.ceil(2 * dlon / step)) + 1
    lats = lat0 + step * np.arange(ny)
    lons = lon0 + step * np.arange(nx)
    return lats, lons


# ── WPS intermediate writer (version 5, big-endian Fortran sequential) ──────
def _rec(payload):
    return struct.pack(">i", len(payload)) + payload + struct.pack(">i", len(payload))


def _str(s, n):
    return s.ljust(n)[:n].encode("ascii")


def write_slab(fh, hdate, xfcst, field, units, desc, xlvl, slab, lat0, lon0, dlat, dlon, source="HRDPS 2.5 km ECCC"):
    ny, nx = slab.shape
    fh.write(_rec(struct.pack(">i", 5)))
    fh.write(_rec(_str(hdate, 24) + struct.pack(">f", xfcst) + _str(source, 32) + _str(field, 9)
                  + _str(units, 25) + _str(desc, 46) + struct.pack(">f", xlvl) + struct.pack(">iii", nx, ny, 0)))
    fh.write(_rec(_str("SWCORNER", 8) + struct.pack(">fffff", lat0, lon0, dlat, dlon, EARTH_RADIUS_KM)))
    fh.write(_rec(struct.pack(">i", 1)))                       # IS_WIND_EARTH_REL = .TRUE.
    fh.write(_rec(np.ascontiguousarray(slab, dtype=">f4").tobytes()))


def write_intermediate(grib_dir, wps_dir, center_lat, center_lon, valid_times=None, prefix="FILE"):
    """Sample every usable field in grib_dir onto the tile's box and write FILE:<time> files.

    Returns the number of files written. valid_times (datetimes) restricts the
    output; None writes every valid time present.
    """
    import eccodes as ec
    from scipy.ndimage import map_coordinates

    files = sorted(Path(grib_dir).glob("*.grib2"))
    by_time = {}
    for f in files:
        c = classify(f)
        if c is None:
            continue
        valid = c[0]
        if valid_times is not None and valid not in valid_times:
            continue
        by_time.setdefault(valid, []).append((f,) + c[1:])
    if not by_time:
        raise RuntimeError(f"no HRDPS fields in {grib_dir}")

    lats, lons = target_box(center_lat, center_lon)
    LON, LAT = np.meshgrid(lons, lats)
    grid = None
    written = 0
    for valid in sorted(by_time):
        entries = by_time[valid]
        # read everything for this time, keyed so U/V pairs can be rotated together
        fields = {}
        for f, name, xlvl, units, desc in entries:
            with open(f, "rb") as fh:
                gid = ec.codes_grib_new_from_file(fh)
            if gid is None:
                raise RuntimeError(f"not a GRIB file: {f}")
            try:
                if grid is None:
                    grid = RotatedGrid.from_gid(gid)
                    fj, fi = grid.fractional_index(LAT, LON)
                    inside = (fj >= 0) & (fj <= grid.nj - 1) & (fi >= 0) & (fi <= grid.ni - 1)
                    if not inside.all():
                        raise RuntimeError("the tile's box reaches outside the HRDPS grid")
                    theta = grid.east_axis_angle(LAT, LON) if grid.uv_relative else None
                    print(f"  HRDPS grid: {grid.ni}x{grid.nj} rotated lat-lon, pole {grid.pole_lat:.2f}N {grid.pole_lon:.2f}E; "
                          f"box {lats[0]:.3f}..{lats[-1]:.3f}N {lons[0]:.3f}..{lons[-1]:.3f}E ({len(lons)}x{len(lats)}); "
                          f"winds {'grid' if grid.uv_relative else 'earth'}-relative")
                vals = np.asarray(ec.codes_get_values(gid), dtype=np.float64).reshape(grid.nj, grid.ni)
                if grid.dj < 0:
                    vals = vals[::-1, :]
            finally:
                ec.codes_release(gid)
            slab = map_coordinates(vals, [fj, fi], order=1, mode="nearest")
            fields[(name, xlvl)] = (slab, units, desc)
        if theta is not None:
            for (name, xlvl), (u, uu, ud) in list(fields.items()):
                if name != "UU" or ("VV", xlvl) not in fields:
                    continue
                v, vu, vd = fields[("VV", xlvl)]
                ue = u * np.cos(theta) - v * np.sin(theta)
                ve = u * np.sin(theta) + v * np.cos(theta)
                fields[("UU", xlvl)] = (ue, uu, ud)
                fields[("VV", xlvl)] = (ve, vu, vd)
        add_deep_soil_layers(fields)
        hdate = valid.strftime("%Y-%m-%d_%H:%M:%S")
        out = Path(wps_dir) / f"{prefix}:{valid.strftime('%Y-%m-%d_%H')}"
        with open(out, "wb") as fh:
            for (name, xlvl), (slab, units, desc) in sorted(fields.items(), key=lambda kv: (kv[0][0], -kv[0][1])):
                write_slab(fh, hdate, 0.0, name, units, desc, xlvl, slab, float(lats[0]), float(lons[0]), 0.025, 0.025)
        nlev = len({x for (n, x) in fields if n == "TT" and x != SURFACE})
        print(f"  {out.name}: {len(fields)} slabs, {nlev} pressure levels")
        written += 1
    return written
