#!/usr/bin/env Rscript
#
# The product suite: the artefact Claim B needs.
#
# @artefact data/processed/product-grid.rds
#
# E1 retired Claim C and made Claim B -- the irreducible-loss bound -- the
# book's spine. Claim B's operative instruction is "report every result against
# the floor rather than against zero". On the main grid that instruction does
# nothing: the chart is two-dimensional and the target is two-dimensional, so
# the floor is identically 0 in every cell. The spine had no artefact.
#
# The product construction is what makes the bound bite. Pairing two crease
# patterns gives intrinsic dimension 4 with the chart still exact and still in
# closed form, so forcing it into 2 dimensions has a floor that is strictly
# positive, computable, and attained -- the optimal rank-2 projection sits
# exactly on it. Every method can then be scored by how far ABOVE the floor it
# lands, which separates the loss the data imposes from the loss the method is
# responsible for.
#
# That distinction is the whole of Claim B. "PCA scores 0.66" reads as failure;
# "PCA is 0.007 above the best any 2-D embedding could achieve" says the loss
# belongs to the data.
#
# NOT run in CI and not run at render time. Run it locally, commit the .rds, and
# keep this script as the record of how.
#
# Usage:  Rscript scripts/run-product-grid.R [--quick]

for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(f)
source("_common.R")

quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)

# The factors. Both are Miura -- the only family with a certified folding -- but
# with different cell geometry, so the product is not a square of one object.
# theta is swept on the SECOND factor only: varying both at once confounds the
# two contributions to the floor, which is the mistake arm A of E1 made in a
# different guise.
FACTORS <- list(
  a = function(th) miura_ori(4L, 4L, alpha = pi / 3),
  b = function(th) miura_ori(3L, 5L, b = 1.4, alpha = pi / 4)
)

THETA_A <- 0.55
THETA   <- if (quick) c(0.2, 0.7) else seq(0.1, 0.9, by = 0.1)
DIMS    <- if (quick) c(2L, 3L)    else c(1L, 2L, 3L, 4L)
SEEDS   <- if (quick) BENCH_SEEDS[1:2] else BENCH_SEEDS[1:10]
N       <- if (quick) 150L else 400L

rows <- list()
for (th in THETA) for (seed in SEEDS) {
  a <- sample_manifold(FACTORS$a(th), theta = THETA_A, n = N, seed = seed,
                       boundary = TRUE)
  b <- sample_manifold(FACTORS$b(th), theta = th, n = N, seed = seed + 500L,
                       boundary = TRUE)
  p <- product_manifold(a, b)

  for (d in DIMS) {
    fl <- irreducible_loss(p, d)
    for (mname in names(METHOD_REGISTRY)) {
      spec <- METHOD_REGISTRY[[mname]]
      sd  <- if (isTRUE(spec$stochastic)) seed else NULL
      emb <- tryCatch(embed(mname, p, d = d, seed = sd), error = function(e) NULL)
      na  <- is.null(emb)
      err <- if (na) NA_real_ else reconstruction_error(emb, p$truth)
      rows[[length(rows) + 1L]] <- data.frame(
        theta = th, seed = seed, d = d, method = mname,
        consumes = spec$consumes, ran = !na,
        rmse = err, floor = fl,
        excess = if (na) NA_real_ else err - fl,
        # How much of the achievable range the method actually gave away. 0 is
        # optimal, 1 is as bad as a random embedding.
        gave_away = if (na) NA_real_ else (err - fl) / max(1e-12, 1 - fl),
        stringsAsFactors = FALSE
      )
    }
  }
  message("done: theta ", th, " seed ", seed)
}

grid <- do.call(rbind, rows)

attr(grid, "provenance") <- list(
  quick = quick, theta_a = THETA_A, theta = THETA, dims = DIMS,
  seeds = SEEDS, n = N, methods = names(METHOD_REGISTRY),
  r_sha = tryCatch(system2("git", c("rev-parse", "--short", "HEAD"),
                           stdout = TRUE), error = function(e) NA_character_)
)

out <- if (quick) "data/processed/product-grid-quick.rds" else
  "data/processed/product-grid.rds"
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
saveRDS(grid, out)
message("wrote ", out, " -- ", nrow(grid), " rows",
        if (quick) "  (QUICK smoke test)" else "")

# ── The check that makes it a bound ─────────────────────────────────────────
ok <- grid[grid$ran, ]
viol <- ok[ok$excess < -1e-9, ]
if (nrow(viol)) {
  cat("\n", nrow(viol), " cells BEAT the floor -- it is not a bound:\n", sep = "")
  print(utils::head(viol[, c("theta", "d", "method", "rmse", "floor")]))
  quit(status = 1)
}
cat("\nno method beat the floor in any of ", nrow(ok), " fits.\n", sep = "")

cat("\nmean excess over the floor, by method and target dimension:\n")
print(stats::reshape(
  stats::aggregate(excess ~ method + d, data = ok, FUN = function(x) round(mean(x), 4)),
  idvar = "method", timevar = "d", direction = "wide"), row.names = FALSE)
