"""HRDPS reader: rotated-grid geometry and the WPS intermediate format (no eccodes needed)."""
import struct
from datetime import datetime
from io import BytesIO

import numpy as np

from rasp.hrdps_reader import RotatedGrid, add_deep_soil_layers, classify, target_box, write_slab, SURFACE

# The continental grid as read from a 2026-11-13 file.
GRID = RotatedGrid(2540, 1290, -12.302501, 345.17878, 0.0225, 0.0225, -36.08852, 245.305142)


def test_first_grid_point_matches_eccc_docs():
    lat, lon = GRID.to_geographic(np.array([GRID.la1]), np.array([GRID.lo1]))
    assert abs(lat[0] - 39.6) < 0.1 and abs(lon[0] + 133.6) < 0.1      # docs: 39N 134W


def test_rotation_round_trip_and_indices():
    lat, lon = np.array([47.22, 49.9, 41.9]), np.array([-121.80, -117.3, -122.5])
    rlat, rlon = GRID.to_rotated(lat, lon)
    back = GRID.to_geographic(rlat, rlon)
    assert np.allclose(back[0], lat, atol=1e-6) and np.allclose(back[1], lon, atol=1e-6)
    fj, fi = GRID.fractional_index(lat, lon)
    assert ((fj > 0) & (fj < GRID.nj - 1) & (fi > 0) & (fi < GRID.ni - 1)).all()


def test_east_axis_angle_is_small_near_the_central_meridian():
    th = GRID.east_axis_angle(np.array([47.22]), np.array([-121.80]))
    assert 0 < np.degrees(th[0]) < 10


def test_classify_field_names():
    assert classify("20261113T06Z_MSC_HRDPS_TMP_ISBL_0850_RLatLon0.0225_PT012H.grib2") == \
        (datetime(2026, 11, 13, 18), "TT", 85000.0, "K", "Temperature")
    assert classify("20261113T06Z_MSC_HRDPS_SOILW_DBS-0-10cm_RLatLon0.0225_PT012H.grib2")[1:3] == ("SM000010", SURFACE)
    assert classify("20261113T06Z_MSC_HRDPS_SPFH_ISBL_0850_RLatLon0.0225_PT012H.grib2") is None


def test_target_box_covers_the_parent_with_margin():
    lats, lons = target_box(47.22, -121.80)
    assert lats[0] < 47.22 - 1.5 and lats[-1] > 47.22 + 1.5
    assert lons[0] < -121.80 - 2.0 and lons[-1] > -121.80 + 2.0
    assert abs((lats[1] - lats[0]) - 0.025) < 1e-9


def test_write_slab_is_a_version_5_record_sequence():
    slab = np.arange(12, dtype=float).reshape(3, 4)          # ny=3, nx=4
    buf = BytesIO()
    write_slab(buf, "2026-11-13_18:00:00", 0.0, "TT", "K", "Temperature", 85000.0, slab, 45.0, -124.0, 0.025, 0.025)
    b = buf.getvalue(); pos = 0; recs = []
    while pos < len(b):
        n = struct.unpack(">i", b[pos:pos + 4])[0]
        assert struct.unpack(">i", b[pos + 4 + n:pos + 8 + n])[0] == n
        recs.append(b[pos + 4:pos + 4 + n]); pos += 8 + n
    assert struct.unpack(">i", recs[0])[0] == 5
    h = recs[1]
    assert h[:24].decode().strip() == "2026-11-13_18:00:00" and h[60:69].decode().strip() == "TT"
    xlvl, nx, ny, iproj = struct.unpack(">fiii", h[140:156])
    assert (xlvl, nx, ny, iproj) == (85000.0, 4, 3, 0)
    assert recs[2][:8] == b"SWCORNER" and struct.unpack(">i", recs[3])[0] == 1
    assert np.array_equal(np.frombuffer(recs[4], dtype=">f4").reshape(3, 4), slab)


def test_deep_soil_layers_are_copied_from_the_shallow_ones():
    sm = np.full((2, 2), 0.3); st = np.full((2, 2), 280.0)
    fields = {("SM000010", SURFACE): (sm, "fraction", "x"), ("ST000010", SURFACE): (st, "K", "y"), ("TT", 85000.0): (st, "K", "z")}
    add_deep_soil_layers(fields)
    assert np.array_equal(fields[("SM010040", SURFACE)][0], sm) and np.array_equal(fields[("ST010040", SURFACE)][0], st)
    assert sum(1 for n, _ in fields if n.startswith("SM")) == 2 and sum(1 for n, _ in fields if n.startswith("ST")) == 2
    assert classify("20261113T06Z_MSC_HRDPS_SOILW_DBS-0-1cm_RLatLon0.0225_PT012H.grib2") is None
