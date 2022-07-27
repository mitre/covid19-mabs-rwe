#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to select pscores for downstream use among candidate PS models
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

model_selection <- function(covariate_balance, covariate_balance_assessment) {
  
  # define overall best model as most occurring best model across each metric
  best_model <- names(sort(-table(covariate_balance_assessment$best_model)))[1]
  print(best_model)
  
  df <- covariate_balance
  
  # stabilized weights
  prob_treat = mean(df$treatment_group)
  df$weight_ATE <- ifelse(df$treatment_group == 1, prob_treat/df[[best_model]], (1-prob_treat)/(1-df[[best_model]]))
  
  covs <- df %>%
    select(-c(starts_with("model"), "person_id", "treatment_group", "imputed_demographics","imputed_vitals")) 
  
  final_df <- df %>%
    select(c(person_id, impute_id, best_model, treatment_group, colnames(covs)))
  
  return(final_df)
}