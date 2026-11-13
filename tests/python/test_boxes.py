"""User-added formal boxes are rendered by Lean and saved as declaration references."""
from dataclasses import replace
import json
from pathlib import Path
import shutil
import tempfile
import threading
import urllib.request
import urllib.error
from _support import ROOT
from project import load_project
from serve import make_server

original = load_project()
if original.id != "basics":
    print("SKIP: interactive definition/theorem authoring is covered by the Basics fixture")
else:
    with tempfile.TemporaryDirectory(dir=ROOT / "build", prefix="box-test-") as directory:
        folder = Path(directory)
        notes = folder / "notes.json"
        notes.write_bytes(original.notes.read_bytes())
        output = folder / "output"
        shutil.copytree(original.output, output)
        project = replace(original, notes=notes, output=output)
        server = make_server(project)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = f"http://127.0.0.1:{server.server_port}"
        def get(route):
            return json.load(urllib.request.urlopen(base + route, timeout=300))
        def post(route, data):
            request = urllib.request.Request(base + route, data=json.dumps(data).encode(),
                headers={"Content-Type": "application/json", "Origin": base})
            try:
                return json.load(urllib.request.urlopen(request, timeout=300))
            except urllib.error.HTTPError as error:
                raise AssertionError(error.read().decode()) from error
        try:
            state = get("/api/explanations")
            info = get("/api/project")
            cases = [("definition", {"name": "Basics.double", "title": "My definition"}),
                     ("theorem", {**info["proofs"][0], "title": "My theorem box"})]
            for kind, spec in cases:
                compiled = post("/api/box", {"kind": kind, "spec": spec})
                assert compiled["report"]["name"] == spec["name"]
                state["cells"].append({"id": "test-" + kind, "kind": kind,
                    "source": json.dumps(spec), "rendered": "<script>untrusted client markup</script>"})
            state = post("/api/explanations", state)
            reloaded = get("/api/explanations")
            for cell in reloaded["cells"][-2:]:
                assert cell["kind"] in ("definition", "theorem")
                assert "untrusted client markup" not in cell["rendered"]
                assert cell["report"]["name"].startswith("Basics.")
            assert "rendered" not in notes.read_text(encoding="utf-8")
            assert project.source.read_bytes() == original.source.read_bytes()
            print("PASS: add definition and theorem boxes through real HTTP/Lean; save, reload, and discard client HTML")
        finally:
            server.shutdown()
            server.server_close()
