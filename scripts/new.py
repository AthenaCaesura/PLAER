"""Start a new paper, then open it in the browser.

    python scripts/new.py MyTopic
    python scripts/new.py MyTopic --title "Facts about primes" --no-serve

This creates examples/MyTopic/ with a Paper.md holding one statement, a proof
file for it, and the generated Statements.lean. It also registers the folder in
lakefile.toml. Then it starts the editor at http://127.0.0.1:8767/.
"""
from __future__ import annotations

import argparse
import os
import re
import sys

import paper
from project import ROOT

NAME = re.compile(r"[A-Z][A-Za-z0-9_]*\Z")

PAPER = """# {title}

```lean
import Mathlib.Data.Nat.Basic
import Plaer.Latex
```

Write notes in Markdown, with $...$ for mathematics. Every Lean declaration
becomes a box. Add more with **+ Theorem**, **+ Definition** and **+ Markdown**.

```lean
/-- Adding zero -/
def {name}.add_zero_statement : Prop := ∀ n : ℕ, n + 0 = n
-- proof: proofs/AddZero.lean {name}.Proofs.add_zero
```

For every natural number $n$, $n + 0 = n$. Press the play button to check the proof.
"""

PROOF = """import {name}.Statements

theorem {name}.Proofs.add_zero : {name}.add_zero_statement := by
  intro n
  rfl
"""


def register(lakefile: str, name: str) -> str:
    """Add a folder to the `roots` and `globs` lists of the Examples library."""
    section = re.search(r'\[\[lean_lib\]\]\nname = "Examples"\n(?:(?!\[\[).*\n?)*', lakefile)
    if section is None:
        raise ValueError('lakefile.toml has no lean_lib named "Examples"')
    text = section.group(0)

    def add(key: str, entry: str, text: str) -> str:
        line = re.search(rf'^{key} = \[(.*)\]$', text, re.M)
        if line is None:
            raise ValueError(f"The Examples library in lakefile.toml has no {key} list")
        entries = re.findall(r'"([^"]*)"', line.group(1))
        if entry not in entries:
            entries.append(entry)
        listed = ", ".join(f'"{e}"' for e in entries)
        return text[:line.start()] + f"{key} = [{listed}]" + text[line.end():]

    text = add("globs", f"{name}.+", add("roots", name, text))
    return lakefile[:section.start()] + text + lakefile[section.end():]


def create(name: str, title: str) -> "Path":
    if not NAME.match(name):
        raise ValueError(f"{name!r} names a Lean module, so use a capitalized identifier such as Primes")
    folder = ROOT / "examples" / name
    if folder.exists():
        raise ValueError(f"examples/{name} already exists")
    lakefile = ROOT / "lakefile.toml"
    updated = register(lakefile.read_text(encoding="utf-8"), name)

    (folder / "proofs").mkdir(parents=True)
    markdown = PAPER.format(title=title, name=name)
    (folder / "Paper.md").write_text(markdown, encoding="utf-8")
    (folder / "Statements.lean").write_text(paper.lean_source(markdown), encoding="utf-8")
    (folder / "proofs" / "AddZero.lean").write_text(PROOF.format(name=name), encoding="utf-8")
    lakefile.write_text(updated, encoding="utf-8")
    return folder / "Paper.md"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("name", help="Folder and Lean namespace, such as Primes")
    parser.add_argument("--title", help="The document title (default: the name)")
    parser.add_argument("--port", type=int, default=8767)
    parser.add_argument("--no-serve", action="store_true", help="Only create the files")
    args = parser.parse_args()
    try:
        created = create(args.name, args.title or args.name)
    except ValueError as error:
        sys.exit(str(error))
    print(f"Created {created.relative_to(ROOT)}", flush=True)
    if args.no_serve:
        print(f"Open it with: python scripts/serve.py {created.relative_to(ROOT).as_posix()}")
        return
    serve = ROOT / "scripts" / "serve.py"
    os.execv(sys.executable, [sys.executable, str(serve), str(created), "--port", str(args.port)])


if __name__ == "__main__":
    main()
