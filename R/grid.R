# ── One cell of a benchmark grid ────────────────────────────────────────────
#
# Every grid this book runs asks the same question of a sample: fit each method,
# score it against the chart, and record what happened. The main grid asks it of
# a folded Miura across theta and noise; the Part II sweeps ask it of one Miura
# across k; the classic grid asks it of a Swiss roll, an S-curve and a severed
# sphere. Three producers, one cell.
#
# It lived inside `scripts/run-benchmark-grid.R`, so the other two could not have
# it -- which is a large part of why they did not exist. Two of the book's nine
# specified artefacts had no producer at all, and the reason was not that the
# work was hard.
#
# WHAT A ROW IS. One method, one sample, and every quantity a chapter might ask
# for, including the ones that say why a fit did not happen. A row is never
# dropped for failing: three causes -- the method declares itself unavailable,
# the method returns NULL by design, the method throws -- used to collapse into
# one indistinguishable `ran = FALSE`, and a grid that cannot say which is a grid
# that cannot be debugged from its own artefact.

#' Fit every method to one sample and score it.
#'
#' @param sample  a `manifold_sample`.
#' @param seed    the seed the sample was drawn with; stochastic methods are
#'   seeded with it per fit and never left to inherit position in the RNG
#'   stream. `umap::umap` does not advance R's stream, so a loop that seeds once
#'   collapses every replicate onto one answer.
#' @param methods which methods to fit; defaults to the whole registry.
#' @param k       the neighbourhood size passed to the methods that take one.
#' @param d       the target dimension.
#' @param ...     extra columns, recycled down the rows. This is how a producer
#'   records what varied: `theta =`, `noise =`, `turns =`, whatever its own
#'   design is. They come first in the row so the artefact reads as design then
#'   result.
#'
#' @return one row per method.
grid_cell <- function(sample, seed, methods = names(METHOD_REGISTRY),
                      k = K_DEFAULT, d = EMBED_DIM, ...) {
  dA <- reference_dist(sample, "ambient")
  dU <- reference_dist(sample, "chart")
  fl <- irreducible_loss(sample, d)
  design <- list(...)

  do.call(rbind, lapply(methods, function(mname) {
    spec <- METHOD_REGISTRY[[mname]]
    sd   <- if (isTRUE(spec$stochastic)) seed else NULL

    err <- NULL
    emb <- tryCatch(embed(mname, sample, d = d, k = k, seed = sd),
                    error = function(e) { err <<- conditionMessage(e); NULL })
    na  <- is.null(emb)
    status <- if (!is.null(err)) "error"
              else if (na) { if (!is.null(spec$unavailable)) "unavailable" else "declined" }
              else "ok"
    reason <- if (!is.null(err)) sub("\n.*", "", err)
              else if (status == "unavailable") spec$unavailable
              else if (status == "declined")
                "the method returned NULL on this cell; see R/methods.R"
              else NA_character_

    # Two passes, not one and not four. Trust, continuity and kNN preservation
    # are asked against AMBIENT distance at `k`; Q_NX is asked against the CHART
    # at K_QNX. Two k's and two reference geometries, which is what this book has
    # always done and what nothing had written down until R/constants.R did.
    rk_a <- if (na) NULL else rank_metrics(dA, emb, k = k)
    rk_u <- if (na) NULL else rank_metrics(dU, emb, k = K_QNX)

    data.frame(
      design,
      seed = seed, method = mname, consumes = spec$consumes,
      ran = !na, status = status, reason = reason,
      d = d,
      # The k Isomap actually used, which is not always the k it was asked for:
      # a disconnected graph is repaired by raising k, and the artefact records
      # that rather than only warning about it.
      k_effective = if (na) NA_integer_ else (attr(emb, "k_effective") %||% NA_integer_),
      # Anything else a method had to change about its own settings to run at
      # all -- a widened diffusion bandwidth, say. NA means it ran as asked.
      tuning = if (na) NA_character_ else (attr(emb, "tuning") %||% NA_character_),
      k_tck = k,     ref_tck = "ambient",
      k_qnx = K_QNX, ref_qnx = "chart",
      rmse  = if (na) NA_real_ else reconstruction_error(emb, sample$truth),
      qnx   = if (na) NA_real_ else rk_u$qnx,
      trust = if (na) NA_real_ else rk_a$trust,
      cont  = if (na) NA_real_ else rk_a$cont,
      knn   = if (na) NA_real_ else rk_a$knn,
      # Reported against the floor, not against zero. E1 made this the book's
      # spine: an error of 0.31 says little; an error of 0.31 against a floor of
      # 0.30 says the method is at the limit of what the data permit.
      floor = fl,
      stringsAsFactors = FALSE
    )
  }))
}

#' What did not run, and why.
#'
#' Printed by every producer rather than buried in a column nobody reads.
report_failures <- function(grid) {
  bad <- grid[!grid$ran, ]
  if (!nrow(bad)) {
    cat("\nevery fit ran.\n")
    return(invisible(NULL))
  }
  cat("\n", nrow(bad), " of ", nrow(grid), " fits did not run:\n", sep = "")
  print(stats::aggregate(seed ~ method + status + reason, data = bad, FUN = length),
        row.names = FALSE)
  invisible(bad)
}
