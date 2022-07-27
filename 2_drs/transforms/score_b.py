##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function plots DRS results between imputation groups
## Date: May 2022
## Developers: Jerez Te
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

def calibration_curve_agg(agg_results):
    from sklearn.calibration import calibration_curve
    import matplotlib.pyplot as plt
    df = agg_results
    for id in df['impute_id'].unique().tolist():
        subset_df = df[df['impute_id'] == id]
        y_true = subset_df['target']
        y_pred = subset_df['prediction']
        prob_true, prob_pred = calibration_curve(y_true, y_pred, n_bins=10)
        plt.plot(prob_true, prob_pred, label=str(id))        
    plt.legend()
    plt.xlabel('Mean Predicted Probability')
    plt.ylabel('Fraction of positives')
    plt.savefig('2_drs/figures/calibration_curve.png')
    return
