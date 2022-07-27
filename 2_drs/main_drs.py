#!/usr/bin/env python

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This script executes the functions defined and found in 2_drs/transforms
## Date: May 2022
## Developers: Lauren D'Arinzo, Jerez Te
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# import libraries
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.impute import SimpleImputer, KNNImputer
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import GridSearchCV
from sklearn.compose import make_column_transformer, ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import make_scorer, accuracy_score, matthews_corrcoef, confusion_matrix, precision_score, recall_score
from sklearn.calibration import calibration_curve
import matplotlib.pyplot as plt

from transforms.model import MLmodeling_hpo
from transforms.score_a import drs_metrics, score
from transforms.score_b import calibration_curve_agg

from pathlib import Path

# read in data from previous step
current = Path.cwd()
impute_pmm = pd.read_csv('1_imputation/data/mab_patient_effect_imputed_no_treatment.csv')

# preprocess and train model
agg_results = MLmodeling_hpo(impute_pmm)

# evaluate model
results = drs_metrics(agg_results)
conf_matrix = score(agg_results)

# plot curve comparing results between impute groups
calibration_curve_agg(agg_results)

# write results to csv 
agg_results.to_csv(current / '2_drs' / 'data' / 'agg_results.csv', index = False)