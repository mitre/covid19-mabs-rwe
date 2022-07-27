##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to parse and preprocess necessary columns for fitting PS candidate models
## Date: May 2022
## Developers: Alexander Wood
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

import re
import warnings
import pandas as pd
from string import punctuation

def get_dataframe(df, configs, RUN_DEBUG = False):
    """DataFrame formattting
    Input
    -----
    df -- [PySpark DataFrame]
        Load the full data table direct from file.

    configs -- [Pandas DataFrame]
        The configurations for data handling.

    Output
    ------
    [Pandas DataFrame]
        The dataframe, set up according to config
    """

    # ########################################################################## #
    # If you get an error here, there is a mis-match between columns in the
    # input dataset and the columns defined in the global code.
    df = df[configs['variable'].tolist()]

    # Now, we want to reformat column names. Replace blank space with dash
    # and remove all capitalization.
    df.columns = df.columns.str.replace(' ', '-').str.lower()

    str_out = "Dataframe shape after removing excess " + \
                "columns: {}".format(df.shape)
    print(str_out)

    # Make sure column formats satisfy necessary conditions.
    df = format_numeric(df, configs)
    df = format_onehot(df, configs)
    df = format_bool(df, configs)

    # Should be a redundant check.
    if RUN_DEBUG:
        print('\nNull count by column:')
        for col in df.columns:
            print('*', col, df[col].isna().sum(), sep='\t')
    return df


# ########################################################################## #
#                           FORMAT BOOLEAN COLUMNS                           #
# ########################################################################## #
def format_bool(df, configs, RUN_DEBUG = False):
    """Format Boolean columns.

    Make sure that all boolean columns are cast as numeric types with
    all values equal to either zero or one. If values are not already
    zero and one, cast them according to the bool_0 and bool_1 config
    specifications.

    Input
    ----
    df -- [Pandas DataFrame]
        Full input dataframe
    configs -- [Pandas DataFrame]
        Configurations

    Output
    ------
    df -- [Pandas DataFrame]
        Input dataframe with Boolean columns formatted.
    """
    for _, row in configs[configs['dtype']=='bool'].iterrows():
        variable = row.variable

        ############### Make sure we have no null values. ###################
        # Null values would make Boolean encoding not possible.
        assert df[variable].isna().sum() == 0 , \
            f'Failed Check: Null values in Boolean column {variable}.'

        ############# Verify column has 1 or 2 unique values ################
        # First, make sure there are only two unique values
        # present in this column. (Or just one, if everyone
        # has the same value in the column.)
        assert df[variable].nunique() in [1, 2] , \
            f"Failed Check: The Boolean variable {variable} takes on " + \
            "than two possible values."

        ################## Map column values to -1 and 1 #####################
        # Now, the values should be 0 and 1.
        # For columns where the are not, map
        # them according to the specifications
        # in the bool_* config columns
        if RUN_DEBUG:
            str_out = f'*\tUnique values in column {variable} ' + \
                      f'before mapping:{df[variable].unique()}'
            print(str_out)

        bool0, bool1 = row.bool_0, row.bool_1
        if bool0 or bool1:
            # Include maps for 0 and 1 in case either
            # bool_0=None or bool_1=None
            df[variable] = df[variable].map({
                bool0: 0.0,
                bool1: 1.0,
                0:     0.0,
                1:     1.0
            })

        if RUN_DEBUG:
            str_out = f'*\tUnique values in column {variable} ' + \
                      f'after mapping:{df[variable].unique()}'
            print(str_out)

        ################ Make sure column dtype is numeric #################
        # Note that is_numeric_dtype(bool) evaluates to True
        assert pd.api.types.is_numeric_dtype(df[variable]) , \
            f"Failed Check: The Boolean variable {variable} must be " + \
            "numeric."

        ############## Make sure every value is either 0 or 1 ###############
        # Redundant check.
        assert df[variable].isin([0, 1]).all() , \
            f"Failed Check: The Boolean variable {variable} " +\
            "contains non-Boolean values."

        ############## Make sure there are no missing values ################
        null_count = df[variable].isna().sum()
        assert df[variable].isna().sum() == 0 , \
            f"Failed check: The Boolean variable {variable} " +\
            f"contains {null_count} missing values."

    return df


# ########################################################################## #
#                      FORMAT ONEHOT/OBJECT COLUMNS                          #
# ########################################################################## #
def format_onehot(df, configs):
    """Format categorical columns.

    Make sure that all categorical columns are cast as object types.
    Replace all null values with the "unknown" category.

    Input
    ----
    df -- [Pandas DataFrame]
        Full input dataframe
    configs -- [Pandas DataFrame]
        Configurations

    Output
    ------
    df -- [Pandas DataFrame]
        Input dataframe with Categorical columns formatted.
    """
    for _, row in configs[configs['dtype']=='object'].iterrows():
        variable = row.variable

        ################### Map Null/None Values #########################
        # If we want to replace None with some value, then replace it.
        # Then, verify there are no empty values in the column.
        null_count = df[variable].isna().sum()
        map_null = configs[configs['variable']==variable]['map_null'].values[0]
        if (null_count > 0) and map_null:
            warnings.warn(f"Total of {null_count} nulls in {variable} column cast as unknown.")
            df[variable] = df[variable].fillna(value=map_null)

        ############## Format strings for one-hot encoding. #############
        # Remove white space or invalid characters e.g. []{}&%!@
        # so that the one-hot encoder creates valid column names

        # Make sure dtype is string.
        df[variable] = df[variable].astype(str)

        # Special characters in our case are the regular set of
        # special characters, minus the underscore.
        special_chars = punctuation.replace('_', '')
        df[variable] = df[variable].replace('[^\w\s_-]', '', regex=True)

        # Replace whitespace with dash.
        df[variable] = df[variable].replace(' ', '-')

        # Replace underscore with dash
        df[variable] = df[variable].replace('_', '')

        # Enforce lower case.
        df[variable] = df[variable].str.lower()

        ############## Make sure no missing values remain ###############
        null_count = df[variable].isna().sum()
        assert df[variable].isna().sum() == 0 , \
            f"Failed check: The categorical variable {variable} " +\
            f"contains {null_count} missing values."

    ################# Cast columns as "object" dtype #####################
    # Now, cast this column to have type 'object'.
    # The column *must* have type 'object' in order
    # to be one-hot encoded in the next pipeline stage.
    columns = configs[configs['dtype']=='object']['variable'].values.tolist()
    map_dict = {column: 'object' for column in columns}
    df = df.astype(map_dict)

    return df


# ########################################################################## #
#                           FORMAT NUMERIC COLUMNS                           #
# ########################################################################## #
def format_numeric(df, configs):
    """Format NUMERIC columns.

    Make sure that all numeric columns are cast as numeric types. Missing values
    are mean-imputed and a warning message is displayed.

    Future option: Enforce data ranges restrictions? #TODO

    Input
    ----
    df -- [Pandas DataFrame]
        Full input dataframe
    configs -- [Pandas DataFrame]
        Configurations

    Output
    ------
    df -- [Pandas DataFrame]
        Input dataframe with Numeric columns formatted.
    """

    cond = (configs['dtype']=='int') | (configs['dtype']=='float')
    for _, row in configs[cond].iterrows():
        variable = row.variable

        ################### Map Null/None Values #############################
        # If we want to replace None with some value, then replace it.
        # Then, verify there are no empty values in the column.

        # Find number of null values and check if we wish to map null values.
        null_count = df[variable].isna().sum()
        map_null = configs[configs['variable']==variable]['map_null'].values[0]

        # If mean imputation is used, a warning displays that null values are
        # being replaced.
        if (null_count > 0):# and map_null:
            warnings.warn(f"Total of {null_count} nulls in {variable} column mean imputed.")
            temp_mean_impute = df[variable].mean()
            df[variable] = df[variable].fillna(value=temp_mean_impute)

        ############## Make sure there are no missing values ################
        null_count = df[variable].isna().sum()
        assert df[variable].isna().sum() == 0 , \
            f"Failed check: The Numeric variable {variable} " +\
            f"contains {null_count} missing values."

        ################ Make sure column dtype is numeric #################
        # Note that is_numeric_dtype(bool) evaluates to True
        assert pd.api.types.is_numeric_dtype(df[variable])

    return df
