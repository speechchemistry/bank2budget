# bank2budget

Utilities for converting bank statement exports into a consistent CSV format for budgeting workflows.

## Scripts

- `scripts/lloyds_csv_to_standard_csv.R`: Converts raw Lloyds CSV exports to the old intermediate CSV format.
- `scripts/convert_single_bank_statement_to_new_format.R`: Converts the old CSV format to the standard CSV format. (This script won't be needed once the lloyds script just uses the standard CSV format)
- `scripts/firstbank_qif_to_standard_csv.py`: Converts FirstBank QIF exports directly into the standard CSV format.
- `scripts/wuki_2025xlsx_to_standard_csv.R`: Converts WUKI 2025 monthly Excel statement into the standard CSV format.
- `scripts/opayxlsx_to_standard_csv.R`: Converts OPay Excel statement XLSX into the standard CSV format.

## Acknowledgements

GitHub Copilot was used as an AI coding assistant for the FirstBank conversion script and for setting up the test framework. 
