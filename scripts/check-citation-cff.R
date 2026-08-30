#!/usr/bin/env Rscript
#
# CITATION.cff, checked against the parts of CFF 1.2.0 that actually bite.
#
# The file shipped with `type: book` at the top level. CFF 1.2.0's top level
# describes the REPOSITORY and its `type` enum admits only `software` and
# `dataset`, so GitHub's citation dialog rejected the file and rendered empty --
# a citation surface that is silently broken is worse than one that is absent,
# because nothing looks wrong. A book is expressed as `preferred-citation`.
#
# This is not a full schema validator. cffconvert is, and it is a Python
# dependency this repository does not otherwise have; what is here covers the
# rules whose violation produces exactly that silent failure, plus the fields a
# citation manager needs to render anything at all.
#
# Usage:  Rscript scripts/check-citation-cff.R

if (!requireNamespace("yaml", quietly = TRUE)) {
  stop("the yaml package is required", call. = FALSE)
}

FILE <- "CITATION.cff"
if (!file.exists(FILE)) {
  stop(FILE, " is missing. GitHub's 'Cite this repository' needs it, and so ",
       "does 98-citing-this-guide.Rmd.", call. = FALSE)
}

problems <- character(0)
bad <- function(...) problems <<- c(problems, paste0(...))

cff <- tryCatch(yaml::read_yaml(FILE), error = function(e) e)
if (inherits(cff, "error")) {
  stop(FILE, " is not valid YAML: ", conditionMessage(cff), call. = FALSE)
}

# ── The top level describes the repository ──────────────────────────────────

REPO_TYPES <- c("software", "dataset")
if (!is.null(cff$type) && !cff$type %in% REPO_TYPES) {
  bad("top-level `type: ", cff$type, "` is not a CFF 1.2.0 repository type. ",
      "It must be one of ", paste(REPO_TYPES, collapse = " / "),
      " -- a book goes under `preferred-citation`. GitHub renders an EMPTY ",
      "citation dialog for an invalid type rather than reporting an error.")
}

if (is.null(cff$`cff-version`) || !grepl("^1\\.2", as.character(cff$`cff-version`))) {
  bad("cff-version must be 1.2.x; got ",
      if (is.null(cff$`cff-version`)) "nothing" else cff$`cff-version`)
}

for (f in c("message", "title", "authors")) {
  if (is.null(cff[[f]])) bad("required field `", f, "` is missing")
}

check_authors <- function(a, where) {
  if (!length(a)) { bad(where, " has no authors"); return(invisible()) }
  for (i in seq_along(a)) {
    p <- a[[i]]
    if (is.null(p$`family-names`) && is.null(p$name)) {
      bad(where, " author ", i, " has neither `family-names` nor `name`; a ",
          "citation manager has nothing to render")
    }
    if (!is.null(p$orcid) && !grepl("^https://orcid\\.org/[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9X]{4}$", p$orcid)) {
      bad(where, " author ", i, " has an orcid that is not a full ",
          "https://orcid.org/ URI: ", p$orcid)
    }
  }
}
check_authors(cff$authors, "top level")

for (f in c("date-released")) {
  if (!is.null(cff[[f]]) && !grepl("^\\d{4}-\\d{2}-\\d{2}$", as.character(cff[[f]]))) {
    bad("`", f, "` must be YYYY-MM-DD; got ", cff[[f]])
  }
}

# ── preferred-citation is the thing to cite ─────────────────────────────────
#
# Required, in this repository, because the repository is not the work: a reader
# citing the software when they meant the book is the failure this file exists
# to prevent.

REFERENCE_TYPES <- c(
  "article", "book", "booklet", "conference", "conference-paper", "database",
  "dataset", "edited-work", "generic", "manual", "map", "misc", "pamphlet",
  "proceedings", "report", "software", "thesis", "unpublished")

pc <- cff$`preferred-citation`
if (is.null(pc)) {
  bad("no `preferred-citation`. The repository is not the work: without this, ",
      "GitHub offers the software as the thing to cite.")
} else {
  if (is.null(pc$type) || !pc$type %in% REFERENCE_TYPES) {
    bad("preferred-citation type `", pc$type %||% "missing",
        "` is not a CFF reference type")
  }
  for (f in c("title", "authors", "year")) {
    if (is.null(pc[[f]])) bad("preferred-citation is missing `", f, "`")
  }
  check_authors(pc$authors, "preferred-citation")
  if (!is.null(pc$year) && !grepl("^\\d{4}$", as.character(pc$year))) {
    bad("preferred-citation year must be four digits; got ", pc$year)
  }
  if (!identical(pc$title, cff$title)) {
    bad("the repository title and the preferred citation's title differ. That ",
        "is allowed, and here it is almost certainly a copy that drifted:\n",
        "    repository: ", cff$title, "\n    citation:   ", pc$title)
  }
}

# ── The version this file claims ────────────────────────────────────────────
#
# Four files assert a version git has never recorded. That is not this script's
# to fix, but it is this script's to say out loud: a citation carrying a version
# number no tag corresponds to sends a reader to a state they cannot check out.

tags <- tryCatch(suppressWarnings(system2("git", c("tag", "--list"), stdout = TRUE)),
                 error = function(e) character(0))
if (!is.null(cff$version) && length(tags) &&
    !any(sub("^v", "", tags) == as.character(cff$version))) {
  cat("note: CITATION.cff claims version ", cff$version,
      " and no git tag matches it. Tag the release, or the citation points at ",
      "a state a reader cannot check out.\n", sep = "")
} else if (!is.null(cff$version) && !length(tags)) {
  cat("note: CITATION.cff claims version ", cff$version,
      " and this repository has no tags at all.\n", sep = "")
}

if (length(problems)) {
  cat("\nCITATION.cff FAILED:\n")
  for (p in problems) cat("  * ", p, "\n", sep = "")
  quit(status = 1L)
}

cat("CITATION.cff is valid: repository as ", cff$type %||% "software",
    ", preferred citation as ", pc$type, ".\n", sep = "")
