"""The blipspot table (rasp.blipspot) written beside each windgram."""
import json
import math

import numpy as np
import pytest

from rasp.blipspot import UNITS, build_blipspot, BSRATIO_LIMIT
from rasp.windgram import _extract_site_data, render_windgram

import synthetic_wrfout as syn


@pytest.fixture(scope="module")
def wrfout(tmp_path_factory):
    return syn.write_synthetic_wrfout(tmp_path_factory.mktemp("wrf") / "wrfout_d02_test.nc")


@pytest.fixture(scope="module")
def rendered(wrfout, tmp_path_factory):
    out = tmp_path_factory.mktemp("out")
    png = render_windgram(wrfout, syn.SITE_LAT, syn.SITE_LON, "Synth", str(out),
                          utc_offset=syn.UTC_OFFSET, start_hour=8, model_name="NAM")
    blip_path = out / "2026-10-27_Synth_blipspot.json"
    return png, blip_path


def test_json_written_beside_png(rendered):
    png, blip_path = rendered
    assert png.endswith("2026-10-27_Synth_windgram.png")
    assert blip_path.exists()
    text = blip_path.read_text()
    assert "NaN" not in text and "Infinity" not in text      # strict JSON only
    blip = json.loads(text)
    assert blip["schema"] == 1
    assert blip["site"] == "Synth" and blip["model"] == "nam"
    assert blip["date"] == "2026-10-27" and blip["utc_offset"] == -7
    # the chart's hours: 8a-8p local
    assert blip["hours_local"] == list(range(8, 21))
    assert len(blip["valid_utc"]) == 13 and blip["valid_utc"][0] == "2026-10-27_15:00:00"
    # every row the synthetic wrfout can feed is present, each with a unit
    assert set(blip["params"]) == set(UNITS)
    assert set(blip["units"]) == set(blip["params"])
    for key, vals in blip["params"].items():
        assert len(vals) == 13, key
    # the renderer takes the first mass level as terrain; the synthetic layers
    # are 14 mb (~120 m) thick, so that level sits ~60 m above the 400 m ground
    assert 0 < blip["terrain_ft"] - syn.TER_M * 3.28084 < 220


def test_rows_match_the_synthetic_day(rendered):
    blip = json.loads(rendered[1].read_text())
    P = blip["params"]
    hours = blip["hours_local"]
    ter_ft = blip["terrain_ft"]
    for i, hl in enumerate(hours):
        # BL top = terrain + depth, depth = PBLH
        assert P["bl_top_ft"][i] == pytest.approx(ter_ft + P["bl_depth_ft"][i], abs=1)
        assert P["bl_depth_ft"][i] == pytest.approx(syn.pblh_m(hl) * 3.28084, abs=2)
        # W* from the Deardorff formula on the same inputs
        hfx = syn.hfx_wm2(hl); lh = 0.4 * max(hfx, 0.0); t2 = syn.sfc_temp_c(hl) + 273.15
        vhf = max(hfx + 0.000245268 * t2 * lh, 0.0)
        wstar = ((9.81 / t2) * (vhf / 1200.0) * syn.pblh_m(hl)) ** (1 / 3) if vhf > 0 else 0.0
        assert P["wstar_fpm"][i] == pytest.approx(wstar * 196.85, abs=max(2, 0.02 * wstar * 196.85))
        # surface heating, 2 m temperature straight from the surface fields
        assert P["sfc_heating_wm2"][i] == pytest.approx(hfx, abs=1)
        assert P["t2_f"][i] == pytest.approx(syn.sfc_temp_c(hl) * 1.8 + 32, abs=1)
        # lowest-level wind from the synthetic profile at that level's height AGL
        # (u = 2 + 9*zagl/3000 m/s, v = 1.5 m/s -> ~5 kt from ~235 deg)
        zagl_m = blip["levels_agl_ft"]["sfc"] / 3.28084
        u0, v0 = 2.0 + 9.0 * zagl_m / 3000.0, 1.5
        assert P["sfc_wind_kt"][i] == round(math.hypot(u0, v0) * 1.94384)
        assert P["sfc_wind_dir"][i] == pytest.approx((270 - math.degrees(math.atan2(v0, u0))) % 360, abs=1)
        assert P["wind10m_kt"][i] == round(0.8 * math.hypot(u0, v0) * 1.94384)   # U10/V10 = 0.8 x level 0
        # soaring heights are ordered: hcrit AGL within the BL, cloud-limited <= dry
        assert 0 <= P["hcrit_agl_ft"][i] <= P["bl_depth_ft"][i] + 1
        assert P["hcrit_ft"][i] == pytest.approx(ter_ft + P["hcrit_agl_ft"][i], abs=1)
        assert P["hglider_ft"][i] <= P["hcrit_ft"][i]
        assert P["hglider_ft"][i] <= P["lcl_ft"][i]
        # rain: the two configured hours only
        assert P["rain_1h_mm"][i] == pytest.approx(syn.rain_rate_mm(hl), abs=0.05)
        # sea-level pressure of a 967 mb surface at 400 m
        assert 1005 <= P["mslp_mb"][i] <= 1030
        assert 0 <= P["bl_cloud_pct"][i] <= 95
        assert 0 <= P["bs_ratio"][i] <= BSRATIO_LIMIT
    # the morning stratus deck (RH ~97% at 300-700 m AGL until 10:00) shows as
    # heavy BL cloud cover once the BL reaches it, and clears by midday
    assert P["bl_cloud_pct"][hours.index(10)] >= 80
    assert P["bl_cloud_pct"][hours.index(14)] < 50
    # convergence: the 0.15 m/s updraft in the 11:00-16:00 BL reads as 15 cm/s
    assert P["bl_convergence_cms"][hours.index(13)] == 15
    assert P["bl_convergence_cms"][hours.index(9)] == 0
    # shear grows with the BL: the deeper afternoon BL reaches stronger wind aloft
    assert P["bl_shear_kt"][hours.index(14)] > P["bl_shear_kt"][hours.index(8)]
    assert P["bltop_wind_kt"][hours.index(14)] > P["sfc_wind_kt"][hours.index(14)]
    # level heights above the real ground (HGT) for the three "surface" wind
    # rows: the synthetic first mass level is ~59 m up, then ~120 m per layer
    lv = blip["levels_agl_ft"]
    assert 150 < lv["sfc"] < 250 and lv["sfc"] < lv["treetop"] < lv["above_treetop"] < 1500
    # BL-top variability: theta rises 3.5 K/km above the synthetic BL top, so a
    # 1 C warmer BL would mix ~286 m (~940 ft) deeper, at every hour
    for v in P["bl_top_variability_ft"]:
        assert 800 <= v <= 1100


def test_build_without_optional_fields(wrfout):
    """The HRRR direct reader's dict has none of the extra point fields: the
    table still builds, from the chart's own quantities, with those rows gone."""
    d = _extract_site_data(wrfout, syn.SITE_LAT, syn.SITE_LON)
    for key in ("pblh_m", "hfx", "lh", "t2_k", "u10_kts", "v10_kts", "q2",
                "psfc_mb", "rain_1h_mm", "w_ms"):
        d.pop(key)
    blip = build_blipspot(d, "Bare", model_name="hrrr", utc_offset=-7)
    P = blip["params"]
    for gone in ("wind10m_kt", "wind10m_dir", "rain_1h_mm", "bl_convergence_cms", "sfc_heating_wm2"):
        assert gone not in P
    assert set(blip["units"]) == set(P)
    # BL depth backed out of the chart's pressure marker (32 ft/mb) agrees with PBLH
    for t in range(d["ntimes"]):
        hl = (d["hours_utc"][t] - 7) % 24
        assert P["bl_depth_ft"][t] == pytest.approx(syn.pblh_m(hl) * 3.28084, rel=0.02, abs=5)
    assert all(v is not None for v in P["t2_f"])            # falls back to the lowest level
    assert all(v is not None for v in P["mslp_mb"])


def test_table_failure_never_breaks_the_png(wrfout, tmp_path, monkeypatch):
    import rasp.blipspot as bp

    def boom(*a, **k):
        raise RuntimeError("synthetic table failure")
    monkeypatch.setattr(bp, "write_blipspot", boom)
    png = render_windgram(wrfout, syn.SITE_LAT, syn.SITE_LON, "Synth", str(tmp_path),
                          utc_offset=syn.UTC_OFFSET, start_hour=8)
    assert png.endswith("_windgram.png")
    assert not list(tmp_path.glob("*_blipspot.json"))


def test_no_blipspot_switch(wrfout, tmp_path):
    render_windgram(wrfout, syn.SITE_LAT, syn.SITE_LON, "Synth", str(tmp_path),
                    utc_offset=syn.UTC_OFFSET, start_hour=8, blipspot=False)
    assert list(tmp_path.glob("*_windgram.png")) and not list(tmp_path.glob("*_blipspot.json"))
