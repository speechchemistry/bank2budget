# This script converts the firstbank.qif file (Quicken Interchange Format) into a standardized CSV file

# import quiffen library
from quiffen import Qif
import csv
import os
import argparse
from decimal import Decimal, InvalidOperation

# import pandas
import pandas as pd 


def convert_qif_to_standard_csv(qif_path: str, exchange_rate_for_one_GBP: float | None = None) -> pd.DataFrame:
    """Parse a QIF file and return a standardized DataFrame and write CSV.

    Parameters
    ----------
    qif_path : str
        Path to the input .qif file.
    exchange_rate_for_one_GBP : float | None
        Optional exchange rate (NGN per 1 GBP). If provided, an `Amount_GBP`
        column will be added (amount divided by the rate).
    """
    # Parse the QIF file using quiffen (day-first dates)
    qif_data = Qif.parse(qif_path, day_first=True)

    # Convert to DataFrame using the library helper
    df = qif_data.to_dataframe()

    # start creating a new dataframe with standardized columns
    new_df = pd.DataFrame()
    parsed = pd.to_datetime(df['date'], errors='coerce')
    new_df['Day'] = parsed.dt.day
    new_df['Month'] = parsed.dt.month
    new_df['Year'] = parsed.dt.year
    # add column "Account" that should always be "Firstbank Naira"
    new_df['Account'] = 'Firstbank Naira'
    # add column "Transaction_type" that should be "DR" if a debit and "CR" if a credit
    new_df['Transaction_type'] = df['amount'].apply(lambda x: 'CR' if x > 0 else 'DR')
    # add column "Transaction_description" that is the same as "Memo" column but with the final "Ref"
    # string removed. Ref and everything after it should be removed if there is at most 1 space after "Ref"
    # if there are more than 1 space after "Ref" then it should be kept
    new_df['Transaction_description'] = df['memo'].str.replace(r'Ref.+\s?', '', regex=True)


    #new_df['Transaction_description'] = df['memo'].str.replace(r'\s+Ref\d+$', '', regex=True)
    # add column "Debit_positive_amount_in_original_currency" that is just negative Amount
    new_df['Debit_positive_amount_in_original_currency'] = -df['amount']
    # add column "Exchange_rate_for_one_GBP" that is the same as the input parameter
    new_df['Exchange_rate_for_one_GBP'] = exchange_rate_for_one_GBP
    # insert an empty column "Category"
    new_df['Category'] = ''
 
    # add a new column "Debit_positive_amount_in_GBP"
    # and is calculated as Debit_positive_amount_in_original_currency divided by exchange_rate_for_one_GBP
    # round to 2 decimal places and place it after the column "Category"
    if exchange_rate_for_one_GBP is not None:
        new_df['Debit_positive_amount_in_GBP'] = (
            new_df['Debit_positive_amount_in_original_currency'] / exchange_rate_for_one_GBP
        ).round(2)
    else:
        new_df['Debit_positive_amount_in_GBP'] = ''
    
    # add new column "Comments" that is empty
    new_df['Comments'] = ''
    # reverse the order of the rows
    new_df = new_df.iloc[::-1].reset_index(drop=True)
    # add a new column "Original_statement_row_number"
    new_df['Original_statement_row_number'] = new_df.index + 1
    # Resort the columns in the following order:
    # Day, Month, Year, Account, Transaction_type, Transaction_description, Category,
    # Debit_positive_amount_in_GBP, Comments,Original_statement_row_number, 
    # Debit_positive_amount_in_original_currency, Exchange_rate_for_one_GBP
    new_df = new_df[
        [
            'Day',
            'Month',
            'Year',
            'Account',
            'Transaction_type',
            'Transaction_description',
            'Category',
            'Debit_positive_amount_in_GBP',
            'Comments',
            'Original_statement_row_number',
            'Debit_positive_amount_in_original_currency',
            'Exchange_rate_for_one_GBP',
        ]
    ] 
    # Format the Debit column so values like 10.0 become '10' in CSV output
    def _fmt_number_remove_trailing_zero(v):
        if pd.isna(v):
            return ''
        try:
            # Use Decimal to avoid float artifacts and remove trailing zeros
            d = Decimal(str(v)).normalize()
            # format with 'f' to avoid scientific notation
            return format(d, 'f')
        except (InvalidOperation, ValueError):
            return str(v)

    new_df['Debit_positive_amount_in_original_currency'] = (
        new_df['Debit_positive_amount_in_original_currency'].apply(_fmt_number_remove_trailing_zero)
    )

    return new_df


def main() -> None:
    parser = argparse.ArgumentParser(description='Convert a QIF file to a standardized CSV')
    parser.add_argument('--exchange_rate_for_one_GBP', type=int, default=1,
                        help='exchange rate (integer NGN per 1 GBP)')
    parser.add_argument('qif_path', help='the original FirstBank QIF file')
    args = parser.parse_args()

    df = convert_qif_to_standard_csv(args.qif_path, args.exchange_rate_for_one_GBP)
    # print out the dataframe as CSV to stdout
    print(df.to_csv(index=False),end='')

if __name__ == '__main__':
    main()