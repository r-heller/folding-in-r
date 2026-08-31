#!/usr/bin/env Rscript
#
# Claim A: are the evaluators optimistic, and is there a law to it?
#
# @artefact data/processed/evaluator-audit.rds        the full sweep
# @artefact data/processed/evaluator-audit-pilot.rds  --pilot, the narrow design
#                                                     that decided the chapter
#
# THE CLAIM, AND WHY IT NEEDS A PRODUCER BEFORE IT NEEDS A CHAPTER.
# Chapter 9 is 4,400 words, the largest in the book, and is where
# PROJECT_CONCEPT.md places its novel contribution: that the standard evaluation
# metrics are optimistic, and by a quantity that can be stated. It had no code.
# Its only supporting numbers came from an accordion pleat that is now documented
# as a negative result, in a theta parameterisation retired in Phase 14. Nothing
# in this repository had ever asked the question on the Miura, on [0, 1].
#
# THE QUESTION, MADE FALSIFIABLE. A benchmark whose truth is known can do
# something no real dataset can: hand an evaluator the EXACT answer as a
# candidate. If an evaluator is a good judge, the exact unfolding must score at
# least as well as any wrong embedding. The sharpest wrong embedding to hand it
# is a two-component PCA of the folded cloud, which is a plainly bad chart and an
# excellent reproduction of ambient distance.
#
#   INVERSION: an evaluator ranks the exact chart BELOW two-component PCA.
#
# An inversion is not a bug in the evaluator. It is the evaluator answering the
# question it was actually asked -- an ambient-referenced metric measures
# reproduction of ambient distance, and folding contracts ambient distance
# strictly, so the exact unfolding reproduces it badly BY CONSTRUCTION. That is
# Chapter 2's stress proposition, and this script is where it stops being a
# proposition.
#
# WHAT THE PILOT DECIDES. `--pilot` runs the narrow design the risk register
# calls for: 3 theta x k in {5,10,20,40} x n in {400,800} x 20 seeds, on
# miura_ori only. If no theta produces an inversion under an ambient-referenced
# evaluator, Claim A does not reproduce on this family in this parameterisation,
# and Chapter 9 is re-budgeted down before 4,400 words are written on it rather
# than after 3,000 have been.
#
# THREE REFERENCE GEOMETRIES, because the point is comparative. The same
# evaluator against ambient distance, against graph distance and against the
# chart is three different questions, and if the inversion is a property of the
# reference rather than of the metric then that IS the law -- stated as which
# question each evaluator is answering, not as a correction factor.
#
# Usage:  Rscript scripts/run-evaluator-audit.R [--pilot] [--quick]

for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(f)
source("_common.R")

args  <- commandArgs(trailingOnly = TRUE)
pilot <- "--pilot" %in% args
quick <- "--quick" %in% args
STARTED <- Sys.time()

THETA <- if (quick) c(0.5) else if (pilot) c(0.2, 0.5, 0.8) else THETA_GRID
KS    <- if (quick) c(10L) else c(5L, 10L, 20L, 40L)
NS    <- if (quick) c(200L) else if (pilot) c(400L, 800L) else c(400L, 800L)
SEEDS <- if (quick) BENCH_SEEDS[1:2] else BENCH_SEEDS
PAT   <- miura_ori(6L, 6L)

REFERENCES <- c("ambient", "graph", "chart")

# The two candidates. `truth` is the exact unfolding -- the answer key itself,
# handed to the evaluator as though it were a submission. `pca2` is the
# two-component PCA of the folded cloud: a bad chart, and the best possible
# linear reproduction of the ambient configuration.
candidates <- function(m) {
  list(truth = m$truth,
       pca2  = stats::prcomp(m$X, rank. = 2L)$x[, 1:2, drop = FALSE])
}

rows <- list()
for (n in NS) for (th in THETA) {
  message("theta ", th, ", n ", n, ": ", length(SEEDS), " seeds")
  for (s in SEEDS) {
    m  <- sample_manifold(PAT, theta = th, n = n, seed = s)
    cd <- candidates(m)

    for (ref in REFERENCES) {
      D <- reference_dist(m, ref, k = max(KS))
      if (any(!is.finite(D))) next            # disconnected graph: report nothing
      for (cn in names(cd)) {
        # One pass over the ranks for every k, which is what rank_metrics()
        # exists for -- it was written for this artefact and had no caller.
        rm <- rank_metrics(D, cd[[cn]], k = KS)
        rm$theta <- th; rm$n <- n; rm$seed <- s
        rm$reference <- ref; rm$candidate <- cn
        rm$rmse <- reconstruction_error(cd[[cn]], m$truth)
        rows[[length(rows) + 1L]] <- rm
      }
    }
  }
}

audit <- do.call(rbind, rows)

# ── Inversions ──────────────────────────────────────────────────────────────
#
# Per (reference, metric, theta, k, n, seed): did the evaluator prefer PCA to
# the exact chart? Computed here rather than in the chapter so that the artefact
# carries the answer and the prose reads it.

wide <- stats::reshape(
  audit[, c("reference", "k", "theta", "n", "seed", "candidate",
            "trust", "cont", "knn", "qnx")],
  idvar = c("reference", "k", "theta", "n", "seed"),
  timevar = "candidate", direction = "wide")

inv <- do.call(rbind, lapply(c("trust", "cont", "knn", "qnx"), function(mt) {
  data.frame(
    metric = mt,
    wide[, c("reference", "k", "theta", "n", "seed")],
    truth = wide[[paste0(mt, ".truth")]],
    pca2  = wide[[paste0(mt, ".pca2")]],
    inverted = wide[[paste0(mt, ".pca2")]] > wide[[paste0(mt, ".truth")]],
    stringsAsFactors = FALSE)
}))

out <- if (quick) "data/processed/evaluator-audit-quick.rds" else
       if (pilot) "data/processed/evaluator-audit-pilot.rds" else
                  "data/processed/evaluator-audit.rds"
write_run(list(scores = audit, inversions = inv), out,
          quick = quick, pilot = pilot, theta = THETA, k = KS, n = NS,
          seeds = SEEDS, references = REFERENCES,
          candidates = names(candidates(sample_manifold(PAT, 0.5, n = 50L, seed = 1L))),
          started = STARTED)

# ── The report the decision is made on ──────────────────────────────────────

cat("\n== inversion rate: how often the evaluator prefers PCA to the exact chart ==\n")
rate <- stats::aggregate(inverted ~ reference + metric + theta, data = inv,
                         FUN = function(x) round(mean(x), 3))
print(stats::reshape(rate, idvar = c("reference", "metric"), timevar = "theta",
                     direction = "wide"), row.names = FALSE)

cat("\n== the margin, where it inverts: pca2 - truth, mean over inverting cells ==\n")
m <- inv[inv$inverted, ]
if (nrow(m)) {
  print(stats::aggregate(cbind(margin = pca2 - truth) ~ reference + metric,
                         data = m, FUN = function(x) round(mean(x), 4)),
        row.names = FALSE)
} else {
  cat("  no inversions anywhere in this design.\n")
}

cat("\n== and the reconstruction error of the two candidates, for scale ==\n")
print(stats::aggregate(rmse ~ candidate + theta, data = audit,
                       FUN = function(x) round(mean(x), 4)), row.names = FALSE)

any_amb <- any(inv$inverted[inv$reference == "ambient"])
cat("\n", if (any_amb)
  "An ambient-referenced evaluator DOES rank the exact chart below PCA on this family."
else
  "NO ambient-referenced evaluator ranks the exact chart below PCA anywhere in this design.",
  "\n", sep = "")
if (pilot) {
  cat("This is the pilot (ROADMAP.md item 1.4 / risk R1). Chapter 9's budget ",
      "follows from it, and the decision is recorded in GENERATION_LOG.md ",
      "before any of it is drafted.\n", sep = "")
}
