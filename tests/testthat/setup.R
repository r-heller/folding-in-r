# Put the helper scripts on the search path, exactly as _common.R does.
#
# testthat runs with the working directory set to tests/testthat, so the
# repository root is two levels up. Resolved once here rather than in each test
# file, and asserted rather than assumed -- a silently empty R/ would make
# every test pass by testing nothing.

BOOK_ROOT <- normalizePath(file.path("..", ".."), mustWork = TRUE)

helpers <- sort(list.files(file.path(BOOK_ROOT, "R"), pattern = "\\.R$",
                           full.names = TRUE))
if (!length(helpers)) {
  stop("R/ holds no scripts -- nothing to test. ",
       "If that is genuinely the state of the tree, delete these tests too.")
}
for (f in helpers) source(f)
