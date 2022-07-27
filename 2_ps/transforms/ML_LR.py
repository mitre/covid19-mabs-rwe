##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to fit Logistic Regression candidate PS Models
## Date: May 2022
## Developers: Alexander Wood
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

from sklearn.linear_model import LogisticRegression
from sklearn.base import clone
from sklearn.model_selection import ParameterGrid
from sklearn.metrics import (
    precision_recall_fscore_support,
    confusion_matrix)
import numpy as np
import warnings

# UNCOMMENT TO SUPPRESS SCIKIT-LEARN CONVERGENCE WARNINGS
# Do not uncomment unless you're really, really, really sure you want to.
# The warnings are important.
# Debug purposes only.
#@ignore_warnings(category=ConvergenceWarning)
def ML_LR(df, INDEX_ID, INDEX_IMPUTATION_ID,  INDEX_COLUMNS, TARGET_COLUMNS, RUN_CHECKS = True, RUN_DEBUG = False):
    """Train logistic regression (LR) models.

    Trains the logistic regression models according to a hyperparameter grid search.

    Input
    -----
    df -- [Pandas DataFrame]
        The formatted and prepared data.

    Output
    ------
    [Pandas DataFrame]
        The dataframe with columns added for each trained model.
        Column names "model_lr_{}"
    """
    # ################################################### #
    # CREATE HYPERPARAMETER GRID                          #
    # ################################################### #
    # This is the reduced hyperparameter grid.
    name_str = "model_lr_{}"
    param_grid = ParameterGrid([
        {
            'penalty': ['l1','l2'],        # l1=lasso, l2=ridge
            'C': [0.01, 0.1],
            'solver':['saga'],
            'max_iter': [500],
            'class_weight': ['balanced']
        }
    ])

    # Add the columns for the LR models' outputs.
    param_grid_columns = [name_str.format(i) for i in range(len(param_grid))]
    for col in param_grid_columns:
        df[col] = np.nan

    print("Number of LR models: {}".format(len(param_grid_columns)))

    # Get names of features for model training.
    cols = df.columns
    model_columns = cols[cols.str.contains('model_')].tolist()
    feature_columns = [
        col for col in df.columns
        if col not in (INDEX_COLUMNS + TARGET_COLUMNS + model_columns)
    ]

    if RUN_DEBUG:
        print(f'*\tDataframe shape: {df.shape}')
        print(f'*\tNumber of LR models: {len(param_grid_columns)}')

    # ################################################### #
    # TRAIN MODELS FOR EACH IMPUTATION GROUP              #
    # ################################################### #
    num_imputation_groups = df[INDEX_IMPUTATION_ID].nunique()

    # An array to store which models have failed a convergence test.
    convergence_fails = {col: 0 for col in model_columns}

    # An array to store the trained models so that we can extract the
    # summary from the ones that end up best-performing.
    trained_models = {col: [] for col in model_columns}

    model_gbl = LogisticRegression(random_state=2022)
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
            print('model,penalty,c,solver,class_weight')

        # ############################################### #
        # TRAIN EACH MODEL.                               #
        # ############################################### #
        for i in range(len(param_grid)):
            col_name = name_str.format(i)

            # If this model has already failed to converge
            # on a previous imputation group, skip.
            if convergence_fails[col_name]:
                continue

            # Create the model.
            model = clone(model_gbl)
            model.set_params(**param_grid[i])

            # Print model description logs.
            if imputation_group == 1:
                p = model.get_params()
                print(f"{col_name},{p['penalty']},{p['C']},{p['solver']},{p['class_weight']}")
            else:
                print("\tTraining model {}.".format(col_name))

            # Train the model. Train while catching warnings
            # in order to determine when convergence
            # has failed.
            with warnings.catch_warnings(record=True) as w:
                warnings.simplefilter("always")
                model = model.fit(X, y)

                # Predict & save if the model converged.
                if len(w) and issubclass(w[-1].category, ConvergenceWarning):
                    # Flag the model as one that has failed a convergence test
                    # and do not train this model again on future imputation
                    # groups.
                    convergence_fails[col_name] = 1
                    print(f'Convergence failed: {col_name}')

                    # Delete any saved copies of this model.
                    del trained_models[col_name]
                else:
                    # Predict.
                    y_pred = model.predict_proba(X)

                    # Store the trained model.
                    trained_models[col_name].append(model)

                    # Save the predicted values on the corresponding dataframe slice.
                    df.loc[df[INDEX_IMPUTATION_ID]==imputation_group, col_name] = y_pred[:,-1]

    # ################################################### #
    # REMOVE CONVERGENCE FAILURES                         #
    # ################################################### #
    col_fails = [c for c in convergence_fails.keys() if convergence_fails[c]]
    num_fail = sum(convergence_fails.values())
    num_pass = len(convergence_fails) - num_fail
    print(f"{num_fail} of {num_fail+num_pass} models failed to converge.")
    print('\n\t'.join(col_fails))

    # Remove the columns
    df = df.drop(columns=col_fails)
    param_grid_columns = [col for col in param_grid_columns if not convergence_fails[col]]

    # ################################################### #
    # Run optional checks.                                #
    if RUN_CHECKS:
        run_sanity_checks(df, param_grid_columns)

    # Want to save only the index columns and model output.
    # (Saves a lot of storage space.)
    columns_out = [INDEX_ID, INDEX_IMPUTATION_ID] + TARGET_COLUMNS
    columns_out +=  [col for col in df.columns if col[:8]==name_str[:8]]
    df = df[columns_out]

    return df


# ############################################################################# #
# OPTIONAL CHECKS                                                               #
# ############################################################################# #
def run_sanity_checks(df, param_grid_columns):
    """Optional sanity checks.

    Verify that no dataframe columns contain null values. To enable,
    set RUN_CHECKS=TRUE in the global code.

    Input
    -----
    df -- [pandas dataframe or pyspark dataframe]
        The dataframe with trained LR model columns included.
    param_grid_columns -- [iterable]
        The columns containing the trained LR model outputs.

    Output
    ------
    [bool]
        Returns 1 if all checks pass.
    """
    print(
        "\n\nNumber of models trained: {}".format(len(param_grid_columns)),
        "\n\nShape of dataframe: {}".format(df.shape),
        "\n\nMean of all predicted values per model:\n{}".format(df[param_grid_columns].mean()),
        "\n\nStdev of all predicted values per model:\n{}".format(df[param_grid_columns].std()),
    )

    # Verify that every single value was calculated in the new columns.
    # Assertion fails when all models have null output.
    assert( df[param_grid_columns].isna().sum().sum() == 0 )
    return 1
