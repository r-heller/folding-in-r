#!/usr/bin/env Rscript
#
# Chapter 10 benchmark grid: method x pattern x theta x noise, over
# BENCH_SEEDS. Writes data/processed/benchmark-grid.rds.
#
# NOT run in CI and not run at render time -- the full grid takes hours. Run it
# locally, commit the .rds, and keep this script as the provenance record for
# how that file was produced. If the grid is regenerated, note the date and the
# foldbench version in GENERATION_LOG.md.
#
# Usage:  Rscript scripts/run-benchmark-grid.R [--quick]
#         --quick  runs a small grid for smoke-testing the pipeline

suppressPackageStartupMessages({
  library(foldbench)
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

# TODO: add the embedding methods (prcomp, cmdscale, Isomap, LLE, Rtsne, umap,
# torch autoencoder) once the chapters that describe them are written. The grid
# machinery below is deliberately method-agnostic: add an entry to METHODS and
# it joins the grid.
METHODS <- list(
  pca = function(X, d = 2) stats::prcomp(X, rank. = d)$x[, seq_len(d), drop = FALSE]
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
          rows[[length(rows) + 1L]] <- data.frame(
            pattern = pname, theta = th, noise = nname,
            seed = seed, method = mname,
            rmse  = reconstruction_error(emb, m$truth),
            trust = trustworthiness(m$X, emb, k = 10),
            cont  = continuity(m$X, emb, k = 10),
            knn   = knn_preservation(m$X, emb, k = 10),
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
