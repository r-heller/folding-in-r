#!/usr/bin/env Rscript
#
# One PDF per chapter, for the "This chapter (PDF)" button in the right-hand
# panel of the HTML book.
#
# Three things here are easy to get wrong and were wrong in the version
# inherited from methods-in-r:
#
#   * The chapter list comes from _bookdown.yml, not from a recursive glob for
#     *.Rmd. Once renv is set up, a glob also picks up the vignettes shipped
#     inside renv/ and cheerfully renders packrat.pdf and docker.pdf into the
#     book's download directory.
#
#   * Output files are named after the chapter's HTML anchor, not after the
#     source file. The download button is built client-side from the current
#     page's filename, so 01-introduction.Rmd must produce intro.pdf — named
#     after {#intro} — or every button 404s. The script checks each name
#     against docs/ and fails loudly rather than producing dead links.
#
#   * _common.R is sourced into the render environment. bookdown applies
#     before_chapter_script on its own; rmarkdown::render() does not.
#
# And one that was wrong here until now:
#
#   * Cross-references. This used rmarkdown::render() with --citeproc, which
#     knows nothing about \@ref(): every reference emitted as the literal text
#     "\@ref(label)" into the PDF. Nobody noticed because the sources held six
#     \@ref calls between them and 00-how-to-use.Rmd, which holds most of them,
#     is on the SKIP list. The chapter specification multiplies that roughly
#     twentyfold.
#
#     Each chapter is now rendered through bookdown::pdf_book against a
#     one-chapter _bookdown.yml, so bookdown's reference resolver runs.
#     Within-chapter references resolve; references into other chapters degrade
#     to a visible "??" rather than to raw markup, which is the honest failure
#     mode for a single-chapter extract. Citations go through the book's own
#     natbib path rather than citeproc, so a chapter PDF cites exactly the way
#     the book does.

suppressPackageStartupMessages({
  library(bookdown)
  library(fs)
  library(yaml)
})

SKIP <- c("index.Rmd", "00-impressum.Rmd", "00-acknowledgments.Rmd",
          "95-colophon.Rmd")

cfg <- yaml::read_yaml("_bookdown.yml")
chapters <- cfg$rmd_files
chapters <- chapters[!chapters %in% SKIP & !grepl("^part-", chapters)]

# bookdown names each page after the explicit {#anchor} on the chapter's H1,
# falling back to a slug of the title.
anchor_of <- function(f) {
  h1 <- grep("^#\\s+", readLines(f, warn = FALSE), value = TRUE)[1]
  if (is.na(h1)) return(path_ext_remove(path_file(f)))
  # The brace can carry classes and attributes as well as the id --
  # "{#citing .unnumbered}" is one of ours -- and bookdown slugs the page after
  # the id alone. Taking the whole brace produced "citing .unnumbered.pdf",
  # which is a dead download button, which is exactly the failure this script
  # exists to catch. It caught it.
  id <- regmatches(h1, regexpr("\\{#[^} \t]+", h1))
  if (length(id)) return(sub("^\\{#", "", id))
  title <- trimws(sub("\\s*\\{[^}]*\\}\\s*$", "", sub("^#\\s+", "", h1)))
  tolower(gsub("(^-|-$)", "", gsub("[^A-Za-z0-9]+", "-", title)))
}

title_of <- function(f) {
  h1 <- grep("^#\\s+", readLines(f, warn = FALSE), value = TRUE)[1]
  if (is.na(h1)) return(path_ext_remove(path_file(f)))
  trimws(sub("\\s*\\{[^}]*\\}\\s*$", "", sub("^#\\s+", "", h1)))
}

out_dir <- path_abs("docs/pdf-chapters")
dir_create(out_dir)

# Each chapter is rendered in its own temporary directory.
#
# The obvious approach -- render_book(config_file = "a one-chapter yml") in
# place -- does not work, and fails in a way worth recording. bookdown resolves
# the project config on its first call in a session before config_file takes
# effect, so the FIRST chapter of the loop was rendered against the project
# _bookdown.yml: the whole book, written over docs/folding-in-r.pdf, with
# render_book returning success. Every later chapter used the intended config.
# A bug that hits one iteration out of nineteen and reports success is the kind
# this repository has had enough of.
#
# An isolated directory removes the ambiguity rather than working around it:
# there is exactly one _bookdown.yml in scope and nothing there can touch the
# built book. Assets are symlinked because the render only reads them.

ASSETS <- c("style", "images", "data", "R", "book.bib", "packages.bib", "_common.R")

render_one <- function(ch, slug, title) {
  tmp <- file_temp("chapter-pdf-")
  dir_create(tmp)
  on.exit(dir_delete(tmp), add = TRUE)

  for (a in ASSETS) {
    if (file_exists(a) || dir_exists(a)) link_create(path_abs(a), path(tmp, a))
  }
  file_copy(ch, path(tmp, path_file(ch)))

  # bookdown takes YAML metadata from the first file in rmd_files, and a
  # chapter file has none of its own. This header-only stand-in carries the
  # bibliography, the CSL and the document class, and contributes no body text.
  #
  # Its name must not begin with an underscore: bookdown skips those, which is
  # what made the part files invisible in Phase 10, and a skipped front file
  # takes the bibliography with it.
  front <- path(tmp, "chapter-front.Rmd")
  writeLines(c(
    "---",
    sprintf('title: "%s"', gsub('"', "'", title)),
    'subtitle: "Folding in R"',
    'author: "R. Heller"',
    'date: "`r Sys.Date()`"',
    "documentclass: book",
    "bibliography: [book.bib, packages.bib]",
    "biblio-style: apalike",
    "csl: style/vancouver.csl",
    "link-citations: yes",
    "---",
    ""
  ), front)

  writeLines(c(
    sprintf('book_filename: "%s"', slug),
    "delete_merged_file: true",
    'output_dir: "."',
    "new_session: no",
    'before_chapter_script: "_common.R"',
    "rmd_files:",
    "  - 'chapter-front.Rmd'",
    sprintf("  - '%s'", path_file(ch))
  ), path(tmp, "_bookdown.yml"))

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE, after = FALSE)
  setwd(tmp)

  got <- bookdown::render_book(
    input         = "chapter-front.Rmd",
    output_format = bookdown::pdf_book(
      base_format      = rmarkdown::pdf_document,
      latex_engine     = "xelatex",
      citation_package = "natbib",
      toc              = FALSE,
      includes         = rmarkdown::includes(in_header = "style/preamble.tex"),
      pandoc_args      = "--top-level-division=chapter"
    ),
    quiet = TRUE
  )

  produced <- path(tmp, paste0(slug, ".pdf"))
  if (!file_exists(produced)) {
    stop("render produced no ", slug, ".pdf (returned ", got, ")", call. = FALSE)
  }
  file_copy(produced, path(out_dir, paste0(slug, ".pdf")), overwrite = TRUE)
  invisible(TRUE)
}

failed       <- character()
missing_page <- character()
unresolved   <- character()

for (ch in chapters) {
  slug <- anchor_of(ch)
  if (!file_exists(path("docs", paste0(slug, ".html")))) {
    missing_page <- c(missing_page, sprintf("%s -> %s.html", ch, slug))
  }

  ok <- tryCatch({ render_one(ch, slug, title_of(ch)); TRUE },
                 error = function(e) {
                   failed <<- c(failed, sprintf("%s: %s", ch, conditionMessage(e)))
                   FALSE
                 })
  if (!ok) next

  # A chapter whose own \\@ref() calls did not resolve is wrong invisibly: the
  # reader sees a bare "??" with no way to know what was meant. References into
  # other chapters legitimately show ?? in a single-chapter extract; references
  # within the chapter must not, and raw markup must never reach the page.
  src <- readLines(ch, warn = FALSE)
  own <- sub("^\\\\@ref\\(", "",
             sub("\\)$", "",
                 unlist(regmatches(src, gregexpr("\\\\@ref\\(([^)]+)\\)", src)))))
  local_ids <- sub("^\\{#", "", unlist(regmatches(src, gregexpr("\\{#[^} \t]+", src))))
  if (any(own %in% local_ids) && nzchar(Sys.which("pdftotext"))) {
    txt <- suppressWarnings(system2("pdftotext",
                                    c(path(out_dir, paste0(slug, ".pdf")), "-"),
                                    stdout = TRUE, stderr = FALSE))
    if (any(grepl("@ref\\(", txt))) {
      unresolved <- c(unresolved, sprintf("%s: raw \\@ref() reached the PDF", ch))
    }
  }
}

if (length(missing_page)) {
  cat("No HTML page matches these chapter anchors, so their download buttons\n",
      "would 404:\n", sep = "")
  cat(paste0("  - ", missing_page, "\n"), sep = "")
}
if (length(failed)) {
  cat("Failed to render:\n")
  cat(paste0("  - ", failed, "\n"), sep = "")
}
if (length(unresolved)) {
  cat("Cross-references did not resolve:\n")
  cat(paste0("  - ", unresolved, "\n"), sep = "")
}
if (length(missing_page) || length(failed) || length(unresolved)) quit(status = 1)

# Count what is on disk, not what was attempted.
n <- length(dir_ls(out_dir, glob = "*.pdf"))
if (n != length(chapters)) {
  cat("Expected ", length(chapters), " chapter PDFs, found ", n, ".\n", sep = "")
  quit(status = 1)
}
cat(n, " chapter PDFs written to ", out_dir, ".\n", sep = "")
