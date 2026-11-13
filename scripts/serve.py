"""Serve one paper for reading, live proof checks, and editing in the browser.

    python scripts/serve.py examples/Fermat/Paper.md

Each play button compiles its attached proof file. Edits made in the browser
are written to the paper at once and Lean compiles them in the background; edits
made to the paper in a text editor appear when the page is reloaded.
"""
from __future__ import annotations

import argparse
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import subprocess
import sys
import threading

import paper
from document import (LeanRejected, Results, StaleSource, build_state, build_statements,
                      engine_fingerprint, find_proof, proof_key, statements_built)
from package_document import package_document
from project import Project, load_project
from verify_proof import check_proof


def revision(project: Project) -> str:
    return hashlib.sha256(project.paper.read_bytes()).hexdigest()


def current(server) -> dict:
    """The document as the page sees it, with whether Lean is still catching up."""
    return {**server.state, "compiling": not server.state["compiled"] and server.lean_error is None,
            "leanError": server.lean_error}


def refresh(server) -> dict:
    """Rebuild the document from the paper without running Lean, then let Lean catch up.

    Boxes whose Lean is unchanged keep their rendering; new or changed Lean shows
    as code until the background compile finishes.
    """
    with server.state_lock:
        server.state = build_state(server.project, run_proofs=False, compile=False)
        server.lean_error = None
        package_document(server.project, server.state)
    if not server.state["compiled"]:
        server.wanted.set()
    return current(server)


def compile_now(server) -> None:
    """Compile the paper's Lean and publish the result. Call with the Lean lock held."""
    project = server.project
    while True:
        server.wanted.clear()
        started = revision(project)
        try:
            state, error = build_state(project, run_proofs=False), None
        except StaleSource:
            continue          # an edit landed mid-compile; compile the new paper
        except LeanRejected as rejected:
            state, error = None, str(rejected)
        except (RuntimeError, subprocess.TimeoutExpired) as failure:
            state, error = None, str(failure) or "Lean timed out."
        with server.state_lock:
            if revision(project) != started:
                continue
            if state is not None:
                server.state = state
                package_document(project, state)
            server.lean_error = error
            return


def compiler(server) -> None:
    """Background worker: whenever an edit leaves Lean behind, compile."""
    while True:
        server.wanted.wait()
        with server.lean_lock:
            if server.wanted.is_set():
                compile_now(server)


def apply_edit(server, request: dict) -> dict:
    """Write one browser edit into the paper right away. Lean compiles afterwards."""
    project = server.project
    with server.state_lock:
        before = project.paper.read_text(encoding="utf-8")
        if request.get("revision") != revision(project):
            raise ValueError("The paper changed on disk. Reload the page before editing.")
        blocks = paper.edit(paper.parse(before), request)
        project.paper.write_text(paper.serialize(blocks), encoding="utf-8")
    return refresh(server)


def verify(server, request: dict) -> dict:
    """Check one attached proof now, and remember the result."""
    project = server.project
    with server.lean_lock:
        if server.state["revision"] != revision(project):
            raise ValueError("The paper changed on disk. Reload the page.")
        if not server.state["compiled"]:
            compile_now(server)
            if server.lean_error:
                raise LeanRejected(server.lean_error)
        if not statements_built(project):
            build_statements(project)   # proofs import the paper's compiled Lean
        statement, proof = find_proof(server.state, request.get("theorem"), request.get("proof"))
        report = check_proof(project, statement, proof)
        with server.state_lock:
            blocks = paper.parse(project.paper.read_text(encoding="utf-8"))
            Results(project, paper.lean_fingerprint(blocks) + engine_fingerprint()).put(proof_key(statement, proof), report)
            proof.update(report)
            package_document(project, server.state)
    return report


class PaperHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".lean": "text/plain; charset=utf-8",
                      ".md": "text/plain; charset=utf-8"}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.server_project.output), **kwargs)

    def log_message(self, *args):
        pass

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

    def answer(self, work):
        """Run one request and turn its failures into replies."""
        try:
            self.reply_json(200, work())
        except LeanRejected as error:
            self.reply_json(422, {"error": "Lean rejected this:\n\n" + str(error)})
        except (ValueError, TypeError, json.JSONDecodeError) as error:
            self.reply_json(400, {"error": str(error)})
        except subprocess.TimeoutExpired:
            self.reply_json(408, {"error": "Lean timed out."})
        except RuntimeError as error:
            self.reply_json(500, {"error": str(error)})

    def do_GET(self):
        server = self.server
        if not self.trusted_request():
            self.reply_json(403, {"error": "Local preview requests only"})
        elif self.path == "/api/document":
            # Pick up edits made to the paper outside the browser.
            self.answer(lambda: current(server) if server.state["revision"] == revision(server.project)
                        else refresh(server))
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
        except (ValueError, json.JSONDecodeError) as error:
            self.reply_json(400, {"error": str(error)})
            return
        if self.path == "/api/document":
            self.answer(lambda: apply_edit(self.server, data))
        elif self.path == "/api/verify":
            self.answer(lambda: verify(self.server, data))
        else:
            self.reply_json(404, {"error": "Unknown endpoint"})


def make_server(project: Project, port: int = 0) -> ThreadingHTTPServer:
    handler = type("Handler", (PaperHandler,), {"server_project": project})
    server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    server.project = project
    server.lean_lock = threading.Lock()     # one Lean job at a time
    server.state_lock = threading.Lock()    # the paper file and the document state
    server.wanted = threading.Event()       # set when the Lean is ahead of the last compile
    refresh(server)
    with server.lean_lock:
        compile_now(server)
    threading.Thread(target=compiler, args=(server,), daemon=True).start()
    return server


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paper", nargs="?", help="A Paper.md or its folder (default: $PLAER_PROJECT)")
    parser.add_argument("--project", help=argparse.SUPPRESS)
    parser.add_argument("--port", type=int, default=8767)
    args = parser.parse_args()
    try:
        project = load_project(args.paper or args.project)
        print(f"Compiling {project.paper.name} with Lean…", flush=True)
        server = make_server(project, args.port)
    except LeanRejected as error:
        sys.exit(f"Lean rejected the paper:\n\n{error}")
    except ValueError as error:
        sys.exit(str(error))
    except OSError:
        sys.exit(f"Port {args.port} is already in use, probably by another PLAER server. "
                 f"Stop that one, or add --port {args.port + 1}.")
    if server.lean_error:
        print(f"Lean rejected the paper; the page shows why:\n\n{server.lean_error}", flush=True)
    print(f"PLAER — {server.state['title']}: http://127.0.0.1:{args.port}/", flush=True)
    server.serve_forever()
