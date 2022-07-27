
##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Thie function prints evaluation metrics for the DRS model
## Date: May 2022
## Developers: Jerez Te
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

from sklearn.metrics import make_scorer, accuracy_score, matthews_corrcoef, confusion_matrix, precision_score, recall_score
import numpy as np 
import pandas as pd
def drs_metrics(agg_results):
    df = agg_results
    results = []
    for impute in df['impute_id'].unique():
        print(f'ALL POPULATION FOR IMPUTE ID: {impute}')
        new_df = df[df['impute_id'] == impute].reset_index(drop=True)
        conf_mat = score(new_df)
        results.append(conf_mat)
        print('##### UNTREATED ####')
        untreated = new_df[new_df['treatment_group'] == 0].reset_index(drop=True)
        score(untreated)
        print('##### TREATED ####')
        treated = new_df[new_df['treatment_group'] == 1].reset_index(drop=True)
        score(treated)
    results = pd.DataFrame(results)
    results.columns = ['tn', 'fp', 'fn', 'tp']
    print(results.describe())
    return results
    
def score(df):
    y_pred = np.where(df['prediction'] >= 0.5, 1, 0)
    y_test = df['target']
    conf_mat = confusion_matrix(y_test,y_pred).ravel()
    print(conf_mat , "tn, fp, fn, tp")
    print(f'MCC: {matthews_corrcoef(y_test, y_pred)}')
    print(f'PPV: {precision_score(y_test, y_pred)}')
    print(f'Recall: {recall_score(y_test, y_pred)}')
    return conf_mat
