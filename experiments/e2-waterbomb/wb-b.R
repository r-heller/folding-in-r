# The waterbomb tessellation proper: the arrangement of three families of
# straight lines at 0, 45 and 135 degrees. Every vertex is a triple crossing,
# hence degree 6 with sectors (45, 90, 45, 45, 90, 45) -- the vertex PLAN.md
# names, and here it is the ONLY vertex type in the pattern.
#
# Vertices are the checkerboard sublattice: integer corners (i, j) and cell
# centres (i+1/2, j+1/2). Facets are right isosceles triangles, legs sqrt(2)/2
# on the diagonals and hypotenuse 1 on a horizontal. Six creases per cell:
#   h  (i,j)-(i+1,j)                 horizontal through the corners
#   m  centre(i,j)-centre(i+1,j)     horizontal through the centres
#   a  (i,j)-centre(i,j)             "/" corner to centre
#   b  centre(i,j)-(i+1,j+1)         "/" centre to corner
#   c  (i+1,j)-centre(i,j)           "\" corner to centre
#   dd centre(i,j)-(i,j+1)           "\" centre to corner

wb_tess_B <- function(m = 3L, n = 3L) {
  corner <- expand.grid(a = seq(0L, 2L * m, by = 2L), b = seq(0L, 2L * n, by = 2L))
  cent   <- expand.grid(a = seq(1L, 2L * m - 1L, by = 2L), b = seq(1L, 2L * n - 1L, by = 2L))
  lat <- rbind(corner, cent)
  keys <- paste(lat$a, lat$b, sep = ",")
  id <- function(a, b) match(paste(a, b, sep = ","), keys)

  tri <- list()
  add <- function(v) if (!anyNA(v)) tri[[length(tri) + 1L]] <<- v
  # every horizontal crease carries the two triangles that lean on it; that is
  # all of them, and enumerating this way leaves no ragged row at the top edge
  for (i in seq_len(m) - 1L) for (j in 0:n) {
    ai <- 2L * i; bj <- 2L * j
    add(c(id(ai, bj), id(ai + 2L, bj), id(ai + 1L, bj + 1L)))
    add(c(id(ai, bj), id(ai + 2L, bj), id(ai + 1L, bj - 1L)))
  }
  for (i in seq_len(max(m - 1L, 0L)) - 1L) for (j in seq_len(n) - 1L) {
    ai <- 2L * i; bj <- 2L * j
    add(c(id(ai + 1L, bj + 1L), id(ai + 3L, bj + 1L), id(ai + 2L, bj + 2L)))
    add(c(id(ai + 1L, bj + 1L), id(ai + 3L, bj + 1L), id(ai + 2L, bj)))
  }
  xy <- cbind(lat$a / 2, lat$b / 2)
  tri <- lapply(tri, function(f) {                       # orient counter-clockwise
    p <- xy[f, ]
    s <- (p[2, 1] - p[1, 1]) * (p[3, 2] - p[1, 2]) - (p[3, 1] - p[1, 1]) * (p[2, 2] - p[1, 2])
    if (s < 0) rev(f) else f
  })
  list(vertices = xy, facets = tri, family = "waterbomb", params = list(m = m, n = n))
}

# Crease orbit under the translation lattice, refined to an M x N supercell.
# Returns 1..6 for the six types and the supercell index the crease sits in.
crease_orbit_B <- function(pattern, creases, M = 1L, N = 1L) {
  mid <- (pattern$vertices[creases$p, ] + pattern$vertices[creases$q, ]) / 2
  fx <- round((mid[, 1] %% 1) * 4); fy <- round((mid[, 2] %% 1) * 4)
  key <- paste(fx, fy)
  type <- unname(c("2 0" = 1L, "0 2" = 2L, "1 1" = 3L, "3 3" = 4L,
                   "3 1" = 5L, "1 3" = 6L)[key])
  ci <- ifelse(type == 2L, round(mid[, 1]) - 1L, floor(mid[, 1]))
  cj <- floor(mid[, 2])
  as.integer(((cj %% N) * M + (ci %% M)) * 6L + type)
}

# Vertex closure system on an M x N torus of cells.
torusB_system <- function(M = 1L, N = 1L) {
  cid <- function(type, i, j) as.integer((((j %% N) * M) + (i %% M)) * 6L + type)
  dirs <- list(); idx <- list(); tag <- character(0)
  for (i in seq_len(M) - 1L) for (j in seq_len(N) - 1L) {
    dirs[[length(dirs) + 1L]] <- c(0, 45, 135, 180, 225, 315)
    idx[[length(idx) + 1L]] <- c(cid(1, i, j), cid(3, i, j), cid(5, i - 1L, j),
                                 cid(1, i - 1L, j), cid(4, i - 1L, j - 1L),
                                 cid(6, i, j - 1L))
    tag <- c(tag, sprintf("corner(%d,%d)", i, j))
    dirs[[length(dirs) + 1L]] <- c(0, 45, 135, 180, 225, 315)
    idx[[length(idx) + 1L]] <- c(cid(2, i, j), cid(4, i, j), cid(6, i, j),
                                 cid(2, i - 1L, j), cid(3, i, j), cid(5, i, j))
    tag <- c(tag, sprintf("centre(%d,%d)", i, j))
  }
  list(dirs = dirs, idx = idx, tag = tag, n_rho = 6L * M * N, M = M, N = N,
       lab = paste0(rep(c("h", "m", "a", "b", "c", "d"), M * N), "_",
                    rep(seq_len(M * N) - 1L, each = 6L)))
}
