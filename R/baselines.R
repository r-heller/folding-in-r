# ── Classical benchmarks ────────────────────────────────────────────────────
#
# The Swiss roll, the S-curve and the severed sphere, returned as
# manifold_sample objects so that every metric in R/metrics.R works on them
# unchanged and Chapter 11 compares like with like.
#
# THE POINT OF THIS FILE is the chart, not the surface. The customary Swiss roll
# is parameterised by the spiral's ANGLE, and the "ground truth" published with
# it is that angle paired with the height. Arc length along an Archimedean
# spiral is not proportional to angle, so the customary answer key is not the
# isometric chart, and almost every Swiss-roll evaluation in the literature is
# scored against a target that is not the isometry it claims to measure.
#
# That is a known defect, and it has a known fix: Schoeneman et al. (SDM 2017,
# 10.1137/1.9781611974973.84) proposed the Euler Isometric Swiss Roll, which
# replaces the Archimedean spiral with an Euler spiral -- the Fresnel integrals
# x(t) = int_0^t sin(s^2) ds, y(t) = int_0^t cos(s^2) ds -- precisely so that
# isometry holds. Their stated reason is that the Euler spiral has curvature
# proportional to distance from the origin, giving "constant angular
# acceleration ... thus ensuring that isometry is preserved". The construction
# is right and the reason is not quite: what makes it isometric is that the
# Fresnel parameterisation is UNIT SPEED, |(x'(t), y'(t))| = 1, so t is arc
# length by definition. Chapter 11 can say that in one line, and it should,
# because it is checkable.
#
# So all three constructions here offer the isometric chart by default and the
# customary one on request. Chapter 11's contribution is not noticing the
# defect -- that was done in 2017 -- it is measuring how large it is.

manifold_sample <- function(X, truth, facet, theta, seed, exact = TRUE, ...) {
  structure(c(list(X = X, truth = truth, facet = facet, theta = theta,
                   seed = seed, exact_truth = exact), list(...)),
            class = "manifold_sample")
}

.with_seed <- function(seed, expr) {
  # Restore the caller's stream. A benchmark generator that perturbs the RNG is
  # a benchmark generator that makes the run before it irreproducible.
  if (is.null(seed)) return(force(expr))
  if (exists(".Random.seed", .GlobalEnv)) {
    old <- get(".Random.seed", .GlobalEnv)
    on.exit(assign(".Random.seed", old, .GlobalEnv), add = TRUE)
  } else {
    on.exit(suppressWarnings(rm(".Random.seed", envir = .GlobalEnv)), add = TRUE)
  }
  set.seed(seed)
  force(expr)
}

.add_noise <- function(X, noise, scale) {
  if (is.null(noise) || identical(noise$type, "none") || !isTRUE(noise$sd > 0)) return(X)
  switch(
    noise$type,
    ambient = X + matrix(stats::rnorm(length(X), sd = noise$sd * scale),
                         nrow(X), ncol(X)),
    outlier = {
      m <- max(1L, round(0.02 * nrow(X)))
      i <- sample.int(nrow(X), m)
      X[i, ] <- X[i, ] + matrix(stats::rnorm(m * ncol(X), sd = noise$sd * scale * 10),
                                m, ncol(X))
      X
    },
    stop("unknown noise type '", noise$type, "'", call. = FALSE)
  )
}

# ── Swiss roll ──────────────────────────────────────────────────────────────

#' Arc length along the Archimedean spiral r = a*t, in closed form.
#'
#' The curve is (a t cos t, a t sin t), so the speed is a sqrt(1 + t^2) and
#'
#'     s(t) = (a/2) [ t sqrt(1 + t^2) + asinh(t) ].
#'
#' Integrated rather than approximated, because the whole point of this file is
#' that the difference between arc length and angle is not negligible.
archimedean_arclength <- function(t, a = 1) {
  (a / 2) * (t * sqrt(1 + t^2) + asinh(t))
}

#' Swiss roll
#'
#' @param turns How tightly wound. Larger means the sheets come closer together
#'   in the ambient space at fixed sampling density, which is the difficulty
#'   axis -- the same thing folding a crease pattern varies, expressed
#'   differently. This is what E1 tests.
#' @param spiral "archimedean" is the customary roll; "euler" is the
#'   isometric-by-construction one of Schoeneman et al.
#' @param isometric TRUE returns the arc-length chart, which is the correct
#'   answer key. FALSE returns the customary angle chart, so that Chapter 11 can
#'   measure the difference rather than assert it.
swiss_roll <- function(n = N_DEFAULT, turns = 2, noise = NULL, seed = NULL,
                       spiral = c("archimedean", "euler"),
                       isometric = TRUE, height = 10, outer_radius = 12) {
  spiral <- match.arg(spiral)
  .with_seed(seed, {
    # `turns` has to tighten the roll, not just make it bigger. The obvious
    # parameterisation -- let the angle run further and the radius with it --
    # adds revolutions at CONSTANT sheet spacing, so the k-NN graph stays
    # faithful however many turns are asked for and the knob controls nothing.
    # It measured a short-circuit index of 0.999 at four turns, which is what
    # exposed it.
    #
    # Instead the outer radius is held fixed and the requested revolutions are
    # fitted inside it: a = R / t_end, so the radial gap between consecutive
    # sheets is 2 pi a and falls as 1/turns. That is the difficulty axis
    # Balasubramanian & Schwartz identified, and the thing E1 compares against
    # folding a crease pattern.
    t0    <- 1.5 * pi
    t_end <- t0 + turns * 2 * pi
    a     <- outer_radius / t_end
    if (spiral == "archimedean") {
      # Uniform over ARC LENGTH, not over t: sampling t uniformly puts more
      # points on the inner turns, where the sheets are closest, and quietly
      # makes the short-circuit index a function of the sampler.
      s_lo <- archimedean_arclength(t0, a); s_hi <- archimedean_arclength(t_end, a)
      s <- stats::runif(n, s_lo, s_hi)
      tg <- seq(t0, t_end, length.out = 4001L)
      t <- stats::approx(archimedean_arclength(tg, a), tg, s)$y
      x <- a * t * cos(t); y <- a * t * sin(t)
      conventional <- t
    } else {
      # Fresnel: unit speed, so t IS arc length and no integration is needed.
      # Scaled to the same outer radius so the two spirals are comparable.
      u <- stats::runif(n, sqrt(t0), sqrt(t_end))
      xs <- .fresnel_s(u); ys <- .fresnel_c(u)
      k <- outer_radius / max(sqrt(xs^2 + ys^2))
      x <- k * xs; y <- k * ys
      s <- k * u
      conventional <- u^2
    }
    z <- stats::runif(n, 0, height)

    X <- cbind(x = x, y = z, z = y)
    truth <- cbind(u = if (isometric) s else conventional, v = z)
    X <- .add_noise(X, noise, scale = diff(range(X)))

    manifold_sample(X, truth, facet = rep(1L, n), theta = turns, seed = seed,
                    exact = TRUE, family = "swiss_roll", spiral = spiral,
                    chart = if (isometric) "arclength" else "angle")
  })
}

# Fresnel integrals, by adaptive quadrature. Vectorised over t and cached on a
# grid, because E1 calls this once per sample and stats::integrate() per point
# would dominate the run.
.fresnel_grid <- function(t_max, m = 2001L) {
  g <- seq(0, t_max, length.out = m)
  h <- diff(g)[1]
  fs <- sin(g^2); fc <- cos(g^2)
  # cumulative trapezoid
  list(g = g,
       S = c(0, cumsum((fs[-1] + fs[-m]) / 2 * h)),
       C = c(0, cumsum((fc[-1] + fc[-m]) / 2 * h)))
}
.fresnel_s <- function(t) { gr <- .fresnel_grid(max(t)); stats::approx(gr$g, gr$S, t)$y }
.fresnel_c <- function(t) { gr <- .fresnel_grid(max(t)); stats::approx(gr$g, gr$C, t)$y }

# ── S-curve ─────────────────────────────────────────────────────────────────

#' S-curve
#'
#' The standard construction is already unit speed: with x = sin(t) and
#' z = sign(t)(cos(t) - 1), the speed is sqrt(cos^2 t + sin^2 t) = 1, so t is
#' arc length exactly and the customary chart happens to be the isometric one.
#' Worth stating rather than leaving implicit -- it is the reason the S-curve
#' does not carry the Swiss roll's defect.
s_curve <- function(n = N_DEFAULT, noise = NULL, seed = NULL, height = 2) {
  .with_seed(seed, {
    t <- stats::runif(n, -1.5 * pi, 1.5 * pi)
    z <- stats::runif(n, 0, height)
    X <- cbind(x = sin(t), y = z, z = sign(t) * (cos(t) - 1))
    X <- .add_noise(X, noise, scale = diff(range(X)))
    manifold_sample(X, cbind(u = t, v = z), rep(1L, n), theta = NA_real_,
                    seed = seed, exact = TRUE, family = "s_curve",
                    chart = "arclength")
  })
}

# ── Severed sphere ──────────────────────────────────────────────────────────

#' Severed sphere -- a sphere with a polar cap removed.
#'
#' THIS ONE HAS NO ISOMETRIC PLANAR CHART, and cannot: a sphere has constant
#' positive Gaussian curvature, so by Gauss's Theorema Egregium no planar chart
#' preserves distances anywhere on it. That is exactly why it is in the book. It
#' is the case where exact truth does not exist, and the contrast with a crease
#' pattern -- where it does -- is the whole argument.
#'
#' The returned truth is therefore the CONVENTIONAL chart, not ground truth, and
#' the object is flagged exact_truth = FALSE so that no chapter can quietly
#' score against it as though it were exact. `require_exact_truth()` is what
#' enforces that.
severed_sphere <- function(n = N_DEFAULT, noise = NULL, seed = NULL,
                           cap = pi / 8) {
  .with_seed(seed, {
    phi <- stats::runif(n, cap, pi - cap)
    lam <- stats::runif(n, 0, 2 * pi)
    X <- cbind(x = sin(phi) * cos(lam), y = sin(phi) * sin(lam), z = cos(phi))
    X <- .add_noise(X, noise, scale = 2)
    manifold_sample(X, cbind(u = lam, v = phi), rep(1L, n), theta = NA_real_,
                    seed = seed, exact = FALSE, family = "severed_sphere",
                    chart = "conventional (not isometric; Theorema Egregium)")
  })
}

#' Refuse to proceed on a sample whose truth is not exact.
#'
#' The book reserves "ground truth" for objects that have one. Any analysis that
#' would report a reconstruction error as though it were measured against truth
#' calls this first, so the severed sphere cannot be used as if it were a crease
#' pattern by inattention.
require_exact_truth <- function(sample, what = "this analysis") {
  if (!isTRUE(sample$exact_truth)) {
    stop(what, " needs exact ground truth, and this sample does not have it: ",
         sample$family, " carries a conventional chart (",
         sample$chart, "). Scoring against it measures agreement with a ",
         "convention, not recovery of a structure.", call. = FALSE)
  }
  invisible(TRUE)
}

# ── The difficulty index ────────────────────────────────────────────────────

#' Short-circuit index.
#'
#' The median ambient nearest-neighbour distance, over the median TRUE intrinsic
#' distance between those same pairs. Near 1 means the k-NN graph is faithful:
#' points that are close in the ambient space are close along the surface too.
#' Well below 1 means the graph is short-circuiting -- it is joining points that
#' the surface keeps far apart, which is the failure mode that breaks every
#' geodesic method.
#'
#' Reported alongside branch_gap() from R/folding.R. The two measure the same
#' phenomenon from opposite ends: branch_gap asks how close distant sheets come,
#' this asks whether the neighbours a method would actually pick are honest.
short_circuit_index <- function(sample, k = K_DEFAULT) {
  dA <- as.matrix(stats::dist(sample$X))
  dU <- as.matrix(stats::dist(sample$truth))
  diag(dA) <- Inf

  nn <- t(apply(dA, 1, function(r) order(r)[seq_len(k)]))
  i  <- rep(seq_len(nrow(dA)), each = k)
  j  <- as.vector(t(nn))

  stats::median(dA[cbind(i, j)]) / stats::median(dU[cbind(i, j)])
}
