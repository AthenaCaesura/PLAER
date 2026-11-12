"""Check notebook persistence and conflicts over the actual HTTP route."""

import json
import tempfile
import threading
import urllib.error
import urllib.request
from pathlib import Path
from http.server import ThreadingHTTPServer

import explanations
import package_document
from serve import PaperHandler


def main():
    original_file = explanations.CELL_FILE
    original_package = package_document.package_document
    calls = []
    with tempfile.TemporaryDirectory() as directory:
        try:
            explanations.CELL_FILE = Path(directory) / "cells.json"
            explanations.CELL_FILE.write_bytes(original_file.read_bytes())
            package_document.package_document = lambda: calls.append("packaged")
            server = ThreadingHTTPServer(("127.0.0.1", 0), PaperHandler)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            base = f"http://127.0.0.1:{server.server_port}"
            state = json.load(urllib.request.urlopen(base + "/api/explanations"))
            state["cells"][0]["source"] = "An **editable** explanation with $x \\in I$."

            def post(data, origin=base):
                request = urllib.request.Request(base + "/api/explanations",
                    data=json.dumps(data).encode(), headers={"Content-Type": "application/json", "Origin": origin})
                return json.load(urllib.request.urlopen(request))

            updated = post(state)
            assert updated["revision"] != state["revision"]
            assert explanations.read_cells()["cells"][0]["source"] == state["cells"][0]["source"]
            assert calls == ["packaged"]
            for request, code, origin in [(state, 400, base),
                    ({**updated, "cells": [{"id": "bad", "kind": "python", "source": "pass"}]}, 400, base),
                    (updated, 403, "https://example.com")]:
                try:
                    post(request, origin)
                    raise AssertionError("Invalid notebook update accepted")
                except urllib.error.HTTPError as error:
                    assert error.code == code
            print("PASS: edits persist; packaging triggered; stale writes, Python cells, and cross-origin writes rejected")
        finally:
            if "server" in locals():
                server.shutdown()
                server.server_close()
            explanations.CELL_FILE = original_file
            package_document.package_document = original_package


if __name__ == "__main__":
    main()
