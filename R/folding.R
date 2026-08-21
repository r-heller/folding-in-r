# ── The folding map ─────────────────────────────────────────────────────────
#
# fold(pattern, theta) places a flat crease_pattern in R^3 at folding parameter
# theta. It knows nothing about how the pattern was constructed; patterns.R
# knows nothing about folding.
#
# THETA IS A PARAMETER, NOT AN ANGLE. It runs on [0, 1]: 0 is the flat sheet
# and 1 is the flat-folded state, where the sheet has collapsed onto itself. The
# glossary already says this -- "the parameter of the folding map ... not an
# angle read off a figure" -- and the alternative is worse in two ways. A
# dihedral angle is family-specific and its valid range depends on the cell
# parameters (a Miura with acute angle alpha folds flat at corrugation angle
# alpha, so [0, 1.4] is not a legal sweep for alpha = pi/3), and a normalised
# parameter makes Miura, Yoshimura and any later family directly comparable at
# equal fold fraction. The dihedral angles are derived and returned in `rho`.
#
# The sweep in scripts/run-benchmark-grid.R was [0, 1.4], inherited from an
# accordion-fold stand-in that no longer exists. It is corrected to this scale.
#
# HOW THE FOLDINGS ARE DERIVED. Not by rotating facets about creases and hoping
# the placement closes -- by writing down the folded vertex positions with
# unknown metric constants, imposing edge-length and facet-angle preservation,
# and solving. That yields a one-parameter family in closed form, and the
# isometry is then exact by construction rather than to solver tolerance. The
# tests verify it anyway, because "exact by construction" is a claim about the
# algebra and the algebra is what might be wrong.

folded_pattern <- function(pattern, theta, vertices3, rho) {
  structure(list(pattern = pattern, theta = theta,
                 vertices3 = vertices3, rho = rho),
            class = "folded_pattern")
}

fold <- function(pattern, theta) {
  stopifnot(inherits(pattern, "crease_pattern"))
  if (theta < 0 || theta > 1) {
    stop("theta is the folding parameter and runs on [0, 1]: 0 is the flat ",
         "sheet, 1 the flat-folded state. Got ", theta,
         ". If you meant a dihedral angle, see the glossary -- they are not the ",
         "same thing and conflating them is the error this book already made ",
         "once.", call. = FALSE)
  }
  v3 <- switch(
    pattern$family,
    miura     = .fold_miura(pattern, theta),
    yoshimura = .fold_yoshimura(pattern, theta),
    stop("no folding map for family '", pattern$family, "'", call. = FALSE)
  )
  folded_pattern(pattern, theta, v3, .dihedrals(pattern, v3))
}

# ── Miura ───────────────────────────────────────────────────────────────────
#
# Flat vertex (i, j) sits at (i a + (j mod 2) b cos alpha, j b sin alpha).
# Look for a folded placement of the same combinatorial form,
#
#     x = i Lx + (j mod 2) dx,   y = j Ly,   z = (i mod 2) H,
#
# so that the corrugation runs across the columns and the rows contract. Two
# facet side vectors follow immediately,
#
#     e1 = (Lx, 0, +/- H)        the horizontal edge, flat length a
#     e2 = (+/- dx, Ly, 0)       the zigzag edge,     flat length b
#
# and because e1 and e2 are the same for both pairs of opposite sides, every
# facet is a parallelogram and therefore planar without further conditions.
# Isometry needs the two edge lengths and the angle between them:
#
#     Lx^2 + H^2   = a^2                     (1)
#     dx^2 + Ly^2  = b^2                     (2)
#     Lx dx        = a b cos(alpha)          (3)
#
# Three equations, four unknowns: a one-parameter family, which is the rigid
# folding. Writing Lx = a cos(phi), H = a sin(phi) solves (1) identically and
# leaves
#
#     dx = b cos(alpha) / cos(phi),   Ly = b sqrt(1 - cos^2(alpha)/cos^2(phi)).
#
# Ly is real only while phi <= alpha, and Ly = 0 exactly at phi = alpha, which
# is the flat-folded state. So phi runs on [0, alpha] and the natural normalised
# parameter is theta = phi / alpha. At theta = 0: Lx = a, H = 0, dx = b cos
# alpha, Ly = b sin alpha -- the flat pattern, recovered exactly rather than in
# the limit.
.fold_miura <- function(pattern, theta) {
  p <- pattern$params
  nx <- p$nx; ny <- p$ny; a <- p$a; b <- p$b; alpha <- p$alpha

  phi <- theta * alpha
  Lx  <- a * cos(phi)
  H   <- a * sin(phi)
  dx  <- b * cos(alpha) / cos(phi)
  s   <- 1 - (cos(alpha) / cos(phi))^2
  Ly  <- b * sqrt(max(0, s))          # max() guards the endpoint, where s is
                                      # zero up to rounding

  ii <- rep(0:nx, times = ny + 1L)
  jj <- rep(0:ny, each  = nx + 1L)
  cbind(
    x = ii * Lx + (jj %% 2L) * dx,
    y = jj * Ly,
    z = (ii %% 2L) * H
  )
}

# ── Yoshimura ───────────────────────────────────────────────────────────────
#
# Every facet is a triangle, so facet rigidity is equivalent to edge-length
# preservation alone -- there is no angle condition to impose and no planarity
# to check. Take the folded placement
#
#     x = i a + (j mod 2) a/2,   y = j Ly,   z = (j mod 2) H,
#
# corrugating across the rows. The horizontal edges keep length a with no
# contraction. Both the zigzag and the diagonal edges give the same condition,
#
#     (a/2)^2 + Ly^2 + H^2 = a^2,   i.e.   Ly^2 + H^2 = 3a^2/4,
#
# for the equilateral patch, and in general Ly^2 + H^2 = h^2 with h the row
# height. Writing Ly = h cos(psi), H = h sin(psi) solves it identically, psi
# runs on [0, pi/2], and theta = 2 psi / pi.
#
# The literature's negative result about Yoshimura rigid-foldability is about
# the closed CYLINDER, where circumferential closure removes the mechanism. A
# finite planar patch has free boundary and is a different object.
.fold_yoshimura <- function(pattern, theta) {
  p <- pattern$params
  nx <- p$nx; ny <- p$ny; a <- p$a; h <- p$height

  psi <- theta * pi / 2
  Ly  <- h * cos(psi)
  H   <- h * sin(psi)

  ii <- rep(0:nx, times = ny + 1L)
  jj <- rep(0:ny, each  = nx + 1L)
  cbind(
    x = ii * a + (jj %% 2L) * a / 2,
    y = jj * Ly,
    z = (jj %% 2L) * H
  )
}

# ── Derived quantities ──────────────────────────────────────────────────────

#' Dihedral angle at each crease, measured from the placement.
#'
#' Derived, never assumed: rho is what the folded geometry says it is, so an
#' error in a closed form above shows up here rather than being papered over.
#' A crease in a flat sheet sits at rho = pi, and rho decreases as the sheet
#' folds -- the glossary is explicit about this because the earlier draft had it
#' backwards.
.dihedrals <- function(pattern, v3) {
  fe <- facet_edges(pattern)
  key <- paste(pmin(fe$i, fe$j), pmax(fe$i, fe$j), sep = "-")

  vapply(seq_len(nrow(pattern$creases)), function(e) {
    i <- pattern$creases$i[e]; j <- pattern$creases$j[e]
    k <- paste(min(i, j), max(i, j), sep = "-")
    fs <- unique(fe$facet[key == k])
    if (length(fs) < 2L) return(pi)         # boundary edge: no fold

    axis <- v3[j, ] - v3[i, ]
    axis <- axis / sqrt(sum(axis^2))

    # One point per facet, off the crease, projected into the plane normal to it
    off <- vapply(fs[1:2], function(f) {
      vs <- setdiff(pattern$facets[[f]], c(i, j))
      w  <- v3[vs[1], ] - v3[i, ]
      w - sum(w * axis) * axis
    }, numeric(3))

    u <- off[, 1] / sqrt(sum(off[, 1]^2))
    w <- off[, 2] / sqrt(sum(off[, 2]^2))
    acos(max(-1, min(1, sum(u * w))))
  }, numeric(1))
}

#' Worst departure from isometry within any facet.
#'
#' All pairwise distances between the vertices of a facet, folded against flat.
#' Pairwise and not edges-only: an implementation that preserves every edge of a
#' parallelogram while shearing it passes an edge test and is not a rigid
#' folding.
facet_isometry_error <- function(pattern, theta) {
  f <- fold(pattern, theta)
  max(vapply(pattern$facets, function(vs) {
    flat <- as.matrix(stats::dist(pattern$vertices[vs, , drop = FALSE]))
    amb  <- as.matrix(stats::dist(f$vertices3[vs, , drop = FALSE]))
    max(abs(flat - amb))
  }, numeric(1)))
}

#' Branch separation over sampling density.
#'
#' g = the closest approach in R^3 between two sampled points that are far apart
#'     along the surface, "far" meaning further than the length scale L.
#' s = the median nearest-neighbour ambient distance in the sample.
#'
#' g/s is Balasubramanian & Schwartz's ratio for Isomap's topological
#' instability, and it is the axis E1 plots against: it is what tightening a
#' Swiss roll's turn count varies, and what folding a crease pattern varies. At
#' theta = 0 nothing self-approaches, so g is set by L; as the pattern folds,
#' sheets come together and g falls.
#'
#' L defaults to the facet diagonal, which is the smallest scale at which "far
#' apart along the surface" is meaningful for these patterns.
branch_gap <- function(sample, L = NULL) {
  X <- sample$X
  U <- sample$truth

  if (is.null(L)) {
    L <- attr(sample, "facet_diagonal")
    if (is.null(L)) {
      # Fall back to a robust scale from the chart itself.
      L <- 2 * stats::median(as.matrix(stats::dist(U))[
        cbind(seq_len(nrow(U)), max.col(-as.matrix(stats::dist(U)) -
                                          diag(Inf, nrow(U))))])
    }
  }

  dA <- as.matrix(stats::dist(X))
  dU <- as.matrix(stats::dist(U))
  diag(dA) <- Inf

  s <- stats::median(apply(dA, 1, min))

  far <- dU > L
  g <- if (any(far)) min(dA[far]) else NA_real_

  list(g = g, s = s, ratio = g / s, L = L)
}
