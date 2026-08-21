# Fold-angle formulation. A crease pattern on a disk folds rigidly iff every
# interior vertex closes: walking counter-clockwise round the vertex and
# composing the rotations about the outgoing crease directions returns the
# identity. For a disk that per-vertex condition is also sufficient, so the whole
# rigid-folding variety of a patch is cut out by these equations alone.
#
# The reason this formulation is worth having alongside the bar framework: fold
# angles are the natural place to impose "every unit cell folds the same way".
# A configuration whose fold angles are constant on translation orbits is
# invariant under a rigid motion cell to cell -- a screw, not necessarily a pure
# translation -- so this test covers the cylindrical waterbomb, not only flat
# periodic folds.

rodrigues <- function(u, r) {
  K <- matrix(c(0, u[3], -u[2], -u[3], 0, u[1], u[2], -u[1], 0), 3, 3)
  diag(3) + sin(r) * K + (1 - cos(r)) * (K %*% K)
}

# Residual of one vertex: the closure matrix minus the identity, flattened.
vertex_closure <- function(dirs_deg, rho) {
  M <- diag(3)
  for (k in seq_along(rho)) {
    a <- dirs_deg[k] * pi / 180
    M <- M %*% rodrigues(c(cos(a), sin(a), 0), rho[k])
  }
  as.vector(M - diag(3))
}

# System residual for a list of vertices; idx[[v]] picks which unknowns feed
# vertex v, in counter-clockwise order, and dirs[[v]] their in-plane directions.
closure_system <- function(rho, dirs, idx) {
  unlist(lapply(seq_along(dirs), function(v) vertex_closure(dirs[[v]], rho[idx[[v]]])))
}

num_jacobian <- function(f, x, h = 1e-6) {
  f0 <- f(x)
  J <- matrix(0, length(f0), length(x))
  for (k in seq_along(x)) {
    xp <- x; xp[k] <- xp[k] + h
    xm <- x; xm[k] <- xm[k] - h
    J[, k] <- (f(xp) - f(xm)) / (2 * h)
  }
  J
}

# Newton on the closure system with one angle driven to a target. The driven
# angle plays the role of theta: if a one-parameter folding exists, sweeping it
# traces the folding out.
drive_angle <- function(rho, dirs, idx, drive, target, iters = 200, tol = 1e-13) {
  f <- function(r) c(closure_system(r, dirs, idx), r[drive] - target)
  for (it in seq_len(iters)) {
    r0 <- f(rho)
    if (max(abs(r0)) < tol) break
    J <- num_jacobian(function(r) f(r), rho)
    rho <- rho - as.vector(pinv_solve(J, r0))
  }
  list(rho = rho, resid = max(abs(closure_system(rho, dirs, idx))),
       drive_err = abs(rho[drive] - target), iters = it)
}
