test_that("opay XLSX to standard CSV end-to-end", {
  input <- "../data/opayxlsx_to_standard_csv/input/sample_opay_statement.xlsx"
  expected <- readLines(
    "../data/opayxlsx_to_standard_csv/expected/opay_standard.csv"
  )

  result <- system2(
    "Rscript",
    args = c(
      "../../scripts/opayxlsx_to_standard_csv.R",
      "--exchange_rate_for_one_GBP",
      "1920",
      input
    ),
    stdout = TRUE
  )

  expect_equal(result, expected)
})
