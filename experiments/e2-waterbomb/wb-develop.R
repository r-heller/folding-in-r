# Developing map. Given a fold angle on every crease of a patch, place facet 1
# in the plane and walk the facet adjacency graph, rotating about each crease as
# it is crossed. The folding is valid exactly when the walk is single valued --
# when every vertex gets the same position from every facet that contains it.
# This is the end-to-end test: it uses the fold angles and produces the ambient
# coordinates the book's fold() contract would have to return.

# Directed boundary edges of each facet, so a crease can be oriented by the
# facet the walk is leaving.
facet_edges <- function(pattern) {
  do.call(rbind, lapply(seq_along(pattern$facets), function(f) {
    v <- pattern$facets[[f]]
    cbind(facet = f, a = v, b = c(v[-1], v[1]))
  }))
}

crease_table <- function(pattern) {
  fe <- as.data.frame(facet_edges(pattern))
  key <- paste(pmin(fe$a, fe$b), pmax(fe$a, fe$b), sep = ",")
  sp <- split(seq_len(nrow(fe)), key)
  sp <- sp[lengths(sp) == 2L]
  do.call(rbind, lapply(sp, function(ix) {
    data.frame(fA = fe$facet[ix[1]], fB = fe$facet[ix[2]],
               p = fe$a[ix[1]], q = fe$b[ix[1]])
  }))
}

rot_about_line <- function(P, u, r) {
  K <- matrix(c(0, u[3], -u[2], -u[3], 0, u[1], u[2], -u[1], 0), 3, 3)
  R <- diag(3) + sin(r) * K + (1 - cos(r)) * (K %*% K)
  list(R = R, t = as.vector(P - R %*% P))
}

develop <- function(pattern, creases, rho, root = 1L) {
  V <- nrow(pattern$vertices)
  x0 <- cbind(pattern$vertices, 0)
  nf <- length(pattern$facets)
  Rs <- vector("list", nf); ts <- vector("list", nf)
  Rs[[root]] <- diag(3); ts[[root]] <- c(0, 0, 0)
  adj <- vector("list", nf)
  for (e in seq_len(nrow(creases))) {
    adj[[creases$fA[e]]] <- c(adj[[creases$fA[e]]], e)
    adj[[creases$fB[e]]] <- c(adj[[creases$fB[e]]], e)
  }
  queue <- root
  while (length(queue)) {
    f <- queue[1]; queue <- queue[-1]
    for (e in adj[[f]]) {
      g <- if (creases$fA[e] == f) creases$fB[e] else creases$fA[e]
      if (!is.null(Rs[[g]])) next
      s <- if (creases$fA[e] == f) 1 else -1
      P <- x0[creases$p[e], ]; Q <- x0[creases$q[e], ]
      u <- (Q - P) / sqrt(sum((Q - P)^2))
      M <- rot_about_line(P, u, s * rho[e])
      Rs[[g]] <- Rs[[f]] %*% M$R
      ts[[g]] <- as.vector(Rs[[f]] %*% M$t + ts[[f]])
      queue <- c(queue, g)
    }
  }
  place <- function(f, v) as.vector(Rs[[f]] %*% x0[v, ] + ts[[f]])
  pos <- matrix(NA_real_, V, 3); seen <- logical(V); disc <- 0
  for (f in seq_len(nf)) for (v in pattern$facets[[f]]) {
    p <- place(f, v)
    if (!seen[v]) { pos[v, ] <- p; seen[v] <- TRUE }
    else disc <- max(disc, sqrt(sum((p - pos[v, ])^2)))
  }
  list(vertices3 = pos, discrepancy = disc, placed = sum(!sapply(Rs, is.null)))
}

# Which of the nine crease orbits each patch crease belongs to. Classified from
# the midpoint's position within the unit cell, which is unambiguous: the nine
# types sit at nine distinct quarter-lattice offsets.
crease_orbit <- function(pattern, creases) {
  mid <- (pattern$vertices[creases$p, ] + pattern$vertices[creases$q, ]) / 2
  fx <- round((mid[, 1] %% 1) * 4); fy <- round((mid[, 2] %% 1) * 4)
  key <- paste(fx, fy)
  map <- c("2 0" = 1L, "0 1" = 2L, "0 3" = 3L, "1 2" = 4L, "3 2" = 5L,
           "3 3" = 6L, "1 3" = 7L, "1 1" = 8L, "3 1" = 9L)
  unname(map[key])
}
