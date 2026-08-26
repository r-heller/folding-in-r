# The constructions, and the bound the book now rests on.

mk <- function(n = 200L) {
  a <- sample_manifold(miura_ori(3L, 3L), theta = 0.6, n = n, seed = 1001L,
                       boundary = TRUE)
  b <- sample_manifold(miura_ori(3L, 3L, alpha = pi / 4), theta = 0.5, n = n, seed = 1002L,
                       boundary = TRUE)
  list(a = a, b = b, p = product_manifold(a, b))
}

test_that("the product keeps exact truth and the right dimensions", {
  s <- suppressMessages(mk())
  expect_equal(ncol(s$p$X), ncol(s$a$X) + ncol(s$b$X))
  expect_equal(ncol(s$p$truth), ncol(s$a$truth) + ncol(s$b$truth))
  expect_equal(nrow(s$p$X), nrow(s$a$X))
  expect_true(s$p$exact_truth)
  expect_s3_class(s$p, "manifold_sample")
})

test_that("the product's distances are the Pythagorean combination of its factors", {
  # This is what keeps the answer exact: the chart of the product is the pair of
  # charts, and distance in it is sqrt(dA^2 + dB^2). If that failed, the product
  # would have no closed-form truth and Chapter 8 would have nothing to stand on.
  s <- suppressMessages(mk(120L))
  dA <- as.matrix(stats::dist(s$a$truth))
  dB <- as.matrix(stats::dist(s$b$truth))
  dP <- as.matrix(stats::dist(s$p$truth))
  expect_lt(max(abs(dP - sqrt(dA^2 + dB^2))), 1e-10)
})

test_that("the lift changes no distance at all", {
  s <- suppressMessages(mk(150L))
  for (D in c(10L, 40L, 100L)) {
    l <- lift(s$a, D = D, seed = 5L)
    expect_equal(ncol(l$X), D)
    expect_lt(max(abs(as.matrix(stats::dist(s$a$X)) -
                      as.matrix(stats::dist(l$X)))), 1e-12)
    expect_equal(l$truth, s$a$truth)      # the chart is untouched
  }
})

test_that("the lift refuses a map that is not an isometry", {
  s <- suppressMessages(mk(80L))
  expect_error(lift(s$a, D = 2L), "D >= p|not greater")
})

test_that("the irreducible loss is zero exactly when it should be", {
  s <- suppressMessages(mk(150L))
  expect_equal(irreducible_loss(s$a, 2L), 0)      # 2-D chart, 2-D target
  expect_equal(irreducible_loss(s$p, 4L), 0)      # 4-D chart, 4-D target
  expect_gt(irreducible_loss(s$p, 2L), 0)         # 4-D chart, 2-D target
})

test_that("the irreducible loss decreases as the target dimension grows", {
  s <- suppressMessages(mk(150L))
  v <- vapply(1:4, function(d) irreducible_loss(s$p, d), numeric(1))
  expect_false(is.unsorted(rev(v)))
  expect_equal(v[4], 0)
})

test_that("the bound is attained, so it is tight and not merely valid", {
  # The optimal rank-d projection of the centred chart must sit exactly ON the
  # floor. A bound nothing can reach is not a floor, it is a guess.
  s <- suppressMessages(mk(200L))
  U <- sweep(as.matrix(s$p$truth), 2L, colMeans(s$p$truth))
  sv <- svd(U)
  best <- sv$u[, 1:2] %*% diag(sv$d[1:2])
  expect_equal(reconstruction_error(best, s$p$truth),
               irreducible_loss(s$p, 2L), tolerance = 1e-8)
})

test_that("no method beats the bound", {
  # The property that makes it a bound at all, tested by trying to break it with
  # every method in the registry rather than by argument.
  s <- suppressMessages(mk(200L))
  fl <- irreducible_loss(s$p, 2L)
  for (nm in names(METHOD_REGISTRY)) {
    sd <- if (isTRUE(METHOD_REGISTRY[[nm]]$stochastic)) 1001L else NULL
    e <- suppressWarnings(suppressMessages(
      tryCatch(embed(nm, s$p, seed = sd), error = function(x) NULL)))
    if (is.null(e)) next
    expect_gte(reconstruction_error(e, s$p$truth), fl - 1e-9, label = nm)
  }
})

test_that("against_floor separates the data's loss from the method's", {
  s <- suppressMessages(mk(150L))
  e <- embed("pca", s$p)
  r <- against_floor(reconstruction_error(e, s$p$truth), s$p, 2L)
  expect_gte(r$excess, -1e-9)
  expect_equal(r$error - r$floor, r$excess)
  expect_gt(r$ratio, 1)

  # On a 2-D chart the floor is zero and the whole error belongs to the method.
  r2 <- against_floor(reconstruction_error(embed("pca", s$a), s$a$truth), s$a, 2L)
  expect_equal(r2$floor, 0)
  expect_true(is.na(r2$ratio))
})
