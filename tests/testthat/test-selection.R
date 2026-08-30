# The pre-registered selection rule.
#
# Written against a SYNTHETIC grid, on purpose. The real grid does not exist yet
# and must not exist when this rule is registered -- that is the whole point of
# a pre-registration, and a rule tested against the numbers it will later be
# applied to is not one. What is tested is that the procedure is total, that it
# is deterministic, and that each of its three pre-registered thresholds
# actually changes the decision.

fake_grid <- function(means, within = 0.01, seeds = 20L, thetas = c(0.4, 0.5),
                      noise = "none", ran = TRUE, floor = 0.10,
                      consumes = NULL) {
  if (is.null(consumes)) {
    consumes <- setNames(rep("ambient", length(means)), names(means))
  }
  set.seed(3L)
  do.call(rbind, lapply(names(means), function(m) {
    do.call(rbind, lapply(thetas, function(th) {
      data.frame(
        pattern = "miura", theta = th, noise = noise, seed = seq_len(seeds),
        method = m, consumes = unname(consumes[[m]]),
        ran = if (is.logical(ran)) ran else ran[[m]],
        rmse = floor + means[[m]] + stats::rnorm(seeds, 0, within),
        floor = floor, stringsAsFactors = FALSE
      )
    }))
  }))
}

test_that("it selects the method with the least excess over the floor", {
  g <- fake_grid(c(pca = 0.05, isomap = 0.20, umap = 0.35))
  d <- select_method(g, theta = c(0.4, 0.5), noise = "none")

  expect_equal(d$decision, "select")
  expect_equal(d$method, "pca")
  expect_equal(names(d$ranking), c("pca", "isomap", "umap"))
  expect_gt(d$resolving$R, MIN_RESOLVING)
  expect_match(d$reason, "exceeds the pre-registered reportable difference")
})

test_that("it declines when the benchmark cannot tell the methods apart", {
  # The null-result promise, and the reason the rule has to exist in advance.
  # Three methods separated by 0.002 with a within-cell spread of 0.05: there is
  # an ordering, it is perfectly well defined, and it is noise.
  g <- fake_grid(c(pca = 0.200, isomap = 0.202, umap = 0.204), within = 0.05)
  d <- select_method(g, theta = c(0.4, 0.5), noise = "none")

  expect_equal(d$decision, "decline")
  expect_true(is.na(d$method))
  expect_lte(d$resolving$R, MIN_RESOLVING)
  expect_match(d$reason, "resolving power")

  # And it still reports the ranking it declined to act on, so the chapter can
  # show the reader what was and was not there.
  expect_equal(length(d$ranking), 3L)
})

test_that("raising the seed count does not buy a decision", {
  # The specific abuse the rule is written against: "the temptation on
  # discovering R < 1 will be to raise the seed count until something
  # separates". R is a ratio of two spreads, and neither is a standard error, so
  # more seeds estimate both more precisely and move the ratio nowhere.
  set.seed(1L)
  R <- vapply(c(20L, 100L, 400L), function(s) {
    g <- fake_grid(c(a = 0.200, b = 0.202, c = 0.204), within = 0.05, seeds = s)
    select_method(g, theta = c(0.4, 0.5), noise = "none")$resolving$R
  }, numeric(1))
  expect_true(all(R <= MIN_RESOLVING))
})

test_that("a method that cannot run is not a candidate", {
  # However well it scores where it does run. Chapter 12 has to fit the thing.
  g <- fake_grid(c(pca = 0.20, lle = 0.02, isomap = 0.25),
                 ran = list(pca = TRUE, lle = FALSE, isomap = TRUE))
  d <- select_method(g, theta = c(0.4, 0.5), noise = "none")

  expect_equal(d$decision, "select")
  expect_equal(d$method, "pca")
  expect_true("lle" %in% d$excluded)
  expect_false("lle" %in% d$eligible)
})

test_that("a margin below the reportable difference is a tie, and says so", {
  # 0.02 is PROJECT_CONCEPT.md's pre-registered reportability threshold, not a
  # number chosen here. A 0.005 margin is a tie whatever the ordering says.
  g <- fake_grid(c(umap = 0.100, pca = 0.105, isomap = 0.400),
                 within = 0.001,
                 consumes = list(umap = "neighbourhood", pca = "ambient",
                                 isomap = "geodesic"))
  d <- select_method(g, theta = c(0.4, 0.5), noise = "none")

  expect_equal(d$decision, "select")
  expect_setequal(d$tied, c("umap", "pca"))
  # Broken toward the method that assumes least, not toward the lower number.
  expect_equal(d$method, "pca")
  expect_match(d$reason, "below the pre-registered reportable difference")
})

test_that("the tie-break is total, so the rule always returns the same answer", {
  # Two methods identical in every column the rule reads, and a third far enough
  # behind to give the regime resolving power. A procedure that fell through to
  # whichever row came first would depend on the order the grid was built in,
  # which is not a pre-registration.
  g <- fake_grid(c(zeta = 0.10, alpha = 0.10, tail = 0.40), within = 0.0005)
  d1 <- select_method(g, theta = c(0.4, 0.5), noise = "none")
  d2 <- select_method(g[rev(seq_len(nrow(g))), ], theta = c(0.4, 0.5), noise = "none")

  expect_equal(d1$decision, "select")
  expect_equal(d1$method, d2$method)
  expect_equal(d1$method, "alpha")           # alphabetical, the last resort
  expect_setequal(d1$tied, c("alpha", "zeta"))
})

test_that("two methods that are the same method are a decline, not a coin flip", {
  # The degenerate case of the same rule, and it comes out right for the right
  # reason: with nothing between them the spread across methods is zero, so R is
  # zero, so the benchmark has no resolving power and the rule says so. It does
  # not pick one and call it a winner.
  g <- fake_grid(c(zeta = 0.10, alpha = 0.10), within = 0.0005)
  d <- select_method(g, theta = c(0.4, 0.5), noise = "none")
  expect_equal(d$decision, "decline")
  expect_true(is.na(d$method))
})

test_that("it refuses a grid whose schema is not the one it was registered against", {
  # Adapting the rule to a changed schema is re-writing it after the fact. It
  # stops instead, and says so.
  g <- fake_grid(c(pca = 0.05, isomap = 0.20))
  g$floor <- NULL
  expect_error(select_method(g, theta = c(0.4, 0.5), noise = "none"),
               "the rule has to be re-registered")
})

test_that("it refuses an empty regime rather than deciding on nothing", {
  g <- fake_grid(c(pca = 0.05, isomap = 0.20))
  expect_error(select_method(g, theta = 0.95, noise = "none"),
               "no cells in the stated regime")
})

test_that("the thresholds are the ones the plan pre-registered", {
  # If one of these moves, the rule is not the rule that was registered, and the
  # commit that moves it has to say so out loud.
  expect_equal(MIN_REPORTABLE, 0.02)
  expect_equal(MIN_RUN_RATE, 0.90)
  expect_equal(MIN_RESOLVING, 1.0)
  expect_equal(CONSUMES_ORDER, c("ambient", "geodesic", "neighbourhood"))
})

test_that("it reads the grid the producer actually writes", {
  # The rule is registered against a schema, and the schema is whatever
  # grid_cell() emits -- so the schema is asserted by BUILDING a row, not by
  # grepping the producer for column names. The grep version passed until
  # grid_cell() moved out of the producer into R/grid.R, at which point it
  # failed for the right reason and was replaced by this.
  #
  # A tiny sample, because what is being checked is the shape.
  m <- sample_manifold(miura_ori(3L, 3L), theta = 0.5, n = 60L, seed = 1L)
  row <- grid_cell(m, seed = 1L, methods = c("pca", "mds"), k = 5L,
                   pattern = "miura", theta = 0.5, noise = "none")

  for (col in c("pattern", "theta", "noise", "seed", "method", "consumes",
                "ran", "rmse", "floor")) {
    expect_true(col %in% names(row), info = col)
  }
  expect_equal(nrow(row), 2L)
  expect_true(all(row$ran))

  # And the rule runs on it end to end, which is the only assertion that covers
  # the columns' TYPES as well as their names.
  d <- select_method(row, theta = 0.5, noise = "none")
  expect_true(d$decision %in% c("select", "decline"))
})
