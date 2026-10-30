# Maintenance review — 30 October 2026

## Scope and acceptance criteria

Preserve the book's scientific data and benchmark provenance while making the
existing developed material reproducible and accurately scoped. A complete
submission is not the acceptance criterion for this increment: Chapters 7 and
12 remain explicitly unfinished. The working 0.1 material must render, retain
its geometry/metric checks, resolve local links, and expose a working interactive
folding figure. Standalone foldbenchR is revived separately, as requested.

## Findings and completed repairs

- Medium, `scripts/build-fold-figure.R`: the exact sync gate falsely failed for
  IEEE negative zero versus positive zero in otherwise identical geometry.
  Canonicalize numeric zero before JSON output. The byte-level check remains;
  a regression confirms that a real changed coordinate still fails.
- Medium, `_common.R`: absent required helpers silently entered an obsolete
  scaffold mode. Missing helpers now stop the render before scientific output.
- Medium, chapter 5: an escaped cross-reference inside a block engine became a
  nonexistent citation `ref`. Use a chapter link that survives both HTML/EPUB.
- README distinguishes ten developed chapters from two outlines, documents the
  local build evidence, and preserves book-helper and standalone-package roles.

## Verification

R 4.6.1 on macOS arm64. Existing helper tests passed (101.71 s); added figure-sync
regressions passed (1.49 s). Chapter lint passed with the two known outline
warnings. Artifact-producer and visual contrast gates passed; the existing ten
seed-design exceptions remain explicit. Committed benchmark files were not
regenerated or replaced.

Initial HTML failed for missing Rtsne; after installing dependencies it passed.
The final HTML build passed in 457.59 s. EPUB passed in 192.26 s; its ZIP and XML
integrity checks passed (78 entries, 27 XHTML documents). All 1,751 local links,
assets and anchors in 25 HTML files resolve. Chromium exercised the home page,
flat and folded slider endpoints, and view reset with no page errors. The final
interactive figure was visually inspected. This browser check does not certify
every occlusion configuration or independently prove geometry-renderer parity.

## Remaining roadmap

Essential for a complete manuscript: finish the learned-fold chapter with a
qualified backend and the real-data application with documented data permissions,
provenance and validation. Preserve the current scientific claims while doing so.
Next validate the pinned environment and PDF on a TeX-equipped machine; no PDF,
remote CI, submission or public deployment was performed here. Future work may
broaden embedding/noise regimes after these chapters are complete.

For the current draft, follow README to render HTML/EPUB and open docs/index.html.
Review/integrate this candidate branch before publishing it. The repository is
locally usable as a clearly marked draft, not a completed scientific submission.
