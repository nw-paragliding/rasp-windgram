"""
Full RASP pipeline — domain.yaml → WPS → WRF → windgrams.

Single entry point that runs the entire forecast pipeline:
1. Generate namelists from domain config
2. Download GRIB data (or use pre-provided)
3. Run WPS (geogrid, ungrib, metgrid)
4. Run WRF (real.exe, wrf.exe)
5. Render windgrams for all sites

Usage:
    python -m rasp.pipeline domain.yaml --sites sites.csv --output-dir ./output
    python -m rasp.pipeline domain.yaml --date 2026-04-06 --cycle 00 --sites sites.csv
"""

import argparse
import fnmatch
import math
import os
import random
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

from .namelist_generator import generate_namelists, load_domain_config, MODELS
from .windgram import render_windgram


def _run(cmd, desc, cwd=None):
    """Run a shell command, stream output, raise on failure."""
    print(f"\n{'='*60}")
    print(f"  {desc}")
    print(f"{'='*60}\n", flush=True)
    result = subprocess.run(
        cmd, shell=True, cwd=cwd,
        stdout=sys.stdout, stderr=sys.stderr,
    )
    if result.returncode != 0:
        print(f"\nERROR: {desc} failed (exit {result.returncode})")
        sys.exit(result.returncode)


def _run_exe(args, desc, cwd):
    """Run an executable (not shell), stream output, raise on failure."""
    print(f"  {desc}...", flush=True)
    result = subprocess.run(
        args, cwd=cwd,
        stdout=sys.stdout, stderr=sys.stderr,
    )
    if result.returncode != 0:
        print(f"\n  ERROR: {desc} failed (exit {result.returncode})")
        sys.exit(result.returncode)
    return result.returncode


def _tail_log(path, lines=15):
    """Print the last lines of a WPS/WRF log file, if it exists."""
    try:
        text = Path(path).read_text().rstrip().splitlines()
    except OSError:
        return
    print(f"  --- {Path(path).name} (last {min(lines, len(text))} lines) ---")
    for ln in text[-lines:]:
        print(f"  {ln}")


def _cleanup_files(paths, label):
    """Delete intermediate files to reclaim disk mid-pipeline.

    Sums bytes of real files (symlinks are unlinked without counting) and
    prints how much was freed. Best-effort: missing/locked files are skipped.
    """
    freed = 0
    removed = 0
    for f in paths:
        try:
            if not f.is_symlink():
                freed += f.stat().st_size
            f.unlink()
            removed += 1
        except OSError:
            pass
    if removed:
        print(f"  Freed {freed / 1e9:.1f}GB ({removed} files): {label}", flush=True)


def _resolve_model_urls(model_cfg, model):
    """Substitute {root} in the model's URL patterns (in place) and return model_cfg.

    Models whose NOMADS path moves (RRFS: rrfs/v1.0 parallel feed now, rrfs/prod
    from 2026-11-03) carry a "root" key; RASP_<MODEL>_ROOT overrides it so the
    switch needs no code change.
    """
    root = os.environ.get(f"RASP_{model.upper()}_ROOT", model_cfg.get("root", "")).rstrip("/")
    for key in ("url_pattern", "sfc_url_pattern"):
        if model_cfg.get(key) and "{root}" in model_cfg[key]:
            model_cfg[key] = model_cfg[key].replace("{root}", root)
    if root:
        print(f"  Data root: {root}")
    return model_cfg


def _remote_exists(url, timeout=5):
    """HEAD a URL; True only on HTTP 200 (a throttling 302 is not "present")."""
    try:
        r = subprocess.run(
            ["curl", "--http1.1", "-sI", "-o", "/dev/null", "-w", "%{http_code}",
             "--max-time", str(timeout), url],
            capture_output=True, text=True, timeout=timeout + 3,
        )
        return r.returncode == 0 and r.stdout.strip() == "200"
    except Exception:
        return False


def _cycle_files_ready(model_cfg, date_compact, cycle, fhrs):
    """True if every needed file (main + surface, if any) exists for these fhrs.

    For .idx-subset files the sidecar must be there too: the AWS mirrors publish
    it 10-30 s after the GRIB, and a missing .idx means a full-file download.
    """
    patterns = [(model_cfg["url_pattern"], model_cfg.get("idx_subset"))]
    if model_cfg.get("sfc_url_pattern"):
        patterns.append((model_cfg["sfc_url_pattern"], model_cfg.get("sfc_idx_subset")))
    subset = os.environ.get("RASP_IDX_SUBSET", "1") != "0"
    for fhr in fhrs:
        for pat, idx in patterns:
            url = pat.format(date=date_compact, cycle=f"{int(cycle):02d}", fhr=fhr)
            if not _remote_exists(url) or (idx and subset and not _remote_exists(url + ".idx")):
                return False
    return True


# ── .idx byte-range subsetting ──────────────────────────────────────────────
# NOMADS publishes a .grib2.idx sidecar (wgrib2 inventory: "n:offset:d=...:VAR:
# LEVEL:FCST:") for RRFS and HRRR. Fetching only the records a run needs cuts an
# RRFS forecast hour from ~850 MB to ~300 MB. There is no server-side grib
# filter for RRFS, so this is the only subsetting available.

def _parse_idx(text):
    """Parse a .idx inventory into [(start, end_or_None, 'VAR:LEVEL:FCST')]."""
    lines = [ln for ln in text.splitlines() if ln.strip()]
    recs = []
    for i, line in enumerate(lines):
        parts = line.split(":")
        if len(parts) < 6:
            continue
        start = int(parts[1])
        end = None
        if i + 1 < len(lines):
            end = int(lines[i + 1].split(":")[1]) - 1
        recs.append((start, end, ":".join(parts[3:6])))
    return recs


def _idx_ranges(recs, patterns, max_gap=0):
    """Merged byte ranges of records whose key matches any fnmatch pattern.

    A pattern with one colon matches "VAR:LEVEL"; with two colons it also
    constrains the forecast-type field (e.g. "SHTFL:surface:* hour fcst"
    excludes the hourly-average duplicate). Ranges separated by at most
    `max_gap` bytes are merged (fewer HTTP requests at the cost of a few
    unwanted records in between).
    """
    selected = []
    for start, end, key in recs:
        var_level = ":".join(key.split(":")[:2])
        for p in patterns:
            target = key if p.count(":") >= 2 else var_level
            if fnmatch.fnmatchcase(target, p):
                selected.append((start, end))
                break
    merged = []
    for s, e in selected:
        if merged and merged[-1][1] is not None and s - (merged[-1][1] + 1) <= max_gap:
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))
    return merged


# ── Throttling-aware retries ────────────────────────────────────────────────
# When many runners hit NOMADS at once it answers 302 (redirect to a "busy"
# page), 429 or 503, or drops the connection. That means "come back later", not
# "file missing": back off exponentially (jittered) instead of failing within
# seconds, and never answer it with a full-file download (that only adds load).
# Only a 404 on the .idx means "no sidecar here" and justifies the full file.

_THROTTLE_STATUSES = {302, 429, 502, 503, 504}
_BACKOFF_S = (15, 30, 60, 120, 240)     # 6 attempts, <= ~9.5 min of sleep with jitter


class _NotFound(RuntimeError):
    """HTTP 404: the file (or .idx sidecar) is not on the server."""


class _Throttled(RuntimeError):
    """Server kept throttling (302/429/5xx/connection reset) through the whole backoff schedule."""


def _backoff_schedule():
    """Delays between attempts; RASP_DOWNLOAD_BACKOFF="15,30,60" overrides the default."""
    env = os.environ.get("RASP_DOWNLOAD_BACKOFF")
    if env:
        return tuple(float(x) for x in env.split(",") if x.strip())
    return _BACKOFF_S


def _sleep(seconds):
    time.sleep(seconds)                 # indirection so tests can skip the waits


def _with_backoff(what, attempt_fn):
    """Call attempt_fn() until it returns, backing off on throttling.

    attempt_fn returns the result, raises _NotFound (no retry), or raises any
    other exception, which counts as throttling/transient and is retried on the
    jittered schedule. Raises _Throttled once the schedule is exhausted.
    """
    delays = _backoff_schedule()
    attempts = len(delays) + 1
    t0 = time.time()
    for attempt in range(1, attempts + 1):
        try:
            return attempt_fn()
        except _NotFound:
            raise
        except Exception as ex:          # noqa: BLE001 — throttled or transient
            if attempt == attempts:
                raise _Throttled(f"{what}: still failing after {attempts} attempts over "
                                 f"{time.time() - t0:.0f}s (last: {ex})") from ex
            wait = delays[attempt - 1] * random.uniform(0.8, 1.2)
            print(f"    {what}: {ex} — attempt {attempt}/{attempts}, retrying in {wait:.0f}s", flush=True)
            _sleep(wait)


class _RangeClient:
    """Minimal keep-alive HTTP/1.1 client for .idx + Range requests.

    curl's --range is global (one range per invocation, not per URL), and NOMADS
    chokes on HTTP/2, so plain http.client with a persistent connection is the
    simplest way to pull ~50 ranges per file over one connection.
    """

    def __init__(self, url, timeout=60):
        import urllib.parse
        self.u = urllib.parse.urlsplit(url)
        self.timeout = timeout
        self.conn = None

    def _connect(self):
        import http.client
        if self.conn is None:
            cls = http.client.HTTPSConnection if self.u.scheme == "https" else http.client.HTTPConnection
            self.conn = cls(self.u.hostname, self.u.port, timeout=self.timeout)

    def close(self):
        if self.conn is not None:
            try:
                self.conn.close()
            except Exception:
                pass
            self.conn = None

    def _get_once(self, path, headers, byte_range):
        try:
            self._connect()
            self.conn.request("GET", path, headers=headers)
            resp = self.conn.getresponse()
            data = resp.read()                    # drain fully so the connection can be reused
        except Exception:
            self.close()                          # connection reset / timeout: reconnect next time
            raise
        if resp.getheader("Connection", "").lower() == "close":
            self.close()
        want = 206 if byte_range is not None else 200
        if resp.status == 404:
            raise _NotFound(f"HTTP 404 for {path}")
        if resp.status != want:
            self.close()
            raise RuntimeError(f"HTTP {resp.status} (expected {want})")
        if byte_range is not None and byte_range[1] is not None:
            expect = byte_range[1] - byte_range[0] + 1
            if len(data) != expect:
                self.close()
                raise RuntimeError(f"short range: got {len(data)} of {expect} bytes")
        return data

    def get(self, path, byte_range=None):
        """GET path (optionally one byte range). Returns bytes.

        Raises _NotFound on 404, _Throttled when the backoff schedule runs out.
        """
        headers = {"User-Agent": "rasp-windgram", "Connection": "keep-alive"}
        if byte_range is not None:
            s, e = byte_range
            headers["Range"] = f"bytes={s}-{'' if e is None else e}"
        what = path.rsplit("/", 1)[-1] + (f" [{headers['Range']}]" if byte_range is not None else "")
        return _with_backoff(what, lambda: self._get_once(path, headers, byte_range))


def _fetch_grib_subset(url, dest, patterns, max_gap):
    """Download only the .idx-selected byte ranges of `url` into `dest`.

    Returns True on success. Returns False (and leaves no partial file) when the
    .idx is genuinely missing (404) or nothing matches, so the caller can fall
    back to a full download. Raises _Throttled when the server kept throttling:
    a full download would only make that worse.
    """
    dest = Path(dest)
    tmp = dest.with_name(dest.name + ".part")
    client = _RangeClient(url)
    try:
        try:
            idx_text = client.get(client.u.path + ".idx").decode("utf-8", "replace")
        except _NotFound as ex:
            print(f"    no .idx for {dest.name} ({ex}); falling back to full download")
            return False

        recs = _parse_idx(idx_text)
        ranges = _idx_ranges(recs, patterns, max_gap)
        if not ranges:
            print(f"    .idx matched no records for {dest.name}; falling back to full download")
            return False
        total_known = sum(e - s + 1 for s, e in ranges if e is not None)
        file_size = recs[-1][0] if recs else 0

        t0 = time.time()
        with tmp.open("wb") as out:
            for rng in ranges:
                out.write(client.get(client.u.path, rng))
        got = tmp.stat().st_size
        with tmp.open("rb") as fh:
            magic = fh.read(4)
        if got < total_known or magic != b"GRIB":
            raise RuntimeError(f"assembled file invalid ({got} bytes, magic {magic!r})")
        tmp.replace(dest)
        print(f"    subset: {len(ranges)} ranges, {got // 1_000_000}MB of ~{file_size // 1_000_000}MB "
              f"in {time.time() - t0:.0f}s from {client.u.hostname}")
        return True
    except _Throttled:
        if tmp.exists():
            tmp.unlink()
        raise
    except Exception as ex:          # noqa: BLE001 — e.g. a 404 on a range or a bad assembly
        print(f"    range download failed for {dest.name} ({ex}); falling back to full download")
        if tmp.exists():
            tmp.unlink()
        return False
    finally:
        client.close()


def _curl_once(url, dest):
    """One full-file curl download. Returns on success, raises _NotFound/RuntimeError."""
    # No -L: a 302 from NOMADS is throttling, not a mirror to follow.
    result = subprocess.run(
        ["curl", "--http1.1", "-sS", "-o", str(dest), "-w", "%{http_code}", url],
        stdout=subprocess.PIPE, stderr=sys.stderr, text=True,
    )
    status = (result.stdout or "").strip()[-3:]
    ok = result.returncode == 0 and status == "200" and dest.exists() and dest.stat().st_size > 1_000_000
    if ok:
        return
    if dest.exists():
        dest.unlink()
    if status == "404":
        raise _NotFound(f"HTTP 404 for {url}")
    if result.returncode != 0:
        raise RuntimeError(f"curl exit {result.returncode} (HTTP {status or '000'})")
    raise RuntimeError(f"HTTP {status}" if status != "200" else "HTTP 200 but file < 1MB")


def _fetch_grib(url, dest, patterns=None, max_gap=0):
    """Download one GRIB file (subset via .idx when patterns are given), with backoff."""
    dest = Path(dest)
    fname = dest.name
    if dest.exists() and dest.stat().st_size > 1_000_000:
        print(f"  {fname}: cached ({dest.stat().st_size // 1_000_000}MB)")
        return True

    print(f"  Downloading {fname}...", flush=True)
    try:
        if patterns and os.environ.get("RASP_IDX_SUBSET", "1") != "0":
            if _fetch_grib_subset(url, dest, patterns, max_gap):
                print(f"  {fname}: OK ({dest.stat().st_size // 1_000_000}MB, subset)")
                return True

        _with_backoff(fname, lambda: _curl_once(url, dest))
        print(f"  {fname}: OK ({dest.stat().st_size // 1_000_000}MB)")
        return True
    except (_NotFound, _Throttled) as ex:
        print(f"  ERROR: {fname} download failed: {ex}")
        return False


def _download_grib(model_cfg, date, cycle, fhours, dest_dir):
    """Download GRIB files using the model's URL pattern(s).

    Models with "idx_subset" / "sfc_idx_subset" (RRFS in the registry; any model
    through the domain YAML, see DOMAIN_MODEL_OVERRIDES) get byte-range subsetting
    through the .grib2.idx sidecar; anything else is a full-file download.
    """
    print(f"\n{'='*60}")
    print(f"  Downloading GRIB data ({model_cfg['name']})")
    print(f"{'='*60}\n", flush=True)

    Path(dest_dir).mkdir(parents=True, exist_ok=True)
    date_compact = date.replace("-", "")
    max_gap = int(model_cfg.get("idx_max_gap_mb", 4) * 1_000_000)

    jobs = [("", model_cfg["url_pattern"], model_cfg.get("idx_subset"))]
    if model_cfg.get("sfc_url_pattern"):
        jobs.append(("surface ", model_cfg["sfc_url_pattern"], model_cfg.get("sfc_idx_subset")))

    for label, pattern, patterns in jobs:
        if label:
            print(f"\n  Downloading {label}GRIB data...\n")
        downloaded = 0
        for fhr in fhours:
            url = pattern.format(date=date_compact, cycle=f"{int(cycle):02d}", fhr=fhr)
            dest = Path(dest_dir) / url.split("/")[-1]
            if not _fetch_grib(url, dest, patterns, max_gap):
                sys.exit(1)
            downloaded += 1
        print(f"\n  Downloaded {downloaded}/{len(fhours)} {label}files to {dest_dir}")


def _detect_latest_cycle(model, date=None, model_cfg=None):
    """Auto-detect the latest available cycle from NOMADS.

    Returns (date_str, cycle_str) e.g. ("2026-04-06", "06").
    """
    if date is None:
        date = datetime.utcnow().strftime("%Y-%m-%d")

    date_compact = date.replace("-", "")
    if model_cfg is None:
        model_cfg = _resolve_model_urls(dict(MODELS[model]), model)

    if model_cfg.get("source") != "nomads":
        return date, "00"

    # Try each known cycle (newest first) and check if a sample file exists
    url_pattern = model_cfg["url_pattern"]
    known_cycles = sorted(model_cfg.get("cycles", [0, 6, 12, 18]), reverse=True)

    for try_date in [date, (datetime.strptime(date, "%Y-%m-%d") - timedelta(days=1)).strftime("%Y-%m-%d")]:
        dc = try_date.replace("-", "")
        for cyc in known_cycles:
            # Check if a low forecast hour file exists (fhr 3 as probe)
            probe_url = url_pattern.format(date=dc, cycle=f"{cyc:02d}", fhr=3)
            if _remote_exists(probe_url):
                print(f"  Auto-detected latest cycle: {try_date} {cyc:02d}z")
                return try_date, f"{cyc:02d}"

    print(f"  WARNING: Could not detect cycles, defaulting to {date} 00z")
    return date, "00"


# Model-registry keys a domain YAML may override. An absent key leaves the
# registry entry untouched, so existing domains run exactly as before.
#   direct_reader: false     force the WPS/WRF path (HRRR defaults to the direct reader)
#   vtable: Vtable.X         ungrib Vtable for the atmosphere pass; wins over the
#                            registry's wrf_vtable (e.g. Vtable.RAP.pressure.ncep to
#                            initialise WRF from HRRR without hydrometeors, like NAM)
#   sfc_vtable: Vtable.Y     second (soil) ungrib pass; `null` skips it
#   idx_subset / sfc_idx_subset / idx_max_gap_mb
#                            .idx byte-range download patterns (see _fetch_grib_subset)
DOMAIN_MODEL_OVERRIDES = ("direct_reader", "vtable", "sfc_vtable",
                          "idx_subset", "sfc_idx_subset", "idx_max_gap_mb")


def _apply_domain_overrides(model_cfg, config):
    """Copy the domain YAML's overrides of registry keys into model_cfg (in place)."""
    for key in DOMAIN_MODEL_OVERRIDES:
        if key in config:
            model_cfg[key] = config[key]
            if key == "vtable":
                # The atmosphere pass reads wrf_vtable first (HRRR: Vtable.HRRR.full).
                model_cfg["wrf_vtable"] = config[key]
    return model_cfg


def _utc_offset_from_lon(lon):
    """Estimate UTC offset from longitude (rough, ignores DST)."""
    # -122 → -8 (PST), -121 → -8, etc.
    # Add 1 for daylight savings (rough approximation for North America in summer)
    offset = round(lon / 15)
    # Assume DST for simplicity (April-October)
    offset += 1
    return offset


def run_pipeline(config_path, date=None, cycle=None, target_date=None,
                 sites_csv=None, output_dir="./output", grib_dir=None,
                 geog_path="/mnt/geog", basedir="/opt/rasp", num_procs=1,
                 utc_offset=None, start_hour=8,
                 max_hours=None, target_cycle=None,
                 poll_interval_min=10, poll_max_min=240):
    """Run the full forecast pipeline."""
    config = load_domain_config(config_path)
    model = config["model"]
    # Copy so domain overrides don't mutate the global registry.
    model_cfg = _apply_domain_overrides(dict(MODELS[model]), config)

    # Resolve {root} in URL patterns (RRFS para -> prod switch via env var)
    _resolve_model_urls(model_cfg, model)

    # UTC offset: CLI flag > domain YAML (utc_offset:) > longitude heuristic.
    # The heuristic always adds a DST hour, so zones without DST (Arizona) must
    # set it in the YAML.
    if utc_offset is None and config.get("utc_offset") is not None:
        utc_offset = int(config["utc_offset"])
        print(f"  UTC offset: {utc_offset} (from domain config)")
    if utc_offset is None:
        utc_offset = _utc_offset_from_lon(config["center_lon"])
        print(f"  UTC offset: {utc_offset} (from center lon {config['center_lon']:.1f})")

    # Compute the soaring window target in UTC hours.
    # If --target-date is given, the soaring window is for that specific date.
    # Otherwise, it's derived from the cycle date.
    target_start_local = 8   # 8am local
    target_end_local = 20    # 8pm local
    max_fhr = max(model_cfg.get("forecast_hours", [84]))
    native_interval = model_cfg["interval_seconds"] // 3600
    # Direct reader can use native interval (e.g. 1h for HRRR).
    # WPS/WRF path needs ≥3h for boundary condition consistency.
    if model_cfg.get("direct_reader"):
        interval_hours = native_interval
    else:
        interval_hours = max(native_interval, 3)
    known_cycles = sorted(model_cfg.get("cycles", [0, 6, 12, 18]), reverse=True)
    url_pattern = model_cfg["url_pattern"]

    if target_date:
        # User wants forecasts for a specific date (e.g. "tomorrow")
        # Compute soaring window as absolute UTC times, then find the best cycle
        target_dt = datetime.strptime(target_date, "%Y-%m-%d")
        soaring_start_utc = target_dt + timedelta(hours=target_start_local - utc_offset)
        soaring_end_utc = target_dt + timedelta(hours=target_end_local - utc_offset)
        print(f"  Target date: {target_date} ({soaring_start_utc.strftime('%H')}z-{soaring_end_utc.strftime('%d %H')}z)")
    else:
        soaring_start_utc = None
        soaring_end_utc = None

    # --target-cycle: pin to a specific cycle and poll NOMADS until ready.
    # Better than --not-before (time-based) — runs as soon as data is actually available.
    if target_cycle is not None:
        target_cyc = int(target_cycle)
        # Use today's UTC date for the target cycle. If the cycle is in the future
        # (e.g. running at 22z asking for 00z today which already passed), use today.
        # If it's far in the past (>23h), bump to next day. Generally cron should
        # fire just before/after the cycle is initialized.
        if date is None:
            date = datetime.utcnow().strftime("%Y-%m-%d")
        cycle = f"{target_cyc:02d}"
        cycle_dt = datetime.strptime(f"{date}_{target_cyc:02d}", "%Y-%m-%d_%H")

        # Compute needed forecast hours from soaring window
        if soaring_start_utc:
            fhr_end = int((soaring_end_utc - cycle_dt).total_seconds() / 3600)
        else:
            fhr_end = (target_end_local - utc_offset) - target_cyc
            if fhr_end < 0:
                fhr_end += 24
        # Start from cycle init (fhr 0) for WRF spin-up. The windgram renderer
        # filters output to start_hour=8 local time, so early fhrs aren't shown
        # but WRF gets proper initialization time before the soaring window.
        # Matches DrJack RASP convention (e.g. TIGER.12z uses 12Z+0 through 12Z+15).
        fhr_start = 0
        download_fhours = list(range(fhr_start, fhr_end + 1, interval_hours))
        if max_hours is not None:
            cutoff = download_fhours[0] + max_hours
            truncated = [f for f in download_fhours if f <= cutoff]
            if len(truncated) < 2 and len(download_fhours) >= 2:
                truncated = download_fhours[:2]
            download_fhours = truncated

        print(f"  Target cycle: {date} {target_cyc:02d}z (fhr {download_fhours[0]}-{download_fhours[-1]})")

        # Poll until the LAST needed fhour (every file kind) is published on NOMADS
        dc = date.replace("-", "")
        elapsed_min = 0
        while elapsed_min < poll_max_min:
            if _cycle_files_ready(model_cfg, dc, target_cyc, [download_fhours[-1]]):
                print(f"  Target cycle ready (waited {elapsed_min} min)")
                break
            print(f"  Cycle {target_cyc:02d}z fhr {download_fhours[-1]} not ready, sleeping {poll_interval_min} min (elapsed {elapsed_min} min)", flush=True)
            time.sleep(poll_interval_min * 60)
            elapsed_min += poll_interval_min
        else:
            print(f"  ERROR: Target cycle {target_cyc:02d}z not ready after {poll_max_min} min")
            sys.exit(1)

    # Find the best cycle: latest available that covers the soaring window
    if date is not None and cycle is not None:
        # User specified both — use as-is
        pass
    else:
        # Auto-detect: try recent dates and cycles
        if date is None:
            date = datetime.utcnow().strftime("%Y-%m-%d")

        best_date, best_cycle, best_fhours = None, None, None
        search_dates = [date, (datetime.strptime(date, "%Y-%m-%d") - timedelta(days=1)).strftime("%Y-%m-%d")]

        for try_date in search_dates:
            dc = try_date.replace("-", "")
            for cyc in known_cycles:
                cycle_dt = datetime.strptime(f"{try_date}_{cyc:02d}", "%Y-%m-%d_%H")

                if soaring_start_utc:
                    # target-date mode: compute fhr from absolute times
                    fhr_start = int((soaring_start_utc - cycle_dt).total_seconds() / 3600)
                    fhr_end = int((soaring_end_utc - cycle_dt).total_seconds() / 3600)
                else:
                    # Auto mode: soaring window relative to cycle
                    fhr_start = (target_start_local - utc_offset) - cyc
                    fhr_end = (target_end_local - utc_offset) - cyc
                    if fhr_start < 0:
                        fhr_start += 24
                        fhr_end += 24

                fhr_start = max(fhr_start, 3)
                if fhr_end <= max_fhr and fhr_start < fhr_end and fhr_start >= 0:
                    # Verify ALL needed files exist on NOMADS — probe the first
                    # and LAST forecast hour (the most likely to still be
                    # publishing), for every file kind the model needs. NOMADS
                    # publishes forecast hours progressively, so a cycle with
                    # fhr 3 available may not yet have fhr 27.
                    if not _cycle_files_ready(model_cfg, dc, cyc, [fhr_start, fhr_end]):
                        continue
                    best_date = try_date
                    best_cycle = f"{cyc:02d}"
                    best_fhours = list(range(fhr_start, fhr_end + 1, interval_hours))
                    print(f"  Selected cycle: {try_date} {cyc:02d}z (fhr {fhr_start}-{fhr_end})")
                    break
            if best_fhours:
                break

        if best_fhours:
            date, cycle, download_fhours = best_date, best_cycle, best_fhours
        else:
            print(f"  WARNING: No cycle covers the soaring window. Using latest available.")
            auto_date, auto_cycle = _detect_latest_cycle(model, date, model_cfg)
            date, cycle = auto_date, auto_cycle
            fhr_start = 3
            fhr_end = min(max_fhr, 18)
            download_fhours = list(range(fhr_start, fhr_end + 1, interval_hours))

    # If user specified date+cycle explicitly, compute fhours from them
    if 'download_fhours' not in locals():
        cycle_hour = int(cycle)
        if soaring_start_utc:
            cycle_dt = datetime.strptime(f"{date}_{cycle}", "%Y-%m-%d_%H")
            fhr_start = max(int((soaring_start_utc - cycle_dt).total_seconds() / 3600), 3)
            fhr_end = min(int((soaring_end_utc - cycle_dt).total_seconds() / 3600), max_fhr)
        else:
            fhr_start = max((target_start_local - utc_offset) - cycle_hour, 3)
            fhr_end = min((target_end_local - utc_offset) - cycle_hour, max_fhr)
            if fhr_start < 0:
                fhr_start += 24
                fhr_end += 24
        download_fhours = list(range(fhr_start, fhr_end + 1, interval_hours))

    # --max-hours: truncate the simulation window for fast iteration/debugging.
    # Always preserve the native interval so WRF boundary times line up.
    if max_hours is not None:
        cutoff = download_fhours[0] + max_hours
        truncated = [f for f in download_fhours if f <= cutoff]
        # Need at least 2 fhrs for WRF (start + end boundary)
        if len(truncated) < 2 and len(download_fhours) >= 2:
            truncated = download_fhours[:2]
        download_fhours = truncated
        print(f"  --max-hours {max_hours}: truncated to {len(download_fhours)} fhrs ({download_fhours[0]}-{download_fhours[-1]})")

    base_dt = datetime.strptime(f"{date}_{cycle}", "%Y-%m-%d_%H")

    start_dt = base_dt + timedelta(hours=download_fhours[0])
    end_dt = base_dt + timedelta(hours=download_fhours[-1])
    start_valid = start_dt.strftime("%Y-%m-%d_%H")
    end_valid = end_dt.strftime("%Y-%m-%d_%H")
    run_hours = download_fhours[-1] - download_fhours[0]
    interval_seconds = interval_hours * 3600  # match what we actually download

    # Directories
    wps_dir = f"{basedir}/wps"
    run_dir = f"{basedir}/runs/{config['name']}"
    scripts_dir = f"{basedir}/scripts"

    # Resolve paths before any chdir
    if sites_csv:
        sites_csv = str(Path(sites_csv).resolve())
    config_path = str(Path(config_path).resolve())
    output_dir = str(Path(output_dir).resolve())

    print(f"\n  Pipeline: {config['name']}")
    print(f"  Model: {model.upper()}, Date: {date} {cycle}z")
    print(f"  Valid: {start_valid} to {end_valid} ({run_hours}h)")
    print(f"  UTC offset: {utc_offset}")
    print(f"  WPS dir: {wps_dir}")
    print(f"  Run dir: {run_dir}", flush=True)

    # ── Step 1: Generate namelists ──────────────────────────────────────
    result = generate_namelists(
        config_path, date, cycle,
        output_dir=wps_dir,
        geog_path=geog_path,
        start_date=start_valid,
        end_date=end_valid,
        run_hours=run_hours,
        interval_seconds_override=interval_seconds,
    )

    # Also copy namelist.input to the WRF run dir
    Path(run_dir).mkdir(parents=True, exist_ok=True)
    shutil.copy(f"{wps_dir}/namelist.input", f"{run_dir}/namelist.input")

    # ── Step 2: Download GRIB ───────────────────────────────────────────
    if grib_dir is None:
        grib_dir = f"{basedir}/grib"
        _download_grib(model_cfg, date, cycle, download_fhours, grib_dir)

    # ── HRRR direct reader: skip WPS/WRF, read GRIB output directly ───
    if model_cfg.get("direct_reader"):
        from .hrrr_reader import extract_hrrr_sites_data

        prs_files = sorted(Path(grib_dir).glob(model_cfg.get("prs_glob", "*wrfprs*.grib2")))
        sfc_files = sorted(Path(grib_dir).glob(model_cfg.get("sfc_glob", "*wrfsfc*.grib2")))

        if not prs_files or not sfc_files:
            print(f"  ERROR: Missing {model.upper()} pressure-level or surface files for direct reader")
            sys.exit(1)

        print(f"\n{'='*60}")
        print(f"  Direct HRRR reader ({len(prs_files)} forecast hours)")
        print(f"{'='*60}\n", flush=True)

        sites = _load_sites(sites_csv) if sites_csv else []
        if not sites:
            print("  No sites provided — skipping windgram rendering")
            return

        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        # Single pass over the GRIB files for all sites (decode once, pluck
        # every site), then render each. Avoids re-decoding the whole CONUS
        # grid once per site.
        site_data = extract_hrrr_sites_data(
            [str(f) for f in prs_files],
            [str(f) for f in sfc_files],
            sites,
        )

        rendered = 0
        for (name, lat, lon), (_, data) in zip(sites, site_data):
            if data is None:
                print(f"  WARNING: {name} failed: no usable data extracted")
                continue
            try:
                render_windgram(
                    None, lat, lon, name, str(output_path),
                    utc_offset=utc_offset, start_hour=start_hour,
                    model_name=model, data=data,
                )
                rendered += 1
            except Exception as e:
                print(f"  WARNING: {name} failed: {e}")

        print(f"\n{'='*60}")
        print(f"  Pipeline complete!")
        print(f"  Rendered {rendered}/{len(sites)} windgrams to {output_path}/")
        print(f"{'='*60}\n")
        return  # Skip WPS/WRF

    # ── Step 3: Run WPS (geogrid → ungrib → metgrid) ───────────────────
    print(f"\n{'='*60}")
    print(f"  Running WPS")
    print(f"{'='*60}\n", flush=True)

    os.chdir(wps_dir)

    # 3a. geogrid
    # WPS executables exit 0 even after an ERROR (e.g. a missing GEOG dataset),
    # so check for the files each step must produce and stop early instead of
    # letting real.exe fail later on "file not in directory".
    ndomains = len(result.get("domains", [])) or 1
    if not Path(f"{wps_dir}/geo_em.d01.nc").exists():
        _run_exe(["./geogrid.exe"], "geogrid", cwd=wps_dir)
        geo_em = sorted(Path(wps_dir).glob("geo_em.d0*.nc"))
        if len(geo_em) < ndomains:
            print(f"  ERROR: geogrid produced {len(geo_em)}/{ndomains} geo_em files")
            _tail_log(Path(wps_dir) / "geogrid.log")
            sys.exit(1)
        print(f"  geogrid: OK ({len(geo_em)} domains)")
    else:
        print(f"  geogrid: cached (geo_em files exist)")

    # 3b. Link GRIB files
    grib_files = sorted(
        list(Path(grib_dir).glob("*.grib2")) +
        list(Path(grib_dir).glob("*.pgrb2*"))
    )
    if not grib_files:
        print(f"  ERROR: No GRIB2 files found in {grib_dir}")
        sys.exit(1)

    for f in Path(wps_dir).glob("GRIBFILE.*"):
        f.unlink()
    for i, f in enumerate(grib_files):
        c1 = chr(65 + i // 676)
        c2 = chr(65 + (i % 676) // 26)
        c3 = chr(65 + i % 26)
        link = Path(wps_dir) / f"GRIBFILE.{c1}{c2}{c3}"
        link.symlink_to(f)
    print(f"  Linked {len(grib_files)} GRIB files")

    # 3c. Link Vtable
    # Use wrf_vtable if available (single-pass: atmosphere + soil + hydrometeors)
    vtable_name = model_cfg.get("wrf_vtable", model_cfg["vtable"])
    vtable_src = Path(wps_dir) / "Variable_Tables" / vtable_name
    vtable_dst = Path(wps_dir) / "Vtable"
    if vtable_dst.exists() or vtable_dst.is_symlink():
        vtable_dst.unlink()
    vtable_dst.symlink_to(vtable_src)
    print(f"  Vtable: {vtable_name}")

    # 3d. ungrib (atmosphere)
    _run_exe(["./ungrib.exe"], "ungrib", cwd=wps_dir)
    file_count = len(list(Path(wps_dir).glob("FILE:*")))
    if file_count == 0:
        print("  ERROR: ungrib produced no FILE:* intermediates (Vtable/GRIB mismatch?)")
        _tail_log(Path(wps_dir) / "ungrib.log")
        sys.exit(1)
    print(f"  ungrib: OK ({file_count} intermediate files)")

    # 3d'. Second ungrib pass — extract soil fields with a different Vtable.
    # Vtable.raphrrr extracts soil data from wrfprs at below-ground levels
    # (atmosphere fields don't match due to hybrid vs pressure level types).
    sfc_vtable_name = model_cfg.get("sfc_vtable")
    if sfc_vtable_name:
        # GRIB files are already linked — just switch Vtable and prefix
        vtable_src = Path(wps_dir) / "Variable_Tables" / sfc_vtable_name
        if vtable_dst.is_symlink():
            vtable_dst.unlink()
        vtable_dst.symlink_to(vtable_src)
        print(f"  Vtable: {sfc_vtable_name}")

        # Update namelist.wps prefix for second pass
        nml_path = Path(wps_dir) / "namelist.wps"
        nml_text = nml_path.read_text()
        nml_text = nml_text.replace("prefix = 'FILE'", "prefix = 'SFC'")
        nml_path.write_text(nml_text)

        _run_exe(["./ungrib.exe"], "ungrib (soil)", cwd=wps_dir)
        sfc_count = len(list(Path(wps_dir).glob("SFC:*")))
        print(f"  ungrib (soil): OK ({sfc_count} intermediate files)")

        # Update fg_name for metgrid to merge both atmosphere and soil data
        nml_text = nml_path.read_text()
        nml_text = nml_text.replace("fg_name = 'FILE'", "fg_name = 'FILE','SFC'")
        nml_text = nml_text.replace("prefix = 'SFC'", "prefix = 'FILE'")
        nml_path.write_text(nml_text)

    # 3e. metgrid
    _run_exe(["./metgrid.exe"], "metgrid", cwd=wps_dir)
    met_files = sorted(Path(wps_dir).glob("met_em.d0*.nc"))
    if not met_files:
        print("  ERROR: metgrid produced no met_em files")
        _tail_log(Path(wps_dir) / "metgrid.log")
        sys.exit(1)
    print(f"  metgrid: OK ({len(met_files)} met_em files)")
    for f in met_files:
        print(f"    {f.name}")

    # Free intermediates that metgrid has consumed: raw GRIB, the
    # GRIBFILE.* symlinks, and ungrib output (FILE:/SFC:/PFILE:). On the
    # 1km nest these total many GB and can exhaust the runner disk before
    # WRF even starts. met_em (the input WRF needs) is kept.
    _cleanup_files(
        list(Path(grib_dir).glob("*.grib2")) +
        list(Path(grib_dir).glob("*.pgrb2*")) +
        list(Path(wps_dir).glob("GRIBFILE.*")) +
        list(Path(wps_dir).glob("FILE:*")) +
        list(Path(wps_dir).glob("SFC:*")) +
        list(Path(wps_dir).glob("PFILE:*")),
        "GRIB/ungrib intermediates",
    )

    # ── Step 4: Run WRF (real.exe → wrf.exe) ───────────────────────────
    print(f"\n{'='*60}")
    print(f"  Running WRF ({run_hours}h, {num_procs} procs)")
    print(f"{'='*60}\n", flush=True)

    run_path = Path(run_dir)
    run_path.mkdir(parents=True, exist_ok=True)
    os.chdir(run_dir)

    # Link met_em files
    for f in met_files:
        dst = run_path / f.name
        if dst.exists() or dst.is_symlink():
            dst.unlink()
        dst.symlink_to(f)
    print(f"  Linked {len(met_files)} met_em files")

    # Link WRF run tables
    wrf_run_dir = Path(f"{basedir}/run")
    if wrf_run_dir.exists():
        for f in wrf_run_dir.iterdir():
            dst = run_path / f.name
            if not dst.exists():
                dst.symlink_to(f)

    # Link executables
    for exe in ["real.exe", "wrf.exe", "ndown.exe"]:
        src = Path(f"{basedir}/bin/{exe}")
        dst = run_path / exe
        if dst.exists() or dst.is_symlink():
            dst.unlink()
        if src.exists():
            dst.symlink_to(src)

    # Auto-detect num_metgrid_levels from met_em
    met_sample = met_files[0] if met_files else None
    if met_sample:
        try:
            r = subprocess.run(
                f"ncdump -h {met_sample} | awk '/num_metgrid_levels =/ {{print $3+0; exit}}'",
                shell=True, capture_output=True, text=True
            )
            nml = int(r.stdout.strip())
            # Also detect num_metgrid_soil_levels
            r2 = subprocess.run(
                f"ncdump -h {met_sample} | awk '/NUM_METGRID_SOIL_LEVELS/ {{print $3+0; exit}}'",
                shell=True, capture_output=True, text=True
            )
            nsl = int(r2.stdout.strip()) if r2.stdout.strip() else 4

            nl_path = run_path / "namelist.input"
            nl_text = nl_path.read_text()
            nl_text = re.sub(
                r'num_metgrid_levels\s*=\s*\d+',
                f'num_metgrid_levels = {nml}',
                nl_text
            )
            nl_text = re.sub(
                r'num_metgrid_soil_levels\s*=\s*\d+',
                f'num_metgrid_soil_levels = {nsl}',
                nl_text
            )
            nl_path.write_text(nl_text)
            print(f"  num_metgrid_levels: {nml}, num_metgrid_soil_levels: {nsl}")
        except Exception as e:
            print(f"  WARNING: Could not detect num_metgrid_levels: {e}")

    # 4a. real.exe
    print(f"  real.exe...", flush=True)
    if num_procs > 1:
        real_cmd = ["mpirun", "--allow-run-as-root", "--oversubscribe", "-np", "1", "./real.exe"]
    else:
        real_cmd = ["./real.exe"]
    real_result = subprocess.run(real_cmd, cwd=run_dir, stdout=sys.stdout, stderr=sys.stderr)

    if real_result.returncode != 0 or not (run_path / "wrfinput_d01").exists():
        print(f"  ERROR: real.exe failed (exit {real_result.returncode})")
        for rsl_name in ["rsl.error.0000", "rsl.out.0000"]:
            rsl = run_path / rsl_name
            if rsl.exists():
                content = rsl.read_text()
                print(f"\n  === {rsl_name} (last 1500 chars) ===")
                print(content[-1500:])
        sys.exit(1)
    print(f"  real.exe: OK")

    # real.exe has baked met_em into wrfinput/wrfbdy; free the met_em files
    # (several GB on the 1km nest) before wrf.exe writes its output.
    _cleanup_files(
        list(Path(wps_dir).glob("met_em.d0*.nc")) +
        list(run_path.glob("met_em.d0*.nc")),
        "met_em intermediates",
    )

    # 4b. wrf.exe — cap procs at available CPUs inside container
    try:
        avail = len(os.sched_getaffinity(0))
    except AttributeError:
        avail = os.cpu_count() or 4
    if num_procs > avail:
        print(f"  Note: capping MPI procs from {num_procs} to {avail} (container limit)")
        num_procs = avail

    t0 = time.time()
    if num_procs > 1:
        _run_exe(["mpirun", "--allow-run-as-root", "--oversubscribe", "-np", str(num_procs), "./wrf.exe"],
                 f"wrf.exe ({num_procs} procs)", cwd=run_dir)
    else:
        _run_exe(["./wrf.exe"], "wrf.exe", cwd=run_dir)
    elapsed = time.time() - t0
    print(f"  wrf.exe: completed in {int(elapsed//60)}m {int(elapsed%60)}s")

    # Check wrf.exe output
    wrfout_files = sorted(run_path.glob("wrfout_d*"))
    if not wrfout_files:
        print("  ERROR: wrf.exe produced no output")
        rsl = run_path / "rsl.error.0000"
        if rsl.exists():
            print(rsl.read_text()[-500:])
        sys.exit(1)
    print(f"  wrfout files: {len(wrfout_files)}")
    for f in wrfout_files:
        size_mb = f.stat().st_size / 1e6
        print(f"    {f.name} ({size_mb:.0f}MB)")

    # Copy wrfout to output if /mnt/wrfout is available
    wrfout_mount = Path("/mnt/wrfout")
    if wrfout_mount.exists() and os.access(str(wrfout_mount), os.W_OK):
        for f in wrfout_files:
            shutil.copy(str(f), str(wrfout_mount / f.name))
        print(f"  Copied wrfout to {wrfout_mount}")

    # ── Step 5: Render windgrams ────────────────────────────────────────
    print(f"\n{'='*60}")
    print(f"  Rendering windgrams")
    print(f"{'='*60}\n", flush=True)

    finest_wrfout = str(wrfout_files[-1])
    print(f"  Source: {finest_wrfout}")

    # ── V2: soaring data cube (Zarr v3, native LCC) for the interactive
    # frontend — full-grid overlays (TOL/w*/BL-wind) + profiles for
    # click-anywhere windgrams, served from one chunked GeoZarr on R2.
    # Non-fatal: a cube failure must never break the windgram forecast.
    try:
        from .export_cube import export_soaring_cube
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        cube_path = str(Path(output_dir) / "soaring.zarr")
        info = export_soaring_cube(
            finest_wrfout, cube_path, model=model,
            cycle=str(cycle) if cycle else "", date=str(date) if date else "")
        print(f"  Soaring cube: {cube_path}  {info}")
    except Exception as e:
        print(f"  WARNING: soaring-cube export failed (non-fatal): {e}")

    sites = _load_sites(sites_csv) if sites_csv else []
    if not sites:
        print("  No sites provided — skipping windgram rendering")
        print(f"  Render manually: python -m rasp.windgram {finest_wrfout} --lat LAT --lon LON --site NAME")
        return

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    rendered = 0
    for name, lat, lon in sites:
        try:
            render_windgram(finest_wrfout, lat, lon, name, str(output_path),
                            utc_offset=utc_offset, start_hour=start_hour,
                            model_name=model)
            rendered += 1
        except Exception as e:
            print(f"  WARNING: {name} failed: {e}")

    print(f"\n{'='*60}")
    print(f"  Pipeline complete!")
    print(f"  Rendered {rendered}/{len(sites)} windgrams to {output_path}/")
    print(f"{'='*60}\n")


def _load_sites(csv_path):
    """Load site definitions from a CSV file."""
    if csv_path is None:
        return []
    path = Path(csv_path)
    if not path.exists():
        print(f"WARNING: Sites file not found: {csv_path}")
        return []
    sites = []
    for line in path.read_text().strip().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.replace(",", " ").split()
        if len(parts) >= 3:
            try:
                sites.append((parts[0], float(parts[1]), float(parts[2])))
            except ValueError:
                print(f"WARNING: Skipping invalid site: {line}")
    return sites


def main():
    parser = argparse.ArgumentParser(
        description="Run the full RASP forecast pipeline"
    )
    parser.add_argument("config", help="Path to domain.yaml")
    parser.add_argument("--target-date", help="Generate forecast for this date YYYY-MM-DD (auto-selects best cycle)")
    parser.add_argument("--date", help="Model cycle date YYYY-MM-DD (default: auto-detect)")
    parser.add_argument("--cycle", help="Model cycle HH (default: auto-detect latest)")
    parser.add_argument("--sites", help="CSV file with sites (name lat lon)")
    parser.add_argument("--output-dir", default="./output", help="Output directory")
    parser.add_argument("--grib-dir", help="Directory with GRIB2 files")
    parser.add_argument("--geog-path", default="/mnt/geog", help="GEOG data path")
    parser.add_argument("--num-procs", type=int, default=1, help="MPI processes")
    parser.add_argument("--utc-offset", type=int, help="UTC offset (default: auto from domain center)")
    parser.add_argument("--start-hour", type=int, default=8, help="Earliest local hour to show")
    parser.add_argument("--target-cycle", help="Pin to specific cycle hour (e.g. 0 or 12), poll NOMADS until the needed forecast hours are available, then run. Replaces time-based --not-before.")
    parser.add_argument("--poll-interval-min", type=int, default=10, help="Minutes between NOMADS availability polls (default 10)")
    parser.add_argument("--poll-max-min", type=int, default=240, help="Max minutes to wait for cycle to become available (default 240)")
    parser.add_argument("--max-hours", type=int, help="Truncate simulation to N hours (for fast debug iterations)")
    args = parser.parse_args()

    run_pipeline(
        args.config,
        date=args.date,
        cycle=args.cycle,
        target_date=args.target_date,
        sites_csv=args.sites,
        output_dir=args.output_dir,
        grib_dir=args.grib_dir,
        geog_path=args.geog_path,
        num_procs=args.num_procs,
        utc_offset=args.utc_offset,
        start_hour=args.start_hour,
        target_cycle=args.target_cycle,
        poll_interval_min=args.poll_interval_min,
        poll_max_min=args.poll_max_min,
        max_hours=args.max_hours,
    )


if __name__ == "__main__":
    main()
