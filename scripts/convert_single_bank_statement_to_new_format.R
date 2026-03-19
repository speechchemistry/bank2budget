#!/usr/bin/env Rscript

library(readr)
library(argparser)
suppressMessages(library(dplyr))
library(tidyr)

p <- arg_parser("This script takes a the original bank statement CSV standard file and 
produces the new standard CSV file that includes for example, separate columns 
for day, month, and year. It also has a single column that includes debits and 
credits (debits are positive)")
# Add a positional argument
p <- add_argument(p, "original_statement_format.csv", 
                  help="the original CSV standard bank statement file or use '-' for stdin")
argv <- parse_args(p)

# Read from stdin or file based on input argument
if (argv$original_statement_format.csv == "-") {
  # Read from stdin
  input_file <- file("stdin")
} else {
  # Read from the specified file
  input_file <- argv$original_statement_format.csv
}

# Read the input CSV file
# interpret all columns as strings except for the Debit_amount_in_GBP, Credit_amount_in_GBP, Debit_in_original_currency, and Credit_in_original_currency columns
input_data <- read_csv(input_file, col_types = cols(
    Debit_amount_in_GBP = col_double(),
    Credit_amount_in_GBP = col_double(),
    Debit_in_original_currency = col_double(),
    Credit_in_original_currency = col_double(),
    .default = col_character()
))

# Add the new columns
with_new_columns <- input_data |>
    # Fix the date format so that it's got separate columns for day, month, and year
    separate(Transaction_date, into = c("Day", "Month", "Year"), sep = "/") |>
    mutate(
        Day = as.integer(Day),
        Month = as.integer(Month),
        Year = as.integer(Year)
    ) |>
    # Create the Debit_positive_amount_in_GBP column
    mutate(Debit_positive_amount_in_GBP = ifelse(Debit_amount_in_GBP > 0, Debit_amount_in_GBP, -Credit_amount_in_GBP)) |>
    # Create a row number column
    mutate(Original_statement_row_number = row_number()) |>
    # Create a Debit_positive_amount_in_original_currency column
    mutate(Debit_positive_amount_in_original_currency = ifelse(
        Debit_in_original_currency > 0, 
        Debit_in_original_currency, 
        -Credit_in_original_currency
    )) |>
    # Rename Sort_code to Account
    rename(Account = Sort_code)

# Now re-order the columns
output_data <- with_new_columns |>
    select(
        Day, Month, Year, Account, 
        Transaction_type, Transaction_description, Category, 
        Debit_positive_amount_in_GBP, Comments, Original_statement_row_number, 
        Debit_positive_amount_in_original_currency, Exchange_rate_for_one_GBP
    )

# Write the processed data to standard output
# All "NA" values should be empty strings
cat(format_csv(output_data,na=""))
