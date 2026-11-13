# Authoring a project

A project combines formal statements, a paper layout, authored notes, and an
explicit mapping from each statement to its separate proof file. Read
[Getting started](getting-started.md) to build an included project first.

## Add boxes in the document

Start the chosen project's local server. Alongside **+ Markdown**, use
**+ Definition** or **+ Theorem**. Enter the declaration's fully qualified
Lean name and the title you want readers to see. A theorem box also asks for
its proof file (relative to the project manifest) and exported proof declaration.
Existing configured mappings fill those fields automatically.

The declaration must already exist in the statements file. If you edit that
file, rebuild the project before adding boxes. Adding a box does not invent a
new mathematical definition or assert a theorem. Lean renders the selected
declaration, and a new theorem box starts **Not checked** until its play button
runs the mapped proof file.

Boxes are saved in the project's notes file and restored on reload. Use their
edit, move, and remove controls to arrange the document. Downloaded documents
preserve rendered formal boxes; adding formal boxes requires the local server.

## Project manifest

Create a project directory under `examples/` or another repository-contained
location. The included Basics project provides a minimal manifest:

```json
{
  "version": 1,
  "id": "basics",
  "title": "Adding zero",
  "source": "Statements.lean",
  "source_module": "Basics.Statements",
  "paper": "Paper.lean",
  "paper_module": "Basics.Paper",
  "notes": "notes.json",
  "output": "../../dist/basics",
  "statements": [
    {
      "name": "Basics.add_zero_statement",
      "title": "Adding zero leaves a natural number unchanged",
      "proof_file": "proofs/AddZero.lean",
      "proof_declaration": "Basics.Proofs.add_zero"
    }
  ]
}
```

Paths are relative to the manifest's directory. They must remain inside the
repository; input files must exist. Project IDs use lowercase letters, digits,
hyphens, or underscores and begin with a letter. Declaration and module names
use dotted Lean identifiers with ASCII letters, digits, underscores, or
apostrophes. Each statement name must be unique within a project.

The Lean module names must also be available through the project's Lake
configuration. Merely adding a filesystem path to a manifest does not install
a new external Lean package.

## Write statement-only input

Represent each displayed proposition as a closed definition of type `Prop`:

```lean
namespace Basics

def add_zero_statement : Prop := ∀ n : Nat, n + 0 = n

end Basics
```

All parameters are bound inside the proposition. This defines what the claim
says; it does not add an axiom or claim that a proof exists. The entire statement
module must compile, including its imports. PLAER does not slice declarations
out of an arbitrary broken source file.

Keep proof attempts out of that module. Put each independently checkable proof
in its own file, exporting the declaration named in the manifest. A proof file
may import the statement module and the mathematical dependencies it needs.
A play-button check must establish that its export proves the displayed
proposition.

## Map statements to proofs

Proof files currently use ordinary Lean import headers, as in the included
examples. The checker adds its import before the file and a final assertion
after it; it does not replace the proof body. The optional Lean `module` header
is not yet supported in proof files.

The included projects make the mapping explicit:

| Statement | Proof file | Exported declaration |
| --- | --- | --- |
| `Basics.add_zero_statement` | `examples/Basics/proofs/AddZero.lean` | `Basics.Proofs.add_zero` |
| `Fermat.last_statement` | `examples/Fermat/proofs/Last.lean` | `Fermat.Proofs.last` |
| `Fermat.little_statement` | `examples/Fermat/proofs/Little.lean` | `Fermat.Proofs.little` |

The Fermat last-theorem file is deliberately invalid. Its failure describes
that proof attempt, not the truth of Fermat's last theorem. Its separate file
must not prevent the little-theorem proof from being checked.

Compose the paper using the framework's statement blocks and only the
declarations listed by its manifest. Use the included `Paper.lean` files as
working examples. Then build the chosen project:

```sh
python scripts/build.py --project examples/Basics/project.json
python scripts/check.py --project examples/Basics/project.json
```

Use `python3` if that is your Python command.

## Inspect what gets checked

Open **Source & proof** on a statement to inspect its original source, exact proof
file, exported declaration, and generated checker command. The output directory
also contains `audit.json` and `checks/*.lean` files. Check those artifacts
when reviewing or changing a proof mapping.

Notation is registered in the framework's Lean renderer. Unsupported notation
fails rather than being guessed. Extend the appropriate LeanTeX registration
rules and add a rendering regression for new mathematical forms.

## Write application notes

Use **+ Markdown** and **Edit** with the local server, or edit the notes JSON
named in the manifest. Markdown supports `$...$` and `$$...$$` mathematics.

Useful notes explain:

- What the inputs and types represent.
- Which assumptions must hold.
- What the conclusion guarantees.
- Which object or constraint in your application corresponds to each symbol.
- A concrete example and a situation where an assumption fails.

These are authored explanations, separate from the formal statement. PLAER
does not infer application mappings or verify claims made in Markdown. See
[saving explanations](getting-started.md#keep-your-explanations) for the
difference between server and offline storage.
