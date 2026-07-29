knitr::opts_chunk$set(
  echo       = TRUE,
  eval       = FALSE,
  message    = FALSE,
  warning    = FALSE,
  cache      = FALSE,
  fig.align  = "center",
  fig.width  = 7,
  fig.height = 4.5,
  fig.retina = 2,
  dpi        = 300,
  out.width  = "90%",
  comment    = "#>"
)

options(
  scipen = 999,
  digits = 3,
  knitr.kable.NA = "—"
)

set.seed(42)

# NOTE — do not copy the tweak_part_screwup() no-op from methods-in-r.
# That volume patches bookdown::tweak_part_screwup() to a no-op, working around
# a crash in bookdown 0.46 (`xml_attr(parent, "class") == "row"` yields NA when
# the parent div has no class attribute). The bug is fixed in 0.47, and applying
# the patch here silently suppresses ALL part headings: "(PART) Part I — Folding"
# renders to nothing, in the sidebar and in the body. Verified by rendering both
# ways: 0 occurrences of "Part I" with the patch, 98 without it.
# If a future bookdown reintroduces the crash, guard the patch on
# packageVersion("bookdown") rather than restoring it unconditionally.

# ── Series conventions ──────────────────────────────────────────────────────
# One viridis option per volume, so figures stay visually separable when
# chapters from different books sit side by side.
#   strategy-in-r = "D"   scientometrics-in-r = "A"   folding-in-r = "C" (plasma)
scale_fill_book  <- function(...) viridis::scale_fill_viridis_d(option = "C", ...)
scale_color_book <- function(...) viridis::scale_color_viridis_d(option = "C", ...)
scale_colour_book <- scale_color_book

# Every stochastic result in this book is reported across seeds, never from a
# single run — t-SNE and UMAP are seed-dependent and one run is an anecdote.
# See "How to use this book".
N_SEEDS     <- 20L
BENCH_SEEDS <- 1000L + seq_len(N_SEEDS)

# Package bibliography, regenerated on every render so `packages.bib` never
# drifts from the loaded versions.
knitr::write_bib(
  c(.packages(), "bookdown", "knitr", "rmarkdown", "ggplot2", "viridis",
    "Rtsne", "umap", "igraph", "vegan", "Matrix", "RSpectra"),
  "packages.bib"
)
