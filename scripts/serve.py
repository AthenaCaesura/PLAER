"""Serve one chosen document; each play request compiles its configured proof file."""
from __future__ import annotations
import argparse
from functools import partial
import json
import os
from pathlib import Path
import subprocess
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from project import Project, load_project
from explanations import rendered_cells, save_cells
from boxes import render_box
from verify_proof import source_fingerprint, verify_theorem

class PaperHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".lean": "text/plain; charset=utf-8"}
    def __init__(self, *args, project: Project, **kwargs):
        self.project = project
        super().__init__(*args, directory=str(project.output), **kwargs)

    def reply_json(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def trusted_request(self):
        hosts = {f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"}
        origin = self.headers.get("Origin")
        return self.headers.get("Host") in hosts and (origin is None or origin in {"http://" + h for h in hosts})

    def build_status(self):
        data = json.loads((self.project.output / "build.json").read_text(encoding="utf-8"))
        ready = source_fingerprint(self.project) == data["source_fingerprint"]
        return {"ready": ready, "sourceReady": ready, "warming": False,
                "error": None if ready else "Statements changed; rebuild this project.",
                "leanVersion": data["lean_version"], "project": self.project.id}

    def do_GET(self):
        if not self.trusted_request():
            self.reply_json(403, {"error": "Local preview requests only"})
        elif self.path == "/api/status":
            self.reply_json(200, self.build_status())
        elif self.path == "/api/explanations":
            self.reply_json(200, rendered_cells(self.project))
        elif self.path == "/api/project":
            self.reply_json(200, {"source": Path(os.path.relpath(self.project.source, self.project.manifest.parent)).as_posix(),
                "sourceUrl": "sources/" + self.project.source.name,
                "proofs": [{**entry, "proof_file": Path(os.path.relpath(entry["proof_file"], self.project.manifest.parent)).as_posix()}
                           for entry in self.project.statements]})
        else:
            super().do_GET()

    def do_POST(self):
        if not self.trusted_request():
            self.reply_json(403, {"error": "Local preview requests only"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 262144 or self.headers.get_content_type() != "application/json":
                raise ValueError("Expected a small JSON request")
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict):
                raise ValueError("Expected a JSON object")
            if self.path == "/api/explanations":
                self.reply_json(200, save_cells(self.project, data))
            elif self.path == "/api/box":
                if not self.build_status()["sourceReady"]:
                    self.reply_json(409, {"error": "Statements changed. Rebuild before adding formal boxes."})
                    return
                if not self.server.proof_lock.acquire(blocking=False):
                    self.reply_json(409, {"error": "Lean is already compiling. Try again when it finishes."})
                    return
                try:
                    result = render_box(self.project, data.get("kind"), json.dumps(data.get("spec")))
                finally:
                    self.server.proof_lock.release()
                self.reply_json(200, result)
            elif self.path == "/api/verify":
                if not self.build_status()["sourceReady"]:
                    self.reply_json(409, {"error": "Statements changed. Rebuild this project."})
                    return
                if not self.server.proof_lock.acquire(blocking=False):
                    self.reply_json(409, {"error": "A proof file is already being checked."})
                    return
                try:
                    result = verify_theorem(self.project, data.get("theorem"))
                finally:
                    self.server.proof_lock.release()
                self.reply_json(200, result)
            else:
                self.reply_json(404, {"error": "Unknown endpoint"})
        except (ValueError, TypeError, json.JSONDecodeError) as error:
            self.reply_json(400, {"error": str(error)})
        except subprocess.TimeoutExpired:
            self.reply_json(408, {"error": "The Lean proof-file check timed out."})
        except RuntimeError as error:
            self.reply_json(500, {"error": str(error)})

def make_server(project: Project, port=0):
    server = ThreadingHTTPServer(("127.0.0.1", port), partial(PaperHandler, project=project))
    server.proof_lock = threading.Lock()
    return server

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project")
    parser.add_argument("--port", type=int, default=8767)
    args = parser.parse_args()
    project = load_project(args.project)
    server = make_server(project, args.port)
    print(f"PLAER — {project.title}: http://127.0.0.1:{args.port}/", flush=True)
    server.serve_forever()
