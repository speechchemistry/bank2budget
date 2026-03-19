test_that("firstbank_qif_to_standard_csv end-to-end", {
  python_cmd <- Sys.getenv("BANK2BUDGET_PYTHON", unset = Sys.which("python3"))
  skip_if(python_cmd == "", "python3 not found")

  dep_check <- suppressWarnings(system2(
    python_cmd,
    c("../../scripts/firstbank_qif_to_standard_csv.py", "--help"),
    stdout = TRUE,
    stderr = TRUE
  ))
  dep_status <- attr(dep_check, "status")
  skip_if(
    !is.null(dep_status) && dep_status != 0,
    paste(
      "Python dependencies missing (need quiffen and pandas):",
      paste(dep_check, collapse = "\n")
    )
  )

  input <- "../data/firstbank_qif_to_standard_csv/input/firstbank_statement.qif"
  expected <- readLines(
    "../data/firstbank_qif_to_standard_csv/expected/firstbank_new_standard.csv"
  )

  result <- system2(
    python_cmd,
    args = c(
      "../../scripts/firstbank_qif_to_standard_csv.py",
      "--exchange_rate_for_one_GBP",
      "1840",
      input
    ),
    stdout = TRUE
  )

  expect_equal(result, expected)
})
