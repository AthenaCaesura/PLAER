"""Serve the paper and its actual local Lean verification endpoint."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

from verify_proof import ROOT, WARM_LEAN, verify_theorem
from explanations import read_cells, save_cells

VERIFY_LOCK = threading.Lock()


class PaperHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT / "dist"), **kwargs)

    def reply_json(self, status: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def trusted_request(self) -> bool:
        port = self.server.server_port
        hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
        if self.headers.get("Host") not in hosts:
            return False
        origin = self.headers.get("Origin")
        return origin is None or origin in {"http://" + host for host in hosts}

    def build_status(self) -> dict:
        provenance = json.loads((ROOT / "dist/build.json").read_text(encoding="utf-8"))
        source_hash = hashlib.sha256((ROOT / "Plaer/Definitions.lean").read_bytes()).hexdigest()
        source_ready = source_hash == provenance["source_sha256"]
        WARM_LEAN.start_warmup()
        return {"ready": source_ready and WARM_LEAN.ready,
                "sourceReady": source_ready, "warming": WARM_LEAN.warming,
                "error": WARM_LEAN.error,
                "leanVersion": provenance["lean_version"], "sourceHash": source_hash}

    def do_GET(self) -> None:
        if not self.trusted_request():
            self.reply_json(403, {"error": "Local preview requests only"})
        elif self.path == "/api/status":
            self.reply_json(200, self.build_status())
        elif self.path == "/api/explanations":
            self.reply_json(200, read_cells())
        else:
            super().do_GET()

    def do_POST(self) -> None:
        if not self.trusted_request():
            self.reply_json(403, {"error": "Local preview requests only"})
            return
        if self.path == "/api/explanations":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 262144 or self.headers.get_content_type() != "application/json":
                    raise ValueError("Expected a small JSON notebook")
                self.reply_json(200, save_cells(json.loads(self.rfile.read(length))))
            except (ValueError, TypeError, json.JSONDecodeError) as error:
                self.reply_json(400, {"error": str(error)})
            return
        if self.path != "/api/verify":
            self.reply_json(404, {"error": "Unknown endpoint"})
            return
        if not self.build_status()["sourceReady"]:
            self.reply_json(409, {"error": "The definition changed. Rebuild the paper before checking proofs."})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 8192 or self.headers.get_content_type() != "application/json":
                raise ValueError("Expected a small JSON verification request")
            request = json.loads(self.rfile.read(length))
            if not VERIFY_LOCK.acquire(blocking=False):
                self.reply_json(409, {"error": "Lean is checking another proof. Try again when it finishes."})
                return
            try:
                report = verify_theorem(request.get("theorem"))
            finally:
                VERIFY_LOCK.release()
            self.reply_json(200, report)
        except (ValueError, TypeError, json.JSONDecodeError) as error:
            self.reply_json(400, {"error": str(error)})
        except subprocess.TimeoutExpired:
            self.reply_json(408, {"error": "The Lean check exceeded 60 seconds"})
        except RuntimeError as error:
            self.reply_json(500, {"error": str(error)})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8767)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), PaperHandler)
    WARM_LEAN.start_warmup()
    print(f"Paper with live Lean checking: http://127.0.0.1:{args.port}/", flush=True)
    try:
        server.serve_forever()
    finally:
        WARM_LEAN.close()
