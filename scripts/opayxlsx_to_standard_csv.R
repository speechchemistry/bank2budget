#!/usr/bin/env Rscript

library(readr)
library(readxl)
suppressMessages(library(dplyr))
suppressMessages(library(lubridate))
library(argparser)

p <- arg_parser("This script takes an OPay statement spreadsheet and
produces a standard CSV file so it can be combined with other banks and
further processed.")
p <- add_argument(p, "opay_statement", help = "the original OPay statement file (.xlsx)")
p <- add_argument(
  p,
  "--exchange_rate_for_one_GBP",
  help = "exchange rate i.e. equivalent amount to one British pound",
  default = 1
)
argv <- parse_args(p)

parse_opay_amount <- function(x) {
  x |>
    #as.character() |>
    trimws() |>
    na_if("--") |>
    #na_if("") |>
    #na_if("NA") |>
    parse_number(locale = locale(grouping_mark = ",", decimal_mark = "."))
}

statement_file <- argv$opay_statement
raw <- read_excel(statement_file, col_names = FALSE)

header_row <- which(raw[[1]] == "Trans. Date")[1]
if (is.na(header_row)) {
  stop("Could not find transaction header row ('Trans. Date').")
}

header_values <- raw[header_row, ] |>
  unlist(use.names = FALSE) |>
  as.character()

transactions <- raw |>
  slice((header_row + 1):n())
colnames(transactions) <- header_values

transactions_clean <- transactions |>
  filter(!is.na(`Trans. Date`)) |>
  mutate(
    Day = day(dmy_hms(`Trans. Date`)),
    Month = month(dmy_hms(`Trans. Date`)),
    Year = year(dmy_hms(`Trans. Date`)),
    Account = "Opay",
    Transaction_type = as.character(Channel),
    Transaction_description = as.character(Description),
    Category = NA_character_,
    Debit_amount_raw = parse_opay_amount(`Debit(₦)`),
    Credit_amount_raw = parse_opay_amount(`Credit(₦)`),
    Debit_positive_amount_in_original_currency_numeric = if_else(
      !is.na(Debit_amount_raw),
      Debit_amount_raw,
      -Credit_amount_raw
    ),
    Exchange_rate_for_one_GBP = as.numeric(argv$exchange_rate_for_one_GBP),
    Debit_positive_amount_in_GBP = round(
      Debit_positive_amount_in_original_currency_numeric / Exchange_rate_for_one_GBP,
      2
    ),
    Debit_positive_amount_in_original_currency =
      Debit_positive_amount_in_original_currency_numeric,
    Comments = NA_character_,
    Original_statement_row_number = row_number()
  ) |>
  select(
    Day,
    Month,
    Year,
    Account,
    Transaction_type,
    Transaction_description,
    Category,
    Debit_positive_amount_in_GBP,
    Comments,
    Original_statement_row_number,
    Debit_positive_amount_in_original_currency,
    Exchange_rate_for_one_GBP
  )

cat(format_csv(transactions_clean, na = ""))
