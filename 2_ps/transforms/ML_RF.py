##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to fit Random Forest candidate PS Models
## Date: May 2022
## Developers: Alexander Wood
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import ParameterGrid
from sklearn.metrics import (
    precision_recall_fscore_support,
    confusion_matrix)
import numpy as np
import warnings
from collections import namedtuple
from itertools import product

def ML_RF(df, INDEX_ID, INDEX_IMPUTATION_ID,  INDEX_COLUMNS, TARGET_COLUMNS, RUN_CHECKS = True, RUN_DEBUG = False):
    """Train Random Forest (RF) models.

    Trains the Random Forest models according to a hyperparameter
    grid search.

    Input
    -----
    preprocess_PropensityScore -- [Pandas DataFrame]
        The formatted and prepared data.

    Output
    ------
    [Pandas DataFrame]
        The dataframe with columns added for each trained model.
        Column names "model_rf_{}"
    """
    print('Training Random Forest Classifiers.')

    # ################################################### #
    # CREATE HYPERPARAMETER GRID                          #
    # ################################################### #
    # Create parameter grid of options
    #     class_weight=balanced_subsample gives an
    #     annoying error right now (warns that we
    #     shouldn't use  balanced option with warm
    #     start unless the dataset is the same -
    #     which it is!). sklearn doesn't let us disable warnings.
    #     So I turned it off.
    name_str = "model_rf_{}_{}"
    param_grid = ParameterGrid([
        {
            'warm_start': [True],
            'max_depth': [10],
            'min_samples_leaf': [1, 10],
            'oob_score': [True],
            'class_weight':[None],
            'max_samples': [0.5, 0.9]
        }
    ])
    num_estimators = [50]

    # Add columns for the rf models.
    param_grid_columns = [
        name_str.format(x[0], x[1]) for x in
        product(range(len(param_grid)), num_estimators)
    ]
    for col in param_grid_columns:
        df[col] = np.nan

    print("Number of RF models: {}".format(len(param_grid_columns)))

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
            print('max_depth,min_samples_leaf,class_weight,max_samples,n_estimators') #TODO

        # ############################################### #
        # MODEL TRAINING                                  #
        # ############################################### #
        for i in range(len(param_grid)):

            # Initialize model and set to current parameters.
            model = RandomForestClassifier(random_state=42)
            model.set_params(**param_grid[i])

            # Iterate over num_estimators hyperparam to utilize warm_start
            for num in num_estimators:
                col_name = name_str.format(i, num)

                # Set the number of estimators for this experiment.
                model.set_params(**{'n_estimators': num})

                # Print model description logs.
                if imputation_group == 1:
                    p = model.get_params()
                    print(f"{col_name},{p['max_depth']},{p['min_samples_leaf']},{p['class_weight']},{p['max_samples']},{p['n_estimators']}")
                else:
                    print("\tTraining model {}.".format(col_name))

                # Train, evaluate, and store results.
                model = model.fit(X,y)
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
    print("Num columns, dataframe shape:", len(param_grid_columns), df[param_grid_columns].shape)

    # Verify that every single value was calculated in the new columns.
    assert( df[param_grid_columns].isna().sum().sum() == 0 )

    return 1
