#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function creates a plot for comparing adjusted outcomes of treated and untreated patients with vaccine status as an effect modifier
## Date: May 2022
## Developers: Lauren D'Arinzo, Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

immunized_status_plot <- function(probability_results, outcome_order, treatment_status_order, effect_modifier_value_order) {
  
  i = 'immunized_sarscov2_status'
  
  # Filter to only immunization effect modifier results
  df = probability_results %>%
    rename(prob = prob_from_OR) %>%
    mutate(outcome = factor(outcome, levels = outcome_order, labels = names(outcome_order)),
           treatment_status = factor(treatment_status, levels = treatment_status_order,
                                     labels = names(treatment_status_order))
    ) %>%
    filter(effect_modifier == i) %>%
    mutate(effect_modifier_value = factor(effect_modifier_value,
                                          levels = effect_modifier_value_order[[i]],
                                          labels = names(effect_modifier_value_order[[i]]))
    )
  
  # Use effect_modifier_plot function defined in config.R
  p = effect_modifier_plot(df)
  plot(p)
  return(p)
}