#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function reformats probability results that are output from the pooling step
## Date: May 2022
## Developers: Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# Using the output of probability_results(), 
# filters just to the effect modifier pandemic_phase 
# and creates a visualization comparing all outcomes between treated and untreated patients
# for all pandemic phases.

# NOTE: In the syntropy environment, functions can only return one output
# As such, there exists a unique script for every plot produced

probability_results <- function(msm_effect_wgraph_vals_pooled) {
  # Split the combined "model" feature into "timeframe" and "outcome"
  msm_effect_wgraph_vals_pooled <- msm_effect_wgraph_vals_pooled %>% separate(model, c("outcome", "effect_modifier"), " : ", extra = "merge")  
  # Split the combined "variable" feature into "treatment_status" and "effect_modifier_value"
  msm_effect_wgraph_vals_pooled <- msm_effect_wgraph_vals_pooled %>% separate(variable, c("treatment_status", "effect_modifier_value"), " : ", extra = "merge")  
  df <- msm_effect_wgraph_vals_pooled %>% select(outcome, effect_modifier, treatment_status, effect_modifier_value, prob_from_OR, lb_prob, ub_prob, n, total_in_group, outcomes_in_group)

  # Ensure naming convention is consistent
  df <-  df %>%
    mutate(outcome = ifelse(outcome == 'death_inpt_14day', 'death_inpt_14d', outcome)) %>%
    mutate(outcome = ifelse(outcome == 'death_inpt_30day', 'death_inpt_30d', outcome))
  return(df)
}