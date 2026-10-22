"""GRIB downloader: .idx subsetting, throttling backoff, 404 fallback (fake HTTP server)."""

import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from rasp import pipeline

# Three fake GRIB records (the last one runs to EOF); the .idx selects the first and last.
REC = [b"GRIB" + bytes([i]) * 996 for i in range(3)]
BODY = b"".join(REC) + b"7777" * 300_000          # > 1 MB so a full download counts as valid
SUBSET = BODY[:1000] + BODY[2000:]
IDX = "\n".join(f"{i + 1}:{i * 1000}:d=2026102206:{var}:surface:anl:"
                for i, var in enumerate(["TMP", "UGRD", "HGT"])) + "\n"
PATTERNS = ["TMP:surface", "HGT:surface"]


class _Server:
    """Serves /f.grib2 and /f.grib2.idx; `script[path]` is a list of statuses to answer first."""

    def __init__(self):
        self.script = {}
        self.log = []
        self.has_idx = True
        outer = self

        class H(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *a):
                pass

            def do_HEAD(self):
                self.head = True
                self.do_GET()

            def do_GET(self):
                rng = self.headers.get("Range")
                outer.log.append((self.path, rng))
                queued = outer.script.get(self.path)
                if queued:
                    status = queued.pop(0)
                    if status == "reset":
                        self.close_connection = True
                        self.connection.shutdown(socket.SHUT_RDWR)
                        return
                    self.send_response(status)
                    if status == 302:
                        self.send_header("Location", "/busy.html")
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return
                if self.path == "/f.grib2.idx" and outer.has_idx:
                    data, status = IDX.encode(), 200
                elif self.path == "/f.grib2":
                    data, status = BODY, 200
                    if rng:
                        s, e = rng.split("=")[1].split("-")
                        data = BODY[int(s):(int(e) + 1 if e else None)]
                        status = 206
                else:
                    data, status = b"", 404
                self.send_response(status)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                if not getattr(self, "head", False):
                    self.wfile.write(data)

        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), H)
        self.url = f"http://127.0.0.1:{self.httpd.server_port}/f.grib2"
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def gets(self, path):
        return [r for p, r in self.log if p == path]


@pytest.fixture
def server():
    s = _Server()
    yield s
    s.httpd.shutdown()


@pytest.fixture
def sleeps(monkeypatch):
    waits = []
    monkeypatch.setattr(pipeline, "_sleep", waits.append)
    monkeypatch.delenv("RASP_DOWNLOAD_BACKOFF", raising=False)
    monkeypatch.delenv("RASP_IDX_SUBSET", raising=False)
    return waits


def test_200_subset_unchanged(server, sleeps, tmp_path):
    dest = tmp_path / "f.grib2"
    assert pipeline._fetch_grib(server.url, dest, PATTERNS)
    assert dest.read_bytes() == SUBSET
    assert server.gets("/f.grib2") == ["bytes=0-999", "bytes=2000-"]
    assert sleeps == []


def test_302_on_idx_then_200_backs_off(server, sleeps, tmp_path, capsys):
    server.script["/f.grib2.idx"] = [302, 503]
    dest = tmp_path / "f.grib2"
    assert pipeline._fetch_grib(server.url, dest, PATTERNS)
    assert dest.read_bytes() == SUBSET            # still a subset, no full-file fallback
    assert None not in server.gets("/f.grib2")
    assert len(sleeps) == 2
    assert 12 <= sleeps[0] <= 18 and 24 <= sleeps[1] <= 36
    out = capsys.readouterr().out
    assert "HTTP 302" in out and "HTTP 503" in out and "attempt 1/6" in out


def test_reset_on_range_retries(server, sleeps, tmp_path):
    server.script["/f.grib2"] = ["reset", 429]
    dest = tmp_path / "f.grib2"
    assert pipeline._fetch_grib(server.url, dest, PATTERNS)
    assert dest.read_bytes() == SUBSET
    assert len(sleeps) == 2


def test_persistent_503_fails_after_schedule(server, sleeps, tmp_path, capsys):
    server.script["/f.grib2.idx"] = [503] * 20
    dest = tmp_path / "f.grib2"
    assert not pipeline._fetch_grib(server.url, dest, PATTERNS)
    assert not dest.exists() and not (tmp_path / "f.grib2.part").exists()
    assert len(server.gets("/f.grib2.idx")) == 6
    assert server.gets("/f.grib2") == []                   # never fell back to the full file
    assert len(sleeps) == 5 and sum(sleeps) <= 600
    out = capsys.readouterr().out
    assert "ERROR: f.grib2 download failed" in out and "after 6 attempts" in out and "HTTP 503" in out


def test_404_idx_falls_back_to_full_file(server, sleeps, tmp_path):
    server.has_idx = False
    dest = tmp_path / "f.grib2"
    assert pipeline._fetch_grib(server.url, dest, PATTERNS)
    assert dest.read_bytes() == BODY
    assert server.gets("/f.grib2") == [None]
    assert sleeps == []


def test_idx_subset_off_downloads_full_file(server, sleeps, tmp_path, monkeypatch):
    monkeypatch.setenv("RASP_IDX_SUBSET", "0")
    dest = tmp_path / "f.grib2"
    assert pipeline._fetch_grib(server.url, dest, PATTERNS)
    assert dest.read_bytes() == BODY
    assert server.gets("/f.grib2.idx") == []


def test_full_file_302_is_retried_not_followed(server, sleeps, tmp_path, monkeypatch):
    monkeypatch.setenv("RASP_IDX_SUBSET", "0")
    server.script["/f.grib2"] = [302]
    dest = tmp_path / "f.grib2"
    assert pipeline._fetch_grib(server.url, dest, PATTERNS)
    assert dest.read_bytes() == BODY
    assert len(sleeps) == 1
    assert all(p != "/busy.html" for p, _ in server.log)


def test_full_file_404_fails_without_backoff(server, sleeps, tmp_path):
    dest = tmp_path / "g.grib2"
    assert not pipeline._fetch_grib(server.url.replace("f.grib2", "g.grib2"), dest)
    assert sleeps == []


def test_readiness_needs_200_and_idx(server, monkeypatch):
    monkeypatch.delenv("RASP_IDX_SUBSET", raising=False)
    cfg = {"url_pattern": server.url.replace("f.grib2", "{fhr}.grib2"), "idx_subset": PATTERNS}
    ready = lambda: pipeline._cycle_files_ready(cfg, "20261022", 6, ["f"])
    assert ready()
    server.has_idx = False                                  # GRIB up, sidecar not yet
    assert not ready()
    server.has_idx = True
    server.script["/f.grib2"] = [302]                       # throttled HEAD is not "present"
    assert not ready()
