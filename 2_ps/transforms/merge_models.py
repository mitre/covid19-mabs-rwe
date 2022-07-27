##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to combine outputs from all candidate models fit
## Date: May 2022
## Developers: Alexander Wood
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

import pandas as pd

def merge_models(df_lr, df_gbt, df_rf, INDEX_ID, INDEX_IMPUTATION_ID, RUN_CHECKS = True, RUN_DEBUG = False):
    """Merge all trained model results in a single DataFrame.

    Input
    -----


    Output
    ------
    [dataset] - The index columns and all trained model columns.
    """

    # Merge all dataframes into one dataframe.
    df = merge(df_lr, df_gbt, INDEX_ID, INDEX_IMPUTATION_ID, RUN_CHECKS, RUN_DEBUG)
    df = merge(df, df_rf, INDEX_ID, INDEX_IMPUTATION_ID, RUN_CHECKS, RUN_DEBUG)

    if RUN_DEBUG:
        print_duplicate_columns(df.columns)

    if RUN_CHECKS:
        assert len(df.columns) == len(set(df.columns)) , "Duplicate columns not allowed."

    return df


def run_sanity_checks(df, df_lr, df_gbt, df_rf):
    # Make sure row count remains exactly the same.
    print(
        "Dataframe rows:",
        "\tOutput: {}".format(df.shape[0]),
        "\tInput ML_LR:  {}".format( df_lr.shape[0]),
        "\tInput ML_GBT: {}".format(df_gbt.shape[0]),
        "\tInput ML_RF:  {}".format( df_rf.shape[0]),
        sep='\n'
    )
    assert df.shape[0] == df_lr.shape[0]  , "Output dataframe row count does not match DF_LR row count."
    assert df.shape[0] == df_gbt.shape[0] , "Output dataframe row count does not match DF_GBT row count."
    assert df.shape[0] == df_rf.shape[0]  , "Output dataframe row count does not match DF_RF row count."

    # Make sure each person_id still occurs exaclty five times,
    # because there are exactly five imputation groups.
    col_person, col_imp_grp = INDEX_COLUMNS[-1], INDEX_COLUMNS[0]
    num_unique_subj = df[col_person].nunique()
    correct_person_counts = sum( df['person_id'].value_counts() == NUM_IMPUTATION_GROUPS )
    print("\nThere are {}/{} person_id values that occur {} times.".format(
        correct_person_counts, num_unique_subj, NUM_IMPUTATION_GROUPS
    ))

    imputation_counts = df[col_imp_grp].nunique()
    print(f"There are {imputation_counts} imputation groups present.")
    assert imputation_counts == NUM_IMPUTATION_GROUPS , "Check imputation groups."

    # Make sure that the number of columns in the output
    # dataframe contains each column, and that we didn't
    # duplicate any columns during joins.


def recover_person_id(df):
    """
    Take the Pandas DataFrame index, which is set to person_id, and
    turn it into a column. Return as a Spark DataFrame.
    :input: Pandas DataFrame
    :output: Spark DataFrame
    """
    df = df.reset_index().rename(columns={'index': 'person_id'})
    df = spark.createDataFrame(df)

    return df


def merge(df1, df2, INDEX_ID, INDEX_IMPUTATION_ID, RUN_CHECKS=True, RUN_DEBUG=False):
    """
    Merge two dataframes via an inner join on person_id and imputation group.
    Remove all non-model columns.
    """
    # Get all columns from df2 that are not included in df1.
    # These are the columns we want to add.
    join_columns = [INDEX_ID, INDEX_IMPUTATION_ID]
    result_columns = [c for c in df2.columns if c not in df1.columns]
    result_columns = join_columns + result_columns

    print(result_columns)
    if RUN_DEBUG:
        print(result_columns)
        n = df2['person_id'].nunique()
        n_add = df2['person_id'].nunique()
        print(f'*\t{n} unique person_id in df2')
        print(f'*\t{n_add} unique person_ids in df2')
        n_common = sum([1 for val in df1['person_id'].tolist() if val in df2['person_id'].tolist()])
        print(f'*\t{n_common} person_ids appear in both')

    if isinstance(df1, pd.DataFrame):
        # In Pandas, use "merge" to join if you are not joining on the index.
        df = df1.merge(df2[result_columns], on=join_columns)
    else:
        # PySpark dataframe case.
        df = df1.join(df2.select(*result_columns), join_columns)

    if RUN_DEBUG:
        print('\n*\tAfter merge:')
        print(df1[INDEX_IMPUTATION_ID].value_counts())
        n = df1[INDEX_ID].nunique()
        print(f'*\t{n} unique person_id in df')

    if RUN_CHECKS:
        pass

    return df


def print_duplicate_columns(columns):
    if len(columns) == len(set(columns)):
        print("All columns are unique.")

        return 1

    used, remains = [], len(columns)
    print('Duplicate columns:')
    for col in columns:
        if col in used:
            print(f'*\t{col}')
        else:
            used.append(col)
            remains -= 1

    print(f"There are {len(columns)} unique columns and {remains} duplicate columns.")
