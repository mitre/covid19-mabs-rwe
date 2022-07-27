# 1. Imputation

These codes are used to impute missing data using multiple imputation with predictive mean matching (PMM). 

- Imputation is used to infer values that could have been observed in the study, but were not recorded 
- *Multiple* imputation is used to account for uncertainty in imputed values 
- Codes in this directory show how one might impute missing values for any covariate in the data set using predictive mean matching
- We use PMM for imputation to preserve the relationships and variable ranges present in the data that were observed instead of using a fully model-based estimate 
- Parameter estimates and associated standard errors are all calculated using Rubin's Rules after completing all steps of the full analysis pipeline 
- See [van Buuren, (2018)](https://stefvanbuuren.name/fimd/) for a detailed overview of methods deployed in this analysis

## Code requirements and process 

The codes in `main_imputation.R` execute the imputation process in a series of three steps: 

- `transforms/1_data_refactored.R` ensures that all covariates in `mab_pt_effect.csv` have the correct data type and initialize imputation meta-analysis fields. This step returns an R data.table of relevant covariates from `mab_pt_effect.csv` and meta-analysis fields. 
- `transforms/2_impute_vars.R` includes a single function that specifies the number of imputations and Gibbs steps for the imputation functions. This step returns an R data.frame with two columns and one row of data to be used in the imputation method. 
- `transforms/3_impute_run.R` executes the imputation step using methods specified in `transforms/0_global.R` for each system in `mab_pt_effect.csv`. This step returns an imputed data set with all the same fields as `mab_pt_effect.csv` or an R data.frame summarizing the Gibb's sampler trajectories. The imputation model should include all available variables (van Buuren, 2018); however, disease risk score models exclude treatment status and rely on an explicit assumption that treatment status is unknowable at any stage. As a result, disease risk score imputation excludes treatment status from the list of imputation model covariates. 
