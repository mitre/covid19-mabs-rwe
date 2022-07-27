##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function formats final time-varying effect modifier results for use in assessment report to sponsor
## Date: May 2022
## Developers: Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# For time-varying effect modifiers,
# takes the output of prob_timevarying() and label ordering from config.R
# and re-formats results such that non-treated and treated adjusted effect estimates
# are side by side for easy comparison, outcomes are ordered appropriately, and 
# outcome-times (14d vs 30d) for the same effect modifier value are stacked in adjacent rows

mab_product_prob_results <- function(prob_timevarying) {
  df = prob_timevarying %>%
    rename(prob = prob_from_OR) %>%
    # Convert decimal proprtions to percentages
    # Split variable name to just include the relevant time indicator
    mutate(prob_ci = sprintf("%.1f%% (%.1f%% - %.1f%%)",prob*100, lb_prob*100, ub_prob*100),
           outcome_time = ifelse(grepl('14d', outcome), '14d', '30d'),
           model = gsub('_14d|_30d', '', outcome)
    ) %>%
    select(-lb_prob, -ub_prob, -prob, -outcome)
  
  # Order results according to order and labels defined in config
  timeframe_order = c(effect_modifier_value_order$pandemic_phase, effect_modifier_value_order$who_variant_cat)
  
  df$timeframe = factor(df$timeframe, levels = timeframe_order, labels = names(timeframe_order))
  
  df$treatment_status = factor(df$treatment_status, levels = product_order,
                               labels = names(product_order))
  df$model = factor(df$model, levels = model_order, labels = names(model_order))
  
  # pivot to include both non-treated and treated estimates in same row
  df = pivot_wider(df,  names_from = 'treatment_status', values_from = c('n_group', 'prob_ci')) %>%
    as.data.frame()
  
  df = df %>%
    arrange(outcome_time, variant_variable, timeframe, model) %>%
    select(outcome_time, variant_variable, timeframe, model, "prob_ci_Non-treated", "prob_ci_Bamlanivimab", "prob_ci_Casirivimab-imdevimab", "prob_ci_Bamlanivimab-etesevimab", "prob_ci_Sotrovimab")
  
  names(df) = gsub(' |+', '', names(df))
  return(df)
}