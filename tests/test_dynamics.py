"""The optional ``dynamics:`` block (WRF stability overrides)."""

import re
from pathlib import Path

import pytest

from rasp.namelist_generator import (_parse_simple_yaml, compute_nest_chain,
                                     estimate_runtime, generate_namelist_input,
                                     load_domain_config, outer_time_step)

ROOT = Path(__file__).resolve().parent.parent

TILE = """\
name: issaquah
model: nam
center_lat: 47.22
center_lon: -121.80
outer_dx_km: 4.0
target_dx_km: 1.33
inner_extent_km: 120
nest_ratio: 3
e_vert: 52
"""


def _nml(tmp_path, extra=""):
    p = tmp_path / "tile.yaml"
    p.write_text(TILE + extra)
    config = load_domain_config(p)
    domains = compute_nest_chain(config)
    return config, domains, generate_namelist_input(config, domains, "2026-10-22", "00")


def _value(nml, key):
    m = re.search(rf"^ {key}\s+= (.*),$", nml, re.M)
    return m.group(1) if m else None


def test_defaults_without_block(tmp_path):
    config, domains, nml = _nml(tmp_path)
    assert "dynamics" not in config
    assert _value(nml, "time_step") == "24"          # 6 * 4 km
    assert _value(nml, "w_damping") == "1"
    assert _value(nml, "hybrid_opt") == "0"
    assert _value(nml, "diff_6th_opt") == "0, 0"
    assert _value(nml, "diff_6th_factor") == "0.12, 0.12"
    assert _value(nml, "epssm") is None              # WRF default (0.1)
    assert _value(nml, "zadvect_implicit") is None


def test_null_block_is_no_block(tmp_path):
    _, _, a = _nml(tmp_path)
    _, _, b = _nml(tmp_path, "dynamics:\n")
    assert a == b


def test_overrides_are_emitted(tmp_path):
    config, domains, nml = _nml(tmp_path, """\
dynamics:
  time_step: 16
  epssm: 0.5
  w_damping: true
  zadvect_implicit: 1
  diff_6th_opt: 2
  diff_6th_factor: [0.12, 0.25]
  hybrid_opt: 2
""")
    assert _value(nml, "time_step") == "16"
    assert _value(nml, "parent_time_step_ratio") == "1, 3"   # nest = 16/3 s
    assert _value(nml, "epssm") == "0.5, 0.5"
    assert _value(nml, "w_damping") == "1"
    assert _value(nml, "zadvect_implicit") == "1"
    assert _value(nml, "diff_6th_opt") == "2, 2"
    assert _value(nml, "diff_6th_factor") == "0.12, 0.25"
    assert _value(nml, "hybrid_opt") == "2"
    # Optional lines sit inside &dynamics.
    dyn = nml.split("&dynamics", 1)[1].split("/", 1)[0]
    assert "epssm" in dyn and "zadvect_implicit" in dyn
    assert outer_time_step(config, domains) == 16


def test_runtime_estimate_scales_with_time_step(tmp_path):
    config, domains, _ = _nml(tmp_path)
    base = estimate_runtime(domains)
    assert estimate_runtime(domains, time_step=24) == base
    assert estimate_runtime(domains, time_step=12) == pytest.approx(2 * base, rel=0.02)


@pytest.mark.parametrize("block, msg", [
    ("  time_step: 0\n", "positive integer"),
    ("  time_step: 16.5\n", "positive integer"),
    ("  epssm: 1.5\n", r"\[0, 1\]"),
    ("  epssm: true\n", "number"),
    ("  w_damping: 2\n", "0/1"),
    ("  hybrid_opt: 1\n", "0 .* or 2"),
    ("  diff_6th_opt: 3\n", "0, 1 or 2"),
    ("  time_step: [16, 5]\n", "single value"),
    ("  smooth_cg_topo: true\n", "unknown key"),
])
def test_validation(tmp_path, block, msg):
    with pytest.raises(ValueError, match=msg):
        _nml(tmp_path, "dynamics:\n" + block)


def test_per_domain_list_length(tmp_path):
    with pytest.raises(ValueError, match="3 values for 2 domains"):
        _nml(tmp_path, "dynamics:\n  epssm: [0.5, 0.5, 0.5]\n")


def test_simple_yaml_fallback(tmp_path):
    parsed = _parse_simple_yaml(TILE + "dynamics:\n  time_step: 16\n  epssm: 0.5\n"
                                "  w_damping: true\n")
    from rasp.namelist_generator import parse_dynamics
    assert parse_dynamics(parsed["dynamics"]) == {"time_step": 16, "epssm": 0.5,
                                                  "w_damping": 1}


def test_ab_arms_differ_only_in_dynamics():
    base = (ROOT / "ab/issaquah.yaml").read_text()
    cand = (ROOT / "ab/issaquah-stable.yaml").read_text()
    strip = lambda t: [l for l in t.splitlines() if l.strip() and not l.lstrip().startswith("#")]
    extra = strip(cand)[len(strip(base)):]
    assert strip(cand)[:len(strip(base))] == strip(base)
    assert extra[0].startswith("dynamics:")


def test_adaptive_time_step(tmp_path):
    _, _, nml = _nml(tmp_path, """\
dynamics:
  use_adaptive_time_step: true
  target_cfl: 1.0
  max_step_increase_pct: [5, 51]
  starting_time_step: [12, 4]
  max_time_step: [24, 8]
  min_time_step: [4, 1]
""")
    dom = nml.split("&domains", 1)[1].split("/", 1)[0]
    assert _value(dom, "use_adaptive_time_step") == ".true."
    assert _value(dom, "step_to_output_time") == ".true."   # implied: wrfout on the hour
    assert _value(dom, "target_cfl") == "1.0, 1.0"
    assert _value(dom, "max_step_increase_pct") == "5, 51"
    assert _value(dom, "starting_time_step") == "12, 4"
    assert _value(dom, "max_time_step") == "24, 8"
    assert _value(dom, "min_time_step") == "4, 1"
    assert _value(nml, "time_step") == "24"


@pytest.mark.parametrize("block, msg", [
    ("  target_cfl: 1.0\n", "only apply with use_adaptive_time_step"),
    ("  use_adaptive_time_step: 1\n", "true/false"),
    ("  use_adaptive_time_step: true\n  min_time_step: 0\n", "or -1"),
    ("  use_adaptive_time_step: true\n  target_cfl: -1\n", "positive number"),
    ("  use_adaptive_time_step: true\n  adaptation_domain: 3\n", "only 2 domains"),
])
def test_adaptive_validation(tmp_path, block, msg):
    with pytest.raises(ValueError, match=msg):
        _nml(tmp_path, "dynamics:\n" + block)
