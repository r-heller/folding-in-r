#!/usr/bin/env Rscript
#
# Snapshot the project library, then put back the packages that are recorded
# deliberately without being installed.
#
# Use this instead of a bare renv::snapshot(). A plain snapshot records only
# what is installed, so it silently drops `torch` from the lockfile every time.
# torch is needed by Chapter 7 alone and pulls a large binary backend on first
# use, so it stays out of the working checkout while staying pinned for anyone
# who does install it.

DEFERRED <- c(torch = "0.17.0")

renv::snapshot(prompt = FALSE)

for (pkg in names(DEFERRED)) {
  renv::record(paste0(pkg, "@", DEFERRED[[pkg]]))
}

# renv::record() writes the full CRAN DESCRIPTION, including fields that are
# empty for this package; drop them so the entry matches the others in shape.
lock <- jsonlite::fromJSON("renv.lock", simplifyVector = FALSE)
for (pkg in names(DEFERRED)) {
  entry <- lock$Packages[[pkg]]
  lock$Packages[[pkg]] <- entry[!vapply(entry, is.null, logical(1))]
}
jsonlite::write_json(lock, "renv.lock", auto_unbox = TRUE, pretty = 2)

cat("Lockfile snapshotted; ", length(DEFERRED), " deferred package(s) re-recorded: ",
    paste(names(DEFERRED), collapse = ", "), ".\n", sep = "")
