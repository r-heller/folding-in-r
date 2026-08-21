# E2 spike -- bar-and-joint machinery for crease patterns.
#
# Scratch only. Nothing here is destined for R/; patterns.R belongs to another
# agent and this file exists to answer one question: does the waterbomb
# tessellation admit a rigid folding, and if so of what dimension.
#
# The whole file works on squared-length constraints
#   c_e(x) = (1/2) ( ||x_i - x_j||^2 - L_e^2 )
# because the Jacobian of that form is linear in x and has no square roots to
# differentiate at coincident points. The reported bar residuals are always
# converted back to actual length error before anyone reads them.

# -- Pattern construction ----

# REJECTED reading of the tessellation, kept because the spike tested it and the
# reason it is wrong is worth recording. It puts a crease on the vertical grid
# lines as well, so the centres are degree-6 (45,90,45,45,90,45) but the lattice
# corners come out degree 8 and the midline vertices degree 4. PLAN.md names a
# pattern whose vertex is degree 6 with those sectors; this one has three vertex
# types, only one of which matches. The pattern actually analysed is wb_tess_B()
# in wb-b.R, where every vertex is that vertex.
#
# Built on the half-integer lattice and stored doubled, so vertex identity is
# integer equality and never a floating-point match.
wb_tessellation <- function(m = 3L, n = 3L) {
  corner <- expand.grid(a = seq(0L, 2L * m, by = 2L), b = seq(0L, 2L * n, by = 2L))
  vmid   <- expand.grid(a = seq(0L, 2L * m, by = 2L), b = seq(1L, 2L * n - 1L, by = 2L))
  cent   <- expand.grid(a = seq(1L, 2L * m - 1L, by = 2L), b = seq(1L, 2L * n - 1L, by = 2L))
  lat    <- rbind(corner, vmid, cent)
  keys   <- paste(lat$a, lat$b, sep = ",")
  id     <- function(a, b) match(paste(a, b, sep = ","), keys)

  facets <- vector("list", 6L * m * n)
  k <- 0L
  for (i in seq_len(m) - 1L) {
    for (j in seq_len(n) - 1L) {
      ai <- 2L * i; bj <- 2L * j
      cc <- id(ai + 1L, bj + 1L)
      # counter-clockwise from the crease pointing along +x
      ring <- rbind(
        c(id(ai + 2L, bj + 1L), id(ai + 2L, bj + 2L)),
        c(id(ai + 2L, bj + 2L), id(ai,      bj + 2L)),
        c(id(ai,      bj + 2L), id(ai,      bj + 1L)),
        c(id(ai,      bj + 1L), id(ai,      bj     )),
        c(id(ai,      bj     ), id(ai + 2L, bj     )),
        c(id(ai + 2L, bj     ), id(ai + 2L, bj + 1L))
      )
      for (r in seq_len(6L)) {
        k <- k + 1L
        facets[[k]] <- c(cc, ring[r, 1L], ring[r, 2L])
      }
    }
  }

  list(
    vertices = cbind(lat$a / 2, lat$b / 2),
    facets   = facets,
    family   = "waterbomb",
    params   = list(m = m, n = n)
  )
}

# Single interior vertex with the given sector angles, as a control. The cone of
# triangles around one vertex is the smallest object whose rigid folding is
# known in closed form (degree n folds with n - 3 degrees of freedom), so it is
# the right thing to validate the continuation code against.
vertex_cone <- function(sectors) {
  ang <- c(0, cumsum(sectors)[-length(sectors)]) * pi / 180
  p   <- rbind(c(0, 0), cbind(cos(ang), sin(ang)))
  d   <- length(ang)
  facets <- lapply(seq_len(d), function(k) c(1L, 1L + k, 1L + (k %% d) + 1L))
  list(vertices = p, facets = facets, family = "cone",
       params = list(sectors = sectors))
}

# -- Bars ----

# Every unordered vertex pair inside a facet becomes a bar. For a triangulated
# pattern that is exactly the crease edges; for a quad facet it adds the two
# diagonals, which is what keeps the facet rigid rather than merely closed.
bars_from_facets <- function(pattern) {
  pr <- do.call(rbind, lapply(pattern$facets, function(f) t(combn(sort(f), 2L))))
  pr <- pr[!duplicated(paste(pr[, 1], pr[, 2], sep = ",")), , drop = FALSE]
  pr <- pr[order(pr[, 1], pr[, 2]), , drop = FALSE]
  colnames(pr) <- c("i", "j")
  pr
}

# Which bars are creases (shared by two facets) and which are boundary.
bar_multiplicity <- function(pattern, bars) {
  edges <- do.call(rbind, lapply(pattern$facets, function(f) {
    cbind(f, c(f[-1], f[1]))
  }))
  edges <- t(apply(edges, 1L, sort))
  tab <- table(paste(edges[, 1], edges[, 2], sep = ","))
  as.integer(tab[paste(bars[, 1], bars[, 2], sep = ",")])
}

# -- Constraint system ----

# x is V x 3. Residual is halved squared-length error, one row per bar.
bar_resid <- function(x, bars, L2) {
  d <- x[bars[, 1], , drop = FALSE] - x[bars[, 2], , drop = FALSE]
  0.5 * (rowSums(d * d) - L2)
}

# Dense Jacobian, E x 3V, column order (x1,y1,z1, x2,y2,z2, ...).
bar_jacobian <- function(x, bars) {
  V <- nrow(x); E <- nrow(bars)
  d <- x[bars[, 1], , drop = FALSE] - x[bars[, 2], , drop = FALSE]
  J <- matrix(0, E, 3L * V)
  ci <- 3L * (bars[, 1] - 1L)
  cj <- 3L * (bars[, 2] - 1L)
  rr <- seq_len(E)
  for (k in 1:3) {
    J[cbind(rr, ci + k)] <-  d[, k]
    J[cbind(rr, cj + k)] <- -d[, k]
  }
  J
}

bar_lengths <- function(x, bars) {
  d <- x[bars[, 1], , drop = FALSE] - x[bars[, 2], , drop = FALSE]
  sqrt(rowSums(d * d))
}

# -- Rank, flexes, trivial motions ----

# The six infinitesimal rigid-body motions at configuration x, as 3V vectors.
trivial_motions <- function(x) {
  V <- nrow(x)
  M <- matrix(0, 3L * V, 6L)
  for (k in 1:3) M[seq(k, by = 3L, length.out = V), k] <- 1
  ax <- diag(3)
  for (k in 1:3) {
    cr <- t(apply(x, 1L, function(p) c(ax[k, 2] * p[3] - ax[k, 3] * p[2],
                                       ax[k, 3] * p[1] - ax[k, 1] * p[3],
                                       ax[k, 1] * p[2] - ax[k, 2] * p[1])))
    M[, 3L + k] <- as.vector(t(cr))
  }
  M
}

# Numerical rank with an explicit, reported tolerance. Everything downstream
# depends on where this cut is placed, so it is never left implicit.
rank_svd <- function(A, tol = NULL) {
  s <- svd(A, nu = 0L, nv = 0L)$d
  if (is.null(tol)) tol <- max(dim(A)) * .Machine$double.eps * max(s)
  list(rank = sum(s > tol), sv = s, tol = tol)
}

null_space <- function(A, tol = NULL) {
  sv <- svd(A, nu = 0L, nv = ncol(A))
  s <- sv$d
  if (is.null(tol)) tol <- max(dim(A)) * .Machine$double.eps * max(s)
  keep <- if (length(s) < ncol(A)) c(s <= tol, rep(TRUE, ncol(A) - length(s))) else s <= tol
  sv$v[, keep, drop = FALSE]
}

left_null_space <- function(A, tol = NULL) null_space(t(A), tol)

# -- Second-order test ----

# At a flat configuration every column of J belonging to a z coordinate is zero,
# so any vertical velocity field is a first-order flex. The flex that matters is
# the one that survives second order: given first-order velocity v there must be
# an acceleration a with  ||v_i - v_j||^2 + (p_i - p_j).(a_i - a_j) = 0 for every
# bar. That is solvable iff the vector of squared velocity differences is
# orthogonal to every self-stress, i.e. iff  sum_e w_e (v_i - v_j)^2 = 0 for each
# self-stress w. For a purely vertical v this is a quadratic form in the heights.
stress_laplacian <- function(bars, w, V) {
  L <- matrix(0, V, V)
  for (e in seq_len(nrow(bars))) {
    i <- bars[e, 1]; j <- bars[e, 2]
    L[i, i] <- L[i, i] + w[e]
    L[j, j] <- L[j, j] + w[e]
    L[i, j] <- L[i, j] - w[e]
    L[j, i] <- L[j, i] - w[e]
  }
  L
}

# -- Gauss-Newton corrector and continuation ----

# Min-norm Newton step from the pseudo-inverse. The framework is under-
# determined off the flat state, so a plain solve would drift along the flex
# directions; the min-norm step keeps the corrector orthogonal to them.
pinv_solve <- function(A, b, tol_rel = 1e-10) {
  sv <- svd(A)
  s  <- sv$d
  keep <- s > tol_rel * max(s)
  if (!any(keep)) return(rep(0, ncol(A)))
  sv$v[, keep, drop = FALSE] %*% ((t(sv$u[, keep, drop = FALSE]) %*% b) / s[keep])
}

# Correct x back onto C(x) = 0 while holding a set of coordinates pinned. pins is
# a matrix of (vertex, coord, value) rows; they are appended as extra equations
# rather than eliminated, so the pin can be as soft or hard as the weight says.
gauss_newton <- function(x, bars, L2, pins = NULL, w_pin = 1, iters = 60,
                         tol = 1e-14) {
  V <- nrow(x)
  for (it in seq_len(iters)) {
    r <- bar_resid(x, bars, L2)
    J <- bar_jacobian(x, bars)
    if (!is.null(pins)) {
      P <- matrix(0, nrow(pins), 3L * V)
      rp <- numeric(nrow(pins))
      for (k in seq_len(nrow(pins))) {
        P[k, 3L * (pins[k, 1] - 1L) + pins[k, 2]] <- w_pin
        rp[k] <- w_pin * (x[pins[k, 1], pins[k, 2]] - pins[k, 3])
      }
      J <- rbind(J, P)
      r <- c(r, rp)
    }
    if (max(abs(r)) < tol) break
    dx <- pinv_solve(J, r)
    x  <- x - matrix(dx, V, 3L, byrow = TRUE)
  }
  list(x = x, iters = it, resid = max(abs(bar_resid(x, bars, L2))))
}

# Predictor-corrector along a chosen direction. The amplitude is carried by one
# pinned coordinate: that is the only thing preventing the corrector from simply
# walking back to the flat state, which is always a solution.
continue <- function(x0, bars, L2, dir, pin_vertex, pin_coord = 3L,
                     steps = 40L, h = 0.02) {
  V <- nrow(x0)
  D <- matrix(dir, V, 3L, byrow = TRUE)
  x <- x0
  out <- data.frame(step = integer(0), amp = numeric(0), resid = numeric(0),
                    disp = numeric(0), maxz = numeric(0), len_err = numeric(0))
  for (s in seq_len(steps)) {
    amp <- x0[pin_vertex, pin_coord] + s * h * D[pin_vertex, pin_coord]
    xp  <- x + h * D
    fit <- gauss_newton(xp, bars, L2,
                        pins = matrix(c(pin_vertex, pin_coord, amp), 1L, 3L))
    x <- fit$x
    len_err <- max(abs(bar_lengths(x, bars) - sqrt(L2)))
    out <- rbind(out, data.frame(
      step = s, amp = amp, resid = fit$resid,
      disp = sqrt(mean(rowSums((x - x0)^2))),
      maxz = max(abs(x[, 3])), len_err = len_err))
    if (len_err > 1e-8) break
    D <- (x - x0) / max(abs(x[, 3]))   # re-aim the predictor along the branch
    D <- D / sqrt(mean(rowSums(D^2)))
  }
  list(x = x, trace = out)
}
