# The classical benchmarks.
#
# The assertions that matter here are about the CHART, not the surface: whether
# the answer key each construction ships is the isometric one, and whether the
# object says so honestly when it is not.

test_that("the closed-form Archimedean arc length is right", {
  # Checked against adaptive quadrature of the speed a sqrt(1 + t^2), which is
  # a different method rather than a rearrangement of the same one.
  err <- unlist(lapply(c(0.5, 1, 2.7), function(a) {
    vapply(c(0.1, 1, pi, 1.5 * pi, 10, 17.28, 40), function(t) {
      num <- stats::integrate(function(u) a * sqrt(1 + u^2), 0, t,
                              rel.tol = 1e-12, abs.tol = 0)$value
      abs(archimedean_arclength(t, a) - num) / num
    }, numeric(1))
  }))
  expect_lt(max(err), 1e-12)          # measured 2.9e-16 over these 21 cases

  expect_equal(archimedean_arclength(0), 0)
  expect_equal(archimedean_arclength(3, a = 2.5), 2.5 * archimedean_arclength(3))
  # Strictly increasing, which is what makes the inversion in swiss_roll() safe.
  expect_false(is.unsorted(archimedean_arclength(seq(0, 20, by = 0.01))))
})

test_that("the Swiss roll's chart is the arc length of the point placed", {
  # A round trip through the ambient coordinates, so the check does not go back
  # through the code that generated the chart. On r = a t the radius recovers t,
  # and the chart value must then be its closed-form arc length exactly -- the
  # Newton inversion that placed the point is allowed to be approximate, the
  # answer key is not.
  s <- swiss_roll(500L, turns = 2, seed = 7L)
  t_end <- 1.5 * pi + 2 * 2 * pi
  a     <- 12 / t_end                     # outer_radius / t_end, the defaults
  t_rec <- sqrt(s$X[, 1]^2 + s$X[, 3]^2) / a
  u <- archimedean_arclength(t_rec, a) - archimedean_arclength(1.5 * pi, a)

  expect_lt(max(abs(u - s$truth[, 1])) / diff(range(s$truth[, 1])), 1e-12)
  expect_identical(s$truth[, 2], s$X[, 2])       # height is carried, not remade

  # Uniform along the chart, not along the angle. Sampling t uniformly would
  # crowd the inner turns, where the sheets are closest, and make every
  # difficulty statistic a property of the sampler.
  expect_gt(stats::ks.test(s$truth[, 1], "punif", min(s$truth[, 1]),
                           max(s$truth[, 1]))$p.value, 0.01)
})

test_that("the arc-length chart is locally isometric, the angle chart not", {
  # Chapter 11's result, as a test. Both charts are scored on exactly the same
  # pairs -- "nearby" is defined by the isometric chart, which is the surface's
  # own geometry -- so the comparison cannot be dismissed as a choice of units.
  s   <- swiss_roll(600L, turns = 2, seed = 7L)
  ang <- swiss_roll(600L, turns = 2, seed = 7L, isometric = FALSE)
  expect_identical(s$X, ang$X)                 # same surface, different key

  dA <- as.matrix(stats::dist(s$X))
  dI <- as.matrix(stats::dist(s$iso_chart))
  dG <- as.matrix(stats::dist(ang$truth))
  ut <- upper.tri(dI)
  ratios <- function(q) {
    near <- ut & dI > 0 & dI < stats::quantile(dI[ut], q)
    list(arc = dA[near] / dI[near], angle = dA[near] / dG[near])
  }
  err    <- function(r) max(abs(r - 1))
  # Scale-invariant: the widest disagreement between any two local ratios. A
  # global rescaling cannot improve it, and Procrustes gives the methods that
  # rescaling for free, so this is the part of the error no method can absorb.
  spread <- function(r) max(r) / min(r)

  wide <- ratios(0.02)
  tight <- ratios(0.001)

  # The arc-length chart's residual is chord-against-arc and nothing else, so
  # it must shrink as the patch does. Measured here: 0.0193 and 0.00033.
  expect_lt(err(wide$arc), 0.03)
  expect_lt(err(tight$arc), 0.002)
  expect_lt(err(tight$arc), err(wide$arc) / 10)
  expect_lt(spread(wide$arc), 1.05)

  # The angle chart's does not shrink, because it is not a chord-versus-arc
  # error: the local scale factor a sqrt(1 + t^2) varies along the spiral, and
  # no neighbourhood is small enough to escape it. Measured: 10.59 at both.
  expect_gt(err(tight$angle), 5)
  expect_gt(spread(tight$angle), 5)
  expect_gt(err(tight$angle) / err(tight$arc), 1000)

  # The S-curve is the control. Its standard construction is unit speed, so the
  # parameter everyone already ships as truth IS arc length and the same
  # measurement returns chord-versus-arc alone: 0.0053 here, against 10.59.
  sc <- s_curve(800L, seed = 3L)
  dS <- as.matrix(stats::dist(sc$X))
  dT <- as.matrix(stats::dist(sc$truth))
  utS <- upper.tri(dT)
  nearS <- utS & dT > 0 & dT < stats::quantile(dT[utS], 0.02)
  expect_lt(max(abs(dS[nearS] / dT[nearS] - 1)), 0.02)
})

test_that("the Euler spiral is unit speed, so its parameter is arc length", {
  # Schoeneman et al. give the reason as constant angular acceleration. The
  # operative property is simpler and is what the test checks: |(x', y')| = 1.
  h <- 1e-5
  sp <- vapply(seq(0.5, 4, by = 0.1), function(x) {
    f <- .fresnel(c(x - h, x + h), t_max = 4.1)
    sqrt(diff(f$S)^2 + diff(f$C)^2) / (2 * h)
  }, numeric(1))
  expect_lt(max(abs(sp - 1)), 1e-5)            # measured 1.6e-7

  # The quadrature that places the points, against stats::integrate -- a
  # different method, not a finer grid of the same one. It is the position that
  # is integrated and never the chart, but the position still has to be right.
  tt <- seq(0.2, 4.2, by = 0.2)
  f <- .fresnel(tt, t_max = max(tt))
  eS <- vapply(tt, function(u) stats::integrate(function(x) sin(x^2), 0, u,
                                               rel.tol = 1e-12)$value, numeric(1))
  eC <- vapply(tt, function(u) stats::integrate(function(x) cos(x^2), 0, u,
                                               rel.tol = 1e-12)$value, numeric(1))
  expect_lt(max(abs(c(f$S - eS, f$C - eC))), 1e-6)   # measured 6.5e-9

  # And the payoff: on the Euler roll the published parameter already is the
  # chart, so the local error is chord-versus-arc, the same as the Archimedean
  # roll's arc-length chart and unlike its angle chart.
  e <- swiss_roll(400L, turns = 2, seed = 7L, spiral = "euler")
  dA <- as.matrix(stats::dist(e$X))
  dI <- as.matrix(stats::dist(e$iso_chart))
  ut <- upper.tri(dI)
  near <- ut & dI > 0 & dI < stats::quantile(dI[ut], 0.02)
  expect_lt(max(abs(dA[near] / dI[near] - 1)), 0.06)
})

test_that("turns actually tightens the roll", {
  # The first version added revolutions at constant sheet spacing, so the knob
  # controlled nothing and the short-circuit index sat at 0.999 however tightly
  # the roll was asked to wind. g/s must fall.
  gs <- vapply(c(0.5, 1, 2, 3, 4, 6), function(tn) {
    branch_gap(swiss_roll(500L, turns = tn, seed = 3L))$ratio
  }, numeric(1))
  expect_false(is.unsorted(rev(gs)))
  expect_gt(gs[1] / gs[length(gs)], 5)
})

test_that("the short-circuit index is one when the graph is faithful", {
  # theta = 0 is the flat sheet: ambient distance IS chart distance, so the
  # index is exactly 1 and any departure is a bug in the statistic rather than
  # a property of the surface.
  flat <- sample_manifold(miura_ori(6L, 6L), theta = 0, n = 500L, seed = 3L)
  expect_equal(short_circuit_index(flat, 10L), 1, tolerance = 1e-9)

  sc <- vapply(c(0, 0.3, 0.6, 0.8, 0.95), function(th) {
    short_circuit_index(sample_manifold(miura_ori(6L, 6L), theta = th,
                                        n = 500L, seed = 3L), 10L)
  }, numeric(1))
  expect_false(is.unsorted(rev(sc)))
  expect_lt(sc[length(sc)], 0.9)

  # The Swiss roll's own difficulty axis. A loose roll is faithful and a tight
  # one is not; measured 0.9998 at half a turn and 0.065 at eight.
  loose <- vapply(c(0.5, 1, 2), function(tn)
    short_circuit_index(swiss_roll(500L, turns = tn, seed = 3L), 10L), numeric(1))
  tight <- vapply(c(6, 8), function(tn)
    short_circuit_index(swiss_roll(500L, turns = tn, seed = 3L), 10L), numeric(1))
  expect_true(all(loose > 0.99))
  expect_true(all(tight < 0.3))

  expect_error(short_circuit_index(flat, 0L), "k must be")
  expect_error(short_circuit_index(flat, 500L), "k must be")
})

test_that("the index reads the isometric chart, not whatever truth holds", {
  # swiss_roll(isometric = FALSE) hands out the wrong answer key deliberately.
  # The difficulty of the sample is a property of the surface and must not move
  # when the key does, which is what iso_chart is for.
  a <- swiss_roll(400L, turns = 2, seed = 9L)
  b <- swiss_roll(400L, turns = 2, seed = 9L, isometric = FALSE)
  expect_identical(a$X, b$X)
  expect_identical(short_circuit_index(a, 10L), short_circuit_index(b, 10L))

  # And on the severed sphere it reads great-circle distance. Scoring against
  # the conventional chart instead would report a 23 per cent short circuit on
  # a surface that has none: 0.770 against 0.998, all of it chart distortion.
  ss <- severed_sphere(500L, seed = 3L)
  expect_gt(short_circuit_index(ss, 10L), 0.99)

  dA <- as.matrix(stats::dist(ss$X)); diag(dA) <- Inf
  nn <- apply(dA, 1L, function(r) order(r)[seq_len(10L)])
  i  <- rep(seq_len(nrow(ss$X)), each = 10L)
  j  <- as.vector(nn)
  dU <- as.matrix(stats::dist(ss$truth))
  by_chart <- stats::median(dA[cbind(i, j)]) / stats::median(dU[cbind(i, j)])
  expect_lt(by_chart, 0.85)
})

test_that("the severed sphere cannot be mistaken for exact truth", {
  # A sphere has constant positive Gaussian curvature, so by Gauss's Theorema
  # Egregium it has no isometric planar chart anywhere. It is in the book as the
  # case where exact truth does not exist, and the guard is what stops a chapter
  # scoring against a convention as though it were a measurement.
  ss <- severed_sphere(200L, seed = 1L)
  expect_false(ss$exact_truth)
  expect_error(require_exact_truth(ss), "exact ground truth")
  expect_error(require_exact_truth(ss, "Procrustes"), "^Procrustes needs")

  for (s in list(swiss_roll(200L, seed = 1L), s_curve(200L, seed = 1L))) {
    expect_true(s$exact_truth)
    expect_true(require_exact_truth(s))
  }

  # The field is absent on a crease-pattern sample, because a crease pattern's
  # chart is the ground truth by construction. Absent must mean exact: a guard
  # that rejected every sample from sample_manifold() would be worse than no
  # guard, because it would be turned off.
  crease <- sample_manifold(miura_ori(3L, 3L), theta = 0.4, n = 60L, seed = 1L)
  expect_null(crease$exact_truth)
  expect_true(require_exact_truth(crease))
})

test_that("the severed sphere is sampled uniformly over area", {
  # Archimedes: on a sphere, equal bands of z hold equal area. So a uniform
  # sample has a uniform z, and drawing the colatitude uniformly instead --
  # which is the obvious thing to write -- crowds the poles by an order of
  # magnitude. Every neighbourhood metric downstream would read that density
  # gradient as structure.
  ss <- severed_sphere(20000L, seed = 5L)
  bands <- table(cut(ss$X[, 3], seq(-1, cos(pi / 8), length.out = 21),
                     include.lowest = TRUE))
  expect_lt(max(bands) / min(bands), 1.2)          # measured 1.10

  phi <- severed_sphere(20000L, seed = 5L, chart = "spherical")$truth[, 2]
  colat <- table(cut(phi, seq(pi / 8, pi, length.out = 21)))
  expect_gt(max(colat) / min(colat), 5)            # measured 12.3
})

test_that("the equidistant chart is exact along radii and wrong around them", {
  # The number Chapter 11 quotes for how wrong the sphere's conventional chart
  # is. Radial geodesics are reproduced exactly by construction; a
  # circumferential arc at geodesic radius r is stretched by r / (R sin(r/R)),
  # which at the default cap reaches 7.18 at the rim.
  ss <- severed_sphere(400L, seed = 2L)
  r <- sqrt(rowSums(ss$truth^2))
  expect_equal(r, 1 * (pi - ss$angles[, 2]))       # radial distances, exactly

  R <- 1; cap <- pi / 8; rim <- R * (pi - cap)
  phi <- pi - rim / R
  dl  <- 1e-5
  d_true  <- R * acos(sin(phi)^2 * cos(dl) + cos(phi)^2)
  d_chart <- 2 * rim * sin(dl / 2)
  expect_equal(d_chart / d_true, rim / (R * sin(rim / R)), tolerance = 1e-4)
  expect_equal(rim / (R * sin(rim / R)), 7.183205, tolerance = 1e-6)
})

test_that("baselines satisfy the manifold_sample contract", {
  for (s in list(swiss_roll(150L, seed = 2L), s_curve(150L, seed = 2L),
                 severed_sphere(150L, seed = 2L))) {
    expect_s3_class(s, "manifold_sample")
    expect_equal(dim(s$X), c(150L, 3L))
    expect_equal(dim(s$truth), c(150L, 2L))
    expect_length(s$facet, 150L)
    expect_type(s$facet, "integer")
    expect_true(all(is.finite(s$X)), info = s$family)
    expect_true(all(is.finite(s$truth)), info = s$family)
    expect_identical(s$seed, 2L)
    # theta is the folding parameter of a crease pattern. These surfaces do not
    # have one, and NA is the honest entry: a join against THETA_GRID must fail
    # rather than succeed and mean nothing.
    expect_true(is.na(s$theta))
  }
  expect_identical(swiss_roll(20L)$seed, NA_integer_)
})

test_that("baselines are reproducible and leave the RNG alone", {
  a <- swiss_roll(100L, seed = 11L)
  b <- swiss_roll(100L, seed = 11L)
  expect_identical(a$X, b$X)
  expect_identical(a$truth, b$truth)

  set.seed(99L)
  before <- stats::runif(1L)
  set.seed(99L)
  invisible(swiss_roll(100L, seed = 11L))
  invisible(s_curve(100L, seed = 11L))
  invisible(severed_sphere(100L, seed = 11L))
  expect_equal(stats::runif(1L), before)

  # No seed means no set.seed() at all: two unseeded calls must differ, or
  # "unseeded" would be a silently fixed sample.
  set.seed(5L)
  expect_false(isTRUE(all.equal(swiss_roll(50L)$X, swiss_roll(50L)$X)))
})

test_that("noise moves X, never truth, on sampling.R's own model", {
  clean <- swiss_roll(200L, seed = 4L)
  noisy <- swiss_roll(200L, seed = 4L, noise = list(type = "ambient", sd = 0.02))
  expect_equal(clean$truth, noisy$truth)
  expect_false(isTRUE(all.equal(clean$X, noisy$X)))

  # Chapter 11 puts a crease pattern and a Swiss roll in one figure, so
  # "sd = 0.05" has to mean the same thing on both. The two implementations are
  # separate because these files do not reach into each other's internals; this
  # is what stops them drifting apart.
  X <- matrix(stats::rnorm(300), 100, 3)
  for (nz in list(list(type = "ambient", sd = 0.05),
                  list(type = "outlier", sd = 0.05),
                  list(type = "none", sd = 0))) {
    set.seed(4L); A <- .baseline_noise(X, nz, 7.5)
    set.seed(4L); B <- .apply_noise(X, nz, 7.5)
    expect_identical(A, B, info = nz$type)
  }
})

test_that("bad arguments fail before anything is drawn", {
  expect_error(swiss_roll(1L), "n must be")
  expect_error(swiss_roll(100L, turns = 0), "turns must be")
  expect_error(swiss_roll(100L, noise = list(type = "gaussian")), "unknown noise")
  expect_error(swiss_roll(100L, isometric = NA), "isometric must be")
  expect_error(swiss_roll(100L, spiral = "fresnel"), "'arg' should be one of")
  expect_error(s_curve(100L, height = -1), "height must be")
  expect_error(severed_sphere(100L, cap = pi), "cap must be")
  expect_error(severed_sphere(100L, seed = "x"), "seed must be")
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
  expect_equal(gs[4] / gs[1], sqrt(8), tolerance = 0.15)  # density, as n^(-1/2)

  # And at fixed n it must track folding, which is what it is used for.
  at <- function(th) branch_gap(
    sample_manifold(miura_ori(6L, 6L), theta = th, n = 400L, seed = 5L))$ratio
  flat   <- at(0)
  folded <- at(0.95)
  expect_gt(flat / folded, 2)
})
