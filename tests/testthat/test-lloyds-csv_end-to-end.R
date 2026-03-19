test_that("lloyds raw CSV to new-format CSV end-to-end pipeline", {
  input <- "../data/lloyds_to_new_format_pipeline/input/sample_lloyds_statement.csv"
  expected <- readLines(
    "../data/lloyds_to_new_format_pipeline/expected/sample_new_format.csv"
  )

  intermediate <- system2(
    "Rscript",
    args = c(
      "../../scripts/lloyds_csv_to_standard_csv.R",
      "--exchange_rate_for_one_GBP",
      "1",
      input
    ),
    stdout = TRUE
  )

  intermediate_path <- tempfile(fileext = ".csv")
  writeLines(intermediate, intermediate_path)

  result <- system2(
    "Rscript",
    args = c("../../scripts/convert_single_bank_statement_to_new_format.R", intermediate_path),
    stdout = TRUE
  )

  expect_equal(result, expected)
})
