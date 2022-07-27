##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This script executes the functions defined and found in 2_ps/transforms
## Date: May 2022
## Developers: Alexander Wood, Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

import sys
import pandas as pd
from transforms.global_utils import *
from transforms import get_configs
from transforms import get_dataframe
from transforms import ML_setup
from transforms import ML_LR
from transforms import ML_RF
from transforms import ML_GBT
from transforms import merge_models
from pathlib import Path

current = Path.cwd()

# Load the raw data and configs.
df = pd.read_csv('1_imputation/data/mab_patient_effect_imputed.csv')
configs = pd.read_csv(current / '2_ps' /'data' / 'configs.csv')

# Parse configs
configs_df = get_configs(df, configs, INDEX_ID, INDEX_IMPUTATION_ID, INDEX_IMPUTATION_FLAG, INDEX_COLUMNS, TARGET_COLUMNS, COVID_COLUMN_PATTERN, CONDITION_COLUMN_PATTERN, RUN_DEBUG)

# Parse relevant confounders from upstream output
df = get_dataframe(df, configs_df, RUN_DEBUG)

# Write out this intermediate output for use in covariate balance step
df.to_csv(current / '2_ps' / 'data' / 'get_dataframe.csv', index=False)

# Perform model training preprocessing
df = ML_setup(df, configs_df, INDEX_IMPUTATION_ID,  RUN_CHECKS, RUN_DEBUG)

# Fit candidate models
df_lr = ML_LR(df, INDEX_ID, INDEX_IMPUTATION_ID, INDEX_COLUMNS, TARGET_COLUMNS, RUN_CHECKS, RUN_DEBUG)
df_rf = ML_RF(df, INDEX_ID, INDEX_IMPUTATION_ID, INDEX_COLUMNS, TARGET_COLUMNS, RUN_CHECKS, RUN_DEBUG)
df_gbt = ML_GBT(df, INDEX_ID, INDEX_IMPUTATION_ID, INDEX_COLUMNS, TARGET_COLUMNS, RUN_CHECKS, RUN_DEBUG)

# Combine outputs and write out results
df = merge_models(df_lr, df_rf, df_gbt, INDEX_ID, INDEX_IMPUTATION_ID, RUN_CHECKS, RUN_DEBUG)
df.to_csv(current / '2_ps' / 'data' / 'merge_models.csv', index=False)
