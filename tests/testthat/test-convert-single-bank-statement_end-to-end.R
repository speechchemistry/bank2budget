test_that("convert_single_bank_statement_to_new_format end-to-end from file", {
  input <- "../data/convert_single_bank_statement_to_new_format/input/lloyds_old_standard.csv"
  expected <- readLines(
    "../data/convert_single_bank_statement_to_new_format/expected/lloyds_new_standard.csv"
  )

  result <- system2(
    "Rscript",
    args = c("../../scripts/convert_single_bank_statement_to_new_format.R", input),
    stdout = TRUE
  )

  expect_equal(result, expected)
})

test_that("convert_single_bank_statement_to_new_format end-to-end from stdin", {
  input <- "../data/convert_single_bank_statement_to_new_format/input/lloyds_old_standard.csv"
  expected <- readLines(
    "../data/convert_single_bank_statement_to_new_format/expected/lloyds_new_standard.csv"
  )

  result <- system2(
    "Rscript",
    args = c("../../scripts/convert_single_bank_statement_to_new_format.R", "-"),
    stdin = input,
    stdout = TRUE
  )

  expect_equal(result, expected)
})
