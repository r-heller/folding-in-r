# Tests for the book's helper scripts in R/.
#
# There is no package here, so there is no library() call to load the code
# under test: helpers.R sources R/*.R the same way _common.R does, and
# testthat finds it because setup files are sourced before the tests run.
#
# Run from the repository root:  Rscript tests/testthat.R

library(testthat)
test_dir("tests/testthat", stop_on_failure = TRUE)
