# Third-party material

What this repository vendors, why, and under what terms. Vendored means the file
is committed here rather than fetched at build time.

Nothing is vendored for convenience. Each entry below is here because fetching it
at render time was tried and failed, or because the build must not depend on a
third-party host being up.

| Path | What | Version | Licence |
|:--|:--|:--|:--|
| `style/font-awesome.min.css` | Font Awesome Free, stylesheet | 6.5.1 | MIT (code) |
| `style/webfonts/fa-*.woff2` | Font Awesome Free, the three font files | 6.5.1 | SIL OFL 1.1 (fonts); icons CC BY 4.0 |
| `style/vancouver.csl` | NLM/Vancouver citation style (citation-sequence) | CSL 1.0 | CC BY-SA 3.0 |

## Font Awesome

Vendored because **the CDN fallback does not work**. `bs4_book` loads its icons
from a Font Awesome kit URL that answers automated requests with HTTP 403, so a
build that relies on it ships a book with no icons anywhere and no error — which
is what happened, and what the render smoke test caught. The stylesheet and the
three `woff2` files are committed so the book's icons are a property of the
commit rather than of a third party's rate limiter.

Font Awesome Free is tri-licensed and all three parts apply here: the CSS is MIT,
the font files are SIL OFL 1.1, and the icon designs are CC BY 4.0. The
attribution the CC BY 4.0 icons require is the header comment inside
`font-awesome.min.css`, which is preserved verbatim and must stay there.

Upstream: <https://fontawesome.com/license/free>

## The Vancouver CSL style

Vendored because the book pins its bibliography style the same way it pins its
packages: a citation style that changes under a rendered book changes the book.
CC BY-SA 3.0, from the Citation Style Language project's repository. The
`<rights>` element inside the file carries the licence and is preserved.

Note the ShareAlike term. It attaches to the style file, not to the book: using
a CSL style to format citations is use, not adaptation. If the file is *modified*
the modified version must be shared under CC BY-SA 3.0, so any change to it
belongs upstream rather than here.

Upstream: <https://github.com/citation-style-language/styles>

## Not vendored, and deliberately

**Inter and JetBrains Mono** are loaded from Google Fonts at render time and are
also bundled by `bs4_book` under `libs/`. Both are SIL OFL 1.1. The book requests
them twice — once through `_output.yml`'s theme and once through a stylesheet
link — which is a performance defect recorded in `ROADMAP.md`, not a licensing
one.

**The R packages** are pinned in `renv.lock`, not vendored. Their licences are
their own; `packages.bib` cites the ones the book discusses in its own text, and
`renv.lock` names the exact version of every one of the 114 the book is built
against.

**The Fresh 68k PBMC dataset** is fetched, not redistributed. See `LICENSE-DATA.md`
and the external-data determination in `A2-datasets.Rmd`.

## What the book itself is under

Prose CC BY 4.0 (`LICENSE`), code MIT (`LICENSE-CODE.md`), generated data CC0
(`LICENSE-DATA.md`).
