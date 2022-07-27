#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This script performs data preprocessing on output from ps step prior to covariate balance assessment
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

preprocessing <- function(ps_merge_models, get_dataframe) {
  # remove treatment group column from one input dataframe before join to avoid duplication
   ps_merge_models <- ps_merge_models %>%
    select(-c("treatment_group")) 

  # join predicted propensity scores with covariates that have been identified as confounders
  covariate_balance_input <- get_dataframe %>% 
    as.data.frame() %>% inner_join(., ps_merge_models, by = c('person_id', 'impute_id'))
  return(covariate_balance_input)
}