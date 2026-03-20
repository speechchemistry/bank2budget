#!/usr/bin/env Rscript

library(readr)
library(tibble)
library(tidyr)
suppressMessages(library(dplyr))
suppressMessages(library(lubridate))
library(readxl)
library(stringr)

suppressMessages(library(janitor))
library(argparser)

p <- arg_parser("This script takes the WUKI 2025 version 
monthly statement excel file and produces a more standard CSV file so it
 can be combined with other banks and further processed.")
p <- add_argument(p, "WUKI_excel_statement", 
                  help="the WUKI 2025 excel file")
p <- add_argument(p, "--donor_list", 
                  help="the TSV file extending the WUKI donor table with short names and categories",
                  default="../donors.tsv")
p <- add_argument(p, "--exchange_rate_for_one_GBP", 
                  help="exchange rate i.e. equivalent amount to one British pound", 
                  default=1)
argv <- parse_args(p)

exchange_rate_for_one_GBP = argv$exchange_rate_for_one_GBP
wuki_excel_file = argv$WUKI_excel_statement
donor_tsv_file = argv$donor_list
assessment_proportion = 0.08 # 0.08 is equivalent to 8% WUKI assessment
# charge (changed in 2022 from 10%)

# Load in donor list
donors <- read_tsv(donor_tsv_file) |>
  clean_names() |>
  # select only donor_name and name_in_statement columns
  select(donor_name, name_in_statement, category)   


donations_raw <- read_excel(wuki_excel_file,
                        sheet="Donations",skip=8, 
                        col_types = c("date", "text", "numeric", "text", "text", "text"))|>
  filter(!is.na(Date)) |> # remove non valid rows
  clean_names() 

# calculate total assessment on regular uk donations
assessment_on_regular_uk_donations <- donations_raw |>
  filter(!is.na(donor_uk_gifts_only)) |>
  summarise(total = sum(amount)) |> 
  pull(total) * assessment_proportion

# find the date of the last donation (used as a dummy value for the assessment charge)
last_donation_date <- donations_raw |>
  summarise(latest_date = max(date, na.rm = TRUE)) %>%
  pull(latest_date)

donations <- donations_raw |>
  # rename the amount column to amount_in_gbp_pre_assessment
  rename(amount_in_gbp_pre_assessment = amount) |>
  # rename donor_uk_gifts_only
  rename(donor_name = donor_uk_gifts_only)


# join the donor names into the donations table
donations_and_short_name <- donations |>
  left_join(donors, by = c("donor_name")) |>
  # remove the date column
  select(-date)

# load in xlsx version of wuki account 
account_statement <- read_excel(wuki_excel_file,
                                sheet="Member Account Statement",skip=13, col_types = c("date", "numeric", "text", "text", "text", "text")) |>
  select(!starts_with("...")) |> # remove the blank columns
  filter(!is.na(Date)) |> # remove non valid rows
  clean_names() |>
  mutate(original_row_number = row_number()) |>
  # add a new column "Amount (£) before assessment" which reverses out the assessment charge
  mutate(amount_in_gbp_pre_assessment = round(amount / (1 - assessment_proportion),2)) |>
  # add a new column "name_in_statement" which is a cleaned up version of the Description column; i.e. removed any " -GA" suffix
  mutate(name_in_statement = str_replace(description, " -GA$", ""))


# add in an extra identifier to ensure there is a way to define each transaction uniquely
account_statement_prepped <- account_statement |>
  arrange(reference, amount_in_gbp_pre_assessment, name_in_statement) |>
  group_by(reference, amount_in_gbp_pre_assessment, name_in_statement) |>
  mutate(transaction_seq = row_number()) |> 
  ungroup() |>
  arrange(original_row_number)

donations_prepped <- donations_and_short_name |>
  arrange(reference, amount_in_gbp_pre_assessment, name_in_statement) |>
  group_by(reference, amount_in_gbp_pre_assessment, name_in_statement) |>
  mutate(transaction_seq = row_number()) |>
  ungroup()

account_statement_extended <- account_statement_prepped |>
  left_join(donations_prepped, by = c("reference","amount_in_gbp_pre_assessment","name_in_statement","transaction_seq"))

# Add the new columns
with_new_columns <- account_statement_extended  |>
    # Fix the date format so that it's got separate columns for day, month, and year
    mutate(
        Day = day(date),
        Month = month(date),
        Year = year(date)
    ) |>
    mutate(Account = "WUKI household") |>
    # Rename columns to standard names
    rename(Transaction_type = reference) |>
    rename(Transaction_description = description) |>
    rename(Category = category) |>
    # if it isn't a donation the amount should be the original
    # if it is the donation, the amount should be the pre assessment amount 
    mutate(Debit_positive_amount_in_original_currency = 
             if_else(is.na(donor_name),-amount,-amount_in_gbp_pre_assessment)) |>
    mutate(Exchange_rate_for_one_GBP = exchange_rate_for_one_GBP) |>
    mutate(Debit_positive_amount_in_GBP = 
             Debit_positive_amount_in_original_currency/Exchange_rate_for_one_GBP) |>
    mutate(Comments = paste0(replace_na(donor_name,""),replace_na(gift_note,""))) |>
    mutate(Original_statement_row_number = original_row_number)

statement_for_output <- with_new_columns |>
    select(Day, Month, Year, Account, Transaction_type, Transaction_description, Category,Debit_positive_amount_in_GBP, Comments, Original_statement_row_number, 
        Debit_positive_amount_in_original_currency, Exchange_rate_for_one_GBP)

# Extract total assessment from summary statement
assessment_row <- read_excel(wuki_excel_file,sheet="Summary Fund Statement",skip=8) |>
  clean_names() |>
  filter(account_name=="Total Assessment")
published_assessment_amount <- 0-pull(assessment_row,amount)
amount_that_published_is_above_calculated <- published_assessment_amount - assessment_on_regular_uk_donations
# alert if published assessment is a pound higher or lower than the calculated assessment
if (amount_that_published_is_above_calculated > 1) {
  message("Warning: Published assessment is higher than calculated amount. (Output will use published assessment.)")
  message("Amount higher = ",amount_that_published_is_above_calculated)
  message("This could be assessment on declared gifts of = ",amount_that_published_is_above_calculated/assessment_proportion)
  } else if (amount_that_published_is_above_calculated < -1) {
  message("Warning: Published assessment is lower than calculated amount. This is unusual. (Output will use published assessment.)")
  message("Amount lower = ",-amount_that_published_is_above_calculated)
  }

assessment_charged_dummy_row <-
  tibble(Day=day(last_donation_date),
         Month=month(last_donation_date),
         Year=year(last_donation_date),
         Account = "WUKI household",
         Transaction_type = NA,
         Transaction_description=assessment_row$account_name,
         Category = NA,
         Debit_positive_amount_in_GBP = -assessment_row$amount*exchange_rate_for_one_GBP,
         Comments="Date corresponds to last credit of month",
         # Below could be Original_statement_row_number = max_row_number + 1. 
         # I'm sure if NA is going to cause problems elsewhere
         Original_statement_row_number=NA, 
         Debit_positive_amount_in_original_currency=-assessment_row$amount,
         Exchange_rate_for_one_GBP = exchange_rate_for_one_GBP)

statement_for_output_with_assessment_row <- bind_rows(statement_for_output,assessment_charged_dummy_row)

# print it out
cat(format_csv(statement_for_output_with_assessment_row,na=""))