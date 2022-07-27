#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function reformats time-varying probability results that are output from the pooling step
## Date: May 2022
## Developers: Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# This function re-formats effect estimate results output after pooling across imputation groups
# by performing string splitting for easier downstream plotting
# For example:
# model = "death_14d : pandemic_phase" becomes "outcome=death_14d", "effect_modifier=pandemic_phase"

prob_timevarying <- function(msm_effect_timevarying_pooled) {
  # Split the combined "model" feature into "timeframe" and "outcome"
  msm_effect_timevarying_pooled <- msm_effect_timevarying_pooled %>% separate(model, c("timeframe", "outcome"), " : ", extra = "merge")  
  # Split the combined "variable" feature into "treatment_status" and "effect_modifier_value"
  msm_effect_timevarying_pooled <- msm_effect_timevarying_pooled %>% separate(variable, c("variant_variable", "treatment_status"), " : ", extra = "merge")  
  df <- msm_effect_timevarying_pooled %>% select(timeframe, outcome, variant_variable, treatment_status, n_group, prob_from_OR, lb_prob, ub_prob)
  
  # Ensure naming convention is consistent
  df <-  df %>%
    mutate(outcome = ifelse(outcome == 'death_inpt_14day', 'death_inpt_14d', outcome)) %>%
    mutate(outcome = ifelse(outcome == 'death_inpt_30day', 'death_inpt_30d', outcome))
  return(df)
}