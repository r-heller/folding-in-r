# E2 -- does the waterbomb tessellation admit a rigid folding?
#
# Run with:  cd <repo> && Rscript scratch-waterbomb/waterbomb-spike.R
#
# Answer, ahead of the evidence: yes, and there is a one-parameter folding, but
# only after imposing one symmetry beyond periodicity. The numbers below are the
# ones that decide it. Nothing here is a helper for R/ -- this is the spike.
#
# The pattern. Every interior vertex of the waterbomb tessellation is degree 6
# with sectors (45, 90, 45, 45, 90, 45). The pattern that has that vertex and
# nothing else is the arrangement of three families of straight lines at 0, 45
# and 135 degrees: horizontals at every half-integer height, and both diagonal
# families. See wb-b.R. The reading that also creases the vertical grid lines
# (wb_tessellation() in wb-core.R) produces degree-8 and degree-4 vertices as
# well and is not the pattern PLAN.md names; it was tested and set aside.
#
# The trap this spike exists to avoid. At the flat state every column of the bar
# Jacobian belonging to a z coordinate is identically zero, because every bar is
# horizontal. So EVERY vertical velocity field is a first-order flex, and the
# "dimension of the infinitesimal flex space at the flat state" is V - 3
# whatever the pattern is -- it says nothing about folding. What decides is the
# second-order condition and then an actual finite motion.

source("scratch-waterbomb/wb-core.R")
source("scratch-waterbomb/wb-angles.R")
source("scratch-waterbomb/wb-develop.R")
source("scratch-waterbomb/wb-b.R")
set.seed(1)

hr <- function(s) cat("\n", s, "\n", strrep("-", nchar(s)), "\n", sep = "")

# -- 1. The framework at the flat state ----

hr("1. bar-and-joint framework at the flat state")

flat_report <- function(p, label) {
  bars <- bars_from_facets(p); V <- nrow(p$vertices); E <- nrow(bars)
  x0 <- cbind(p$vertices, 0)
  Bn <- sum(tabulate(unlist(p$facets), nbins = V) != 6L)
  J <- bar_jacobian(x0, bars)
  rk <- rank_svd(J)
  J2 <- J[, as.vector(sapply(seq_len(V), function(v) 3 * (v - 1) + 1:2))]
  triv <- max(abs(J %*% trivial_motions(x0)))
  cat(sprintf("%s\n", label))
  cat(sprintf("  vertices V = %d, bars E = %d, facets = %d, boundary vertices = %d\n",
              V, E, length(p$facets), Bn))
  cat(sprintf("  every facet is a triangle, so the facet-diagonal bars a quad facet would need are already there: bars = crease edges + boundary edges\n"))
  cat(sprintf("  rank(J) at flat = %d of 3V = %d ; nullity = %d\n", rk$rank, 3 * V, 3 * V - rk$rank))
  cat(sprintf("  the six rigid-body motions lie in ker J to %.1e\n", triv))
  cat(sprintf("  NON-TRIVIAL infinitesimal flexes = %d = V - 3\n", 3 * V - rk$rank - 6))
  cat(sprintf("  rank(J) equals the rank of the 2-D framework, %d = 2V - 3; the z columns are all zero\n", rank_svd(J2)$rank))
  cat(sprintf("  self-stresses = %d = interior vertices ; generic (non-flat) count 3V - 6 - E = %d = boundary vertices - 3\n",
              E - rank_svd(J2)$rank, 3 * V - 6 - E))
  invisible(list(p = p, bars = bars, x0 = x0, L2 = 2 * bar_resid(x0, bars, 0), J = J))
}

f5 <- flat_report(wb_tess_B(5L, 5L), "waterbomb tessellation, 5 x 5 cells")

# -- 2. Second order: which of those flexes survive ----

hr("2. second-order test at the flat state")

solve_quadrics <- function(A, d, nstart = 6L, iters = 300L) {
  best <- NULL; bestv <- Inf
  for (s in seq_len(nstart)) {
    u <- rnorm(d); u <- u / sqrt(sum(u^2))
    for (it in seq_len(iters)) {
      q <- sapply(A, function(a) sum(u * (a %*% u)))
      if (max(abs(q)) < 1e-14) break
      Jq <- t(sapply(A, function(a) 2 * as.vector(a %*% u)))
      u <- u - as.vector(pinv_solve(rbind(Jq, u), c(q, 0)))
      u <- u / sqrt(sum(u^2))
    }
    v <- max(abs(sapply(A, function(a) sum(u * (a %*% u)))))
    if (v < bestv) { bestv <- v; best <- u }
  }
  list(u = best, resid = bestv)
}

second_order <- function(o) {
  V <- nrow(o$p$vertices)
  W <- left_null_space(o$J); K <- ncol(W)
  aff <- cbind(1, o$p$vertices)
  Z <- qr.Q(qr(aff), complete = TRUE)[, -(1:3), drop = FALSE]
  A <- lapply(seq_len(K), function(k) crossprod(Z, stress_laplacian(o$bars, W[, k], V) %*% Z))
  definite <- FALSE
  for (t in seq_len(300L)) {
    M <- Reduce(`+`, Map(function(a, w) a * w, rnorm(K), A))
    ev <- eigen((M + t(M)) / 2, symmetric = TRUE, only.values = TRUE)$values
    if (min(ev) > 1e-8 * max(abs(ev)) || max(ev) < -1e-8 * max(abs(ev))) { definite <- TRUE; break }
  }
  sol <- solve_quadrics(A, ncol(Z))
  cat(sprintf("  %d self-stresses give %d quadratic conditions on the %d heights (mod the affine ones every stress kills)\n",
              K, K, ncol(Z)))
  cat(sprintf("  a definite combination of them would mean no second-order flex at all: found in 300 random draws = %s\n", definite))
  cat(sprintf("  best common zero: max |Q_k(w)| = %.2e -- second-order flexes exist\n", sol$resid))
  as.vector(Z %*% sol$u)
}
w5 <- second_order(f5)

# -- 3. Continuation: does it actually move ----

hr("3. Gauss-Newton continuation from the flat state")

run_cont <- function(o, w, steps = 25L, h = 0.04) {
  bars <- o$bars; x0 <- o$x0; L2 <- o$L2
  w <- w / max(abs(w)); pv <- which.max(abs(w)); dir <- cbind(0, 0, w)
  x_prev <- x0; x <- x0; tr <- data.frame()
  for (s in seq_len(steps)) {
    pred <- if (s == 1L) x0 + h * dir else x + (x - x_prev)
    fit <- gauss_newton(pred, bars, L2, pins = matrix(c(pv, 3L, s * h * w[pv]), 1L, 3L), iters = 80)
    x_prev <- x; x <- fit$x
    tr <- rbind(tr, data.frame(step = s, len_err = max(abs(bar_lengths(x, bars) - sqrt(L2))),
                               maxz = max(abs(x[, 3])), rms = sqrt(mean(rowSums((x - x0)^2)))))
    if (tail(tr$len_err, 1) > 1e-9) break
  }
  cat(sprintf("  %d of %d steps held every bar length to better than 1e-10\n", sum(tr$len_err < 1e-10), nrow(tr)))
  cat(sprintf("  final max |z| = %.4f ; final RMS displacement from flat = %.4f ; worst bar-length error = %.2e\n",
              tail(tr$maxz, 1), tail(tr$rms, 1), max(tr$len_err)))
  tr
}
cont5 <- run_cont(f5, w5)

# -- 4. Controls: patterns whose answer is known ----

hr("4. controls -- the same code on vertices with a known answer")

for (spec in list(list(c(60, 120, 60, 120), "degree-4 vertex, folds with 1 DOF"),
                  list(c(45, 45, 90, 45, 45, 90), "degree-6 waterbomb vertex, folds with 3 DOF"))) {
  o <- flat_report(vertex_cone(spec[[1]]), spec[[2]])
  tr <- run_cont(o, second_order(o), steps = 20L, h = 0.05)
}

# -- 5. Is the motion a folding of the TESSELLATION, or just a floppy sheet? ----

hr("5. uniform folding: every cell folds identically")

# The finite patch has 3V - 6 - E degrees of freedom, most of them living on the
# free boundary. A folding of the tessellation has to be uniform: the fold angle
# must be constant on each translation orbit of creases. Under that constraint
# the folded surface is invariant under a rigid motion cell to cell -- a screw,
# not necessarily a translation -- so a cylindrical waterbomb is not excluded.
sys <- torusB_system(1L, 1L)
res_of <- function(rho) closure_system(rho, sys$dirs, sys$idx)
types <- c("h", "m", "a", "b", "c", "d")

Jf <- num_jacobian(res_of, rep(0, 6))
cat(sprintf("  6 crease orbits, 2 vertex orbits; closure Jacobian rank at flat = %d -> first-order cone is %d-dimensional\n",
            rank_svd(Jf, tol = 1e-7)$rank, 6 - rank_svd(Jf, tol = 1e-7)$rank))

newton <- function(rho, pins, iters = 400, tol = 1e-15) {
  f <- function(r) c(res_of(r), r[pins[, 1]] - pins[, 2])
  for (it in seq_len(iters)) {
    r0 <- f(rho)
    if (max(abs(r0)) < tol) break
    rho <- rho - as.vector(pinv_solve(num_jacobian(f, rho), r0))
  }
  list(rho = rho, closure = max(abs(res_of(rho))), pin_err = max(abs(rho[pins[, 1]] - pins[, 2])))
}
hit <- NULL
for (t in 1:200) {
  fit <- newton(runif(6, -0.8, 0.8), matrix(c(3L, 0.6), 1L, 2L))
  if (fit$closure < 1e-13 && fit$pin_err < 1e-13 && min(abs(fit$rho)) > 1e-4 && max(abs(fit$rho)) < pi) {
    hit <- fit; break
  }
}
cat(sprintf("  a uniform folding with every crease orbit folded: %s (closure %.1e)\n",
            paste(sprintf("%s=%+.4f", types, hit$rho), collapse = " "), hit$closure))
Jh <- num_jacobian(res_of, hit$rho)
cat(sprintf("  closure Jacobian rank there = %d -> the uniform folding variety is %d-dimensional\n",
            rank_svd(Jh, tol = 1e-7)$rank, 6 - rank_svd(Jh, tol = 1e-7)$rank))
cat("  so uniformity alone does NOT give a one-parameter folding\n")

# -- 6. The one-parameter folding, and the symmetry it costs ----

hr("6. the one-parameter folding")

# The extra condition is the pattern's own mirror in a vertical line, which
# exchanges the two diagonal families: rho on "/" equals rho on "\". Imposing it
# leaves exactly one degree of freedom.
S <- cbind(c(1, 1, 0, 0, 0, 0), c(0, 0, 1, 1, 1, 1))   # (h = m, a = b = c = d)
res2 <- function(q) res_of(as.vector(S %*% q))
solve_s <- function(t, s0) {
  s <- s0
  for (it in 1:300) {
    f <- function(z) res2(c(z, t)); r <- f(s)
    if (max(abs(r)) < 1e-15) break
    s <- s - as.vector(pinv_solve(num_jacobian(f, s), r))
  }
  s
}
q <- c(solve_s(1.0, 0), 1.0)
Js <- num_jacobian(res2, q)
cat(sprintf("  with the mirror imposed: 2 parameters, closure rank %d -> branch dimension %d\n",
            rank_svd(Js, tol = 1e-7)$rank, 2 - rank_svd(Js, tol = 1e-7)$rank))

s <- 0; dev <- numeric(0); tt <- seq(0.02, 3.10, by = 0.02)
for (t in tt) { s <- solve_s(t, s); dev <- c(dev, tan(s / 2) / tan(t / 2) + 1 / sqrt(2)) }
cat(sprintf("  identity, solved for numerically and not built in:  tan(rho_horizontal/2) = -tan(rho_diagonal/2)/sqrt(2)\n"))
cat(sprintf("  max deviation over t in [%.2f, %.2f] (%d points): %.3e\n", min(tt), max(tt), length(tt), max(abs(dev))))

s_cf <- function(t) -2 * atan(tan(t / 2) / sqrt(2))
cat(sprintf("  vertex closure using the closed form alone, no solving, t in [0.05, 3.0]: %.3e\n",
            max(sapply(seq(0.05, 3.0, by = 0.05), function(t) max(abs(res2(c(s_cf(t), t))))))))

# -- 7. End-to-end on a finite patch ----

hr("7. the folding built on a finite patch, by an independent route")

# develop() never touches the bar framework: it places one facet and walks the
# facet adjacency graph applying one rotation per crease. If the fold angles are
# consistent the walk is single valued, and the coordinates it returns are the
# vertices3 that fold() would have to produce.
pat <- wb_tess_B(5L, 5L); cr <- crease_table(pat); orb <- crease_orbit_B(pat, cr)
bars <- bars_from_facets(pat); x0 <- cbind(pat$vertices, 0)
L2 <- 2 * bar_resid(x0, bars, 0)

dihedral <- function(X, e) {
  P <- X[cr$p[e], ]; Q <- X[cr$q[e], ]
  fa <- setdiff(pat$facets[[cr$fA[e]]], c(cr$p[e], cr$q[e]))
  fb <- setdiff(pat$facets[[cr$fB[e]]], c(cr$p[e], cr$q[e]))
  u <- (Q - P) / sqrt(sum((Q - P)^2))
  va <- X[fa, ] - P; va <- va - sum(va * u) * u
  vb <- X[fb, ] - P; vb <- vb - sum(vb * u) * u
  atan2(sum(u * c(va[2]*vb[3]-va[3]*vb[2], va[3]*vb[1]-va[1]*vb[3], va[1]*vb[2]-va[2]*vb[1])),
        sum(va * vb))
}

far <- as.matrix(dist(pat$vertices)) > 1.5
tab <- data.frame()
for (t in seq(0, 1.5, by = 0.1)) {
  rho <- as.vector(S %*% c(s_cf(t), t))[orb]
  d <- develop(pat, cr, rho)
  X <- d$vertices3
  amb <- as.matrix(dist(X)); diag(amb) <- Inf
  tab <- rbind(tab, data.frame(
    theta = t, rho_horiz = s_cf(t),
    walk_discrepancy = d$discrepancy,
    bar_err = max(abs(bar_lengths(X, bars) - sqrt(L2))),
    dihedral_err = if (t == 0) 0 else
      max(abs(abs(sapply(seq_len(nrow(cr)), function(e) dihedral(X, e))) - abs(pi - abs(rho)))),
    max_z = max(abs(X[, 3])),
    min_far_ambient = min(amb[far])))
}
print(format(tab, digits = 4))
cat(sprintf("\n  worst developing-map vertex discrepancy over the sweep: %.3e\n", max(tab$walk_discrepancy)))
cat(sprintf("  worst bar-length error (= worst within-facet distance error, every facet is a triangle): %.3e\n", max(tab$bar_err)))
cat(sprintf("  worst error in the dihedral angles read back off the 3-D coordinates: %.3e\n", max(tab$dihedral_err)))
cat(sprintf("  at theta = 0 the reconstruction is the flat sheet: max |z| = %.1e\n", tab$max_z[1]))

# -- 8. Does the folded sheet stay embedded ----

hr("8. embedding")

# A rigid folding is allowed to pass through itself; a benchmark manifold is
# not. If two facets touch, ambient distance stops meaning anything and every
# ambient-metric method in Part II is being fed a surface that is not a graph
# over its chart. This is a sampled test, 15 points per facet, so it detects
# contact rather than proving its absence.
bc <- as.matrix(expand.grid(u = seq(0, 1, by = 0.2), v = seq(0, 1, by = 0.2)))
bc <- bc[rowSums(bc) <= 1 + 1e-12, ]; bc <- cbind(1 - rowSums(bc), bc)
np <- nrow(bc); nf <- length(pat$facets)
shares <- outer(seq_len(nf), seq_len(nf), Vectorize(function(a, b)
  length(intersect(pat$facets[[a]], pat$facets[[b]])) > 0))
for (t in c(0.3, 0.5, 0.7, 0.8, 0.9, 1.0, 1.2)) {
  X <- develop(pat, cr, as.vector(S %*% c(s_cf(t), t))[orb])$vertices3
  P <- do.call(rbind, lapply(seq_len(nf), function(f) bc %*% X[pat$facets[[f]], ]))
  fid <- rep(seq_len(nf), each = np)
  D <- as.matrix(dist(P)); D[shares[cbind(fid[row(D)], fid[col(D)])]] <- Inf
  cat(sprintf("  theta = %.1f : closest approach between facets sharing no vertex = %.4f\n", t, min(D)))
}
