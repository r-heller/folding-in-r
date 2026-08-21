# The classical benchmarks.
#
# The assertions that matter here are about the CHART, not the surface: whether
# the answer key each construction ships is the isometric one.

test_that("the closed-form Archimedean arc length is right", {
  # Checked against numerical integration of the speed, which is a different
  # method rather than a rearrangement of the same one.
  num <- function(t, m = 200001L) {
    g <- seq(0, t, length.out = m)
    f <- sqrt(1 + g^2)
    sum((f[-1] + f[-m]) / 2) * diff(g)[1]
  }
  for (t in c(2, 5, 10, 4 * pi)) {
    expect_equal(archimedean_arclength(t), num(t), tolerance = 1e-9)
  }
  expect_equal(archimedean_arclength(0), 0)
  # linear in the scale factor
  expect_equal(archimedean_arclength(3, a = 2.5), 2.5 * archimedean_arclength(3))
})

test_that("the arc-length chart is locally isometric and the angle chart is not", {
  # Chapter 11's result, as a test. The customary Swiss-roll answer key is the
  # angle, and arc length along an Archimedean spiral is not proportional to
  # angle -- so the customary key is not the isometry it is taken for.
  local_err <- function(s) {
    dA <- as.matrix(stats::dist(s$X))
    dU <- as.matrix(stats::dist(s$truth))
    near <- upper.tri(dU) & dU > 1e-9 &
      dU < stats::quantile(dU[upper.tri(dU)], 0.02)
    max(abs(dA[near] / dU[near] - 1))
  }
  iso <- swiss_roll(500L, turns = 2, seed = 7L, isometric = TRUE)
  ang <- swiss_roll(500L, turns = 2, seed = 7L, isometric = FALSE)

  expect_lt(local_err(iso), 0.05)      # chord-against-arc only
  expect_gt(local_err(ang), 1)         # wrong by more than 100 per cent
  expect_gt(local_err(ang), 20 * local_err(iso))
})

test_that("the Euler spiral is unit speed, so its parameter is arc length", {
  # Schoeneman et al. give the reason as constant angular acceleration. The
  # operative property is simpler and is what the test checks: |(x', y')| = 1.
  t <- seq(0.1, 3, by = 0.05)
  h <- 1e-6
  sp <- vapply(t, function(u) {
    dx <- (.fresnel_s(c(u + h, u))[1] - .fresnel_s(c(u + h, u))[2]) / h
    dy <- (.fresnel_c(c(u + h, u))[1] - .fresnel_c(c(u + h, u))[2]) / h
    sqrt(dx^2 + dy^2)
  }, numeric(1))
  expect_equal(sp, rep(1, length(t)), tolerance = 1e-3)
})

test_that("turns actually tightens the roll", {
  # The first version added revolutions at constant sheet spacing, so the knob
  # controlled nothing and the short-circuit index sat at 0.999 however tightly
  # the roll was asked to wind. g/s must fall.
  gs <- vapply(c(0.5, 1, 2, 3, 4, 6),
               function(tn) branch_gap(swiss_roll(500L, turns = tn, seed = 3L))$ratio,
               numeric(1))
  expect_false(is.unsorted(rev(gs)))
  expect_gt(gs[1] / gs[length(gs)], 5)
})

test_that("the short-circuit index is one on a faithful sample and falls when it should", {
  flat <- sample_manifold(miura_ori(6L, 6L), theta = 0, n = 500L, seed = 3L)
  expect_equal(short_circuit_index(flat, 10L), 1, tolerance = 1e-6)

  sc <- vapply(c(0, 0.3, 0.6, 0.8, 0.95), function(th) {
    short_circuit_index(sample_manifold(miura_ori(6L, 6L), theta = th,
                                        n = 500L, seed = 3L), 10L)
  }, numeric(1))
  expect_false(is.unsorted(rev(sc)))
  expect_lt(sc[length(sc)], 0.9)
})

test_that("branch_gap separates the surface from the sampling, as intended", {
  # g/s is deliberately density-relative -- it is Balasubramanian & Schwartz's
  # branch separation measured IN UNITS OF sampling density, and that is the
  # quantity Isomap's topological stability depends on. So the two halves have
  # to behave differently, and this pins both.
  #
  # g is a property of the surface and must be near-constant in n.
  # s is the median nearest-neighbour distance and must fall as n^(-1/2) on a
  # 2-manifold, so g/s must GROW as sqrt(n).
  #
  # The consequence is methodological and belongs in the chapter: comparing g/s
  # across families is only meaningful at fixed n. E1 holds n fixed for exactly
  # this reason.
  ns <- c(200L, 400L, 800L, 1600L)
  b <- lapply(ns, function(n)
    branch_gap(sample_manifold(miura_ori(6L, 6L), theta = 0.6, n = n, seed = 5L)))

  g  <- vapply(b, `[[`, numeric(1), "g")
  gs <- vapply(b, `[[`, numeric(1), "ratio")

  expect_lt(diff(range(g)) / mean(g), 0.10)             # the surface, unchanged
  expect_equal(gs[4] / gs[1], sqrt(8), tolerance = 0.15) # the density, as n^(-1/2)

  # And at fixed n it must track folding, which is what it is used for.
  flat   <- branch_gap(sample_manifold(miura_ori(6L, 6L), theta = 0,    n = 400L, seed = 5L))$ratio
  folded <- branch_gap(sample_manifold(miura_ori(6L, 6L), theta = 0.95, n = 400L, seed = 5L))$ratio
  expect_gt(flat / folded, 2)
})

test_that("the severed sphere cannot be mistaken for exact truth", {
  # A sphere has constant positive Gaussian curvature, so by Gauss's Theorema
  # Egregium it has no isometric planar chart anywhere. It is in the book as the
  # case where exact truth does not exist, and the guard is what stops a chapter
  # scoring against a convention as though it were a measurement.
  ss <- severed_sphere(200L, seed = 1L)
  expect_false(ss$exact_truth)
  expect_error(require_exact_truth(ss), "exact ground truth")

  for (s in list(swiss_roll(200L, seed = 1L), s_curve(200L, seed = 1L))) {
    expect_true(s$exact_truth)
    expect_true(require_exact_truth(s))
  }
})

test_that("baselines satisfy the manifold_sample contract", {
  for (s in list(swiss_roll(150L, seed = 2L), s_curve(150L, seed = 2L),
                 severed_sphere(150L, seed = 2L))) {
    expect_s3_class(s, "manifold_sample")
    expect_equal(dim(s$X), c(150L, 3L))
    expect_equal(dim(s$truth), c(150L, 2L))
    expect_true(all(is.finite(s$X)), info = s$family)
    expect_true(all(is.finite(s$truth)), info = s$family)
  }
})

test_that("baselines are reproducible and leave the RNG alone", {
  a <- swiss_roll(100L, seed = 11L)
  b <- swiss_roll(100L, seed = 11L)
  expect_equal(a$X, b$X)
  expect_equal(a$truth, b$truth)

  set.seed(99L)
  before <- stats::runif(1L)
  set.seed(99L)
  invisible(swiss_roll(100L, seed = 11L))
  expect_equal(stats::runif(1L), before)
})

test_that("noise moves X and never truth", {
  clean <- swiss_roll(200L, seed = 4L)
  noisy <- swiss_roll(200L, seed = 4L, noise = list(type = "ambient", sd = 0.02))
  expect_equal(clean$truth, noisy$truth)
  expect_false(isTRUE(all.equal(clean$X, noisy$X)))
})
