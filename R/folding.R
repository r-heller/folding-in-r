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
# ── Yoshimura: WITHDRAWN, and why ───────────────────────────────────────────
#
# No certified one-parameter rigid folding of this pattern in which all three
# crease families fold. Two were derived, implemented and verified here, and
# each leaves one family flat:
#
#   z = (i mod 2) H            horizontals and one slanted family fold;
#                              19 of 25 diagonals sit at rho = pi.
#   z = ((i + j) mod 2) H      horizontals and the diagonals fold;
#                              17 of 20 of the other slanted family sit at pi.
#
# Both are exact rigid foldings -- facet isometry 7.8e-16 across the whole theta
# sweep, flat at theta = 0 -- which is exactly what makes this worth recording
# rather than quietly patching. A folding that leaves a family flat is a folding
# of a DIFFERENT, coarser pattern: fuse the facets across the unfolded creases
# and what remains is a parallelogram tessellation. It is a Miura wearing the
# Yoshimura's crease pattern, and shipping it as a second, independent family
# would have been a claim about pattern variety that the geometry does not
# support.
#
# The first version of this function shipped for three days and was worse: a
# plain accordion pleat. It passed the facet-isometry test perfectly, because a
# pleat IS a rigid folding, and it passed Kawasaki, because the flat pattern was
# never the problem. What caught it was deriving the mountain/valley assignment
# from the folded geometry and testing Maekawa on the result -- 12 of 16
# interior vertices failed. An isometry test alone cannot tell a fold from a
# pleat; a Maekawa test on derived labels can.
#
# So the pattern is withdrawn from the benchmark on the same rule the waterbomb
# was: no PATTERNS entry may exist for a pattern that cannot be built. The book
# ships ONE verified family and two documented kinematics results, which is a
# smaller book and a true one. E1's decisive arms swept miura_ori only, so
# nothing downstream of this depends on it.
.fold_yoshimura <- function(pattern, theta) {
  stop("no rigid folding of the Yoshimura pattern is certified in which all ",
       "three crease families fold. Two were derived and each leaves one ",
       "family flat, which makes the folded object a parallelogram ",
       "tessellation rather than a diamond one -- a Miura in this pattern's ",
       "clothing. See the note above this function and PLAN.md R1-1. Until it ",
       "is resolved the book ships one verified family plus two documented ",
       "negative results.", call. = FALSE)
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

#' The winding normal of a facet, by Newell's method.
#'
#' Newell rather than a cross product of the first two edges: it averages over
#' the whole cycle, so it is the least-squares normal of a facet that is only
#' nearly planar, and it does not degenerate when the first corner happens to be
#' the near-collinear one. Direction follows the vertex order, which is the
#' point -- the winding is the orientation.
.facet_normal <- function(P) {
  m <- nrow(P)
  n <- c(0, 0, 0)
  for (k in seq_len(m)) {
    a <- P[k, ]
    b <- P[if (k == m) 1L else k + 1L, ]
    n <- n + c((a[2] - b[2]) * (a[3] + b[3]),
               (a[3] - b[3]) * (a[1] + b[1]),
               (a[1] - b[1]) * (a[2] + b[2]))
  }
  len <- sqrt(sum(n^2))
  if (len < .Machine$double.eps^0.5) {
    stop("a facet has no well-defined normal -- it is degenerate or collinear",
         call. = FALSE)
  }
  n / len
}

#' Which of a facet's directed edges is i -> j, if any.
.walks <- function(vs, i, j) {
  m <- length(vs)
  nxt <- vs[c(2:m, 1L)]
  any(vs == i & nxt == j)
}

#' Refuse to derive an orientation-dependent quantity from an unoriented mesh.
#'
#' Every interior edge of a consistently wound surface is walked exactly once in
#' each direction. If that fails, the facets disagree about which side of the
#' sheet is the front, and every mountain/valley label downstream is a coin flip
#' -- so this stops rather than returning labels that look plausible. Checked
#' against the FLAT pattern, because winding is combinatorial and holds before
#' any folding map is applied.
.check_winding <- function(pattern) {
  seen <- new.env(parent = emptyenv())
  for (vs in pattern$facets) {
    m <- length(vs)
    nxt <- vs[c(2:m, 1L)]
    for (k in seq_len(m)) {
      key <- paste0(vs[k], ">", nxt[k])
      if (!is.null(seen[[key]])) {
        stop("facets are not consistently wound: the directed edge ", key,
             " is walked twice, so the two facets sharing it disagree about ",
             "which side of the sheet is the front. Mountain and valley are ",
             "defined against that side and cannot be derived here.",
             call. = FALSE)
      }
      seen[[key]] <- TRUE
    }
  }
  invisible(TRUE)
}

#' Mountain or valley, derived from the folded geometry.
#'
#' The assignment is a PROPERTY of the folding, not an input to it. Written by
#' hand it is decorative at best: the Miura's labels were originally assigned by
#' a parity rule chosen to satisfy Maekawa's theorem, and when finally checked
#' against `fold()` they matched the geometry on barely half the creases. The
#' figure had been drawing mountain-solid and valley-dashed on that basis.
#'
#' The first derivation written to replace that rule was itself wrong, and wrong
#' in a way the acceptance test could not see. It took the two facets sharing a
#' crease in FACET-INDEX order and the crease axis in stored (i, j) order, and
#' read the sign of a triple product. Both orderings are arbitrary and each
#' negates the sign, so the handedness was a function of which facet happened to
#' be numbered first -- family-dependent, and on the Miura it agreed with the
#' correct labels on exactly half the interior creases. Maekawa passed anyway,
#' because |M - V| = 2 is invariant under a global M<->V swap and so cannot
#' discriminate between a labelling and its inverse, let alone between two that
#' differ on half the creases. See ROADMAP.md section 5.
#'
#' The ordering is now canonical rather than incidental. In a consistently wound
#' mesh every interior edge is traversed once in each direction: exactly one
#' adjacent facet walks it i -> j and the other walks it j -> i. Take `nP` to be
#' the winding normal of the facet that walks i -> j and `nM` that of the other,
#' and `u` the crease direction i -> j. Then
#'
#'     (nP x nM) . u > 0   <=>   mountain
#'
#' which is the signed fold angle's sine, up to a positive factor. Reversing the
#' crease's stored direction swaps nP with nM AND negates u, so the product is
#' unchanged: the criterion no longer depends on either arbitrary choice. What it
#' does depend on -- the sheet's front face, which is what mountain and valley are
#' defined against -- is fixed by the flat pattern's counter-clockwise winding,
#' and `.check_winding()` refuses to guess when that is not what it was given.
#'
#' Maekawa's theorem is then something to TEST -- |M - V| = 2 at every interior
#' vertex of a flat-foldable pattern -- rather than something asserted and then
#' quietly relied upon. It is a necessary condition and not a sufficient one, so
#' the suite tests the labels against an independent up-normal criterion as well
#' (`tests/testthat/test-crease-assignment.R`), which is the check that would
#' have caught the handedness the first time.

crease_assignment <- function(pattern, theta = 0.5) {
  .check_winding(pattern)
  V3 <- fold(pattern, theta)$vertices3
  normals <- lapply(pattern$facets,
                    function(vs) .facet_normal(V3[vs, , drop = FALSE]))

  vapply(seq_len(nrow(pattern$creases)), function(e) {
    i <- pattern$creases$i[e]; j <- pattern$creases$j[e]
    fs <- which(vapply(pattern$facets, function(v) all(c(i, j) %in% v), logical(1)))
    if (length(fs) < 2L) return("B")

    # Canonical, not incidental: the facet that walks i -> j and the one that
    # walks j -> i. In a wound mesh there is exactly one of each.
    fP <- fs[vapply(fs, function(k) .walks(pattern$facets[[k]], i, j), logical(1))]
    fM <- fs[vapply(fs, function(k) .walks(pattern$facets[[k]], j, i), logical(1))]
    if (length(fP) != 1L || length(fM) != 1L) {
      stop("crease ", i, "-", j, " is shared by ", length(fs), " facets but is ",
           "not walked once in each direction; the mesh is not a surface here",
           call. = FALSE)
    }

    nP <- normals[[fP]]; nM <- normals[[fM]]
    u  <- V3[j, ] - V3[i, ]
    u  <- u / sqrt(sum(u^2))
    cr <- c(nP[2] * nM[3] - nP[3] * nM[2],
            nP[3] * nM[1] - nP[1] * nM[3],
            nP[1] * nM[2] - nP[2] * nM[1])
    if (sum(cr * u) > 0) "M" else "V"
  }, character(1))
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
#' L is a fixed fraction of the chart diameter (default one quarter), so that
#' the same question is asked of every family and the answer cannot be an
#' artefact of how densely the sample was drawn.
branch_gap <- function(sample, L_frac = 0.25) {
  X <- sample$X
  U <- sample$truth

  dA <- as.matrix(stats::dist(X))
  dU <- as.matrix(stats::dist(U))

  # The length scale must be a property of the SURFACE, not of the sample.
  #
  # The first version of this took L from the sampling density -- twice the
  # median nearest-neighbour distance -- and the result was g/s pinned at 2.00
  # for every pattern at every theta, because the nearest pair separated by more
  # than L is at distance about L, so the statistic was measuring its own
  # definition. A fixed fraction of the chart diameter has no such circularity:
  # "far apart along the surface" means far in absolute terms, and g then
  # answers the question that matters -- how close does this surface bring two
  # genuinely distant regions?
  #
  # It also makes the families comparable, which is the whole point. A crease
  # pattern has facets and a Swiss roll does not, so anything keyed to facet
  # structure could not be measured on both, and E1 needs one axis both lie on.
  L <- L_frac * max(dU)

  diag(dA) <- Inf
  s <- stats::median(apply(dA, 1, min))

  far <- dU > L
  g <- if (any(far)) min(dA[far]) else NA_real_

  list(g = g, s = s, ratio = g / s, L = L, L_frac = L_frac)
}


# ── Exact facet separation ──────────────────────────────────────────────────
#
# branch_gap() answers the question a METHOD faces: how close do distant parts
# of the surface come, in units of how densely it was sampled. That makes it
# sample-dependent by design -- s falls as n^(-1/2), so g/s grows as sqrt(n) and
# comparisons only mean anything at fixed n.
#
# facet_gap() answers the question the SURFACE poses: the exact minimum ambient
# distance between two facets that do not touch. No sampling, no density, no n.
# It is a property of the folded object alone, so it can be swept finely and
# differentiated, and it is what Chapter 5 needs to predict the short-circuit
# onset analytically rather than by looking at where the curves bend.

# Distance between two segments in R^3, clamped to the segments.
.seg_seg <- function(p1, q1, p2, q2) {
  d1 <- q1 - p1; d2 <- q2 - p2; r <- p1 - p2
  a <- sum(d1 * d1); e <- sum(d2 * d2); f <- sum(d2 * r)
  EPS <- 1e-12
  if (a <= EPS && e <= EPS) return(sqrt(sum(r * r)))
  if (a <= EPS) { s <- 0; t <- max(0, min(1, f / e)) }
  else {
    c0 <- sum(d1 * r)
    if (e <= EPS) { t <- 0; s <- max(0, min(1, -c0 / a)) }
    else {
      b <- sum(d1 * d2); den <- a * e - b * b
      s <- if (den > EPS) max(0, min(1, (b * f - c0 * e) / den)) else 0
      t <- (b * s + f) / e
      if (t < 0)      { t <- 0; s <- max(0, min(1, -c0 / a)) }
      else if (t > 1) { t <- 1; s <- max(0, min(1, (b - c0) / a)) }
    }
  }
  sqrt(sum((p1 + s * d1 - (p2 + t * d2))^2))
}

# Distance from a point to a planar convex polygon in R^3: project onto the
# plane, and if the projection lands inside use the perpendicular distance,
# otherwise fall back to the boundary.
.pt_poly <- function(x, P) {
  n <- .polygon_normal(P)
  w <- x - P[1, ]
  h <- sum(w * n)
  proj <- x - h * n
  if (.inside_planar(proj, P, n)) return(abs(h))
  m <- nrow(P)
  min(vapply(seq_len(m), function(i) {
    .seg_seg(x, x, P[i, ], P[if (i == m) 1L else i + 1L, ])
  }, numeric(1)))
}

.polygon_normal <- function(P) {
  n <- c(0, 0, 0)
  m <- nrow(P)
  for (i in seq_len(m)) {
    a <- P[i, ]; b <- P[if (i == m) 1L else i + 1L, ]
    n <- n + c(a[2] * b[3] - a[3] * b[2],
               a[3] * b[1] - a[1] * b[3],
               a[1] * b[2] - a[2] * b[1])
  }
  L <- sqrt(sum(n^2))
  if (L < 1e-14) c(0, 0, 1) else n / L
}

.inside_planar <- function(x, P, n) {
  m <- nrow(P)
  sgn <- 0
  for (i in seq_len(m)) {
    a <- P[i, ]; b <- P[if (i == m) 1L else i + 1L, ]
    e <- b - a; w <- x - a
    cr <- c(e[2] * w[3] - e[3] * w[2],
            e[3] * w[1] - e[1] * w[3],
            e[1] * w[2] - e[2] * w[1])
    d <- sum(cr * n)
    if (abs(d) < 1e-12) next
    if (sgn == 0) sgn <- sign(d) else if (sign(d) != sgn) return(FALSE)
  }
  TRUE
}

#' Exact minimum ambient distance between two facets that share no vertex.
#'
#' Facets that touch are excluded: they meet at a crease and their distance is
#' zero by construction, which says nothing about whether the sheet is
#' approaching itself.
#'
#' @return a list with the gap, the facet pair attaining it, and the number of
#'   pairs considered.
facet_gap <- function(pattern, theta) {
  V3 <- fold(pattern, theta)$vertices3
  fs <- pattern$facets
  nf <- length(fs)

  best <- Inf; who <- c(NA_integer_, NA_integer_); considered <- 0L
  for (i in seq_len(nf - 1L)) {
    Pi <- V3[fs[[i]], , drop = FALSE]
    for (j in (i + 1L):nf) {
      if (length(intersect(fs[[i]], fs[[j]]))) next   # adjacent or touching
      considered <- considered + 1L
      Pj <- V3[fs[[j]], , drop = FALSE]

      # Cheap reject: if the bounding spheres are already further apart than the
      # best gap so far, no pair of points inside them can beat it.
      ci <- colMeans(Pi); cj <- colMeans(Pj)
      ri <- max(sqrt(rowSums(sweep(Pi, 2L, ci)^2)))
      rj <- max(sqrt(rowSums(sweep(Pj, 2L, cj)^2)))
      if (sqrt(sum((ci - cj)^2)) - ri - rj >= best) next

      d <- Inf
      ni <- nrow(Pi); nj <- nrow(Pj)
      for (a in seq_len(ni)) for (b in seq_len(nj)) {
        d <- min(d, .seg_seg(Pi[a, ], Pi[if (a == ni) 1L else a + 1L, ],
                             Pj[b, ], Pj[if (b == nj) 1L else b + 1L, ]))
      }
      for (a in seq_len(ni)) d <- min(d, .pt_poly(Pi[a, ], Pj))
      for (b in seq_len(nj)) d <- min(d, .pt_poly(Pj[b, ], Pi))

      if (d < best) { best <- d; who <- c(i, j) }
    }
  }
  list(gap = best, facets = who, pairs = considered, theta = theta)
}
