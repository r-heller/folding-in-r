#!/usr/bin/env Rscript
#
# VG Wort eligibility check.
#
# Counts characters in the rendered HTML body of each chapter, excluding code
# chunks and headings, and flags anything below the threshold as ineligible.
# The threshold here is 2500 characters -- deliberately stricter than VG Wort's
# own minimum, so a chapter that is merely borderline is not reported.
#
# Writes vgwort_pixels.csv with one row per chapter.

THRESHOLD <- 2500L

if (!dir.exists("docs")) {
  message("docs/ not found — render the book first.")
  quit(status = 0)
}

files <- list.files("docs", pattern = "\\.html$", full.names = TRUE)
files <- files[!grepl("404\\.html$", files)]

body_chars <- function(f) {
  x <- paste(readLines(f, warn = FALSE), collapse = "\n")

  # (?s) = dotall. Without it "." does not match a newline in R's regex engine,
  # the <main> extraction silently does nothing, and the sidebar navigation is
  # counted as chapter prose -- which made every stub look like 4000+
  # characters and pass a check it should fail.
  x <- sub("(?s)^.*?<main[^>]*>", "", x, perl = TRUE)
  x <- sub("(?s)</main>.*$", "", x, perl = TRUE)
  # Strip script and style blocks FIRST. after-body.html injects the theme
  # switcher and the sidebar part-divider script inside <main>; removing tags
  # without removing these first leaves their source as "prose" and inflates
  # every chapter by roughly 3500 characters -- enough to make an empty stub
  # look eligible.
  x <- gsub("(?s)<script.*?</script>", "", x, perl = TRUE)
  x <- gsub("(?s)<style.*?</style>", "", x, perl = TRUE)
  x <- gsub("(?s)<pre.*?</pre>", "", x, perl = TRUE)              # code chunks
  x <- gsub("(?s)<h[1-6][^>]*>.*?</h[1-6]>", "", x, perl = TRUE)  # headings
  x <- gsub("(?s)<[^>]+>", "", x, perl = TRUE)                    # other tags
  x <- gsub("&[a-z]+;", " ", x)
  nchar(trimws(gsub("\\s+", " ", x)))
}

existing <- if (file.exists("vgwort_pixels.csv")) {
  # colClasses forces character so that an empty pixel_url stays "" rather than
  # becoming NA, which would break the `missing` test below.
  utils::read.csv("vgwort_pixels.csv", stringsAsFactors = FALSE,
                  colClasses = "character", na.strings = NULL)
} else NULL

out <- do.call(rbind, lapply(files, function(f) {
  n <- body_chars(f)
  key <- basename(f)
  prev <- if (!is.null(existing)) existing[existing$chapter_file == key, ] else NULL
  data.frame(
    chapter_file  = key,
    pixel_id      = if (!is.null(prev) && nrow(prev)) prev$pixel_id else "",
    pixel_url     = if (!is.null(prev) && nrow(prev)) prev$pixel_url else "",
    assigned_date = if (!is.null(prev) && nrow(prev)) prev$assigned_date else "",
    char_count    = n,
    eligible      = n >= THRESHOLD,
    stringsAsFactors = FALSE
  )
}))

utils::write.csv(out, "vgwort_pixels.csv", row.names = FALSE)

cat("VG Wort eligibility — threshold ", THRESHOLD, " characters\n", sep = "")
cat("  eligible:   ", sum(out$eligible), "\n", sep = "")
cat("  too short:  ", sum(!out$eligible), "\n", sep = "")
missing <- out$eligible & out$pixel_url == ""
if (any(missing)) {
  cat("\nEligible chapters still without a pixel URL:\n")
  cat(paste0("  - ", out$chapter_file[missing], "\n"), sep = "")
  cat("Request these from the VG Wort T.O.M. portal and paste the URLs into\n",
      "vgwort_pixels.csv. Pixel URLs cannot be generated locally.\n", sep = "")
}
