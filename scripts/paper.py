"""A PLAER paper: one Markdown file whose ```lean blocks are the statements.

The Lean file that gets compiled is the paper with every line outside a lean
block commented out, so line N of the paper is line N of the Lean file.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import re

LEAN_FENCE = re.compile(r"```lean\s*")
# Inside a lean block, `-- proof: proofs/File.lean Namespace.declaration`
# attaches a proof to the statement above it.
PROOF_LINE = re.compile(r"\s*--\s*proof:\s*(\S+)\s+(\S+)\s*$")
# Between two Markdown cells, so they stay two cells. Invisible when rendered.
CELL_BREAK = "<!-- cell -->"


@dataclass
class Block:
    kind: str       # "markdown" or "lean"
    text: str       # for lean, the code between the fences
    line: int = 0   # line number in the paper of the first line of `text`


def parse(markdown: str) -> list[Block]:
    """Split a paper into Markdown and Lean blocks.

    Only a fence that says exactly ```lean is compiled. Any other fenced code,
    including ```lean ignore, stays in the Markdown as a sample.
    """
    lines = markdown.splitlines()
    spans, kind, start = [], "markdown", 0
    for index, line in enumerate(lines):
        if kind == "markdown" and line.strip() == CELL_BREAK:
            spans.append(("markdown", start, index))
            start = index + 1
        elif kind == "markdown" and LEAN_FENCE.fullmatch(line):
            spans.append(("markdown", start, index))
            kind, start = "lean", index + 1
        elif kind == "lean" and line.strip() == "```":
            spans.append(("lean", start, index))
            kind, start = "markdown", index + 1
    spans.append((kind, start, len(lines)))
    blocks = []
    for kind, start, end in spans:
        while start < end and not lines[start].strip():
            start += 1
        while end > start and not lines[end - 1].strip():
            end -= 1
        if start < end:
            blocks.append(Block(kind, "\n".join(lines[start:end]), start + 1))
    return blocks


def serialize(blocks: list[Block]) -> str:
    """Write blocks back out as a paper."""
    parts = []
    for index, block in enumerate(blocks):
        if index and block.kind == "markdown" and blocks[index - 1].kind == "markdown":
            parts.append(CELL_BREAK)
        parts.append(f"```lean\n{block.text}\n```" if block.kind == "lean" else block.text)
    return "\n\n".join(parts) + "\n"


def lean_source(markdown: str) -> str:
    """The Lean file for a paper, line for line."""
    out, in_lean = [], False
    for line in markdown.splitlines():
        if not in_lean and LEAN_FENCE.fullmatch(line):
            in_lean = True
            out.append("-- " + line)
        elif in_lean and line.strip() == "```":
            in_lean = False
            out.append("-- " + line)
        else:
            out.append(line if in_lean or not line.strip() else "-- " + line)
    return "\n".join(out) + "\n"


def lean_fingerprint(blocks: list[Block]) -> str:
    """Changes exactly when some Lean changes. Editing prose leaves it alone."""
    code = [block.text for block in blocks if block.kind == "lean"]
    return hashlib.sha256(json.dumps(code).encode()).hexdigest()


def title(blocks: list[Block], fallback: str) -> str:
    """The paper's first `# heading`."""
    for block in blocks:
        if block.kind == "markdown":
            for line in block.text.splitlines():
                if line.startswith("# "):
                    return line[2:].strip()
    return fallback


def imports_first(blocks: list[Block]) -> bool:
    """Lean needs every `import` before any other Lean in the paper."""
    seen_code = False
    for block in blocks:
        if block.kind != "lean":
            continue
        for line in block.text.split("\n"):
            stripped = line.strip()
            if not stripped or stripped.startswith("--"):
                continue
            if re.match(r"import\s", stripped):
                if seen_code:
                    return False
            else:
                seen_code = True
    return True


def edit(blocks: list[Block], request: dict) -> list[Block]:
    """Apply one editing operation from the browser; return the new blocks."""
    edited = _apply(blocks, request)
    if imports_first(blocks) and not imports_first(edited):
        raise ValueError("Imports must come before all other Lean, so that box stays at the top")
    return edited


def _apply(blocks: list[Block], request: dict) -> list[Block]:
    op, index = request.get("op"), request.get("index")
    blocks = list(blocks)
    if not isinstance(index, int) or isinstance(index, bool):
        raise ValueError("Choose a box")
    if op == "insert":
        kind = request.get("kind")
        if kind not in ("markdown", "lean"):
            raise ValueError("A new box is Markdown or Lean")
        if not 0 <= index <= len(blocks):
            raise ValueError("Choose a position in the document")
        blocks.insert(index, Block(kind, _clean(kind, request.get("text"))))
        return blocks
    if not 0 <= index < len(blocks):
        raise ValueError("That box no longer exists. Reload the document.")
    if op == "replace":
        blocks[index] = Block(blocks[index].kind, _clean(blocks[index].kind, request.get("text")))
    elif op == "replace_lines":
        # Edit one declaration inside a lean block: lines [start, start + count).
        start, count, text = request.get("start"), request.get("count"), request.get("text")
        lines = blocks[index].text.split("\n")
        if blocks[index].kind != "lean" or not isinstance(text, str):
            raise ValueError("Only Lean declarations are edited this way")
        if not all(isinstance(n, int) and not isinstance(n, bool) for n in (start, count)) \
                or start < 0 or count < 1 or start + count > len(lines):
            raise ValueError("That declaration moved. Reload the document.")
        replacement = text.replace("\r\n", "\n").strip("\n").split("\n") if text.strip() else []
        joined = "\n".join(lines[:start] + replacement + lines[start + count:])
        blocks[index] = Block("lean", _clean("lean", joined))
    elif op == "remove":
        del blocks[index]
    elif op == "move":
        offset = request.get("offset")
        if offset not in (-1, 1) or not 0 <= index + offset < len(blocks):
            raise ValueError("That box cannot move further")
        blocks[index], blocks[index + offset] = blocks[index + offset], blocks[index]
    else:
        raise ValueError("Unknown edit")
    return blocks


def _clean(kind: str, text: object) -> str:
    if not isinstance(text, str) or not text.strip():
        raise ValueError("A box cannot be empty. Remove it instead.")
    if len(text) > 30000:
        raise ValueError("Keep each box under 30000 characters")
    text = text.replace("\r\n", "\n").strip("\n")
    fences = [line for line in text.splitlines() if line.startswith("```")]
    if kind == "lean" and fences:
        raise ValueError("Write the Lean without ``` fences")
    if kind == "markdown" and (len(fences) % 2 or any(LEAN_FENCE.fullmatch(f) for f in fences)):
        raise ValueError("Close every ``` fence. For Lean that should be checked, add a "
                         "Definition or Theorem box; for a sample, write ```lean ignore")
    return text
