"""The live server: read the document, edit it from the browser, check a proof."""
import json
import threading
import time
import urllib.error
import urllib.request
from _support import ROOT
from project import load_project
from serve import make_server

project = load_project()
original = project.paper.read_text(encoding="utf-8")
server = make_server(project)
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{server.server_port}"


def call(path, body=None):
    request = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())


def wait_for_compile():
    for _ in range(600):
        status, state = call("/api/document")
        assert status == 200, state
        if not state["compiling"]:
            return state
        time.sleep(0.5)
    raise AssertionError("Lean did not finish compiling")


try:
    status, state = call("/api/document")
    assert status == 200 and state["blocks"], state
    count = len(state["blocks"])
    statement = next(item for block in state["blocks"] for item in block.get("items", [])
                     if item["type"] == "declaration" and item["proofs"])

    # A prose box added in the browser lands in the paper and in the offline page.
    # (Prose added right after prose joins it: adjacent Markdown is one block.)
    status, added = call("/api/document", {"revision": state["revision"], "op": "insert", "index": count,
                                           "kind": "markdown", "text": "A note with $x^2$."})
    assert status == 200 and len(added["blocks"]) in (count, count + 1), added
    assert "A note with $x^2$." in project.paper.read_text(encoding="utf-8")
    assert "A note with $x^2$." in (project.output / "index.html").read_text(encoding="utf-8")

    # A Lean box saves at once, before Lean has compiled it, and shows as pending.
    started = time.perf_counter()
    status, pending = call("/api/document", {"revision": added["revision"], "op": "insert", "index": len(added["blocks"]),
                                             "kind": "lean", "text": "def Server.fresh (n : ℕ) : ℕ := n"})
    assert status == 200 and time.perf_counter() - started < 3, (status, time.perf_counter() - started)
    assert pending["compiling"] and pending["blocks"][-1].get("pending"), pending["blocks"][-1]
    assert "def Server.fresh" in project.paper.read_text(encoding="utf-8")
    compiled = wait_for_compile()
    assert compiled["revision"] == pending["revision"] and not compiled["blocks"][-1].get("pending")
    assert any(i.get("name") == "Server.fresh" for i in compiled["blocks"][-1]["items"]), compiled["blocks"][-1]

    # Lean that does not compile is saved too; the page then shows Lean's error, with the paper's line.
    status, broken = call("/api/document", {"revision": compiled["revision"], "op": "replace", "index": len(compiled["blocks"]) - 1,
                                            "text": "def Broken.statement : Prop := ∀ n : ℕ, n +"})
    assert status == 200, broken
    rejected = wait_for_compile()
    assert project.paper.name + ":" in (rejected["leanError"] or ""), rejected["leanError"]
    assert call("/api/verify", {"theorem": statement["name"], "proof": 0})[0] == 422
    status, added = call("/api/document", {"revision": rejected["revision"], "op": "remove", "index": len(rejected["blocks"]) - 1})
    assert status == 200 and wait_for_compile()["leanError"] is None

    # An edit against an out-of-date page is refused.
    assert call("/api/document", {"revision": state["revision"], "op": "remove", "index": 0})[0] == 400

    # Editing a box back restores the paper exactly.
    last = len(added["blocks"]) - 1
    request = ({"op": "remove", "index": last} if len(added["blocks"]) > count
               else {"op": "replace", "index": last, "text": state["blocks"][-1]["text"]})
    status, restored = call("/api/document", {"revision": added["revision"], **request})
    assert status == 200 and [b["text"] for b in restored["blocks"]] == [b["text"] for b in state["blocks"]]

    status, report = call("/api/verify", {"theorem": statement["name"], "proof": 0})
    assert status == 200 and report["statementHash"] == statement["statementHash"], report
    assert report["result"]["ok"] == statement["proofs"][0]["result"]["ok"]
    assert call("/api/verify", {"theorem": statement["name"], "proof": 99})[0] == 400
    print("PASS: server edits reach the paper, save before Lean compiles, Lean errors show, and a proof checks live")
finally:
    server.shutdown()
    project.paper.write_text(original, encoding="utf-8")
    from document import build_state
    from package_document import package_document
    package_document(project, build_state(project, run_proofs=False))
