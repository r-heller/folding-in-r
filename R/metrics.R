# Scoring an embedding against an answer key.
#
# Every number this book reports about a method comes out of this file, so the
# thing to be clear about first is what each function is a comparison between.
#
# PROJECT_CONCEPT.md commits the book to reporting two headline numbers per
# cell rather than one, because they answer different questions and the gap
# between them is the measurement:
#
#   * reconstruction_error() -- normalised full Procrustes RMSE. Quotients out
#     translation, rotation, reflection and isotropic scale, and nothing else.
#     A reparameterisation of the plane that preserves every neighbourhood but
#     bends the chart is a failure by this measure, correctly, because the
#     claim under test is isometry recovery.
#
#   * qnx() -- co-ranking Q_NX(K). Reads only the rank order of distances, so
#     it is blind to how far apart the points actually are and the same bent
#     chart scores near 1. Reporting only the first would build the scoring
#     function out of one side of the dispute the book claims to arbitrate.
#
#     One refinement on PROJECT_CONCEPT.md, which describes Q_NX as invariant
#     under any diffeomorphism of the plane. The exact statement is narrower:
#     it is invariant under anything that preserves the rank order, and a
#     diffeomorphism does that only where its Jacobian is near-conformal at the
#     scale of a K-neighbourhood. Measured on a 500-point chart under z -> z^2,
#     which is exactly conformal: Q_NX(10) = 0.971 and trustworthiness = 1.000
#     while the Procrustes score is 0.226 (tests/testthat/test-metrics.R).
#
# Two conventions that the rest of R/ and every chapter inherit from here:
#
#   * Chapter 9 owns the alignment convention. There is exactly one Procrustes
#     fit in this book and it lives in procrustes_align(); a chapter that wants
#     an aligned embedding to draw calls that function rather than inventing a
#     second convention whose numbers would not be comparable.
#
#   * "Reference" is a geometry, not necessarily the input data. Q_NX and the
#     rank metrics take whatever distance matrix they are handed, and the
#     book's contribution in Chapter 9 is to hand them reference_dist(s,
#     "chart") -- the exact geodesic -- instead of the ambient distances every
#     published evaluation uses. Nothing in the code prefers one; the argument
#     is named "reference" rather than "data" to keep that visible at the call
#     site.
#
# Argument order is not uniform and that is deliberate: reconstruction_error()
# and qnx() put the embedding first because the embedding is the thing under
# test, while trustworthiness() and continuity() put the high-dimensional
# geometry first, matching Kaski et al.'s own ordering and the call sites
# already committed in scripts/run-benchmark-grid.R.
#
# Cost. The budget is n = 800 (constants.R, N_DEFAULT), so an n x n distance
# matrix is 5.1 MB and an O(n^2) pass is free. Anything worse is written to be
# measured: the all-pairs shortest path in reference_dist(kind = "graph") is
# the one genuinely expensive operation here and its timing is recorded at
# .apsp_minplus().
#
# Internal helpers carry a leading dot, as in plotting.R and sampling.R: R/ is
# sourced into the global environment, so everything here is visible from a
# chapter, and the dot marks what is not part of the interface.

# ── Input coercion ───────────────────────────────────────────────────────────

# Coordinates. Non-finite values are fatal rather than dropped: a method that
# returned NA for a point has failed, and a metric that quietly averaged over
# the survivors would report a score for an embedding that does not exist.
.as_config <- function(x, what) {
  if (is.data.frame(x)) x <- as.matrix(x)
  if (!is.matrix(x) || !is.numeric(x)) {
    stop(what, " must be a numeric matrix of coordinates, one row per point; ",
         "got ", paste(class(x), collapse = "/"), call. = FALSE)
  }
  if (nrow(x) < 2L || ncol(x) < 1L) {
    stop(what, " must hold at least two points and at least one coordinate",
         call. = FALSE)
  }
  if (any(!is.finite(x))) {
    stop(what, " holds a non-finite coordinate", call. = FALSE)
  }
  x
}

# A square, symmetric, non-negative matrix with a zero diagonal is read as
# distances; anything else numeric is read as coordinates and turned into
# distances. The ambiguous case -- an n x n matrix of coordinates -- needs all
# three properties to hold by accident and is not worth an extra argument, but
# the rule is stated here rather than left to be inferred from behaviour.
.is_dmat <- function(x) {
  nrow(x) == ncol(x) && nrow(x) > 2L &&
    all(diag(x) == 0) && !any(x < 0) && isSymmetric(unname(x))
}

.as_dmat <- function(x, what) {
  if (inherits(x, "dist")) return(as.matrix(x))
  if (is.data.frame(x)) x <- as.matrix(x)
  if (!is.matrix(x) || !is.numeric(x)) {
    stop(what, " must be a dist, a square distance matrix, or a numeric ",
         "matrix of coordinates; got ", paste(class(x), collapse = "/"),
         call. = FALSE)
  }
  if (any(!is.finite(x))) {
    stop(what, " holds a non-finite value", call. = FALSE)
  }
  if (.is_dmat(x)) return(unname(x))
  as.matrix(stats::dist(.as_config(x, what)))
}

# Procrustes compares two configurations of the same points, and in Chapter 8
# they do not have the same number of columns: the product construction gives a
# 4-dimensional chart against a 2-dimensional embedding. Padding the narrower
# one with zero columns is the standard resolution and it is the right one --
# a 2-D embedding IS a 4-D configuration confined to a coordinate plane, and
# the rotation is then free to choose which plane.
.pad_cols <- function(x, p) {
  if (ncol(x) >= p) return(x)
  cbind(x, matrix(0, nrow(x), p - ncol(x)))
}

# ── Procrustes ───────────────────────────────────────────────────────────────

# The one alignment convention in this book.
#
# Full (not partial) Procrustes: the similarity group -- translation, rotation,
# REFLECTION and one isotropic scale. Reflection is in because a chart and its
# mirror image are the same isometry class and no method in Part II can be
# expected to pick a handedness; scale is in because t-SNE and UMAP have no
# scale to speak of and scoring them on one would measure a setting rather
# than a geometry. Anisotropic scale and shear are OUT: those are exactly the
# distortions the isometry claim is about, and admitting them would turn this
# metric into a second copy of qnx().
#
# The rotation comes from svd(t(Ac) %*% Bc) as U V', with no determinant
# correction -- that is what puts reflections in the group. A version that
# forced det(R) = 1 would silently score a mirrored but otherwise exact
# recovery as a failure.
#
# Returns the aligned embedding, in the truth's coordinates and padded to the
# truth's dimension, so a chapter can draw it straight on top of the chart.
# The pieces of the fit ride along as attributes rather than forcing every
# caller to unpack a list.
procrustes_align <- function(emb, truth) {
  fit <- .procrustes(emb, truth)
  out <- fit$fitted
  attr(out, "scale")       <- fit$scale
  attr(out, "rotation")    <- fit$rotation
  attr(out, "translation") <- fit$translation
  attr(out, "ss")          <- fit$ss
  attr(out, "ss_truth")    <- fit$ss_truth
  out
}

.procrustes <- function(emb, truth) {
  A <- .as_config(emb, "emb")
  B <- .as_config(truth, "truth")
  if (nrow(A) != nrow(B)) {
    stop("emb and truth must have the same number of rows; got ",
         nrow(A), " and ", nrow(B), call. = FALSE)
  }
  p <- max(ncol(A), ncol(B))
  A <- .pad_cols(A, p)
  B <- .pad_cols(B, p)

  ca <- colMeans(A)
  cb <- colMeans(B)
  Ac <- sweep(A, 2L, ca, check.margin = FALSE)
  Bc <- sweep(B, 2L, cb, check.margin = FALSE)
  ssA <- sum(Ac^2)
  ssB <- sum(Bc^2)

  sv <- svd(crossprod(Ac, Bc))
  rot <- sv$u %*% t(sv$v)

  # A degenerate embedding -- every point on top of every other -- has no
  # scale to solve for. The best similarity fit is then the constant map to
  # the truth's centroid, which is what scale 0 gives, and the residual is the
  # whole of the truth's spread. Returning that beats dividing by zero: it is
  # the honest score for an embedding that collapsed.
  scl <- if (ssA > 0) sum(sv$d) / ssA else 0

  # The residual is formed explicitly rather than from the algebraic identity
  # ssB - sum(sv$d)^2 / ssA. The identity is exact in real arithmetic and
  # catastrophic in floating point at a near-exact fit: it differences two
  # quantities that agree to full precision, so the residual comes out at
  # 1e-16 * ssB and reconstruction_error(truth, truth) lands near 1e-8 instead
  # of 1e-16. Forming Bc - s Ac R costs one extra n x p product and is accurate
  # at both ends of the range.
  fitted <- scl * (Ac %*% rot)
  resid  <- Bc - fitted

  list(fitted      = sweep(fitted, 2L, cb, "+", check.margin = FALSE),
       rotation    = rot,
       scale       = scl,
       translation = cb - scl * as.vector(ca %*% rot),
       ss          = sum(resid^2),
       ss_truth    = ssB)
}

# Normalised Procrustes RMSE.
#
# The normaliser is the truth's own root-mean-square radius about its centroid
# -- sqrt(sum(ss_resid) / sum(ss_truth)) -- so the score is the fraction of the
# chart's total variance that the best similarity transform of the embedding
# fails to explain, square-rooted back into distance units.
#
# That normaliser is what makes the two endpoints mean something:
#
#   0   the embedding is the chart up to a similarity. Exact isometry
#       recovery, and metric_floor() says when 0 is even available.
#   ~1  the embedding explains none of the chart's variance. A random
#       configuration scores 1 - O(1/n), because the best similarity fit of
#       unrelated data captures only the O(sqrt(n)) cross-covariance that
#       appears by chance. Measured over 200 Gaussian embeddings of a uniform
#       rectangular chart at n = 800: mean 0.999, minimum 0.996. At n = 400 the
#       same draw gives mean 0.998, which is the 1/n in view.
#
# The score cannot exceed 1, and that is arithmetic rather than luck: the
# residual is ss_truth - sum(sv$d)^2 / ss_emb and the subtracted term is
# non-negative, so no configuration does worse than the constant map to the
# centroid. Exactly 1 means the cross-covariance vanished. A metric bounded
# above matters here because Chapter 10 reports every result as a ratio to
# metric_floor(), and a ratio needs both ends fixed.
#
# normalise = FALSE returns the raw RMSE per point in the truth's units, which
# is the right thing for a figure with an axis in chart units and the wrong
# thing for anything compared across patterns.
#
# The normalised square of this is the symmetric Procrustes statistic that
# vegan::procrustes(truth, emb, symmetric = TRUE)$ss reports, and the tests
# check the two agree -- to twelve digits at n = 300, including the padded
# 4-D-against-2-D case. That matters twice: it is an independent implementation
# confirming the headline metric, and it means Chapter 9 can name the statistic
# rather than describing a bespoke one.
reconstruction_error <- function(emb, truth, normalise = TRUE) {
  fit <- .procrustes(emb, truth)
  if (normalise) {
    if (fit$ss_truth <= 0) {
      stop("truth has zero spread, so there is nothing to normalise by; ",
           "every point of the chart is the same point", call. = FALSE)
    }
    sqrt(max(fit$ss, 0) / fit$ss_truth)
  } else {
    sqrt(max(fit$ss, 0) / nrow(fit$fitted))
  }
}

# ── Ranks and the co-ranking matrix ──────────────────────────────────────────

# Rank of every point in every other point's neighbourhood, 1 for the nearest
# other point and n - 1 for the farthest. The diagonal is 0, which is not a
# rank: it marks "self" so that every downstream mask can exclude it with
# r > 0 rather than by index arithmetic.
#
# Ties go to the lower index. Kaski et al. average over all compatible rank
# orders instead, which is better defined but produces non-integer ranks that
# the co-ranking matrix cannot index; on continuous distances the two agree
# because ties have measure zero, and on a pattern with exact ties -- a chart
# distance matrix from a regular lattice -- "first" at least gives the same
# answer twice.
.rank_matrix <- function(D) {
  diag(D) <- -Inf
  r <- apply(D, 1L, function(d) rank(d, ties.method = "first"))
  t(r) - 1L
}

# The co-ranking matrix of Lee and Verleysen: Q[k, l] counts the ordered pairs
# (i, j) whose rank is k in the reference geometry and l in the embedding.
# Everything on the diagonal is a rank the embedding got exactly right;
# everything below it is an intrusion, everything above an extrusion.
#
# Built directly rather than through the coRanking package, which is not in
# renv.lock -- and which would in any case take only two configurations, where
# the whole point of Chapter 9 is to substitute a reference geometry that is
# neither of them.
#
# The tabulate() index is (l - 1) * (n - 1) + k, so the count vector is
# (n - 1)^2 long. That overflows integer indexing past n = 46342, which is far
# outside this book's budget but is checked rather than assumed.
coranking <- function(emb, reference) {
  Dl <- .as_dmat(emb, "emb")
  Dh <- .as_dmat(reference, "reference")
  n <- nrow(Dh)
  if (nrow(Dl) != n) {
    stop("emb and reference must describe the same number of points; got ",
         nrow(Dl), " and ", n, call. = FALSE)
  }
  if (n < 3L) stop("the co-ranking matrix needs at least three points",
                   call. = FALSE)
  m <- n - 1L
  if (as.double(m)^2 > .Machine$integer.max) {
    stop("n = ", n, " needs a co-ranking index past .Machine$integer.max; ",
         "this implementation is written for the book's n = 800 budget",
         call. = FALSE)
  }
  rh <- .rank_matrix(Dh)
  rl <- .rank_matrix(Dl)
  keep <- rh != 0L                       # drops the diagonal, i.e. self-pairs
  idx <- (rl[keep] - 1L) * m + rh[keep]
  Q <- matrix(tabulate(idx, nbins = m * m), m, m)
  attr(Q, "n") <- n
  Q
}

# b[K] = sum of the top-left K x K block of Q, for every K at once. Two
# cumulative sweeps rather than a loop over K, so the whole curve costs one
# O(n^2) pass instead of n of them -- auc_qnx() needs every K and the loop
# version is what makes the naive implementation of it slow.
.coranking_blocks <- function(Q) {
  m <- nrow(Q)
  cs <- t(apply(Q, 1L, cumsum))
  cc <- apply(cs, 2L, cumsum)
  cc[cbind(seq_len(m), seq_len(m))]
}

# Q_NX(K): the fraction of K-neighbourhoods preserved.
#
#   Q_NX(K) = (1 / (K n)) * sum_{k <= K} sum_{l <= K} Q[k, l]
#
# which is the mean over points of |kNN_ref(i) intersect kNN_emb(i)| / K. It is
# 1 for an embedding that reproduces every K-neighbourhood and about K / (n - 1)
# for a random one, so it is NOT centred: the K/n baseline is the correction
# rnx() applies, and comparisons across K should go through that.
#
# K may be a vector; the co-ranking matrix is built once and every K read off
# it, which is the reason this returns a vector rather than making the caller
# loop.
qnx <- function(emb, reference, K = K_DEFAULT) {
  Q <- coranking(emb, reference)
  n <- attr(Q, "n")
  .qnx_from(Q, n, K)
}

.qnx_from <- function(Q, n, K) {
  K <- as.integer(K)
  if (anyNA(K) || any(K < 1L) || any(K > n - 1L)) {
    stop("K must lie in 1:", n - 1L, call. = FALSE)
  }
  .coranking_blocks(Q)[K] / (as.double(K) * n)
}

# The K/n-corrected form, R_NX(K) = ((n-1) Q_NX(K) - K) / (n - 1 - K). Zero for
# a random embedding, one for a perfect one, so it is the version to plot
# against K. Undefined at K = n - 1, where the denominator vanishes and every
# embedding trivially preserves everything.
rnx <- function(emb, reference, K = K_DEFAULT) {
  Q <- coranking(emb, reference)
  n <- attr(Q, "n")
  .rnx_from(Q, n, K)
}

.rnx_from <- function(Q, n, K) {
  K <- as.integer(K)
  if (any(K > n - 2L)) {
    stop("R_NX is undefined at K = n - 1; K must lie in 1:", n - 2L,
         call. = FALSE)
  }
  ((n - 1) * .qnx_from(Q, n, K) - K) / (n - 1 - K)
}

# Area under the Q_NX curve, over K on a log scale: weights 1/K normalised to
# sum to one, which is the convention Lee and Verleysen use and the reason it
# is a log scale rather than a linear one -- neighbourhood sizes 5 and 10 are a
# real difference, 505 and 510 are not.
#
# corrected = TRUE integrates R_NX and is the default, because integrating the
# uncorrected Q_NX over K mostly integrates the K/(n-1) baseline: the AUC would
# then be dominated by large K, where every embedding scores near 1, and would
# separate nothing.
auc_qnx <- function(emb, reference, K = NULL, corrected = TRUE) {
  Q <- coranking(emb, reference)
  n <- attr(Q, "n")
  if (is.null(K)) K <- seq_len(n - 2L)
  K <- as.integer(K)
  y <- if (corrected) .rnx_from(Q, n, K) else .qnx_from(Q, n, K)
  w <- 1 / K
  sum(w * y) / sum(w)
}

# ── Trustworthiness and continuity ───────────────────────────────────────────

# A(k), the normalising constant of Kaski et al. 2003, BMC Bioinformatics 4:48,
# section "Measuring trustworthiness and detecting genes for which the
# visualization is suspect", equations (3) and (4):
#
#     A(k) = 2 / (N k (2N - 3k - 1))
#
# STATUS: verified, by two independent routes that agree (PLAN.md S1-4 and R7,
# closed 2026-08-21).
#
#   1. The primary itself. Read from the article's own equation images for
#      eqs (3) and (4) and recorded verbatim in PROJECT_CONCEPT.md, not from
#      recollection and not from a re-implementation.
#   2. First principles, in tests/testthat/test-metrics.R: A(k) is exactly the
#      reciprocal of the largest penalty sum any embedding can produce, which
#      is brute-forced and compared against the closed form with no reference
#      to the paper at all.
#
# Route 2 is worth more than the comparison against coRanking that PLAN.md
# originally proposed as the gate. Two implementations can inherit the same
# misremembered constant from each other, which is precisely the failure R7
# names; an algebraic identity cannot. That comparison is still written, still
# skip()ed and still visible in test output, because "no second implementation
# has ever run this" is a fact about the state of the repository and hiding it
# would cost nothing to hide and something to have hidden.
#
# The identity route in one line. Each point contributes at most k terms --
# |U_k(i)| <= k -- and the largest ranks available to it are N-k .. N-1, so the
# largest sum over all N points is N * sum_{r = N-k}^{N-1} (r - k), which is
# N k (2N - 3k - 1) / 2, which is exactly 1/A(k). That is what makes T = 0 the
# floor rather than merely a small number.
#
# The paper's own caveat travels with the constant and most re-implementations
# drop it. A(k) is described as a scaling, not a proven bound on what a real
# projection can ATTAIN: Kaski et al. estimated the worst attainable M_1
# empirically, in their Figures 2 and 3, rather than deriving it. So T = 0 is a
# floor no real embedding is known to reach, and "T = 0.5" does not mean "half
# as bad as possible".
#
# One thing does follow from the arithmetic, and the tests assert it: under
# this file's tie rule, where every neighbourhood holds exactly k points, T
# cannot fall below 0. Under the paper's tie-averaging rule a boundary tie can
# put more than k points in a neighbourhood and the sum can then exceed 1/A(k),
# which is where a slightly negative value is not a bug. Nothing here clamps
# either way, and Chapter 9 has to say why rather than quietly truncating.
.a_k <- function(N, k) {
  if (k < 1L || k >= (2 * N - 1) / 3) {
    stop("k must satisfy 1 <= k < (2N - 1)/3 = ", format((2 * N - 1) / 3),
         "; outside that range A(k) is not positive and the scaling is ",
         "meaningless", call. = FALSE)
  }
  2 / (N * k * (2 * N - 3 * k - 1))
}

# All three rank metrics need the two geometries to describe the same points.
# Without the check R recycles the shorter mask against the longer one and
# returns a number, which is the worst of the three possible outcomes.
.check_same_n <- function(a, b) {
  if (nrow(a) != nrow(b)) {
    stop("d_high and emb must describe the same number of points; got ",
         nrow(a), " and ", nrow(b), call. = FALSE)
  }
  invisible(TRUE)
}

# Trustworthiness and continuity are the same computation with the two
# geometries swapped, so there is one core and two wrappers. Writing them out
# twice is how the two drift apart under editing.
#
# r_in  ranks in the space that supplies the penalty
# r_out ranks in the space that supplies the neighbourhood
#
# Trustworthiness asks what the display put in the neighbourhood that the
# original does not have there, and charges each intruder how far outside the
# original neighbourhood it really sits. Continuity asks what the original has
# that the display lost, and charges each absentee how far outside the display
# neighbourhood it ended up.
.tc <- function(r_in, r_out, k, N) {
  sel <- r_out >= 1L & r_out <= k & r_in > k
  1 - .a_k(N, k) * sum(r_in[sel] - k)
}

trustworthiness <- function(d_high, emb, k = K_DEFAULT) {
  rh <- .rank_matrix(.as_dmat(d_high, "d_high"))
  rl <- .rank_matrix(.as_dmat(emb, "emb"))
  .check_same_n(rh, rl)
  .tc(r_in = rh, r_out = rl, k = as.integer(k), N = nrow(rh))
}

continuity <- function(d_high, emb, k = K_DEFAULT) {
  rh <- .rank_matrix(.as_dmat(d_high, "d_high"))
  rl <- .rank_matrix(.as_dmat(emb, "emb"))
  .check_same_n(rh, rl)
  .tc(r_in = rl, r_out = rh, k = as.integer(k), N = nrow(rh))
}

# ── k-NN preservation ────────────────────────────────────────────────────────

# Mean agreement of the two k-nearest-neighbour sets.
#
# Both sets have exactly k members, so |A union B| = 2k - |A intersect B| and
# the two measures are related pointwise by jaccard = overlap / (2 - overlap).
# They are not the same number after averaging, but they are close, and the
# fact worth stating plainly is this: measure = "overlap" is EXACTLY Q_NX(k).
# Chapter 9 audits four metrics and two of them would be one metric if this
# defaulted to overlap, which is why it does not -- and why the identity is
# asserted in the tests rather than left for a reader to rediscover.
knn_preservation <- function(d_high, emb, k = K_DEFAULT,
                             measure = c("jaccard", "overlap")) {
  measure <- match.arg(measure)
  rh <- .rank_matrix(.as_dmat(d_high, "d_high"))
  rl <- .rank_matrix(.as_dmat(emb, "emb"))
  .check_same_n(rh, rl)
  k <- as.integer(k)
  if (k < 1L || k > nrow(rh) - 1L) {
    stop("k must lie in 1:", nrow(rh) - 1L, call. = FALSE)
  }
  inter <- rowSums(rh >= 1L & rh <= k & rl >= 1L & rl <= k)
  switch(measure,
         jaccard = mean(inter / (2 * k - inter)),
         overlap = mean(inter) / k)
}

# All four rank metrics, for every k, from one pass over the ranks.
#
# Not sugar -- it is the difference between Chapter 9's audit artefact being
# affordable and not. Each of trustworthiness(), continuity(),
# knn_preservation() and qnx() builds both rank matrices from scratch, and
# .rank_matrix() at n = 800 costs 0.20 s against 0.017 s for a whole Procrustes
# fit. The audit multiplies every cell by 3 reference geometries x 4 values of
# k x 2 candidate embeddings: 96 separate calls at 0.35 s each is 34 s per
# cell, against 15.2 s for fitting all nine methods (PROJECT_CONCEPT.md). Doing
# the ranks once takes the same work to about 0.4 s per geometry: measured at
# n = 800 over four values of k, 5.85 s of separate calls against 0.44 s here.
#
# NOT YET WIRED, and this comment used to read as though it were. It has zero
# callers outside the test suite: run-benchmark-grid.R still rebuilds both rank
# matrices per metric, and the evaluator audit it was written for has no producer
# at all. The measurement above is real and the function is tested; what was
# wrong was writing "the audit multiplies" in the present tense about compute
# that has never been spent. ROADMAP.md items 1.5 and 3.2 are where it gets its
# two consumers -- until then this is a prepared optimisation, not a live one.
#
# Column names match the artefact schema scripts/run-benchmark-grid.R already
# writes -- trust, cont, knn -- so a grid row and an audit row can be bound
# without a rename. knn is the Jaccard form, matching knn_preservation()'s
# default; the overlap form is the qnx column, because they are the same
# number and carrying it twice would be a lie about how many metrics there are.
rank_metrics <- function(reference, emb, k = K_DEFAULT) {
  rh <- .rank_matrix(.as_dmat(reference, "reference"))
  rl <- .rank_matrix(.as_dmat(emb, "emb"))
  .check_same_n(rh, rl)
  N <- nrow(rh)
  k <- as.integer(k)
  if (anyNA(k) || any(k < 1L) || any(k > N - 1L)) {
    stop("k must lie in 1:", N - 1L, call. = FALSE)
  }
  rows <- lapply(k, function(kk) {
    inter <- rowSums(rh >= 1L & rh <= kk & rl >= 1L & rl <= kk)
    data.frame(k     = kk,
               trust = .tc(r_in = rh, r_out = rl, k = kk, N = N),
               cont  = .tc(r_in = rl, r_out = rh, k = kk, N = N),
               knn   = mean(inter / (2 * kk - inter)),
               qnx   = mean(inter) / kk)
  })
  do.call(rbind, rows)
}

# ── Reference geometries ─────────────────────────────────────────────────────

# The three geometries Chapter 9 scores every metric against.
#
#   "ambient"  Euclidean distance in R^3, between the points as observed. What
#              PCA, MDS, t-SNE, UMAP and an autoencoder actually consume, and
#              what every published evaluation of them uses as the reference.
#
#   "chart"    Euclidean distance in the exact 2-D truth. This IS the geodesic
#              distance on the folded surface -- the book's premise, and the
#              reason the answer key is not an estimate of anything.
#
#              The argument in one line: a rigid folding is an isometry of the
#              intrinsic metric, so the length of a path on the folded sheet
#              equals the length of its preimage in the flat chart, and the
#              shortest path in the chart between two points is the straight
#              segment between them.
#
#              The one condition, stated rather than assumed: that segment has
#              to stay on the sheet. For a convex unfolded outline it always
#              does, and neither family here has one -- miura_ori(6, 6) and
#              yoshimura(6, 6) both unfold to a 6.5 x 5.196 region whose right
#              edge is a zigzag with teeth 0.5 deep, so 43 of 49 vertices sit
#              off the convex hull.
#
#              What rescues the equality is the sampler's default. With
#              boundary = FALSE the drawn chart coordinates span x in
#              [0.64, 5.89] and y in [0.51, 4.68] -- strictly inside the convex
#              sub-rectangle [0, 6] x [0, 5.196] -- so every segment between
#              two sampled points stays on the sheet and the chart distance is
#              the geodesic exactly. With boundary = TRUE the draw reaches
#              x = 6.44, into the teeth, and for the pairs that straddle one
#              the chart distance becomes a lower bound on the geodesic rather
#              than equal to it. Check the outline of a new family before
#              claiming equality rather than a bound for it.
#
#   "graph"    The estimate an actual method has to work with: a k-NN graph on
#              the ambient points, weighted by ambient distance, with all-pairs
#              shortest paths. This is Isomap's internal geometry, and the gap
#              between it and "chart" is the short-circuit that Chapter 5
#              predicts analytically.
#
# Returns a plain n x n matrix with the kind recorded as an attribute, and for
# "graph" the k that was actually used -- which is not always the k requested;
# see .knn_graph().
reference_dist <- function(sample, kind = c("ambient", "chart", "graph"),
                           k = K_DEFAULT) {
  kind <- match.arg(kind)
  if (!is.list(sample) || is.null(sample$X) || is.null(sample$truth)) {
    stop("sample must be a manifold_sample, i.e. a list with X and truth ",
         "(see R/README.md)", call. = FALSE)
  }
  X <- .as_config(sample$X, "sample$X")
  U <- .as_config(sample$truth, "sample$truth")
  if (nrow(X) != nrow(U)) {
    stop("sample$X and sample$truth must have the same number of rows",
         call. = FALSE)
  }

  out <- switch(
    kind,
    ambient = as.matrix(stats::dist(X)),
    chart   = as.matrix(stats::dist(U)),
    graph   = .graph_dist(X, k)
  )
  attr(out, "kind") <- kind
  out
}

# Symmetric k-NN graph, union rule: an edge whenever either endpoint is among
# the other's k nearest. That is Isomap's construction, and the union rather
# than the mutual rule matters -- the mutual rule disconnects the sparse
# corners of a sampled patch long before the union rule does.
#
# A disconnected graph has infinite distances, and an infinite entry poisons
# every metric downstream rather than failing where it happened. Raising k
# until the graph connects is what every Isomap implementation does; doing it
# silently is not, so the k actually used comes back as an attribute and the
# caller is warned.
.knn_graph <- function(D, k) {
  n <- nrow(D)
  k <- as.integer(k)
  if (k < 1L || k > n - 1L) stop("k must lie in 1:", n - 1L, call. = FALSE)
  ord <- apply(D, 1L, order)          # column j holds the ordering for point j
  repeat {
    adj <- matrix(FALSE, n, n)
    nb <- ord[seq(2L, k + 1L), , drop = FALSE]
    adj[cbind(as.vector(nb), rep(seq_len(n), each = k))] <- TRUE
    adj <- adj | t(adj)
    if (max(.components(adj)) == 1L) break
    if (k >= n - 1L) {
      stop("the k-NN graph will not connect even at k = n - 1", call. = FALSE)
    }
    k <- k + 1L
  }
  attr(adj, "k") <- k
  adj
}

# Connected components by breadth-first search on the logical adjacency. Small
# enough to write: igraph is not available in this project (a missing system
# library), and pulling in a graph package for one BFS would be a dependency
# per line of code.
.components <- function(adj) {
  n <- nrow(adj)
  lab <- integer(n)
  cur <- 0L
  for (s in seq_len(n)) {
    if (lab[s] != 0L) next
    cur <- cur + 1L
    lab[s] <- cur
    front <- s
    while (length(front)) {
      front <- which(colSums(adj[front, , drop = FALSE]) > 0 & lab == 0L)
      lab[front] <- cur
    }
  }
  lab
}

.graph_dist <- function(X, k) {
  D <- as.matrix(stats::dist(X))
  adj <- .knn_graph(D, k)
  k_used <- attr(adj, "k")
  if (k_used != as.integer(k)) {
    warning("the k-NN graph at k = ", k, " was disconnected; used k = ",
            k_used, " instead. Chapter 5 should report this, not hide it.",
            call. = FALSE)
  }
  out <- .apsp_minplus(adj, D)
  attr(out, "k") <- k_used
  out
}

# All-pairs shortest paths by min-plus relaxation against the sparse adjacency,
# with a work list.
#
# Every source at once: G is n x n, G[i, ] is the distance vector from i, and
# one relaxation of column v is min over v's in-neighbours u of G[, u] + w(u,v).
# A column is only recomputed when a column it depends on has moved, which is
# what the dirty set tracks; without it the same converged columns are
# recomputed every round.
#
# Three implementations were timed at n = 800 with k = 10 on a flat sheet
# (mean degree 11.6):
#
#   Floyd-Warshall, dense in-place min-plus     8.65 s
#   min-plus rounds, no work list               3.78 s
#   min-plus rounds with the work list          2.40 s
#
# so this is the one that ships. A per-source binary-heap Dijkstra has the
# better asymptotics and loses badly here for the usual reason: it needs
# n * O(m log n) interpreter steps where these need O(m) vectorised operations
# on length-n columns, and at n = 800 the constant is the whole story.
#
# Correctness does not depend on the work list: it is Bellman-Ford, and with
# non-negative weights each pass either lowers a distance or terminates. The
# round cap is a guard against a weight matrix that is not what it claims,
# not part of the algorithm.
.apsp_minplus <- function(adj, D) {
  n <- nrow(adj)
  inb <- lapply(seq_len(n), function(v) which(adj[, v]))
  inw <- lapply(seq_len(n), function(v) D[inb[[v]], v])
  outb <- lapply(seq_len(n), function(u) which(adj[u, ]))

  G <- matrix(Inf, n, n)
  diag(G) <- 0
  dirty <- rep(TRUE, n)
  for (round in seq_len(n)) {
    todo <- which(dirty)
    if (!length(todo)) break
    nxt <- logical(n)
    for (v in todo) {
      idx <- inb[[v]]
      w <- inw[[v]]
      best <- G[, v]
      for (t in seq_along(idx)) best <- pmin(best, G[, idx[t]] + w[t])
      if (any(best < G[, v])) {
        G[, v] <- best
        nxt[outb[[v]]] <- TRUE
      }
    }
    dirty <- nxt
  }
  if (any(dirty)) {
    stop("all-pairs shortest paths did not converge in n rounds; the weight ",
         "matrix is not a non-negative metric on this graph", call. = FALSE)
  }
  G
}

# ── The irreducible-loss bound ───────────────────────────────────────────────

# Claim B, and the book's spine. What it returns, stated exactly:
#
#     metric_floor(sample, d)  =  min over ALL n x d configurations Z of
#                                 reconstruction_error(Z, sample$truth)
#
# A minimum, not an infimum -- it is attained, by the projection of the chart
# onto its own top d principal directions, and the tests check that the
# attaining configuration scores exactly this value.
#
# Why the eigenvalue tail gives it. reconstruction_error() minimises
# ||B - s Z R - t||_F over the similarity group, and as Z ranges over every
# n x d configuration and (s, R) over the group, s Z R ranges over exactly the
# centred n x p matrices of rank at most d. Eckart-Young then says the best
# such matrix is the rank-d truncated SVD of the centred truth, with residual
# equal to the tail sum of squared singular values. Normalising by the total
# gives
#
#     floor(d) = sqrt( sum_{i > d} lambda_i / sum_i lambda_i )
#
# where lambda_i are the classical-MDS eigenvalues of the chart -- the
# eigenvalues of its doubly-centred squared-distance matrix, equal to the
# squared singular values of the centred coordinates.
#
# WHAT IT ASSUMES, and these are the sentences Chapter 8 has to get right:
#
#   1. It bounds the normalised full-Procrustes RMSE of this file and NOTHING
#      ELSE. It is not a floor on Q_NX, on trustworthiness, on continuity or on
#      stress, and there is no reason to expect any of those to bottom out at
#      the same configuration: this metric reads distances and they read rank
#      order. An embedding sitting exactly on this floor may score better or
#      worse on any of them than one well above it, which is the whole subject
#      of Chapter 9 and not a defect in the bound.
#
#   2. The truth must be a Euclidean configuration. It is, by construction --
#      truth is the chart, and the chart is a subset of the plane (or of R^4
#      for a product) -- but a distance matrix handed in from somewhere else
#      may not be, and a negative eigenvalue means the tail sum is no longer an
#      Eckart-Young residual. That case is refused rather than reported.
#
#   3. It is a bound over CONFIGURATIONS, not over methods. No claim is made
#      that any algorithm reaches it, and the minimiser is constructed from the
#      answer key, so it cannot be reached by anything that has not been given
#      the answer. Read a method's score as a ratio to this number.
#
#   4. It depends only on the chart, so it is the same at every theta and under
#      every noise model. That is the point: the floor is a property of the
#      answer key, not of the difficulty of recovering it, which is what makes
#      "every method achieves 0.98 of the floor" a statement about a regime
#      rather than about a sample.
#
# For the book's main grid the chart is 2-dimensional and d = 2, so the floor
# is 0 and every reported error is loss the method is responsible for. The
# construction that makes it interesting is Chapter 8's product of two folded
# sheets: a convex box in R^4, where half the variance is unreachable by any
# 2-D embedding once the four eigenvalues equalise. Measured on 4,000 points
# uniform in the unit 4-box: floor 0.6920, against sqrt(1/2) = 0.7071 in the
# limit -- the gap is finite-sample eigenvalue spread and it closes slowly.
metric_floor <- function(sample, d = EMBED_DIM) {
  U <- if (is.list(sample) && !is.null(sample$truth)) sample$truth else sample
  d <- as.integer(d)
  if (is.na(d) || d < 1L) stop("d must be a positive integer", call. = FALSE)

  lam <- chart_spectrum(U)
  tot <- sum(lam)
  if (tot <= 0) {
    stop("the chart has zero spread; there is no bound to state", call. = FALSE)
  }
  tail <- if (d >= length(lam)) 0 else sum(lam[-seq_len(d)])
  sqrt(max(tail, 0) / tot)
}

# Classical-MDS eigenvalues of the chart, decreasing. Public because Chapter 8
# plots this spectrum next to the bound it produces -- the tail IS the bound,
# and a figure that shows both makes the argument in one panel. Kept separate
# from metric_floor() so that the bound can stay a bare number: it is written
# into prose through an inline `r` expression, and a scalar carrying an
# eigenvalue vector as an attribute is a scalar waiting to print wrong.
#
# From the centred coordinates when they are available, because svd() of an
# n x p matrix is exact and cheap where eigen() of an n x n double-centred Gram
# is neither -- at n = 800 that is a 2 x 800 svd against an 800 x 800
# eigendecomposition. From the double centring when only distances are.
#
# The negative-eigenvalue check is the guard on assumption 2 of metric_floor().
# The tolerance is relative to the largest eigenvalue, because an absolute one
# would fire on a chart measured in metres and not on the same chart measured
# in kilometres.
chart_spectrum <- function(U) {
  if (inherits(U, "dist") || (is.matrix(U) && .is_dmat(U))) {
    D2 <- as.matrix(U)^2
    n <- nrow(D2)
    J <- diag(n) - 1 / n
    B <- -0.5 * J %*% D2 %*% J
    lam <- sort(eigen(B, symmetric = TRUE, only.values = TRUE)$values,
                decreasing = TRUE)
    keep <- lam > sqrt(.Machine$double.eps) * max(abs(lam))
    if (any(lam < -sqrt(.Machine$double.eps) * max(abs(lam)))) {
      stop("the chart distances are not Euclidean -- the double-centred ",
           "matrix has a negative eigenvalue, so the tail sum is not an ",
           "Eckart-Young residual and metric_floor() would not bound ",
           "anything", call. = FALSE)
    }
    # A p-dimensional configuration has at most p non-zero eigenvalues and the
    # double centring produces n of them, the rest being rounding. Dropping
    # those keeps this returning the same vector from coordinates and from
    # distances, which is what makes the two paths comparable in a test; the
    # discarded entries are below sqrt(eps) of the largest and change no tail
    # sum that anyone can measure.
    return(lam[keep])
  }
  Uc <- .as_config(U, "sample$truth")
  Uc <- sweep(Uc, 2L, colMeans(Uc), check.margin = FALSE)
  svd(Uc, nu = 0L, nv = 0L)$d^2
}
