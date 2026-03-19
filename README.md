# bank2budget

Utilities for converting bank statement exports into a consistent CSV format for budgeting workflows.

## Scripts

- `scripts/lloyds_csv_to_standard_csv.R`: Converts raw Lloyds CSV exports to a standard intermediate CSV format.
- `scripts/convert_single_bank_statement_to_new_format.R`: Converts standard intermediate CSV into the new normalized format used for analysis. (This will be eventually superseded)
- `scripts/firstbank_qif_to_standard_csv.py`: Converts FirstBank QIF exports directly into the normalized format.

## Tests

This repo uses `testthat` with end-to-end fixture-based tests under `tests/`.

Run all tests:

```r
Rscript -e "testthat::test_dir('tests/testthat', reporter='summary')"
```

Run one test file:

```r
Rscript -e "testthat::test_file('tests/testthat/test-firstbank-qif_end-to-end.R', reporter='summary')"
```

## Acknowledgements

GitHub Copilot was used as an AI coding assistant for the FirstBank conversion script and for setting up the test framework. 
