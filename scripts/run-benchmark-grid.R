#!/usr/bin/env Rscript
#
# Chapter 10 benchmark grid: method x pattern x theta x noise, over
# BENCH_SEEDS. Writes data/processed/benchmark-grid.rds.
#
# NOT run in CI and not run at render time -- the full grid takes hours. Run it
# locally, commit the .rds, and keep this script as the provenance record for
# how that file was produced. If the grid is regenerated, note the date and the
# foldbenchR version in GENERATION_LOG.md.
#
# Usage:  Rscript scripts/run-benchmark-grid.R [--quick]
#         --quick  runs a small grid for smoke-testing the pipeline

suppressPackageStartupMessages({
  library(foldbenchR)
  library(vegan)
  library(Rtsne)
  library(umap)
})

quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)

source("_common.R")   # BENCH_SEEDS, N_SEEDS

PATTERNS <- list(
  miura     = function() miura_ori(6, 6),
  yoshimura = function() yoshimura(6, 6),
  waterbomb = function() waterbomb(6, 6)
)

THETA <- if (quick) c(0, 0.6) else seq(0, 1.4, by = 0.1)
NOISE <- list(
  none    = list(type = "none",    sd = 0),
  ambient = list(type = "ambient", sd = 0.02),
  outlier = list(type = "outlier", sd = 0.05)
)
SEEDS <- if (quick) BENCH_SEEDS[1:2] else BENCH_SEEDS
N     <- if (quick) 150L else 800L

# The grid machinery is deliberately method-agnostic: add an entry to METHODS
# and it joins the grid. Each entry takes the ambient matrix and returns an
# n x d embedding.
#
# The torch autoencoder of Chapter 7 is deliberately NOT here. It is the one
# method whose result depends on a training run rather than a closed-form or
# fixed-iteration procedure, and .github/workflows/render-book.yml excludes
# torch from the restored library to stay inside the 90-minute ceiling. Its
# figures are reproduced from a recorded run instead; see that chapter.
#
# Isomap is run on the k-NN graph rather than the full distance matrix, and it
# is the method that fails discontinuously once short-circuit edges appear, so
# it is wrapped: a disconnected graph is a legitimate outcome of a large theta,
# not a script error, and must be recorded as NA rather than aborting the grid.
METHODS <- list(
  pca = function(X, d = 2) {
    stats::prcomp(X, rank. = d)$x[, seq_len(d), drop = FALSE]
  },
  mds = function(X, d = 2) {
    stats::cmdscale(stats::dist(X), k = d)
  },
  isomap = function(X, d = 2, k = 10) {
    tryCatch(
      vegan::isomap(stats::dist(X), ndim = d, k = k)$points[, seq_len(d), drop = FALSE],
      error = function(e) matrix(NA_real_, nrow = nrow(X), ncol = d)
    )
  },
  tsne = function(X, d = 2) {
    Rtsne::Rtsne(X, dims = d, perplexity = 30, check_duplicates = FALSE,
                 verbose = FALSE)$Y
  },
  umap = function(X, d = 2) {
    umap::umap(X, n_components = d)$layout
  }
)

rows <- list()
for (pname in names(PATTERNS)) {
  pat <- PATTERNS[[pname]]()
  for (th in THETA) {
    for (nname in names(NOISE)) {
      for (seed in SEEDS) {
        m <- sample_manifold(pat, theta = th, n = N,
                             noise = NOISE[[nname]], seed = seed)
        for (mname in names(METHODS)) {
          emb <- METHODS[[mname]](m$X)
          # A method that could not embed this configuration records NA across
          # the row. Dropping the row instead would silently bias the curves by
          # removing exactly the hard cases the benchmark exists to expose.
          ok <- is.matrix(emb) && !anyNA(emb)
          rows[[length(rows) + 1L]] <- data.frame(
            pattern = pname, theta = th, noise = nname,
            seed = seed, method = mname,
            rmse  = if (ok) reconstruction_error(emb, m$truth)   else NA_real_,
            trust = if (ok) trustworthiness(m$X, emb, k = 10)    else NA_real_,
            cont  = if (ok) continuity(m$X, emb, k = 10)         else NA_real_,
            knn   = if (ok) knn_preservation(m$X, emb, k = 10)   else NA_real_,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  message("done: ", pname)
}

grid <- do.call(rbind, rows)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
saveRDS(grid, "data/processed/benchmark-grid.rds")
message("wrote data/processed/benchmark-grid.rds — ", nrow(grid), " rows")
