#!/usr/bin/env Rscript
#
# Verify that every bibliography entry carries an identifier that actually
# resolves. Exits 1 if any entry fails, so it can gate CI.
#
# DOIs are checked against the Handle System resolver at doi.org, not by
# fetching the publisher's landing page and not against a single registration
# agency. Two false-negative modes are avoided that way:
#
#   * Landing pages. Several publishers -- AAAS most notably -- answer
#     automated requests with HTTP 403 whatever the DOI. The two Science DOIs
#     here (Isomap and LLE, Science 290(5500)) are correct and were reported
#     unresolved by the landing-page check inherited from methods-in-r.
#
#   * Single-agency lookup. Crossref does not index DataCite DOIs. arXiv
#     registers under DataCite, so 10.48550/arXiv.* returns 404 from Crossref
#     while being perfectly valid.
#
# doi.org/api/handles/<doi> is the Handle System itself and answers for every
# registration agency, which is exactly the question being asked.

suppressPackageStartupMessages({
  library(bibtex)
  library(httr2)
  library(purrr)
})

bib_file <- if (file.exists("book.bib")) "book.bib" else "references.bib"
if (!file.exists(bib_file)) {
  message("No bibliography file found; skipping verification.")
  quit(status = 0)
}

bib  <- bibtex::read.bib(bib_file)
keys <- names(bib)

# Identify the tool. Named user agents are treated better by both the
# Handle resolver and the arXiv API than anonymous requests.
UA <- "folding-in-r citation checker (https://github.com/r-heller/folding-in-r)"

check_doi <- function(doi) {
  tryCatch({
    resp <- request(paste0("https://doi.org/api/handles/", doi)) |>
      req_user_agent(UA) |>
      req_timeout(20) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform()
    resp_status(resp) == 200L
  }, error = function(e) FALSE)
}

check_arxiv <- function(id) {
  tryCatch({
    resp <- request(paste0("http://export.arxiv.org/api/query?id_list=", id)) |>
      req_user_agent(UA) |>
      req_timeout(20) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform()
    resp_status(resp) == 200L && grepl("<entry>", resp_body_string(resp))
  }, error = function(e) FALSE)
}

check_url <- function(url) {
  tryCatch({
    resp <- request(url) |>
      req_user_agent(UA) |>
      req_timeout(20) |>
      req_error(is_error = function(r) FALSE) |>
      req_perform()
    resp_status(resp) < 400L
  }, error = function(e) FALSE)
}

# An ISBN is checked for shape only. There is no free, reliable, complete ISBN
# resolver; a well-formed ISBN on a book entry is accepted and counted in the
# summary rather than silently trusted.
check_isbn <- function(isbn) {
  digits <- gsub("[^0-9Xx]", "", isbn)
  nchar(digits) %in% c(10L, 13L)
}

verify <- function(entry) {
  if (!is.null(entry$doi))    return(check_doi(entry$doi))
  if (!is.null(entry$eprint)) return(check_arxiv(entry$eprint))
  if (!is.null(entry$isbn))   return(check_isbn(entry$isbn))
  if (!is.null(entry$url))    return(check_url(entry$url))
  NA
}

# Entries allowed to carry no identifier at all, declared IN THE BIB FILE with
# a "% NOIDENT-OK" comment on the line above the @type{key line.
#
# The earlier version of this script returned NA for an identifier-less entry
# and printed it as "tolerated" before exiting 0. That is the single hole that
# matters: CONTRIBUTING.md says nothing is cited from memory, and an entry
# written entirely from memory sailed through CI green. Tolerance is now
# opt-in, one entry at a time, and greppable.
noident_ok <- local({
  lines <- readLines(bib_file, warn = FALSE)
  marks <- grep("^\\s*%\\s*NOIDENT-OK\\b", lines)
  starts <- marks + 1L
  starts <- starts[starts <= length(lines)]
  out <- sub("^\\s*@[A-Za-z]+\\s*\\{\\s*([^,]+),.*$", "\\1", lines[starts])
  trimws(out[grepl("^\\s*@[A-Za-z]+\\s*\\{", lines[starts])])
})

results <- map(bib, verify)

bad       <- keys[map_lgl(results, isFALSE)]
noident   <- keys[map_lgl(results, is.na)]
tolerated <- intersect(noident, noident_ok)
untagged  <- setdiff(noident, noident_ok)
ok        <- sum(map_lgl(results, isTRUE))

# ---- Bidirectional key check ----------------------------------------------
#
# The other hole: nothing checked that a key cited in the text exists in the
# bibliography. A typo in @kaski2003trustworthines renders as a literal
# "@kaski2003trustworthines" or a bracketed "?" and nobody notices in a
# 40,000-word book.
#
# The \@ref(...) form is bookdown's cross-reference, not a citation, and must
# not be swept up -- hence the negative lookbehind on the backslash.
source_files <- c(list.files(".", pattern = "\\.Rmd$"),
                  list.files("R", pattern = "\\.R$", full.names = TRUE))
cited <- unique(unlist(lapply(source_files, function(f) {
  lines <- readLines(f, warn = FALSE)

  # Drop fenced code before looking for citations. Done line by line rather
  # than with a regex because the fences are not all three backticks: the
  # callout examples in 00-how-to-use.Rmd wrap a three-backtick chunk inside a
  # four-backtick fence, and a lazy regex closes on the wrong one. A fence is
  # closed only by a run of backticks at least as long as the one that opened
  # it, which is the rule pandoc itself uses.
  #
  # This matters concretely: 98-citing-this-guide.Rmd prints the book's own
  # BibTeX entry in a fenced block, and "@book{heller2026folding" in there is
  # an example, not a citation.
  fence <- 0L
  keep  <- logical(length(lines))
  for (i in seq_along(lines)) {
    n <- attr(regexpr("^\\s*`{3,}", lines[i]), "match.length")
    n <- if (n > 0L) nchar(gsub("[^`]", "", sub("^\\s*", "", lines[i]))) else 0L
    if (fence == 0L && n >= 3L) { fence <- n; next }
    if (fence >  0L && n >= fence) { fence <- 0L; next }
    keep[i] <- fence == 0L
  }
  txt <- paste(lines[keep], collapse = "\n")

  # Inline code spans too -- `@x` in prose is a name being shown, not cited.
  txt <- gsub("`[^`\n]*`", "", txt)

  # An @ that follows a word character is an email address; one that follows a
  # backslash is bookdown's \@ref cross-reference, not a citation.
  m <- regmatches(txt, gregexpr("(?<![\\w\\\\@])@[A-Za-z][A-Za-z0-9_:.#$%&+?<>~/-]*",
                                txt, perl = TRUE))[[1]]
  sub("^@", "", sub("[.,;:]+$", "", m))
})))

pkg_keys <- if (file.exists("packages.bib")) {
  ls <- readLines("packages.bib", warn = FALSE)
  trimws(sub("^@[A-Za-z]+\\{([^,]+),.*$", "\\1", ls[grep("^@[A-Za-z]+\\{", ls)]))
} else character(0)

known   <- c(keys, pkg_keys)
dangling <- setdiff(cited, known)
uncited  <- setdiff(keys, cited)

# ---- Report ---------------------------------------------------------------

status <- 0L

if (length(tolerated)) {
  cat(length(tolerated), " entries carry no identifier, marked NOIDENT-OK:\n", sep = "")
  cat(paste0("  - ", tolerated, "\n"), sep = "")
}

if (length(untagged)) {
  status <- 1L
  cat("\nEntries with NO identifier and NO NOIDENT-OK marker:\n")
  cat(paste0("  - ", untagged, "\n"), sep = "")
  cat("An entry with no DOI, arXiv ID, ISBN or URL cannot be checked, and an\n",
      "unchecked entry is indistinguishable from one written from memory.\n",
      "Add an identifier, or put a '% NOIDENT-OK' line above the entry in\n",
      bib_file, " and say in the text why the primary does not resolve.\n", sep = "")
}

if (length(bad)) {
  status <- 1L
  cat("\nUnresolved citation keys:\n")
  cat(paste0("  - ", bad, "\n"), sep = "")
  cat("An entry listed here either has a wrong identifier or names a work\n",
      "that does not exist. Fix the identifier or drop the claim that needs\n",
      "it -- do not cite from memory.\n", sep = "")
}

if (length(dangling)) {
  status <- 1L
  cat("\nCited in the sources but absent from the bibliography:\n")
  cat(paste0("  - @", dangling, "\n"), sep = "")
  cat("These render as literal text or as a bracketed question mark.\n")
}

if (length(uncited)) {
  cat("\nIn the bibliography but cited nowhere (warning only):\n")
  cat(paste0("  - ", uncited, "\n"), sep = "")
  cat("Expected while chapters are still stubs; it should reach zero.\n")
}

cat("\n", ok, " identifiers resolved, ", length(tolerated), " tolerated, ",
    length(cited), " keys cited, ", length(dangling), " dangling.\n", sep = "")

quit(status = status)
