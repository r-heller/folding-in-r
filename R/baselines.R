# ── Classical benchmarks ─────────────────────────────────────────────────────
#
# The Swiss roll, the S-curve and the severed sphere, returned as
# manifold_sample objects (R/README.md) so that every metric in R/metrics.R
# works on them unchanged and Chapter 11 compares like with like.
#
# THE POINT OF THIS FILE IS THE CHART, NOT THE SURFACE. The customary Swiss
# roll is parameterised by the spiral's ANGLE, and the "ground truth" shipped
# with it is that angle paired with the height. Arc length along an Archimedean
# spiral is not proportional to angle -- it is
#
#     s(t) = (a/2) [ t sqrt(1 + t^2) + asinh(t) ]
#
# -- so the customary answer key is not the isometric chart. An evaluation
# scored against it measures recovery of a reparameterisation, not recovery of
# the isometry it claims to measure, and the two differ by a factor that is a
# property of the roll rather than of the method under test.
#
# That is a known defect with a known fix. Schoeneman et al. (SDM 2017,
# 10.1137/1.9781611974973.84) proposed the Euler Isometric Swiss Roll, which
# replaces the Archimedean spiral with an Euler spiral -- the Fresnel integrals
# x(t) = int_0^t sin(u^2) du, y(t) = int_0^t cos(u^2) du. Their stated reason is
# that the Euler spiral has curvature proportional to distance from the origin,
# giving "constant angular acceleration along the curve thus ensuring that
# isometry is preserved". The construction is right; the reason is not quite.
# What makes it isometric is that the parameterisation is UNIT SPEED,
# |(x'(t), y'(t))| = 1, so t IS arc length by definition. Chapter 11 should say
# that in one line, because it is checkable and the paper's phrasing is not.
#
# Chapter 11's contribution is therefore not noticing the defect -- that was
# done in 2017 -- it is measuring how large it is. So every construction here
# ships the isometric chart by default and the customary one on request, and
# the gap gets measured on one sample instead of argued about.
#
# Internal helpers carry a leading dot, as in R/sampling.R and R/plotting.R:
# R/ is sourced into the global environment, so everything here is visible from
# a chapter, and the dot marks what is not part of the interface.

# ── The returned object ──────────────────────────────────────────────────────
#
# sample_manifold() builds the same class inline and carries exactly the five
# contract fields. These constructions carry four more, and each earns its
# place:
#
#   family       which construction, so a chapter labels a panel from the
#                object rather than by guessing from the geometry.
#   chart        what `truth` actually is: "arclength", "angle", "equidistant".
#   exact_truth  FALSE when the chart is a convention rather than an isometry.
#                ABSENT MEANS TRUE. A crease pattern always has exact truth, so
#                sample_manifold() has nothing to declare and does not declare
#                it; only a construction that knows its answer key is a
#                convention sets the flag. require_exact_truth() reads it.
#   iso_chart    the isometric chart when one exists, kept even when `truth`
#                has deliberately been set to the customary chart, so that a
#                difficulty statistic measured on a wrong answer key still
#                measures difficulty and not the wrongness of the key.
#
# theta is NA on all three. It is the folding parameter of a crease pattern and
# these surfaces do not have one. Writing `turns` into that slot would let a
# join against THETA_GRID succeed and mean nothing, which is worse than a join
# that fails.
.baseline_sample <- function(X, truth, seed, family, chart, exact = TRUE, ...) {
  dimnames(X) <- NULL
  dimnames(truth) <- NULL
  structure(
    c(list(X     = X,
           truth = truth,
           # One smooth piece: no facets, and one label rather than none, so
           # that code which colours by facet does not have to special-case
           # these three.
           facet = rep(1L, nrow(X)),
           theta = NA_real_,
           seed  = if (is.null(seed)) NA_integer_ else as.integer(seed)[1L],
           family      = family,
           chart       = chart,
           exact_truth = exact),
      list(...)),
    class = "manifold_sample")
}

# ── RNG discipline ───────────────────────────────────────────────────────────
#
# The same contract as sample_manifold(): a seed makes the draw reproducible
# without costing the caller their stream, and no seed means no call to
# set.seed() at all. Restoring the stream in the unseeded case would be worse
# than useless -- two successive unseeded calls would return the same sample.
.with_seed <- function(seed, expr) {
  if (is.null(seed)) return(force(expr))
  # Type checked before coercion: as.integer("x") is NA with a warning, and a
  # warning that a benchmark was seeded with nonsense is not enough.
  if (!is.numeric(seed) || length(seed) != 1L || is.na(seed)) {
    stop("seed must be a single integer or NULL", call. = FALSE)
  }
  seed <- as.integer(seed)
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit({
    if (had) {
      assign(".Random.seed", old, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  }, add = TRUE)
  set.seed(seed)
  force(expr)
}

# ── Noise ────────────────────────────────────────────────────────────────────
#
# The same two models as .apply_noise() in R/sampling.R, with the same
# parameterisation, deliberately: Chapter 11 puts a crease pattern and a Swiss
# roll in the same figure, and a comparison in which "sd = 0.05" means one
# thing on one family and something else on the other measures the noise model
# rather than the surfaces. tests/testthat/test-baselines.R asserts the two
# implementations agree on the same input, so the pair cannot drift apart
# unnoticed.
#
# It is a second implementation rather than a call into R/sampling.R because
# these files do not reach into each other's dotted internals -- sampling.R
# makes the same choice about plotting.R's validator, and for the same reason.
#
# The scale is the INTRINSIC diameter of the surface, not the ambient one, so
# that noise is a fixed fraction of the object rather than of how the object
# happens to sit in R^3. A Swiss roll's ambient diameter barely moves as it is
# wound tighter while its intrinsic diameter grows with every turn; scaling to
# the ambient one would quietly make noise weaker on exactly the hard cells.
.baseline_noise <- function(X, noise, diameter) {
  type <- if (is.null(noise$type)) "none" else as.character(noise$type)[1L]
  if (identical(type, "none")) return(X)

  sdev <- if (is.null(noise$sd)) 0 else as.numeric(noise$sd)[1L]
  if (!is.finite(sdev) || sdev < 0) {
    stop("noise$sd must be a single non-negative number", call. = FALSE)
  }

  if (identical(type, "ambient")) {
    return(X + matrix(stats::rnorm(length(X), sd = sdev * diameter),
                      nrow(X), ncol(X)))
  }

  if (identical(type, "outlier")) {
    frac <- if (is.null(noise$frac)) sdev else as.numeric(noise$frac)[1L]
    mult <- if (is.null(noise$scale)) 0.5 else as.numeric(noise$scale)[1L]
    if (!is.finite(frac) || frac < 0 || frac > 1) {
      stop("the outlier fraction must lie in [0, 1]; got ", frac, call. = FALSE)
    }
    n_out <- as.integer(round(frac * nrow(X)))
    if (n_out < 1L) return(X)
    hit  <- sample.int(nrow(X), n_out)
    dirs <- matrix(stats::rnorm(3L * n_out), n_out, 3L)
    dirs <- dirs / sqrt(rowSums(dirs^2))
    X[hit, ] <- X[hit, ] + (mult * diameter) * dirs
    return(X)
  }

  stop("unknown noise$type \"", type, "\"; expected \"none\", \"ambient\" ",
       "or \"outlier\"", call. = FALSE)
}

# Shared argument checks. Written once because three constructions make the
# same two mistakes possible.
.check_baseline_args <- function(n, noise) {
  n <- as.integer(n)[1L]
  if (is.na(n) || n < 2L) {
    stop("n must be a single integer of at least 2", call. = FALSE)
  }
  if (!is.list(noise)) {
    stop("noise must be a list; see the noise models in R/sampling.R",
         call. = FALSE)
  }
  ntype <- if (is.null(noise$type)) "none" else as.character(noise$type)[1L]
  if (!ntype %in% c("none", "ambient", "outlier")) {
    stop("unknown noise$type \"", ntype, "\"; expected \"none\", ",
         "\"ambient\" or \"outlier\"", call. = FALSE)
  }
  n
}

# One positive finite number, named in the message. Written once because the
# three constructions take five such arguments between them.
.check_positive <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0) {
    stop(name, " must be a single positive number", call. = FALSE)
  }
  as.numeric(x)
}

# ── Arc length along an Archimedean spiral ───────────────────────────────────

#' Arc length of r = a * t, measured from t = 0.
#'
#' The curve is (a t cos t, a t sin t), so the speed is a sqrt(1 + t^2) and
#'
#'     s(t) = (a/2) [ t sqrt(1 + t^2) + asinh(t) ].
#'
#' In closed form rather than quadrature, because the entire claim of this file
#' is that the difference between arc length and angle is not negligible, and a
#' claim of that shape should not be resting on a tolerance. It is linear in a,
#' exact at t = 0, and tested against high-resolution numerical integration.
archimedean_arclength <- function(t, a = 1) {
  (a / 2) * (t * sqrt(1 + t^2) + asinh(t))
}

# Invert s(t) by Newton. s is strictly increasing with s'(t) = a sqrt(1 + t^2),
# so the iteration is globally convergent from any t >= 0, and the large-t limit
# s ~ (a/2) t^2 gives a starting point already within a few per cent over the
# range this file uses.
#
# Inversion is needed only to place points; it is never in the answer key. The
# chart value returned by swiss_roll() is the closed-form arc length of the t
# that was actually used, so truth stays exact whatever the inversion did.
.archimedean_invert <- function(s, a) {
  t <- sqrt(pmax(2 * s / a, 0))
  tol <- 1e-13 * (1 + max(abs(s)))
  for (iter in seq_len(60L)) {
    f <- archimedean_arclength(t, a) - s
    if (max(abs(f)) < tol) break
    t <- pmax(t - f / (a * sqrt(1 + t^2)), 0)
  }
  if (max(abs(archimedean_arclength(t, a) - s)) > 1e-9 * (1 + max(abs(s)))) {
    stop("arc-length inversion did not converge", call. = FALSE)
  }
  t
}

# ── The Euler spiral ─────────────────────────────────────────────────────────
#
# Fresnel integrals by cumulative trapezoid on a grid of fixed step, then
# linear interpolation. Three things make this acceptable in a file that
# refuses to integrate the Archimedean arc length numerically:
#
#   1. It integrates the POSITION, not the chart. The Euler spiral's chart is
#      exact by construction -- unit speed means t is arc length -- so no
#      tolerance enters the answer key.
#   2. The grid step is fixed rather than derived from the number of points
#      requested, so two samples of the same roll sit on the same curve to the
#      last bit, whatever n is.
#   3. The error is measured. tests/testthat/test-baselines.R checks it against
#      stats::integrate(), which is a different method and not a finer version
#      of the same one.
.fresnel <- function(t, t_max = max(t), step = 1e-4) {
  m <- max(2L, as.integer(ceiling(t_max / step)) + 1L)
  g <- seq(0, t_max, length.out = m)
  h <- g[2L] - g[1L]
  fs <- sin(g^2)
  fc <- cos(g^2)
  cum <- function(f) c(0, cumsum((f[-1L] + f[-m]) / 2) * h)
  list(S = stats::approx(g, cum(fs), t)$y,
       C = stats::approx(g, cum(fc), t)$y)
}

# ── Swiss roll ───────────────────────────────────────────────────────────────

#' A Swiss roll, with the chart it is actually scored against as an argument.
#'
#' turns is the difficulty knob and it has to tighten the roll rather than
#' merely make it bigger. The obvious parameterisation -- let the angle run
#' further and the radius run with it -- adds revolutions at CONSTANT sheet
#' spacing, so the k-NN graph stays faithful however many turns are asked for
#' and the knob controls nothing; that version measures a short-circuit index
#' of 0.999 at four turns and 0.999 again at eight, which is what exposed it.
#' Here the outer radius is held fixed and the requested revolutions are fitted
#' inside it (a = R / t_end), so the radial gap between consecutive sheets is
#' 2 pi a and falls as 1 / turns.
#' That is Balasubramanian & Schwartz's ratio, and it is the axis PLAN.md E1
#' plots crease patterns against.
#'
#' isometric = TRUE returns arc length paired with height, which is the correct
#' answer key. isometric = FALSE returns the customary angle chart, so Chapter
#' 11 can measure the gap on one sample rather than assert it. Note that
#' branch_gap() and any other statistic reading `truth` should be given the
#' default: with isometric = FALSE they would be reading the wrong chart, which
#' is why iso_chart travels with the object either way.
#'
#' spiral = "euler" is the Euler Isometric Swiss Roll of Schoeneman et al.,
#' where the parameter published as truth is already arc length -- the control
#' case showing the gap is a property of the Archimedean parameterisation and
#' not of Swiss rolls in general. On that roll isometric = FALSE returns the
#' TURNING ANGLE, which is the analogue of the Archimedean angle chart and not
#' something anyone published: it answers what the Euler roll would have cost
#' had it been labelled the same careless way, and it is a smaller number.
swiss_roll <- function(n = N_DEFAULT, turns = 2,
                       noise = list(type = "none", sd = 0),
                       seed = NULL, isometric = TRUE,
                       spiral = c("archimedean", "euler"),
                       height = 10, outer_radius = 12) {
  n <- .check_baseline_args(n, noise)
  spiral <- match.arg(spiral)
  if (!is.logical(isometric) || length(isometric) != 1L || is.na(isometric)) {
    stop("isometric must be TRUE or FALSE", call. = FALSE)
  }
  turns        <- .check_positive(turns, "turns")
  height       <- .check_positive(height, "height")
  outer_radius <- .check_positive(outer_radius, "outer_radius")

  # The inner end. 1.5 pi is the customary starting angle and it matters: the
  # spiral is nearly straight near t = 0 and the roll would have no roll in it.
  t0    <- 1.5 * pi
  t_end <- t0 + turns * 2 * pi

  .with_seed(seed, {
    if (spiral == "archimedean") {
      a <- outer_radius / t_end
      # Uniform over ARC LENGTH, not over t. Sampling t uniformly puts more
      # points on the inner turns, where the sheets are closest, and quietly
      # makes the short-circuit index a function of the sampler rather than of
      # the surface.
      s_lo <- archimedean_arclength(t0, a)
      s_hi <- archimedean_arclength(t_end, a)
      t <- .archimedean_invert(stats::runif(n, s_lo, s_hi), a)
      x <- a * t * cos(t)
      y <- a * t * sin(t)
      # Both charts recomputed from the t actually used, so neither inherits
      # the inversion's error, and both start at 0 so they overlay directly.
      arc   <- archimedean_arclength(t, a) - s_lo
      angle <- t - t0
      span  <- s_hi - s_lo
    } else {
      # Unit speed, so drawing t uniformly is already uniform in arc length,
      # and the tangent turns through t^2 -- hence sqrt() on both ends to get
      # the same `turns` revolutions as the Archimedean branch.
      u0 <- sqrt(t0)
      u1 <- sqrt(t_end)
      u  <- stats::runif(n, u0, u1)
      # The scale factor is read off a deterministic grid, not off the drawn
      # points: taking it from max() over the sample would make the size of the
      # surface a function of the seed.
      grid <- seq(u0, u1, length.out = 2001L)
      fg   <- .fresnel(grid, t_max = u1)
      k    <- outer_radius / max(sqrt(fg$S^2 + fg$C^2))
      f    <- .fresnel(u, t_max = u1)
      x <- k * f$S
      y <- k * f$C
      arc   <- k * (u - u0)
      angle <- u^2 - t0
      span  <- k * (u1 - u0)
    }
    z <- stats::runif(n, 0, height)

    # Ambient layout follows the usual one: the roll in the x-z plane, the free
    # direction in y.
    X <- cbind(x, z, y)
    iso <- cbind(arc, z)
    X <- .baseline_noise(X, noise, sqrt(span^2 + height^2))

    .baseline_sample(
      X, truth = if (isometric) iso else cbind(angle, z),
      seed = seed, family = "swiss_roll",
      chart = if (isometric) "arclength" else "angle",
      exact = TRUE, iso_chart = iso, spiral = spiral, turns = turns)
  })
}

# ── S-curve ──────────────────────────────────────────────────────────────────

#' The S-curve, whose customary chart happens already to be the isometric one.
#'
#' With x = sin(t) and z = sign(t) (cos(t) - 1) the speed is
#' sqrt(cos^2 t + sin^2 t) = 1, so t is arc length exactly and the answer key
#' shipped with the standard construction is the right one. Worth stating
#' rather than leaving implicit: it is the reason the S-curve does not carry
#' the Swiss roll's defect, and it makes the S-curve the control that shows the
#' Swiss-roll gap is about the Archimedean spiral rather than about the habit
#' of colouring a picture by its generating parameter.
s_curve <- function(n = N_DEFAULT, noise = list(type = "none", sd = 0),
                    seed = NULL, height = 2) {
  n <- .check_baseline_args(n, noise)
  height <- .check_positive(height, "height")
  .with_seed(seed, {
    t <- stats::runif(n, -1.5 * pi, 1.5 * pi)
    z <- stats::runif(n, 0, height)
    X <- cbind(sin(t), z, sign(t) * (cos(t) - 1))
    iso <- cbind(t, z)
    X <- .baseline_noise(X, noise, sqrt((3 * pi)^2 + height^2))
    .baseline_sample(X, truth = iso, seed = seed, family = "s_curve",
                     chart = "arclength", exact = TRUE, iso_chart = iso)
  })
}

# ── Severed sphere ───────────────────────────────────────────────────────────

#' A sphere with one polar cap removed.
#'
#' THIS SURFACE HAS NO ISOMETRIC PLANAR CHART AND CANNOT HAVE ONE. A sphere of
#' radius R has Gaussian curvature 1/R^2 everywhere, the plane has zero, and by
#' Gauss's Theorema Egregium curvature is intrinsic -- so no chart of any patch
#' of it preserves distances, however small the patch or clever the chart. That
#' is exactly why it is in the book: it is the case where exact truth does not
#' exist, and the contrast with a crease pattern, where it does, is the whole
#' argument of Chapter 11.
#'
#' ONE cap, not two. Removing one leaves a topological disk, so the obstruction
#' to a planar chart is purely metric, which is the point being made. Removing
#' both leaves an annulus and confounds curvature with topology -- a method
#' would then be failing for a reason that has nothing to do with curvature.
#'
#' The returned truth is a CONVENTION, not ground truth, and the object says so
#' with exact_truth = FALSE. The default convention is the azimuthal-equidistant
#' chart about the retained pole: the exponential map, which gets every geodesic
#' through the centre exactly right and stretches every circle around it by
#' r / (R sin(r/R)). That factor is the honest statement of how wrong it is, it
#' is closed-form, and Chapter 11 can quote it: at the default cap it reaches
#' 7.18 at the rim. tests/testthat/test-baselines.R checks the closed form
#' against the sphere rather than taking it on trust. chart = "spherical"
#' returns the raw (longitude, colatitude) pair instead, which is what the
#' literature usually colours by and is worse still.
severed_sphere <- function(n = N_DEFAULT, noise = list(type = "none", sd = 0),
                           seed = NULL, cap = pi / 8, radius = 1,
                           chart = c("equidistant", "spherical")) {
  n <- .check_baseline_args(n, noise)
  chart <- match.arg(chart)
  if (!is.numeric(cap) || length(cap) != 1L || is.na(cap) || cap <= 0 ||
      cap >= pi) {
    stop("cap must be a single number in (0, pi)", call. = FALSE)
  }
  radius <- .check_positive(radius, "radius")
  .with_seed(seed, {
    # Uniform over AREA, not over colatitude. The area element is
    # sin(phi) dphi dlambda, so cos(phi) is what must be drawn uniformly;
    # drawing phi uniformly crowds points against the poles and every
    # neighbourhood metric downstream reads that density gradient as structure.
    # R/sampling.R makes the same correction for the same reason.
    phi <- acos(stats::runif(n, -1, cos(cap)))
    lam <- stats::runif(n, 0, 2 * pi)
    X <- radius * cbind(sin(phi) * cos(lam), sin(phi) * sin(lam), cos(phi))

    # Geodesic distance from the retained pole (phi = pi).
    r <- radius * (pi - phi)
    truth <- if (chart == "equidistant") cbind(r * cos(lam), r * sin(lam)) else
      cbind(lam, phi)

    # The intrinsic diameter: the longest geodesic inside the retained region
    # runs from the rim, over the retained pole, and back up to the far side of
    # the rim. The short way over the removed cap is not on the surface.
    X <- .baseline_noise(X, noise, 2 * radius * (pi - cap))

    .baseline_sample(X, truth = truth, seed = seed, family = "severed_sphere",
                     chart = if (chart == "equidistant")
                       "equidistant (a convention; no isometric chart exists)"
                     else "spherical (a convention; no isometric chart exists)",
                     exact = FALSE, angles = cbind(lam, phi),
                     radius = radius, cap = as.numeric(cap))
  })
}

#' Refuse to proceed on a sample whose truth is not exact.
#'
#' The book reserves "ground truth" for objects that have one. Anything about
#' to report a reconstruction error as recovery of a structure calls this
#' first, so the severed sphere cannot be scored as though it were a crease
#' pattern by inattention -- which is the failure this whole file exists to
#' make impossible.
#'
#' Absence of the flag means exact. sample_manifold() does not set it, and
#' should not have to: a crease pattern's chart is the ground truth by
#' construction, and defaulting the other way would turn every call site in
#' Chapters 4-10 into an error to make one construction in Chapter 11 safe.
require_exact_truth <- function(sample, what = "this analysis") {
  if (identical(sample$exact_truth, FALSE)) {
    stop(what, " needs exact ground truth, and this sample does not have it: ",
         sample$family, " carries a conventional chart (", sample$chart,
         "). Scoring against it measures agreement with a convention, not ",
         "recovery of a structure.", call. = FALSE)
  }
  invisible(TRUE)
}

# ── The difficulty index ─────────────────────────────────────────────────────

# True intrinsic distance between the pairs (i[m], j[m]).
#
# Three cases, and the middle one is the reason this helper exists rather than
# a call to dist(sample$truth):
#
#   * The severed sphere has no isometric chart but it does have an intrinsic
#     metric -- great-circle distance, in closed form. "No isometric chart"
#     and "no true distances" are different statements and conflating them
#     would make the sphere unmeasurable when it is merely unchartable. For
#     pairs straddling the removed cap the geodesic on the severed surface is
#     longer than the great circle; nearest-neighbour pairs never straddle it.
#   * A construction that carries iso_chart is measured against that, so
#     swiss_roll(isometric = FALSE) still reports a real difficulty rather than
#     the error of the chart it was asked to hand out.
#   * Everything else -- crease-pattern samples from sample_manifold() -- is
#     measured against the chart, which is the geodesic distance whenever the
#     straight segment between the two chart points stays inside the sheet.
#     The pairs here are nearest neighbours, so it does.
.intrinsic_pairs <- function(sample, i, j) {
  if (identical(sample$family, "severed_sphere")) {
    ang <- sample$angles
    u <- cbind(sin(ang[, 2L]) * cos(ang[, 1L]),
               sin(ang[, 2L]) * sin(ang[, 1L]),
               cos(ang[, 2L]))
    dot <- rowSums(u[i, , drop = FALSE] * u[j, , drop = FALSE])
    return(sample$radius * acos(pmin(1, pmax(-1, dot))))
  }
  U <- sample$iso_chart
  if (is.null(U)) {
    require_exact_truth(sample, "the short-circuit index")
    U <- sample$truth
  }
  sqrt(rowSums((U[i, , drop = FALSE] - U[j, , drop = FALSE])^2))
}

#' Short-circuit index.
#'
#' The median ambient nearest-neighbour distance over the median TRUE intrinsic
#' distance between those same pairs. Near 1 means the k-NN graph is faithful:
#' the points a method would pick as neighbours are neighbours on the surface
#' too. Well below 1 means the graph is short-circuiting -- joining points the
#' surface holds far apart -- which is the failure that breaks every geodesic
#' method, and it is the difficulty axis PLAN.md E1 plots against.
#'
#' It is a ratio of medians rather than a median of ratios on purpose. Every
#' individual short-circuited pair has an ambient-to-intrinsic ratio near zero,
#' so a median of ratios is dominated by whether the sample happens to contain
#' more or fewer of them; the ratio of medians answers the question that
#' matters at the scale that matters, which is whether the typical edge of the
#' graph a method builds is honest.
#'
#' Reported alongside branch_gap() from R/folding.R. The two measure the same
#' phenomenon from opposite ends: branch_gap asks how close distant sheets come
#' in units of the sampling density, this asks whether the neighbours a method
#' would actually pick are honest. Both are needed, and the roll that grows
#' instead of tightening is the case that shows why: over two to six turns of
#' it g/s falls from 10.2 to 4.0 while this index holds at 0.999. g/s fell
#' because the sample thinned over a larger surface, not because the sheets
#' closed in. This index is scale-free -- bounded above by 1 on any surface,
#' comparable across families and sample sizes -- and reports no difficulty,
#' correctly.
short_circuit_index <- function(sample, k = K_DEFAULT) {
  X <- sample$X
  n <- nrow(X)
  k <- as.integer(k)[1L]
  if (is.na(k) || k < 1L || k >= n) {
    stop("k must be a single integer in [1, n - 1]; got ", k, " with n = ", n,
         call. = FALSE)
  }
  dA <- as.matrix(stats::dist(X))
  diag(dA) <- Inf
  # k x n: column m holds the k ambient nearest neighbours of point m, so
  # unrolling column-major lines the pairs up with rep(seq_len(n), each = k).
  nn <- apply(dA, 1L, function(r) order(r)[seq_len(k)])
  i <- rep(seq_len(n), each = k)
  j <- as.vector(nn)
  stats::median(dA[cbind(i, j)]) / stats::median(.intrinsic_pairs(sample, i, j))
}
