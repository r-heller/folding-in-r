#!/usr/bin/env Rscript
#
# Assert that the rendered PDF and EPUB are complete.
#
# The point is to catch a TRUNCATED artefact, which is as bad as a missing one
# and much harder to notice: the render workflow used to tolerate a failed EPUB
# or PDF step and deploy anyway, with download links pointing at whatever was
# left on disk.
#
# The first version of this check used a byte floor, and that was the wrong
# instrument. It failed the first green build in this repository's history --
# a 107 kB PDF and a 67 kB EPUB, both perfectly complete, both correct sizes
# for a book that is still twelve chapter stubs. A floor tuned to a finished
# book rejects an unfinished one, and a floor tuned to an unfinished book stops
# meaning anything once the chapters land.
#
# Completeness is structural, so it is checked structurally, and the test does
# not need retuning as the book grows:
#
#   PDF   -- parses, ends with %%EOF, and has at least one page per chapter.
#   EPUB  -- is a valid zip whose central directory is intact, and holds at
#            least one content document per chapter.
#
# A small absolute floor stays as a backstop against a zero-length file that
# somehow parses.
#
# Usage:  Rscript scripts/check-render-artefacts.R [dir]

args <- commandArgs(trailingOnly = TRUE)
dir  <- if (length(args)) args[[1]] else "docs"

cfg <- yaml::read_yaml("_bookdown.yml")
# Part files produce no page of their own; index.Rmd does.
n_chapters <- sum(!grepl("^part-", cfg$rmd_files))

pdf  <- file.path(dir, paste0(cfg$book_filename, ".pdf"))
epub <- file.path(dir, paste0(cfg$book_filename, ".epub"))

problems <- character(0)
note <- function(...) problems[[length(problems) + 1L]] <<- paste0(...)

have <- function(tool) nzchar(Sys.which(tool))

check_pdf <- function(f) {
  if (!file.exists(f)) return(note(f, " was not produced"))
  size <- file.info(f)$size
  if (size < 10000) return(note(f, " is ", size, " bytes -- not a book"))

  # Byte-level, not string-level. A PDF is full of embedded nuls and
  # rawToChar() refuses them, so the markers are matched as raw sequences.
  con <- file(f, "rb"); on.exit(close(con))
  if (!identical(readBin(con, "raw", 5L), charToRaw("%PDF-"))) {
    return(note(f, " does not begin with %PDF-"))
  }

  tail_n <- min(2048L, size)
  seek(con, where = size - tail_n)
  tail_raw <- readBin(con, "raw", tail_n)
  eof <- charToRaw("%%EOF")
  found <- any(vapply(seq_len(length(tail_raw) - length(eof) + 1L),
                      function(i) identical(tail_raw[i:(i + length(eof) - 1L)], eof),
                      logical(1)))
  if (!found) return(note(f, " has no %%EOF marker -- the file is truncated"))

  if (!have("pdfinfo")) {
    return(note("pdfinfo is not installed, so the page count could not be ",
                "checked. Install poppler-utils; this check is the one that ",
                "catches a PDF that parses but stops early."))
  }
  info  <- system2("pdfinfo", f, stdout = TRUE, stderr = FALSE)
  pages <- suppressWarnings(as.integer(trimws(sub("^Pages:\\s*", "",
             grep("^Pages:", info, value = TRUE)[1]))))
  if (is.na(pages)) return(note(f, " -- pdfinfo reported no page count"))
  if (pages < n_chapters) {
    note(f, " has ", pages, " pages for ", n_chapters,
         " chapters -- the render stopped early")
  } else {
    cat(f, ": ", pages, " pages, %%EOF present (", size, " bytes)\n", sep = "")
  }
}

check_epub <- function(f) {
  if (!file.exists(f)) return(note(f, " was not produced"))
  size <- file.info(f)$size
  if (size < 5000) return(note(f, " is ", size, " bytes -- not a book"))

  if (!have("unzip")) return(note("unzip is not installed; cannot verify ", f))
  ok <- system2("unzip", c("-t", shQuote(f)), stdout = FALSE, stderr = FALSE)
  if (ok != 0L) return(note(f, " fails a zip integrity test -- truncated"))

  entries <- system2("unzip", c("-Z1", shQuote(f)), stdout = TRUE, stderr = FALSE)
  docs <- grep("\\.x?html$", entries, value = TRUE)
  if (length(docs) < n_chapters) {
    note(f, " holds ", length(docs), " content documents for ", n_chapters,
         " chapters -- the render stopped early")
  } else {
    cat(f, ": ", length(docs), " content documents, zip intact (", size,
        " bytes)\n", sep = "")
  }
}

cat("Expecting at least ", n_chapters, " chapters.\n", sep = "")
check_pdf(pdf)
check_epub(epub)

if (length(problems)) {
  cat("\n")
  for (p in problems) cat("::error::", p, "\n", sep = "")
  quit(status = 1)
}
cat("both artefacts are complete.\n")
