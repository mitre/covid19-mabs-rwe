##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to fit Gradient-Boosted Tree candidate PS Models
## Date: May 2022
## Developers: Alexander Wood
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

from sklearn.ensemble import GradientBoostingClassifier

import re
import warnings

import pandas as pd
import numpy as np

from collections import namedtuple
from itertools import product

from sklearn.base import clone
from sklearn.model_selection import ParameterGrid
from sklearn.metrics import (
    precision_recall_fscore_support,
    confusion_matrix
)


def ML_GBT(df, INDEX_ID, INDEX_IMPUTATION_ID,  INDEX_COLUMNS, TARGET_COLUMNS, RUN_CHECKS = True, RUN_DEBUG = False):
    """Train Gradient-Boosting Tree (GBT) models.

    Trains the Gradient-Boosting Decision Tree models according to a
    hyperparameter grid search.

    Input
    -----
    preprocess_PropensityScore -- [Pandas DataFrame]
        The formatted and prepared data.

    Output
    ------
    [Pandas DataFrame]
        The dataframe with columns added for each trained model.
        Column names "model_gbt_{}"
    """

    # ################################################### #
    # CREATE HYPERPARAMETER GRID                          #
    # ################################################### #
    name_str = "model_gbt_{}"
    param_grid = ParameterGrid([
        {
            'learning_rate': [0.01],
            'subsample': [0.1, 0.5],      # reduce variance, increase bias
            'max_features': [0.5],        # reduce bias, increase variance
            'max_depth': [3],
            'n_estimators': [250],
            'n_iter_no_change': [25],     # Early stopping after 25 iterations w/o change.
            'validation_fraction': [0.1], # Validation fraction for early stopping.
            'tol': [1e-3],
        },
        {
            'learning_rate': [0.1],
            'subsample': [0.5, 1.0],         # reduce variance, increase bias
            'max_features': [1.0],      # reduce bias, increase variance
            'max_depth': [5],
            'n_estimators': [250],
            'n_iter_no_change': [25],     # Early stopping after 25 iterations w/o change.
            'validation_fraction': [0.1], # Validation fraction for early stopping.
            'tol': [1e-3],
        }
    ])

    # Add the columns for the gbt models.
    param_grid_columns = [
        name_str.format(x[0]) for x
        in product(range(len(param_grid)))
    ]
    for col in param_grid_columns:
        df[col] = np.nan

    print("Number of GBT models: {}".format(len(param_grid_columns)))

    # Get names of features for model training.
    cols = df.columns
    model_columns = cols[cols.str.contains('model_')].tolist()
    feature_columns = [
        col for col in df.columns
        if col not in (INDEX_COLUMNS + TARGET_COLUMNS + model_columns)
    ]

    if RUN_DEBUG:
        print(f'Number of columns in training data set: {len(param_grid_columns)}')

    # ################################################### #
    # TRAIN MODELS.                                       #
    # ################################################### #
    # Iterate for each imputation group.
    num_imputation_groups = df[INDEX_IMPUTATION_ID].nunique()

    for imputation_group in range(1, num_imputation_groups + 1):
        print("Begin training, imputation Group {}".format(imputation_group))

        # ############################################### #
        # SELECT DATA WITHIN IMP. GROUP                   #
        # ############################################### #
        # NOTE: Must explicitly cast as numpy arrays.
        # Must set types to avoid errors due to conversion from Pandas "object" type.
        X = df.loc[df[INDEX_IMPUTATION_ID]==imputation_group, feature_columns]\
              .to_numpy(dtype=np.float64)
        y = df.loc[df[INDEX_IMPUTATION_ID]==imputation_group, TARGET_COLUMNS]\
              .to_numpy(dtype=np.uint8)\
              .ravel()

        # Display header row for model parameter log
        if imputation_group==1:
            print('\nlearning_rate,subsample,max_features,max_depth,n_estimators')
        else:
            print('\n')
        # ############################################### #
        # MODEL TRAINING                                  #
        # ############################################### #
        for i in range(len(param_grid)):
            col_name = name_str.format(i)

            # Create the model.
            model = GradientBoostingClassifier(random_state=2022)
            model.set_params(**param_grid[i])

            # Print model description logs.
            if imputation_group == 1:
                p = model.get_params()
                print(f"{col_name},{p['learning_rate']},{p['subsample']},{p['max_features']},{p['max_depth']},{p['n_estimators']}")
            else:
                print("\tTraining model {}.".format(col_name))

            # Model training.
            model = model.fit(X,y)  # Continues training since warm start is true
            predictions = model.predict_proba(X)

            # Save predictions in main dataframe.
            df.loc[df[INDEX_IMPUTATION_ID]==imputation_group, col_name] = predictions[:,-1]

    if RUN_CHECKS:
        run_sanity_checks(df, param_grid_columns)

    columns_out = [INDEX_ID, INDEX_IMPUTATION_ID] + TARGET_COLUMNS
    columns_out +=  [col for col in df.columns if col[:9]==name_str[:9]]
    df = df[columns_out]

    return df


# ############################################################################# #
# OPTIONAL CHECKS                                                               #
# ############################################################################# #
def run_sanity_checks(df, param_grid_columns):
    """Optional sanity checks.

    Verify that no dataframe columns contain null values. To enable,
    set RUN_CHECKS=TRUE in the global code.

    :input:
        df -- [pandas dataframe or pyspark dataframe]

    :output:
        [bool]
            Returns 1 if all checks pass.
    """
    print(f"Dataframe info after new params\nShape: {df.shape}\nColumns: {df.columns}")
    print('Mean:', df[param_grid_columns].mean())
    print('Stdev:', df[param_grid_columns].std())
    print('Any null in predictions:', df[param_grid_columns].isna().sum())

    print(len(param_grid_columns), df[param_grid_columns].shape)

    # Verify that every single value was calculated in the new columns.
    assert( df[param_grid_columns].isna().sum().sum() == 0 )

    return 1
