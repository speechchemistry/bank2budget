#!/usr/bin/env Rscript
library(readr)
library(tibble)
library(tidyr)
suppressMessages(library(dplyr))
library(argparser)

p <- arg_parser("This script takes a the original Lloyds Bank CSV file and 
produces a more standard CSV file so it can be combined with other banks and 
further processed. Note that you will probably get a warning saying that 9
columns were expected but only 8 were found. This is because the Lloyds 
online system adds an extra empty column.")
# Add a positional argument
p <- add_argument(p, "lloyds_csv_statement", 
                  help="the original Lloyds Bank CSV file")
# Add another positional argument
p <- add_argument(p, "--exchange_rate_for_one_GBP", 
                  help="exchange rate i.e. equivalent amount to one British pound", 
                  default=1)
argv <- parse_args(p)


# load in Lloyds statement
# we need to define account number as a string to make it compatible with other
# account numbers that contain characters
dat = read_csv(argv$lloyds_csv_statement, 
               col_types = cols("Account Number"=col_character()))
# you will get a warning about 9 columns expected with 8 actual because
# the lloyds spreadsheet adds an extra empty column

# process Lloyds statement
main_sheet <- add_column(dat, 
                         Category = NA, 
                         .after = "Transaction Description")
#main_sheet2 <- main_sheet %>% rename( Comments=X9 ) # this line works for readr older version e.g. 1
# this seems to be something to do with readr col_names behaviour which can both give 
# X1 X2 etc. as well as ...1 ...2 etc.
# https://readr.tidyverse.org/reference/read_delim.html
# ideally we'd have something that would work for both versions but for now I've just updated it
main_sheet2 <- main_sheet %>% rename( Comments=...9 ) # this line works for newer readr version e.g. 2
main_sheet3 <- add_column(main_sheet2, 
                          Debit_in_original_currency = NA, 
                          Credit_in_original_currency = NA, 
                          Exchange_rate_for_one_GBP = argv$exchange_rate_for_one_GBP, 
                          .after = "Comments")
main_sheet3$Debit_in_original_currency = main_sheet3$"Debit Amount"
main_sheet3$Credit_in_original_currency = main_sheet3$"Credit Amount"
main_sheet3$"Debit Amount" = NA
main_sheet3$"Credit Amount" = NA
main_sheet4 <- main_sheet3 %>% rename(Transaction_date="Transaction Date", 
                                      Transaction_type="Transaction Type", 
                                      Sort_code="Sort Code", 
                                      Account_number="Account Number", 
                                      Transaction_description="Transaction Description", 
                                      Debit_amount_in_GBP="Debit Amount", 
                                      Credit_amount_in_GBP="Credit Amount", 
                                      Balance_check_digits="Balance")
main_sheet5 <- mutate(main_sheet4,Sort_code="Lloyds")
#make numerical data consistent
tmb <- main_sheet5 %>% 
  replace_na(list(Credit_in_original_currency=0,Debit_in_original_currency=0))
# do currency conversions to GBP 
tmb$Debit_amount_in_GBP <- tmb$Debit_in_original_currency/tmb$Exchange_rate_for_one_GBP
tmb$Credit_amount_in_GBP <- tmb$Credit_in_original_currency/tmb$Exchange_rate_for_one_GBP

# print it out
cat(format_csv(tmb,na=""))