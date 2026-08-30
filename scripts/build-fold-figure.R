#!/usr/bin/env Rscript
#
# Rebuild the geometry block inside js/fold-figure.html.
#
# The interactive figure is hand-written HTML and CSS, but the numbers it draws
# are not: `window.__FOLD_GEOM__` is generated here, from the same miura_ori()
# and fold() the rest of the book uses. The JavaScript renders; it does not know
# what a crease pattern is and so cannot get one wrong.
#
# This script exists because the geometry block had no producer. When the
# mountain/valley derivation was corrected (ROADMAP.md item 0.1) the figure was
# still drawing the retired parity rule, solid for mountain and dashed for
# valley, and nothing in the repository could regenerate it. An artefact with no
# producer cannot be corrected -- only replaced by hand, which is how it came to
# disagree with the code in the first place.
#
# Usage:
#   Rscript scripts/build-fold-figure.R           # rewrite the block in place
#   Rscript scripts/build-fold-figure.R --check   # exit 1 if it is out of date
#
# --check is what CI runs: it regenerates into memory and compares, so a change
# to patterns.R or folding.R that moves the figure fails the build rather than
# leaving a stale figure in the book.

suppressWarnings(suppressMessages({
  ok <- requireNamespace("jsonlite", quietly = TRUE)
}))
if (!ok) stop("jsonlite is required to build the figure geometry", call. = FALSE)

args <- commandArgs(trailingOnly = TRUE)
check_only <- "--check" %in% args

root <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=",
          commandArgs(FALSE), value = TRUE)[1])), ".."), mustWork = TRUE)
for (f in sort(list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE))) {
  source(f)
}

HTML   <- file.path(root, "js", "fold-figure.html")
NX     <- 4L
NY     <- 4L
THETAS <- seq(0, 0.95, by = 0.05)
NAME   <- "Miura-ori"

# ── Geometry ────────────────────────────────────────────────────────────────

p <- miura_ori(NX, NY)

# Rounded to six decimals in R -- matching figure_geometry(), which the static
# panels go through -- and then serialised at five, which is what the shipped
# figure was. Both numbers are here rather than one because they are not
# interchangeable: round() takes a tie to even, jsonlite takes it away from zero,
# and rounding once at five would move 372 of this figure's coordinates by a unit
# in the last place against the file it is meant to reproduce. Five decimals on a
# unit-radius figure is well under a hundredth of a pixel at any size it is drawn.
#
# The isometry error is passed unrounded: at 1e-16, rounding it would report the
# figure as exactly isometric, which is a stronger claim than the one being made.
DP     <- 6L    # in R, as figure_geometry() does
DIGITS <- 5L    # on the wire

flat_raw <- lapply(p$facets, function(v) p$vertices[v, , drop = FALSE])
cflat    <- colMeans(do.call(rbind, flat_raw))
rf       <- max(sqrt(rowSums(sweep(do.call(rbind, flat_raw), 2, cflat)^2)))

# Each frame is centred on its own centroid and scaled to unit radius, which is
# what the figure already shipped: it keeps the sheet the same size on screen as
# it folds. The contraction is Chapter 2's subject and gets its own static
# figures; here a shrinking sheet would only make the animation harder to read.
frame <- function(P_list) {
  all <- do.call(rbind, P_list)
  ctr <- colMeans(all)
  rad <- max(sqrt(rowSums(sweep(all, 2, ctr)^2)))
  lapply(P_list, function(P) round(sweep(P, 2, ctr) / rad, DP))
}

states <- lapply(THETAS, function(th) {
  V3 <- fold(p, th)$vertices3
  lapply(frame(lapply(p$facets, function(v) V3[v, , drop = FALSE])),
         function(P) unname(as.data.frame(P)))
})

# Isometry is asserted at build time, over every frame. A figure whose flat
# panel is not the exact unfolding of its folded panel would be making the
# book's central claim and quietly breaking it.
worst <- max(vapply(THETAS, function(th) facet_isometry_error(p, th), numeric(1)))
if (worst > 1e-9) {
  stop("the folded states are not isometric to the flat sheet (worst ",
       format(worst), "). Refusing to build a figure that contradicts the book.",
       call. = FALSE)
}

# The mountain/valley labels the figure draws come from the pattern, and the
# pattern's labels are checked against the folded geometry by
# tests/testthat/test-crease-assignment.R. Re-derive here anyway: this script is
# the last point at which a stale label can still be caught before it is drawn.
derived <- crease_assignment(p, 0.5)
if (!identical(derived, p$creases$assignment)) {
  stop("the stored crease assignment disagrees with crease_assignment() on ",
       sum(derived != p$creases$assignment), " creases. The figure would draw ",
       "mountains as valleys. Fix the pattern, not this script.", call. = FALSE)
}

geom <- list(
  name    = NAME,
  n_facet = length(p$facets),
  flat    = lapply(flat_raw,
                   function(P) unname(as.data.frame(round(sweep(P, 2, cflat) / rf, DP)))),
  creases = local({
    cr <- p$creases[p$creases$assignment != "B", , drop = FALSE]
    lapply(seq_len(nrow(cr)), function(k) list(
      a = unname(round((p$vertices[cr$i[k], ] - cflat) / rf, DP)),
      b = unname(round((p$vertices[cr$j[k], ] - cflat) / rf, DP)),
      assignment = cr$assignment[k]))
  }),
  thetas = THETAS,
  states = states,
  worst_isometry_error = worst
)

block <- paste0("window.__FOLD_GEOM__ = ",
                jsonlite::toJSON(geom, auto_unbox = TRUE, digits = DIGITS), ";")

# ── Splice ──────────────────────────────────────────────────────────────────

lines <- readLines(HTML, warn = FALSE)
at <- grep("^window\\.__FOLD_GEOM__ = ", lines)
if (length(at) != 1L) {
  stop("expected exactly one window.__FOLD_GEOM__ assignment in ", HTML,
       ", found ", length(at), call. = FALSE)
}

if (identical(lines[at], block)) {
  cat("js/fold-figure.html geometry is up to date (",
      length(p$facets), " facets, ", length(THETAS), " frames)\n", sep = "")
  quit(status = 0)
}

if (check_only) {
  cat("js/fold-figure.html geometry is STALE.\n",
      "Run: Rscript scripts/build-fold-figure.R\n", sep = "")
  quit(status = 1)
}

lines[at] <- block
writeLines(lines, HTML)
cat("rewrote js/fold-figure.html geometry (", length(p$facets), " facets, ",
    length(THETAS), " frames, ", sum(p$creases$assignment != "B"),
    " creases)\n", sep = "")
