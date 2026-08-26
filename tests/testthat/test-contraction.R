# The ambient contraction: the book's crux, computed rather than quoted.
#
# PROJECT_CONCEPT.md opens on this claim and GENERATION_LOG.md records a
# tolerance for it, but nothing in the repository produced either number -- they
# were quoted. The check is closed-form and costs milliseconds, so there is no
# reason for it not to be a test.

test_that("ambient over geodesic distance across a crease is exactly sin(rho/2)", {
  # One crease, two points symmetric across it, each at perpendicular distance d
  # and the same position along the crease. The chart distance is 2d; the
  # ambient distance should be exactly 2 d sin(rho/2), so the ratio depends on
  # rho alone -- not on d, and not on position along the crease. That
  # independence IS the claim; a ratio that drifted with distance would mean the
  # relation was an approximation.
  worst <- 0
  for (rho in seq(pi, 0.05, length.out = 40)) {
    for (d in c(0.1, 1, 7.3)) {
      for (y in c(-2, 0, 3.5)) {
        half <- rho / 2
        P <- c( d * sin(half), y, d * cos(half))
        Q <- c(-d * sin(half), y, d * cos(half))
        worst <- max(worst, abs(sqrt(sum((P - Q)^2)) / (2 * d) - sin(half)))
      }
    }
  }
  expect_lt(worst, 1e-15)
  expect_equal(sin(pi / 2), 1)          # a flat sheet contracts nothing
})

test_that("the contraction is strict, and stops being representable where predicted", {
  # Mathematically sin(rho/2) < 1 for every rho < pi. In double precision it is
  # not: 1 - sin(rho/2) ~ (pi - rho)^2 / 8, so the contraction falls below
  # machine epsilon while the fold angle is still far above it.
  #
  # This is why the isometry invariant in R/README.md is qualified by the grid
  # rather than stated in general -- an unqualified "ambient is strictly less
  # than chart for every theta > 0" is false as written in floating point.
  gap <- function(g) 1 - sin((pi - g) / 2)
  expect_equal(gap(0), 0)
  expect_gt(gap(1e-3), 0)
  expect_equal(gap(1e-8), 0)            # below the floor, not representable

  floor_pred <- sqrt(8 * .Machine$double.eps / 2)
  expect_gt(gap(floor_pred * 3), 0)
  expect_lt(floor_pred, 1e-7)

  # The book's smallest non-zero theta is far above that floor, which is the
  # only reason the grid can treat the contraction as strict.
  expect_gt(min(THETA_GRID[THETA_GRID > 0]), 1e-3)
})

test_that("folding a real pattern contracts ambient distance and never expands it", {
  p <- miura_ori(4L, 4L)
  dU <- as.matrix(stats::dist(p$vertices))
  for (t in c(0.1, 0.5, 0.9)) {
    dA <- as.matrix(stats::dist(fold(p, t)$vertices3))
    off <- upper.tri(dA) & dU > 1e-9
    expect_lte(max(dA[off] / dU[off]), 1 + 1e-12)
  }
})

test_that("the customary Swiss-roll chart is wrong by orders of magnitude, measured", {
  # GENERATION_LOG.md quoted 637% for this and nothing in the repository
  # produced it. Measured here so the figure has a producer, and pinned loosely
  # enough to survive a seed change but tightly enough to catch a regression.
  worst_local <- function(s, q) {
    dA <- as.matrix(stats::dist(s$X)); dU <- as.matrix(stats::dist(s$truth))
    near <- upper.tri(dU) & dU > 1e-9 &
      dU < stats::quantile(dU[upper.tri(dU)], q)
    max(abs(dA[near] / dU[near] - 1))
  }
  iso <- swiss_roll(500L, turns = 2, seed = 7L, isometric = TRUE)
  ang <- swiss_roll(500L, turns = 2, seed = 7L, isometric = FALSE)

  expect_lt(worst_local(iso, 0.02), 0.05)   # chord against arc, and nothing else
  expect_gt(worst_local(ang, 0.02), 5)      # the customary chart, off by 1000%
  expect_gt(worst_local(ang, 0.02) / worst_local(iso, 0.02), 100)
})
