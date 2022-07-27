##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to load configurations for relevant PS confounders from file
## Date: May 2022
## Developers: Alexander Wood
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

import re
import warnings

import pandas as pd


def get_configs(df, configs, INDEX_ID, INDEX_IMPUTATION_ID, INDEX_IMPUTATION_FLAG, INDEX_COLUMNS, TARGET_COLUMNS, COVID_COLUMN_PATTERN, CONDITION_COLUMN_PATTERN, RUN_DEBUG = False):
    """Load configurations from file.

    This function takes the data configuration file and parses it to
    extract a dictionary of configurations for each column.

    The input data table (currently mab_pt_effect_imputed) is used
    only to cross-reference column names. Any modifications of
    the input data table should be performed in the next pipeline
    stage, as only the new configurations will persist past this pipeline stage.

    Input
    -----
    df -- [Pandas DataFrame]
        Load the full data table direct from file. This is used only
        for extrating column names; no changes made to this table will
        persist past this transform.

    configs -- [Pandas DataFrame]
        Load the configurations direct from file.

    Output
    ------
    configs -- [Pandas DataFrame]
        The configurations, loaded and formatted.
    """
    from transforms.global_utils import print_setup, print_list, get_report, display_dict

    # ########################################################################
    # QUALITY CONTROL                                                        #
    # ########################################################################
    # Verify that the data config file is up-to-date with the dataset.
    df_only_cols, configs_only_cols = [], configs['variable'].values.tolist()

    # Regex patterns
    # Initialize to False; may change below.
    use_condition, use_covid = False, False
    ssri_column_pattern = "ssri_[\w\d]+_prev90days"
    if ssri_column_pattern in configs_only_cols:
        configs_only_cols.remove(ssri_column_pattern)
    if CONDITION_COLUMN_PATTERN in configs_only_cols:
        use_condition = configs[configs['variable']==CONDITION_COLUMN_PATTERN]['ps'].values[0]
        configs_only_cols.remove(CONDITION_COLUMN_PATTERN)
    if COVID_COLUMN_PATTERN in configs_only_cols:
        use_covid = configs[configs['variable']==COVID_COLUMN_PATTERN]['ps'].values[0]
        configs_only_cols.remove(COVID_COLUMN_PATTERN)

    # Find columns only present in dataframe or only present in configs.
    for col in df.columns:
        if col in configs_only_cols:
            configs_only_cols.remove(col)
        elif re.fullmatch(CONDITION_COLUMN_PATTERN, col):
            # Regex pattern match
            continue
        elif re.fullmatch(COVID_COLUMN_PATTERN, col):
            # Regex pattern match
            continue
        elif re.fullmatch(ssri_column_pattern, col):
            continue
        else:
            df_only_cols.append(col)


    for col in df_only_cols:
        warnings.warn(f"Column {col} is present in dataframe but absent in configs.")

    for col in configs_only_cols:
        warnings.warn(f"Column {col} is present in configs but not present in dataframe.")


    # Limit to propensity score variables.
    configs = configs[configs.ps==1]

    # ########################################################################
    # SETUP CONFIGS FOR PS                                                   #
    # ########################################################################

    if RUN_DEBUG:
        print('Nubmer of rows in configs:', configs.shape)

    # Drop the drs and ps marker columns.
    configs = configs.drop(columns=['ps', 'drs'])

    # For output display in debug mode.
    unused_columns = []

    for column in df.columns:
        # There are two patterns of column names we are matching:
        #      condition_*_ps
        #      covid19_*_ps
        if use_condition and re.fullmatch(CONDITION_COLUMN_PATTERN, column):
            # Columns: "condition_[\w\d]+_vs"
            reference_row = configs[configs["variable"]==CONDITION_COLUMN_PATTERN]
        elif use_covid and re.fullmatch(COVID_COLUMN_PATTERN, column):
            # Columns: covid19_*_ps
            reference_row = configs[configs["variable"]==COVID_COLUMN_PATTERN]
        elif configs.loc[configs['variable']==column].shape[0]:
            # All other covariate columns.
            continue
        else:
            # Skip ahead to next column to skip this column
            # because it is not included in the PS model.
            unused_columns.append(column)
            continue

        new_row = {idx: val for idx, val in reference_row.squeeze().iteritems()}
        new_row['variable'] = column
        configs = configs.append(new_row, ignore_index=True)

    # Ensure that all index columns and target columns are present in the configs.
    missing_columns = [
        column for column in INDEX_COLUMNS if column not in configs['variable'].values
    ]
    assert len(missing_columns) == 0  , \
        f'Missing index columns {missing_columns}'

    missing_columns=[
        column for column in TARGET_COLUMNS if column not in configs['variable'].values
    ]
    assert len(missing_columns) == 0  , \
        f'Missing target columns {missing_columns}'

    # Drop the regex pattern rows.
    drop_cols = [CONDITION_COLUMN_PATTERN, COVID_COLUMN_PATTERN]
    configs = configs[configs['variable'].isin(drop_cols) == False]

    for c in configs['variable']:
        print(c)
    print('\n\n')

    # ########################################################################
    # DISPLAY FOR LOGS.                                                      #
    # ########################################################################
    # Display variable, dtype, transformer for each column.
    display_fields = ['variable', 'dtype', 'transformer']
    matrix = [[*config[display_fields]] for _, config in configs.iterrows()]
    fmt = print_setup(matrix)
    print(fmt)
    print(matrix)
    to_print = [fmt.format(*row) for row in matrix]
    to_print = ['| ' + ' | '.join(row) + ' |' for row in matrix]
    print("configs.shape =", configs.shape)
    print(
        '\n| Covariate columns | dtypes | transformers |\n|--|--|--|',
        '\n'.join(to_print), '-'*90,
    sep='\n')

    # Display the unused columns.
    print('\nInput dataframe columns dropped:')
    print_list(unused_columns, width=90)

    return configs
