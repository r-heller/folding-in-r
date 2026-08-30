#!/usr/bin/env Rscript
#
# Every colour pair the book renders text on, in both themes, against WCAG AA.
#
# Standing rule 3 says no result is encoded by colour alone, and the book takes
# accessibility seriously enough to have a dark mode and a merged colour +
# linetype legend. It shipped a dark mode in which the search dropdown rendered
# at **1.40:1** and the comment colour in a code block at **1.90:1** -- both
# unreadable, both invisible to anyone developing in light mode, and neither
# detectable by any check the repository had.
#
# The failure is structural rather than careless: `style/style.css` recolours the
# page through custom properties, and the two surfaces it missed are ones
# bs4_book paints with literals. A token system hides exactly the places it does
# not cover.
#
# So the pairs are enumerated here and computed. Base R only, no CSS parser: the
# pairs are declared, and the declaration is checked against the stylesheet so a
# colour cannot be changed in one place and left here.
#
# Usage:  Rscript scripts/check-contrast.R

CSS <- "style/style.css"
AA        <- 4.5      # WCAG AA, body text
AA_LARGE  <- 3.0      # WCAG AA, large text and non-text contrast

# ── WCAG relative luminance and contrast ────────────────────────────────────

.srgb <- function(hex) {
  hex <- sub("^#", "", hex)
  if (nchar(hex) == 3L) hex <- paste(rep(strsplit(hex, "")[[1]], each = 2L), collapse = "")
  as.integer(as.hexmode(substring(hex, c(1, 3, 5), c(2, 4, 6)))) / 255
}

luminance <- function(hex) {
  c <- .srgb(hex)
  lin <- ifelse(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055)^2.4)
  sum(c(0.2126, 0.7152, 0.0722) * lin)
}

contrast <- function(fg, bg) {
  l <- sort(c(luminance(fg), luminance(bg)), decreasing = TRUE)
  (l[1] + 0.05) / (l[2] + 0.05)
}

# ── The pairs ───────────────────────────────────────────────────────────────
#
# fg / bg / the minimum this pair has to clear / where it appears.

LIGHT_BG   <- "#fafafa"   # --background-color
LIGHT_CODE <- "#f5f5f5"   # --code-bg
DARK_BG    <- "#212121"
DARK_CODE  <- "#2a2a2a"   # --bg-box and --code-bg
DARK_SEL   <- "#1e3a5f"   # the selected search suggestion

PAIRS <- rbind(
  data.frame(fg = "#212121", bg = LIGHT_BG,   min = AA,       where = "light: body text"),
  data.frame(fg = "#1565c0", bg = LIGHT_BG,   min = AA,       where = "light: links"),
  data.frame(fg = "#666666", bg = LIGHT_BG,   min = AA,       where = "light: muted text"),
  data.frame(fg = "#212121", bg = LIGHT_CODE, min = AA,       where = "light: code"),

  data.frame(fg = "#dadada", bg = DARK_BG,    min = AA,       where = "dark: body text"),
  data.frame(fg = "#42a5f5", bg = DARK_BG,    min = AA,       where = "dark: links"),
  data.frame(fg = "#cfcfcf", bg = DARK_BG,    min = AA,       where = "dark: muted text"),
  data.frame(fg = "#dadada", bg = DARK_CODE,  min = AA,       where = "dark: code"),

  # The two surfaces that shipped broken.
  data.frame(fg = "#dadada", bg = DARK_CODE,  min = AA,       where = "dark: search dropdown text"),
  data.frame(fg = "#dadada", bg = DARK_SEL,   min = AA,       where = "dark: selected suggestion"),
  data.frame(fg = "#cfcfcf", bg = DARK_CODE,  min = AA_LARGE, where = "dark: search hint"),

  data.frame(fg = "#d4d0ab", bg = DARK_CODE,  min = AA,       where = "dark: comments"),
  data.frame(fg = "#00e0e0", bg = DARK_CODE,  min = AA,       where = "dark: keywords"),
  data.frame(fg = "#abe338", bg = DARK_CODE,  min = AA,       where = "dark: strings"),
  data.frame(fg = "#f5ab35", bg = DARK_CODE,  min = AA,       where = "dark: numbers"),
  data.frame(fg = "#ffd700", bg = DARK_CODE,  min = AA,       where = "dark: data types"),
  data.frame(fg = "#dcc6e0", bg = DARK_CODE,  min = AA,       where = "dark: functions"),
  data.frame(fg = "#ffa07a", bg = DARK_CODE,  min = AA,       where = "dark: constants")
)

# ── Every colour named here must actually be in the stylesheet ──────────────
#
# Otherwise this file drifts into a description of a stylesheet that no longer
# exists, and reports a green result about colours nobody renders.

css <- if (file.exists(CSS)) paste(readLines(CSS, warn = FALSE), collapse = "\n") else ""
missing <- unique(c(PAIRS$fg, PAIRS$bg))
missing <- missing[!vapply(missing, function(h) grepl(h, css, fixed = TRUE), logical(1))]

cat("contrast, WCAG 2.1 relative luminance\n\n")
PAIRS$ratio <- round(mapply(contrast, PAIRS$fg, PAIRS$bg), 2)
PAIRS$ok <- PAIRS$ratio >= PAIRS$min
print(PAIRS[, c("where", "fg", "bg", "ratio", "min", "ok")], row.names = FALSE)

fails <- PAIRS[!PAIRS$ok, ]
problems <- character(0)
if (nrow(fails)) {
  problems <- c(problems, sprintf("%s: %s on %s is %.2f:1, below %.1f:1",
                                  fails$where, fails$fg, fails$bg, fails$ratio, fails$min))
}
if (length(missing)) {
  problems <- c(problems, sprintf(
    "colour %s is checked here and appears nowhere in %s -- this file is describing a stylesheet that does not exist",
    missing, CSS))
}

if (length(problems)) {
  cat("\nFAILED:\n")
  for (p in problems) cat("  * ", p, "\n", sep = "")
  quit(status = 1L)
}

cat("\nall ", nrow(PAIRS), " pairs clear WCAG AA in both themes.\n", sep = "")
