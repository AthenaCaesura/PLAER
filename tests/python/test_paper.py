"""The paper format: blocks, the line-for-line Lean file, and browser edits. No Lean needed."""
from _support import ROOT
import paper
import new

MARKDOWN = """# Title

Prose with `code`.

```lean
import Mathlib

/-- A statement -/
def Demo.statement : Prop := True
-- proof: proofs/Demo.lean Demo.Proofs.trivial
```

```lean ignore
this sample is not compiled
```
"""

blocks = paper.parse(MARKDOWN)
assert [b.kind for b in blocks] == ["markdown", "lean", "markdown"], blocks
assert blocks[1].line == 6 and blocks[1].text.startswith("import Mathlib")
assert paper.title(blocks, "fallback") == "Title"

# Line N of the paper is line N of the Lean file, and only lean blocks are code.
lean = paper.lean_source(MARKDOWN).splitlines()
source = MARKDOWN.splitlines()
assert len(lean) == len(source)
assert lean[0] == "-- # Title" and lean[5:10] == source[5:10]
assert lean[12] == "-- ```lean ignore" and lean[13].startswith("-- this sample")
assert paper.PROOF_LINE.match(source[9]).groups() == ("proofs/Demo.lean", "Demo.Proofs.trivial")

# Editing prose leaves the Lean fingerprint alone; editing Lean changes it.
fingerprint = paper.lean_fingerprint(blocks)
edited = paper.edit(blocks, {"op": "replace", "index": 0, "text": "# New title"})
assert paper.lean_fingerprint(edited) == fingerprint and paper.title(edited, "") == "New title"
edited = paper.edit(blocks, {"op": "replace", "index": 1, "text": "def x := 1"})
assert paper.lean_fingerprint(edited) != fingerprint

# Editing one declaration in its box replaces only that declaration's lines.
three = [paper.Block("lean", "def a := 1\ndef b := 2\n-- proof: proofs/B.lean B.p\ndef c := 3")]
edited = paper.edit(three, {"op": "replace_lines", "index": 0, "start": 1, "count": 1, "text": "def b := 20\n"})
assert edited[0].text == "def a := 1\ndef b := 20\n-- proof: proofs/B.lean B.p\ndef c := 3", edited[0].text
for bad in [{"start": 3, "count": 2}, {"start": -1, "count": 1}, {"start": 0, "count": 0}, {"start": True, "count": 1}]:
    try:
        paper.edit(three, {"op": "replace_lines", "index": 0, "text": "def z := 0", **bad})
    except ValueError:
        continue
    raise AssertionError(f"accepted {bad}")

# Imports stay first: a move or insert that would put Lean above them is refused.
headed = paper.parse("# T\n\n```lean\nimport Mathlib\n```\n\n```lean\ndef a := 1\n```\n")
for bad in [{"op": "move", "index": 1, "offset": 1}, {"op": "insert", "index": 0, "kind": "lean", "text": "def b := 2"}]:
    try:
        paper.edit(headed, bad)
    except ValueError:
        continue
    raise AssertionError(f"accepted {bad}")
assert paper.edit(headed, {"op": "move", "index": 0, "offset": 1})[1].kind == "markdown"   # prose may move above

# Markdown cells stay separate: moving one next to another keeps two cells.
two = paper.parse("# A\n\n```lean\ndef a := 1\n```\n\nSecond.\n")
moved = paper.parse(paper.serialize(paper.edit(two, {"op": "move", "index": 2, "offset": -1})))
assert [(b.kind, b.text) for b in moved] == [("markdown", "# A"), ("markdown", "Second."), ("lean", "def a := 1")], moved
assert paper.lean_source(paper.serialize(moved)).count("-- " + paper.CELL_BREAK) == 1

# Every edit can be written to the Markdown file and read back unchanged.
for request in [{"op": "insert", "index": 3, "kind": "lean", "text": "def y := 2"},
                {"op": "move", "index": 0, "offset": 1}, {"op": "remove", "index": 2}]:
    written = paper.serialize(paper.edit(blocks, request))
    assert paper.serialize(paper.parse(written)) == written, request
    assert "\n".join(b.text for b in paper.parse(written) if b.kind == "lean").count("def") >= 1

for bad in [{"op": "replace", "index": 1, "text": "```\nx\n```"}, {"op": "replace", "index": 0, "text": "```lean\nx\n```"},
            {"op": "move", "index": 0, "offset": -1}, {"op": "remove", "index": 9}, {"op": "replace", "index": 0, "text": " "}]:
    try:
        paper.edit(blocks, bad)
    except ValueError:
        continue
    raise AssertionError(f"accepted {bad}")

# The checked-in Lean files are exactly what their papers generate.
for folder in sorted((ROOT / "examples").iterdir()):
    if (folder / "Paper.md").exists():
        expected = paper.lean_source((folder / "Paper.md").read_text(encoding="utf-8"))
        assert (folder / "Statements.lean").read_text(encoding="utf-8") == expected, folder.name
# A new paper is registered in the Examples library, once.
lakefile = (ROOT / "lakefile.toml").read_text(encoding="utf-8")
registered = new.register(lakefile, "Primes")
assert 'roots = ["Basics", "Fermat", "Primes"]' in registered and '"Primes.+"]' in registered, registered
assert new.register(registered, "Primes") == registered
assert registered.count("Primes") == 2 and "TestFixtures" in registered
template = new.PAPER.format(title="T", name="Primes")
assert [b.kind for b in paper.parse(template)].count("lean") == 2
assert next(paper.PROOF_LINE.match(l) for l in template.splitlines() if l.startswith("-- proof")).groups() == ("proofs/AddZero.lean", "Primes.Proofs.add_zero")

print("PASS: paper blocks, line-for-line Lean file, edits, and generated Statements.lean files")
