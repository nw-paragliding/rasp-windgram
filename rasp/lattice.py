"""
Shared-lattice placement for WRF domains (the optional ``lattice:`` block).

Several independent WRF runs ("tiles") can be made to share ONE map projection
and ONE grid lattice, so that their grid points coincide wherever they overlap.
A later consumer can then write all tiles into a single statewide array
(e.g. an Icechunk/zarr store, chunk-aligned) without regridding.

Domain YAML::

    lattice:
      truelat1: 46.0
      truelat2: 49.0
      stand_lon: -120.5
      ref_lat: 47.5      # lattice origin: a mass point of every tile's finest grid
      ref_lon: -120.5

How the alignment works
-----------------------
1. All domains use the block's ``truelat1/truelat2/stand_lon`` (Lambert
   conformal), so every tile lives in the same projected (x, y) plane.

2. The outermost domain (d01) is shifted so the lattice origin falls exactly on
   one of its mass points.  In the shared projection we take the requested
   centre's offset from the origin and snap it so that the origin's d01 mass
   index is an integer.  WPS is then given ``ref_lat/ref_lon`` = the origin and
   ``ref_x/ref_y`` = that integer index.  The snapped centre differs from the
   requested one by at most dx/2 in each direction.

   ``ref_x/ref_y`` convention (verified in WPS v4.5 geogrid source):
   they are coordinates on the MASS (unstaggered) grid, mass point (i, j) sits
   at exactly (i, j) (``llxy_module.F: xytoll`` applies no offset for M and
   -0.5 for U/V/corner points), and the default when they are omitted is
   ``(e_we/2, e_sn/2)``, the centre of the 1..e_we-1 mass grid
   (``gridinfo_module.F``).  ``map_set``/``set_lc`` (``module_map_utils.F``)
   only use them to locate the projection pole (``polei = knowni - rsw*sin``);
   there is no range check, so a reference point outside the domain is
   accepted.  We therefore always use the lattice origin itself as the
   reference point (identical ``ref_lat/ref_lon`` in every tile, integer
   ``ref_x/ref_y`` that may lie outside the domain), so no tile depends on a
   lat/lon round-trip through our own projection code.

3. Nests keep WRF's rule: integer ``i_parent_start/j_parent_start`` and
   ``(e_we - 1) % ratio == 0``.  WPS places nest mass point k (1-based) at
   parent mass coordinate ``i_parent_start + (k - (r+1)/2) / r``
   (``llxy_module.F: find_known_latlon``), i.e. at
   ``parent point + (k - (r+1)/2) * dx/r``.  For an ODD ratio r, (r+1)/2 is an
   integer, so every nest mass point lies on the parent lattice refined by r,
   and the origin (a parent mass point) is itself a nest mass point.  By
   induction the finest grid of every tile is ``origin + m * dx_finest`` for
   integer m: tiles with the same finest dx share grid points exactly.  An even
   ratio shifts the nest by half a fine cell, so it is rejected with a
   lattice.

Without a ``lattice:`` block none of this runs and the namelists are unchanged.

The projection is the spherical Lambert conformal conic WPS uses
(``module_map_utils.F``: same cone formula, earth radius 6370 km).
"""

import math

EARTH_RADIUS_M = 6370000.0          # WPS/WRF EARTH_RADIUS_M

LATTICE_KEYS = ("truelat1", "truelat2", "stand_lon", "ref_lat", "ref_lon")


class LambertConformal:
    """Spherical Lambert conformal conic, northern hemisphere, as in WPS.

    ``forward`` returns metres relative to an origin (default: the pole-based
    frame shifted so that (origin_lat, origin_lon) is (0, 0)).
    """

    def __init__(self, truelat1, truelat2, stand_lon, origin_lat, origin_lon,
                 radius=EARTH_RADIUS_M):
        if truelat1 <= 0 or truelat2 <= 0:
            raise ValueError("lattice: only northern-hemisphere Lambert is supported")
        self.truelat1 = float(truelat1)
        self.truelat2 = float(truelat2)
        self.stand_lon = float(stand_lon)
        self.radius = float(radius)
        self.cone = lambert_cone(self.truelat1, self.truelat2)
        t1 = math.radians(self.truelat1)
        self._F = (math.cos(t1) * math.tan(math.pi / 4 + t1 / 2) ** self.cone
                   / self.cone)
        self._x0, self._y0 = 0.0, 0.0
        self._x0, self._y0 = self.forward(origin_lat, origin_lon)

    def _rho(self, lat):
        return (self.radius * self._F
                / math.tan(math.pi / 4 + math.radians(lat) / 2) ** self.cone)

    def forward(self, lat, lon):
        """(lat, lon) degrees -> (x, y) metres relative to the origin."""
        dlon = (lon - self.stand_lon + 180.0) % 360.0 - 180.0
        theta = self.cone * math.radians(dlon)
        rho = self._rho(lat)
        return rho * math.sin(theta) - self._x0, -rho * math.cos(theta) - self._y0

    def inverse(self, x, y):
        """(x, y) metres relative to the origin -> (lat, lon) degrees."""
        px, py = x + self._x0, y + self._y0
        rho = math.hypot(px, py)
        theta = math.atan2(px, -py)
        lat = math.degrees(2 * math.atan((self.radius * self._F / rho)
                                         ** (1.0 / self.cone)) - math.pi / 2)
        lon = self.stand_lon + math.degrees(theta / self.cone)
        lon = (lon + 180.0) % 360.0 - 180.0
        return lat, lon


def lambert_cone(truelat1, truelat2):
    """Cone factor exactly as WPS ``lc_cone`` computes it."""
    if abs(truelat1 - truelat2) > 0.1:
        t1, t2 = math.radians(truelat1), math.radians(truelat2)
        return ((math.log10(math.cos(t1)) - math.log10(math.cos(t2)))
                / (math.log10(math.tan(math.pi / 4 - abs(t1) / 2))
                   - math.log10(math.tan(math.pi / 4 - abs(t2) / 2))))
    return math.sin(math.radians(abs(truelat1)))


def parse_lattice(block):
    """Validate a ``lattice:`` block; returns a dict of the five floats."""
    if not isinstance(block, dict):
        raise ValueError("lattice: expected a mapping with keys "
                         + ", ".join(LATTICE_KEYS))
    unknown = sorted(set(block) - set(LATTICE_KEYS))
    missing = [k for k in LATTICE_KEYS if block.get(k) is None]
    if unknown:
        raise ValueError(f"lattice: unknown key(s) {unknown}; expected {list(LATTICE_KEYS)}")
    if missing:
        raise ValueError(f"lattice: missing key(s) {missing}")
    out = {k: float(block[k]) for k in LATTICE_KEYS}
    LambertConformal(out["truelat1"], out["truelat2"], out["stand_lon"],
                     out["ref_lat"], out["ref_lon"])   # validates the projection
    return out


def _round_half_up(v):
    return int(math.floor(v + 0.5))


def lattice_placement(config, domains):
    """Place a nest chain on the shared lattice.

    Args:
        config:  domain config with ``center_lat/center_lon`` and a parsed
                 ``lattice`` dict
        domains: list from ``compute_nest_chain`` (unchanged; nests are already
                 integer-placed in their parents)

    Returns a dict:
        ref_lat, ref_lon   lattice origin (WPS reference point)
        ref_x, ref_y       integer d01 mass index of the origin (may be outside)
        nominal_center     (lat, lon) requested
        snapped_center     (lat, lon) of the d01 mass-grid centre after snapping
        center_shift_m     (dx, dy) snapped - requested, metres, |.| <= dx/2
        origin_ij          per domain: (i, j) mass index of the origin in that
                           domain's grid (integers for odd ratios)
        fine_dx            finest-grid spacing (m)
        fine_offset        (i, j) of the finest grid's mass point 1 on the
                           statewide fine lattice whose (0, 0) is the origin;
                           i.e. fine mass point k sits at (fine_offset + k - 1)
    """
    lat = config["lattice"]
    proj = LambertConformal(lat["truelat1"], lat["truelat2"], lat["stand_lon"],
                            lat["ref_lat"], lat["ref_lon"])
    d01 = domains[0]
    dx = d01["dx"]
    xc, yc = proj.forward(config["center_lat"], config["center_lon"])
    # Mass coordinate of the domain centre is (e_we/2, e_sn/2); the origin sits
    # at centre + (0 - xc)/dx.  Snap that to an integer mass index.
    ref_x = _round_half_up(d01["e_we"] / 2.0 - xc / dx)
    ref_y = _round_half_up(d01["e_sn"] / 2.0 - yc / dx)
    xs = (d01["e_we"] / 2.0 - ref_x) * dx
    ys = (d01["e_sn"] / 2.0 - ref_y) * dx
    snapped = proj.inverse(xs, ys)

    origin_ij = [(float(ref_x), float(ref_y))]
    for d in domains[1:]:
        r = d["parent_grid_ratio"]
        if r % 2 == 0:
            raise ValueError(
                f"lattice: nest d{d['id']:02d} has even parent_grid_ratio {r}; "
                "mass points only stay on the lattice for odd ratios")
        pi_, pj = origin_ij[-1]
        origin_ij.append(((pi_ - d["i_parent_start"]) * r + (r + 1) / 2.0,
                          (pj - d["j_parent_start"]) * r + (r + 1) / 2.0))
    fi, fj = origin_ij[-1]
    return {
        "ref_lat": lat["ref_lat"],
        "ref_lon": lat["ref_lon"],
        "ref_x": ref_x,
        "ref_y": ref_y,
        "truelat1": lat["truelat1"],
        "truelat2": lat["truelat2"],
        "stand_lon": lat["stand_lon"],
        "nominal_center": (config["center_lat"], config["center_lon"]),
        "snapped_center": snapped,
        "center_shift_m": (xs - xc, ys - yc),
        "origin_ij": [(int(round(i)), int(round(j))) for i, j in origin_ij],
        "fine_dx": domains[-1]["dx"],
        "fine_offset": (int(round(1 - fi)), int(round(1 - fj))),
        "projection": proj,
    }


def fine_mass_points(placement, domains):
    """Projected (x, y) metres of the finest grid's mass points (1-D axes).

    Recomputes positions from WPS's own nest rule (parent coordinate
    ``i_parent_start + (k - (r+1)/2)/r``) rather than from ``origin_ij``, so it
    is an independent check of the alignment claim.
    """
    d01 = domains[0]
    dx = d01["dx"]

    def axis(n_key, start_key, ref):
        # Map each level's mass index -> d01 mass coordinate, then to metres.
        def to_parent(level, coord):
            for d in reversed(domains[1:level + 1]):
                r = d["parent_grid_ratio"]
                coord = d[start_key] + (coord - (r + 1) / 2.0) / r
            return coord
        last = len(domains) - 1
        n = domains[-1][n_key] - 1           # number of mass points
        return [(to_parent(last, k) - ref) * dx for k in range(1, n + 1)]

    return (axis("e_we", "i_parent_start", placement["ref_x"]),
            axis("e_sn", "j_parent_start", placement["ref_y"]))
