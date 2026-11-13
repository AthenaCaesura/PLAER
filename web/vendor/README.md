# Vendored browser libraries

`scripts/package_document.py` inlines these into every document, so a document
is one self-contained HTML file that works offline.

| File | Package | License |
| --- | --- | --- |
| `katex.min.js`, `katex.css` | [KaTeX](https://katex.org) 0.16.22 | MIT, see `katex.LICENSE` |
| `marked.min.js` | [marked](https://marked.js.org) 15.0.12 | MIT, see `marked.LICENSE.md` |

`katex.css` is KaTeX's `dist/katex.min.css` with each `fonts/*.woff2` file
replaced by a `data:` URI and the `.woff`/`.ttf` fallbacks removed. The other
files are unmodified copies from the npm packages.
