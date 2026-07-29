suppressPackageStartupMessages({
  library(rmarkdown)
  library(fs)
})

chapters <- dir_ls(".", recurse = TRUE, glob = "*.Rmd")
chapters <- chapters[
  !path_file(chapters) %in% c("index.Rmd", "00-impressum.Rmd",
                              "00-acknowledgments.Rmd", "95-colophon.Rmd") &
    !grepl("^_part-", path_file(chapters))
]

out_dir <- "docs/pdf-chapters"
dir_create(out_dir)

for (ch in chapters) {
  out_file <- path_ext_set(path_file(ch), "pdf")
  tryCatch({
    rmarkdown::render(
      input         = ch,
      output_format = "pdf_document",
      output_file   = out_file,
      output_dir    = out_dir,
      envir         = new.env(),
      quiet         = TRUE
    )
  }, error = function(e) {
    message("Failed to render ", ch, ": ", conditionMessage(e))
  })
}
