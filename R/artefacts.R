# ── Artefacts: writing provenance, and reading it back ──────────────────────
#
# The book's rule is that every number is computed at render time from a
# committed artefact. That makes two things load bearing, and neither existed:
#
#   provenance()  one description of what produced a run, written the same way
#                 by every producer. It was a bare repo SHA in one script and
#                 nothing at all in another, and the three E1 artefacts asserted
#                 to carry it carried NULL.
#
#   read_run()    the reader. `PLAN.md` and `CHAPTERS.md` both say every chapter
#                 from 4 onward opens with a `read_run()` of a committed .rds and
#                 a digest check. There was no such function.
#
# The digest is the point of the pairing. A chapter is written against numbers,
# and if the artefact behind them is regenerated the prose does not notice: the
# chunks re-run, the figures redraw, the sentences around them keep the old
# values. A recorded digest turns that into a build failure with a name on it.

#' A content digest of a run, ignoring how it was produced.
#'
#' Provenance is stripped before hashing, deliberately. It carries a commit SHA,
#' a timestamp and an elapsed time, so hashing it would make the digest change on
#' every regeneration even when the numbers did not -- and a check that always
#' fires is one that gets deleted. What is hashed is the answer, so re-running a
#' producer and reproducing its results leaves the digest alone, and re-running
#' it and getting different results does not.
run_digest <- function(x) {
  attr(x, "provenance") <- NULL
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("the digest package is required to check artefact digests", call. = FALSE)
  }
  digest::digest(x, algo = "xxhash64")
}

#' What produced this run.
#'
#' Everything here answers a question someone will actually ask of a committed
#' result: which code, on which library, on which machine, and how long did it
#' take. `dirty` is the one that gets left out and matters most -- a SHA recorded
#' from a tree with uncommitted changes names code that was never committed, and
#' silently claims reproducibility the repository cannot deliver.
#'
#' `r_sha` is the SHA of `R/` alone, not of the repository: prose commits move
#' HEAD constantly and would make every artefact look stale against code that
#' never changed.
provenance <- function(..., started = NULL) {
  git <- function(args, default = NA_character_) {
    out <- tryCatch(suppressWarnings(system2("git", args, stdout = TRUE, stderr = FALSE)),
                    error = function(e) NULL)
    if (is.null(out) || !length(out)) default else paste(out, collapse = " ")
  }
  pkgs <- c("base", "Matrix", "RSpectra", "Rtsne", "umap", "uwot", "vegan",
            "FNN", "kernlab", "diffusionMap", "coRanking")
  versions <- vapply(pkgs, function(p) {
    tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
  }, character(1))

  c(list(
    repo_sha  = git(c("rev-parse", "--short", "HEAD")),
    r_sha     = git(c("rev-parse", "--short", "HEAD:R")),
    dirty     = nzchar(git(c("status", "--porcelain", "--", "R", "scripts"), "")),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    platform  = R.version$platform,
    blas      = tryCatch(La_library(), error = function(e) NA_character_),
    packages  = versions[!is.na(versions)],
    date      = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    elapsed   = if (is.null(started)) NA_real_ else
                  round(as.numeric(difftime(Sys.time(), started, units = "secs")), 1),
    cores     = unname(parallel::detectCores())   # of the machine; a producer
                                                  # that spreads work records its
                                                  # own `workers` alongside
  ), list(...))
}

#' Attach provenance and write.
write_run <- function(x, path, ..., started = NULL, quiet = FALSE) {
  attr(x, "provenance") <- provenance(..., started = started)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(x, path)
  if (!quiet) {
    message("wrote ", path, " -- ",
            if (is.null(nrow(x))) length(x) else nrow(x), " rows, digest ",
            run_digest(x))
  }
  invisible(x)
}

#' Read a committed run, and refuse a different one.
#'
#' @param path     the artefact, relative to the book root.
#' @param digest   the digest the calling chapter was written against. When
#'                 supplied and different, this stops.
#' @param quiet    suppress the one-line provenance note.
#'
#' The error is the whole design. A chapter that opens
#'
#'     grid <- read_run("data/processed/benchmark-grid.rds", "3f0c1ad2e8b4c9d1")
#'
#' cannot be rendered against a grid it was not written against. Getting the
#' digest for the first time is deliberately a one-liner the message hands over,
#' so recording it is easier than not recording it.
read_run <- function(path, digest = NULL, quiet = FALSE) {
  if (!file.exists(path)) {
    stop("no artefact at ", path, ". It is committed, not generated at render ",
         "time -- run its producer (the script whose header declares ",
         "`@artefact ", path, "`) and commit the result. ",
         "scripts/check-artefact-producers.R names the producer of every ",
         "artefact the book specifies.", call. = FALSE)
  }

  x  <- readRDS(path)
  pr <- attr(x, "provenance")
  if (is.null(pr)) {
    stop(path, " carries no provenance. It cannot be traced to the code that ",
         "made it, so a chapter must not report numbers from it. Regenerate it ",
         "with its producer.", call. = FALSE)
  }
  if (isTRUE(pr$quick)) {
    stop(path, " was written by a --quick run. That is a smoke test, not the ",
         "book's evidence.", call. = FALSE)
  }

  d <- run_digest(x)
  if (!is.null(digest) && !identical(d, digest)) {
    stop(path, " is not the run this chapter was written against.\n",
         "  expected digest: ", digest, "\n",
         "  found:           ", d, "\n",
         "  produced by:     ", pr$r_sha, if (isTRUE(pr$dirty)) " (DIRTY TREE)" else "",
         " on ", pr$date, "\n",
         "The numbers in the prose around this call were read off the expected ",
         "run. Re-read them against this one and update the digest in the same ",
         "commit, or restore the artefact.", call. = FALSE)
  }
  if (!quiet) {
    message(basename(path), ": ", if (is.null(nrow(x))) length(x) else nrow(x),
            " rows, R/ at ", pr$r_sha, ", digest ", d)
  }
  if (isTRUE(pr$dirty)) {
    warning(path, " was produced from a tree with uncommitted changes in R/ or ",
            "scripts/. Its r_sha names code that was never committed.",
            call. = FALSE)
  }
  attr(x, "digest") <- d
  x
}
