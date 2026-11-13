"""Verify real proof-file compilation through the HTTP endpoint."""
from functools import partial
import json
import threading
import urllib.error
import urllib.request
from _support import ROOT
from project import load_project
from serve import make_server
from verify_proof import documented_statements

def main():
    project = load_project()
    expected = documented_statements(project)
    server = make_server(project)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_port}"
    try:
        assert json.load(urllib.request.urlopen(base + "/api/status"))["ready"]
        for entry in project.statements:
            name = entry["name"]
            request = urllib.request.Request(base + "/api/verify",
                data=json.dumps({"theorem": name}).encode(),
                headers={"Content-Type": "application/json", "Origin": base})
            result = json.load(urllib.request.urlopen(request, timeout=300))
            assert result["name"] == name
            assert result["result"]["ok"] is expected[name]["result"]["ok"], result
            assert result["proofFile"] == entry["proof_file"].relative_to(ROOT).as_posix()
            assert result["proofDeclaration"] == entry["proof_declaration"]
            assert result["statementHash"] == expected[name]["statementHash"]
            checker = (project.output / result["checkerUrl"]).read_text(encoding="utf-8")
            assert entry["proof_file"].read_text(encoding="utf-8") in checker
            assert f"#plaer_check_proof {name} {entry['proof_declaration']}" in checker
            assert "source" not in result
            print("PASS: play compiles the corresponding proof file:", name, flush=True)
        for url, data, headers, code in [
            ("/api/verify", {"theorem": "Not.Displayed"}, {"Content-Type": "application/json", "Origin": base}, 400),
            ("/api/status", None, {"Origin": "https://example.com"}, 403)]:
            request = urllib.request.Request(base + url, data=None if data is None else json.dumps(data).encode(), headers=headers)
            try:
                urllib.request.urlopen(request, timeout=10)
                raise AssertionError("Unexpected request accepted")
            except urllib.error.HTTPError as error:
                assert error.code == code
    finally:
        server.shutdown()
        server.server_close()

if __name__ == "__main__":
    main()
