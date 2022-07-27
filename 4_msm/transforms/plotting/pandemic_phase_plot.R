#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function creates a plot for comparing adjusted outcomes of treated and untreated patients with pandemic phase as an effect modifier
## Date: May 2022
## Developers: Lauren D'Arinzo, Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# Using the output of probability_results(), 
# filters just to the effect modifier pandemic_phase 
# and creates a visualization comparing all outcomes between treated and untreated patients
# for all pandemic phases.

# NOTE: In the syntropy environment, functions can only return one output
# As such, there exists a unique script for every plot produced

pandemic_phase_plot <- function(probability_results, outcome_order, treatment_status_order, effect_modifier_value_order) {
  
  i = 'pandemic_phase'
  
  df = probability_results %>%
    rename(prob = prob_from_OR) %>%
    # Order values according to to config
    mutate(outcome = factor(outcome, levels = outcome_order, labels = names(outcome_order)),
           treatment_status = factor(treatment_status, levels = treatment_status_order,
                                     labels = names(treatment_status_order))
    ) %>%
    filter(effect_modifier == i) %>%
    mutate(effect_modifier_value = factor(effect_modifier_value,
                                          levels = effect_modifier_value_order[[i]],
                                          labels = names(effect_modifier_value_order[[i]]))
    )
  
  # Call plotting function that can be applied to any effect modifier
  p = effect_modifier_plot(df)
  plot(p)
  return(p)
}