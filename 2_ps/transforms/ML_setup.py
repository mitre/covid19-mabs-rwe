##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to set up data for model training, including One-Hot Encoding and Standardization
## Date: May 2022
## Developers: Alexander Wood
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

import numpy as np
import pandas as pd

def ML_setup(df, configs, INDEX_IMPUTATION_ID, RUN_CHECKS = True, RUN_DEBUG = False):
    """Set up data for model training.

    Accepts as input the IMPUTED dataframe, possibly with multiple imputation.
    The column INDEX_IMPUTATION_ID provides the multiple imputation group number.

    This function performs preprocessing for the Propensity Score. Preprocessing includes:
        * Convert to Pandas dataframe
        * Calibration split
        * Data cleaning
        * Feature construction
        * Setup output

    Input
    -----
    df -- [Pandas dataframe]
        The starting table.
    configs -- [Pandas DataFrame]
        Configurations file.

    Output
    ------
    [Pandas dataframe]
        Result of applying preprocessing to input table.
    """
    from sklearn.compose import make_column_transformer, ColumnTransformer
    from sklearn.preprocessing import StandardScaler, FunctionTransformer, OneHotEncoder
    import numpy as np

    # ################################################### #
    # DEFINE PREPROCESSING TRANSFORMERS                   #
    # ################################################### #

    # ONE-HOT
    # These are the onehot columns where we use all variables.
    onehot_columns = (
        configs.loc[(configs['transformer']=='onehot') & (configs['onehot_baseline'].isna())]\
               .loc[:,'variable']\
               .values\
               .tolist()
    )
    onehot_transformer = OneHotEncoder(sparse=False)

    # ONE-HOT DUMMIES
    # These are the onehot columns where we use dummies, or remove
    # some "baseline" column.
    dummy_columns = (
        configs.loc[(configs['transformer']=='onehot') & ~(configs['onehot_baseline'].isna())]\
            .loc[:,'variable']\
            .values\
            .tolist()
    )
    dummy_drop_values = (
        configs.loc[(configs['transformer']=='onehot') & ~(configs['onehot_baseline'].isna())]\
               .loc[:,'onehot_baseline']\
               .values\
               .tolist()
    )
    dummy_transformer = OneHotEncoder(
        sparse=False,
        drop=dummy_drop_values
    )

    # NUMERIC - ACROSS ALL SYSTEMS
    # Numeric features; to be normalized.
    numeric_columns = (
        configs[configs['transformer']=='numeric']
        .loc[:,'variable']
        .values
        .tolist()
    )
    numeric_transformer = StandardScaler()

    # NUMERIC - BY HEALTH SYSTEM
    # Numeric features to be normalized intra-health system rather than across
    # all health systems in order to account for differences in how each system
    # reports the data.
    stratified_columns = (
        configs[configs['transformer']=='numeric_intra_hs']
        .loc[:,'variable']
        .values
        .tolist()
    )
    stratified_columns.append('health_system')
    stratified_transformer = StratifiedScaler(stratifier='health_system')

    # INDEX PASSTHROUGH
    # Index features; passed through.
    passthrough_columns = (
        configs[configs['transformer']=='passthrough']
        .loc[:,'variable']
        .values
        .tolist()
    )
    passthrough_transformer = PassthroughTransformer()

    if RUN_CHECKS:
        print("Passthrough columns:", passthrough_columns)
        print("Numeric columns:", numeric_columns)
        print("Stratified numeric columns:", stratified_columns)
        print("Onehot columns:", onehot_columns)
        print("Dummy columns:", dummy_columns)

    # The combined transformer pipeline.
    column_transformer = ColumnTransformer(
        [
            ("passthrough", passthrough_transformer, passthrough_columns),
            ("numeric", numeric_transformer, numeric_columns),
            ("stratified", stratified_transformer, stratified_columns),
            ("onehot", onehot_transformer, onehot_columns),
            ("dummy", dummy_transformer, dummy_columns)
        ]
    )

    # ################################################### #
    # FIT THE PREPROCESSING TRANSFORMERS                  #
    # ################################################### #
    transformers, transformed_dataframes = [], []
    num_imputation_groups = df[INDEX_IMPUTATION_ID].nunique()
    for imputation_group in range(1, num_imputation_groups + 1):
        # Imputation group sub-dataframe.
        df2 = df[df[INDEX_IMPUTATION_ID] == imputation_group]

        # Fit column transformer. (note: each call to fit() re-fits)
        transformer = column_transformer.fit(df2)
        transformer.feature_names_out = get_feature_names_out(transformer)
        df2 = pd.DataFrame(
            transformer.transform(df2),
            columns=transformer.feature_names_out
        )

        # Merge into output dataframe.
        transformed_dataframes.append(df2)

        # Persist the fit column transformer.
        transformers.append(transformer)

        if RUN_DEBUG:
            str_debug = "*\tImputation group {} added, df2.shape={}"
            print(str_debug.format(imputation_group, df2.shape))

    # Merge the transformed dataframes.
    df_out = transformed_dataframes[0]
    for addl_df in transformed_dataframes[1:]:
        df_out = pd.concat([df_out, addl_df], ignore_index=True)

    # Now, we want to reformat column names. Replace blank space with dash
    # and remove all capitalization.
    df_out.columns = df_out.columns.str.replace(' ', '-').str.lower()

    return df_out


# ############################################################################# #
# OPTIONAL CHECKS                                                               #
# ############################################################################# #
def null_check(df):
    """Optional sanity checks.

    Verify that no dataframe columns contain null values. To enable,
    set RUN_CHECKS=TRUE in the global code.

    :input:
        df -- [pandas dataframe or pyspark dataframe]

    :output:
        [bool]
            Returns 1 if all checks pass.
    """

    # Calculate the number of null values in each column.
    if isinstance(df, DataFrame) or isinstance(df, RDD):
        # Case: df is a PySpark DataFrame or RDD.
        num_null = df.select(
                [F.count(F.when(F.isnan(c), c)).alias(c) for c in df.columns]
            ).toPandas()

    elif isinstance(df, pd.DataFrame):
        # Case: Pandas!
        num_null = df.isna().sum(axis=1).to_frame().transpose()
    else:
        raise TypeError("Input must be Spark or Pandas DataFrame.")

    print(f"Input dataframe column count: {num_null.shape[-1]}")

    # Check for null values in the COVARIATE_COLUMNS.
    print("\nColumns with null values:")
    cols = []
    for col in num_null.columns:
        tmp = num_null.loc[0, col]
        if tmp:
            print(f'\t{col}', tmp, sep='\t')

            # Store information if a covariate column has missing values
            # for the assertion error message below.
            if col in COVARIATE_COLUMNS:
                cols.append(col)

    assert len(cols) == 0, "Null value(s) found in covariate columns: {}".format(cols)

    print('\nNo null values found in covariate columns.\n')
    return 1


# ################################################################################# #
#                Custom numeric transformer, intra-health syste                     #
# ################################################################################# #
from sklearn.base import TransformerMixin, BaseEstimator

class StratifiedScaler(BaseEstimator, TransformerMixin):
    """Intra- for sklearn ColumnTransformer pipeline.

    This is a transformer that we use in a ColumnTransformer for the
    columns we do not want to change.    (index & target columns.)

    Additional methods provided for compatibility purposes.

    Note: this won't be compatible in future versions of sklearn (after 1.2).

    :attributes (edited):
        feature_names_out -- [array-like of str]

    :methods (edited):
        fit(X, y=None)
            fit the passthrough transformer by storing the
            names of passthrough columns. y=None for convention
            only.
    """
    def __init__(self, stratifier=None, with_mean=True, with_std=True):
        self.stratifier = stratifier
        self.with_mean = with_mean
        self.with_std = with_std

    def fit(self, X, y=None):
        """Compute the mean and std to be used for later scaling.
        Parameters
        ----------
        X : {array-like, sparse matrix} of shape (n_samples, n_features)
            The data used to compute the mean and standard deviation
            used for later scaling along the features axis.
        y : None
            Ignored.
        Returns
        -------
        self : object
            Fitted scaler.
        """
        assert isinstance(X, pd.DataFrame) , "Input must be a pandas DataFrame"

        print("ABCD")
        self.feature_names_in = np.asarray(
            [str(column) for column in X.columns],
            dtype=object
        ).tolist()
        self.feature_names_in.remove(self.stratifier)
        print('feature names in\n', self.feature_names_in)

        self.categories = X[self.stratifier].unique().tolist()
        print('categories', self.categories)
        self.means_ = X.groupby(self.stratifier).mean() 
        self.stds_ = X.groupby(self.stratifier).std() 
        self.feature_names_out = self.feature_names_in

        print('means:', self.means_)
        print('stds:', self.stds_)

        return self

    def transform(self, X):
        """Transform X using the forward function.
        Parameters
        ----------
        X : array-like, shape (n_samples, n_features)
            Input array.
        Returns
        -------
        X_out : array-like, shape (n_samples, n_features)
            Transformed input.
        """
        print(X.columns)
        for category in self.categories:
            print('transforming category:', category)
            mask = X[self.stratifier]==category
            print('mask shape', mask.shape)

            # Subtract mean.
            X.loc[mask, self.feature_names_out] = \
                X.loc[mask, self.feature_names_out] \
                - self.means_.loc[category, self.feature_names_out]

            # Divide by variance
            X.loc[mask, self.feature_names_out] = \
                X.loc[mask, self.feature_names_out] \
                / self.stds_.loc[category, self.feature_names_out]

        print(type(X), X.shape, X[self.feature_names_out].shape)

        return X[self.feature_names_out]

    def get_feature_names(self, input_features=None):
        return np.array(self.feature_names_out)


# ################################################################################# #
#                       Custom passthrough transformer                              #
# ################################################################################# #
class PassthroughTransformer(BaseEstimator, TransformerMixin):
    """Passthrough transformer for sklearn ColumnTransformer pipeline.

    This is a transformer that we use in a ColumnTransformer for the
    columns we do not want to change.    (index & target columns.)

    Additional methods provided for compatibility purposes.

    Note: this won't be compatible in future versions of sklearn (after 1.2).

    :attributes:
        feature_names_out -- [array-like of str]

    :methods:
        fit(X, y=None)
            fit the passthrough transformer by storing the
            names of passthrough columns. y=None for convention
            only.

        transform(X)
            "transforms" the dataframe (returns input)

        fit_transform(X, y=None)
            calls .fit().transform()

        get_feature_names(input_features=None)
            Returns the feature names. input_features unused; provided
            for compatibility with sklearn API.

    """
    def __init__(self, **kwargs):
        super().__init__()
        self.feature_names_out = None

    def fit(self, X, y=None):
        """Fit transformer by storing column names from X.

        Parameters
        ----------
        X : array-like, shape (n_samples, n_features)
            Input array.
        y : Ignored
            Not used, present here for API consistency by convention.

        Returns
        -------
        self : object
            FunctionTransformer class instance.
        """
        self.feature_names_in = np.asarray(
            [str(column) for column in X.columns],
            dtype=object
        )
        self.feature_names_out = self.get_feature_names()
        self.fitted_ = True  # to pass check_is_fitted

        return self

    def transform(self, X):
        """Transform X using the forward function.
        Parameters
        ----------
        X : array-like, shape (n_samples, n_features)
            Input array.
        Returns
        -------
        X_out : array-like, shape (n_samples, n_features)
            Transformed input.
        """
        return X

    def fit_transform(self, X, y=None):
        """Fit to data, then transform it.

        Fits transformer to `X` and `y` and returns a transformed version
        of `X`.

        Parameters
        ----------
        X : array-like of shape (n_samples, n_features)
            Input samples.
        y :  array-like of shape (n_samples,) or (n_samples, n_outputs), \
                default=None
            Target values (None for unsupervised transformations).

        Returns
        -------
        X_new : ndarray array of shape (n_samples, n_features_new)
            Transformed array.
        """
        return self.fit(X).transform(X)

    def get_feature_names(self, input_features=None):
        """Get output feature names for transformation.
        Parameters
        ----------
        input_features : Unused
            For API compatibility only.
        Returns
        -------
        feature_names_out : ndarray of str objects
            Same as input features.
        """
        self.feature_names_out = self.feature_names_in
        return self.feature_names_out



# ################################################################################# #
#  HELPER FUNCTIONS                                                                 #
# ################################################################################# #
from sklearn.utils.validation import check_is_fitted


def get_feature_names_out(transformer):
    """Get the feature names of the output of a fitted ColumnTransformer.

    A function to get the output column names for ColumnTransformers with
    incompatible methods across steps. Future versions of sklearn have
    added in compatibility functions so that a call to
        transformer.get_feature_names_out()
    works regardless of class of transformer stages.

    This function is (for our purposes) equivalent to the get_feature_names_out()
    method.

    Parameters
    ----------
    transformer: sklearn.compose.ColumnTransformer
        Fitted ColumnTransformer object.

    Returns
    -------
    feature_names_out: list of shape (n_features_out)
        A list of the output columns in order of appearance
        on the 1-axis of the output numpy array.

    """
    from sklearn.preprocessing import StandardScaler, FunctionTransformer, OneHotEncoder
    # Throws error if the column transformer is not fitted.
    check_is_fitted(transformer)

    feature_names_out = []
    for step in transformer.transformers_:
        # Unpack the tuple.
        name, step_transformer, feature_names_in = step

        if hasattr(step_transformer, 'get_feature_names'):
            # If the transformer has a built-in method for getting
            # feature names, we will utilize this method.

            # Append an additional underscore to OneHotEncoder inputs
            # so that output dataframe variables are separated by '__', eg
            #    <feature>__<value>
            # This will make it easier to reverse one-hot encoding
            # in the future.
            if isinstance(step_transformer, OneHotEncoder):
                feature_names_in = [
                    feature_name + '_' for feature_name in feature_names_in
                ]

            feature_names_out += np.atleast_1d(
                step_transformer.get_feature_names(input_features=feature_names_in)
                                .squeeze()
            ).tolist()

        elif hasattr(step_transformer, 'n_features_out_'):
            # If the transformer doesn't have a built-in method for getting
            # feature names, then we check if the number of features
            # output by the transformer is equal to the number of features
            # given to the transformer. If so, then the input features
            # equal the output features.
            if len(feature_names_in) == step_transformer.n_features_in_:
                feature_names_out += feature_names_in
        else:
            # Assume the features out are the same as the features in.
            # There are better ways to do this in a code workbook setting.
            # Be careful here - could be source of future errors not covered
            # by previous two conditions.
            feature_names_out += feature_names_in

    return feature_names_out
