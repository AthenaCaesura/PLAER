"""Exercise the actual local HTTP endpoint and Lean, without mocked results."""

from __future__ import annotations

import json
import threading
import time
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

from _support import ROOT
from serve import PaperHandler
from verify_proof import WARM_LEAN


def main() -> None:
    from verify_proof import documented_statements
    documented = documented_statements()
    assert WARM_LEAN.prepare()
    server = ThreadingHTTPServer(("127.0.0.1", 0), PaperHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://127.0.0.1:{server.server_port}"
    try:
        with urllib.request.urlopen(base + "/api/status", timeout=5) as response:
            assert json.load(response)["ready"]
        worker_pid = WARM_LEAN.process.pid
        timings = []
        for name, accepted in [("Plaer.fermat_last_statement", False),
                               ("Plaer.fermat_little", True),
                               ("Plaer.fermat_little", True)]:
            request = urllib.request.Request(
                base + "/api/verify", method="POST",
                data=json.dumps({"theorem": name}).encode(),
                headers={"Content-Type": "application/json", "Origin": base},
            )
            started = time.perf_counter()
            with urllib.request.urlopen(request, timeout=70) as response:
                result = json.load(response)
            timings.append(round((time.perf_counter() - started) * 1000))
            assert result["result"]["ok"] is accepted, result
            assert WARM_LEAN.process.pid == worker_pid, "A click restarted Lean"
            assert result["name"] == name
            assert "source" not in result and "reports" not in result
            assert "norm_num" not in json.dumps(result)
            assert result["statementLatex"] == documented[name]["statementLatex"]
            assert "statementLean" in result
            assert result["proofFile"] == "Plaer/Proofs.lean"
            print(f"PASS: external proof checked for {name}; no proof text returned", flush=True)
        unknown = urllib.request.Request(
            base + "/api/verify", method="POST",
            data=json.dumps({"theorem": "Plaer.not_in_the_document"}).encode(),
            headers={"Content-Type": "application/json", "Origin": base},
        )
        try:
            urllib.request.urlopen(unknown, timeout=10)
            raise AssertionError("An undocumented theorem was accepted")
        except urllib.error.HTTPError as error:
            assert error.code == 400
        hostile = urllib.request.Request(base + "/api/status", headers={"Origin": "https://example.com"})
        try:
            urllib.request.urlopen(hostile, timeout=5)
            raise AssertionError("Unexpected cross-origin access")
        except urllib.error.HTTPError as error:
            assert error.code == 403
        print("PASS: undocumented theorems and cross-origin requests rejected", flush=True)
        print(f"Warm HTTP checks (ms): {timings}; reused Lean PID {worker_pid}", flush=True)
    finally:
        server.shutdown()
        server.server_close()
        WARM_LEAN.close()


if __name__ == "__main__":
    main()
