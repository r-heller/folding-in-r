#!/usr/bin/env Rscript
#
# How many seeds does a cell actually need?
#
# @artefact data/processed/seed-budget.rds
#
# Standing rule 1 says "every stochastic result is reported across at least 20
# seeds", unconditionally, and every experiment that has run violated it:
# experiment-e1.R used 10 for arm A and 5 for the arm that produced its headline,
# run-product-grid.R 10. Only the ungenerated main grid uses 20. A rule stated to
# the reader and broken by every producer is worse than no rule.
#
# Twenty is also a convention inherited from the sibling volumes rather than a
# design derived from this book's effect sizes. PROJECT_CONCEPT.md already says
# what the design should be -- "the plan spends MORE where the pre-registered
# 0.02 reportability threshold requires it, and the floor everywhere else" --
# and PLAN.md S2-3 says to invert that threshold for the seed count. Nobody had
# measured the spread it has to be inverted against.
#
# This measures it. For each stochastic method, at cells spanning the grid's
# theta and noise, the within-cell standard deviation of excess over the floor
# across many seeds. Then inverts: the seeds needed to detect a difference of
# MIN_REPORTABLE between two methods, at 80% power and the 5% level, is
#
#     n = 2 (z_(1-a/2) + z_(1-b))^2 sd^2 / delta^2
#
# which for two independent means is the standard two-sample expression. It is
# reported per method and per cell, and the budget is the ceiling over cells.
#
# Deterministic methods need one seed per cell for the METHOD and get 20 anyway,
# because the sample is redrawn per seed and that variation is real. What this
# script sizes is the extra the stochastic ones need on top.
#
# Usage:  Rscript scripts/measure-seed-budget.R [--quick]

for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(f)
source("_common.R")

quick   <- "--quick" %in% commandArgs(trailingOnly = TRUE)
STARTED <- Sys.time()

N       <- if (quick) 200L else 800L
REPS    <- if (quick) 8L   else 40L
THETA   <- if (quick) c(0.5) else c(0.2, 0.5, 0.8)
NOISE   <- list(none    = list(type = "none",    sd = 0),
                outlier = list(type = "outlier", sd = 0.05))
if (quick) NOISE <- NOISE["none"]

PAT <- miura_ori(6L, 6L)

# Every method, not only the stochastic ones: the deterministic methods' spread
# across seeds is the sampling variation alone, and that is the baseline the
# stochastic ones have to be read against. A method whose seed-to-seed spread is
# no larger than PCA's is not seed-dependent in any way that matters here,
# whatever its registry entry says.
METHODS <- names(METHOD_REGISTRY)

# Two-sample, 80% power, 5% level. Written out rather than called from a power
# package so the assumption is visible: two independent means, equal variance,
# normal approximation.
seeds_needed <- function(sd, delta = MIN_REPORTABLE) {
  if (!is.finite(sd) || sd <= 0) return(1L)
  as.integer(ceiling(2 * (stats::qnorm(0.975) + stats::qnorm(0.80))^2 *
                     sd^2 / delta^2))
}

rows <- list()
for (th in THETA) for (nname in names(NOISE)) {
  message("cell: theta ", th, " noise ", nname, " (", REPS, " seeds)")
  fits <- list()
  for (i in seq_len(REPS)) {
    s <- 1000L + i
    m <- sample_manifold(PAT, theta = th, n = N, noise = NOISE[[nname]], seed = s)
    fl <- irreducible_loss(m, 2L)
    for (mn in METHODS) {
      spec <- METHOD_REGISTRY[[mn]]
      sd_i <- if (isTRUE(spec$stochastic)) s else NULL
      emb <- tryCatch(embed(mn, m, seed = sd_i), error = function(e) NULL)
      fits[[length(fits) + 1L]] <- data.frame(
        theta = th, noise = nname, seed = s, method = mn,
        stochastic = isTRUE(spec$stochastic),
        excess = if (is.null(emb)) NA_real_ else
          reconstruction_error(emb, m$truth) - fl,
        stringsAsFactors = FALSE)
    }
  }
  rows[[length(rows) + 1L]] <- do.call(rbind, fits)
}

fits <- do.call(rbind, rows)

# ── Within-cell spread, and what it costs ───────────────────────────────────

agg <- stats::aggregate(excess ~ method + theta + noise + stochastic,
                        data = fits[is.finite(fits$excess), ],
                        FUN = function(x) c(sd = stats::sd(x), n = length(x)))
agg <- do.call(data.frame, agg)
names(agg)[names(agg) == "excess.sd"] <- "sd"
names(agg)[names(agg) == "excess.n"]  <- "n"
agg$seeds_needed <- vapply(agg$sd, seeds_needed, integer(1))

budget <- stats::aggregate(cbind(sd, seeds_needed) ~ method + stochastic,
                           data = agg, FUN = max)
budget <- budget[order(-budget$seeds_needed, budget$method), ]

out <- if (quick) "data/processed/seed-budget-quick.rds" else
  "data/processed/seed-budget.rds"
write_run(list(fits = fits, per_cell = agg, budget = budget), out,
          quick = quick, n = N, reps = REPS, theta = THETA,
          noise = names(NOISE), delta = MIN_REPORTABLE,
          methods = METHODS, started = STARTED)

cat("\nwithin-cell sd of excess over the floor, worst cell per method,\n")
cat("and the seeds needed to detect a difference of ", MIN_REPORTABLE, ":\n\n", sep = "")
print(budget, row.names = FALSE)

cat("\nStanding rule 1's floor is ", N_SEEDS, ".\n", sep = "")
over <- budget[budget$seeds_needed > N_SEEDS, ]
if (nrow(over)) {
  cat("Above it: ", paste(sprintf("%s (%d)", over$method, over$seeds_needed),
                          collapse = ", "), "\n", sep = "")
} else {
  cat("No method needs more than the floor.\n")
}
