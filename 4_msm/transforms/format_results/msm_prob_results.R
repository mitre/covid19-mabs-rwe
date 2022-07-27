##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function formats final results for use in assessment report document
## Date: May 2022
## Developers: Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# Takes the output of probability_results() and label ordering from config.R
# and re-formats results such that non-treated and treated adjusted effect estimates
# are side by side for easy comparison, outcomes are ordered appropriately, and 
# outcome-times (14d vs 30d) for the same effect modifier value are stacked in adjacent rows

msm_prob_results <- function(probability_results, effect_modifier_order, treatment_status_order, effect_modifier_value_order, model_order) {
  df = probability_results %>%
    select(-n) %>%
    rename(prob = prob_from_OR,
           n = total_in_group) %>%
    # Ensure naming is consistent
    mutate(outcome = ifelse(outcome == 'death_inpt_14day', 'death_inpt_14d', outcome)) %>%
    mutate(outcome = ifelse(outcome == 'death_inpt_30day', 'death_inpt_30d', outcome)) %>%
    mutate(
      # Split variable name to just include the relevant time indicator
      outcome_time = ifelse(grepl('14d', outcome), '14d', '30d'),
      model = gsub('_14d|_30d', '', outcome)
    )
  
  df = df %>%
    mutate(
      # Convert decimal proprtions to percentages
      prob_ci = sprintf("%.1f%% (%.1f%% - %.1f%%)",prob*100, lb_prob*100, ub_prob*100)
    ) %>%
    select(-lb_prob, -ub_prob, -prob, -outcome, -outcomes_in_group)
  
  # Order results according to order and labels defined in config
  df$effect_modifier = factor(df$effect_modifier, levels = effect_modifier_order)
  df$treatment_status = factor(df$treatment_status, 
                               levels = treatment_status_order,
                               labels = names(treatment_status_order))
  df$model = factor(df$model, levels = model_order, labels = names(model_order))
  
  # pivot to include both non-treated and treated estimates in same row
  df = pivot_wider(df,  names_from = 'treatment_status', values_from = c('n', 'prob_ci')) %>%
    as.data.frame()
  
  # Order effect modifiers
  df_order = bind_rows(lapply(effect_modifier_order, function(i){
    dat = df[df$effect_modifier == i,]
    dat$effect_modifier_value = factor(dat$effect_modifier_value, levels = effect_modifier_value_order[[i]])
    dat = dat[order(dat$model, dat$outcome_time, dat$effect_modifier_value),]
    return(dat)
  }))
  
  df_order = df_order %>%
    select(effect_modifier, model, outcome_time, effect_modifier_value, "prob_ci_Non-treated", "prob_ci_Treated") %>%
    filter( !(effect_modifier == 'who_variant_cat' & effect_modifier_value == 'Other'))
  
  return(df_order)
}