#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function creates pools results for effect estimates across imputation groups
## Date: May 2022
## Developers: Fraser Gaspar, Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# Following Rubin's Rules
# Equation references are from this book: https://bookdown.org/mwheymans/bookmi/rubins-rules.html

msm_effect_wgraph_vals_pooled <- function(msm_effect_wgraph_vals) {
  n_impute = max(msm_effect_wgraph_vals$impute_id)
  print(n_impute)
  # Some reformatting for make compatible with current loop structure
  msm_effect_wgraph_vals$model <- paste(msm_effect_wgraph_vals$outcome, ":", msm_effect_wgraph_vals$effect_modifier)
  msm_effect_wgraph_vals$variable <- paste(msm_effect_wgraph_vals$treatment_status, ":", msm_effect_wgraph_vals$effect_modifier_value)
  
  pooled_estimates = msm_effect_wgraph_vals %>% 
    group_by(model) %>% 
    mutate(k = length(unique(variable))) %>% # Number of parameters
    ungroup() %>%
    group_by(model, variable, k) %>% 
    summarise(
      log_odds_pooled = mean(log_odds), # Pooled mean difference (9.1)
      Vw = mean(sandwich_std_error^2), # Within imputation variance (9.2)
      Vb = sum((log_odds - mean(log_odds))^2)/(n_impute - 1), # Between imputation variance (9.3)
      n = mean(n), # Sample size
      total_in_group = floor(mean(total_in_group)),
      outcomes_in_group = floor(mean(outcomes_in_group))
    ) %>%
    mutate(Vt = Vw + Vb + Vb/n_impute) %>% # Total variance (9.4)
    mutate(lambda = (Vb + Vb/n_impute)/Vt) %>% # Fraction of missing information (10.1) 
    mutate(
      sandwich_se_pooled = sqrt(Vt), # pooled standard error (9.4)
      wald_pooled = sqrt(((log_odds_pooled - 0)^2)/Vt), # pooled wald (9.5). Assumes null is 0. 
      df_old = (n_impute - 1)/lambda^2, # 'older' method for caculating degrees of freedom (9.8)
      df_obs = (((n-k[1])+1)/((n-k[1])+3))*(n-k[1])*(1-lambda) #observed degrees of freedom (9.10). Bernard and Rubin (1999)
    ) %>%
    mutate(df_adj = (df_old*df_obs)/(df_old+df_obs)) %>% # Adjusted degrees of freedom (9.9)
    mutate(sandwich_p_val = 2*pt(-abs(wald_pooled), df_adj-1)) %>% # P-values (9.6)
    mutate(
      lb_pooled = log_odds_pooled - qt(0.975, df = df_adj-1)*sandwich_se_pooled, # Lower bound of confidence intervals (9.11)
      ub_pooled = log_odds_pooled + qt(0.975, df = df_adj-1)*sandwich_se_pooled  # Upper bound of confidence intervals (9.11)
    ) %>%
    mutate(
      sandwich_OR = exp(log_odds_pooled),
      sandwich_OR_lower = exp(lb_pooled),
      sandwich_OR_upper = exp(ub_pooled),
      sandwich_OR_CI = sprintf("%s - %s", 
                               sprintf("%.5f",exp(lb_pooled)),
                               sprintf("%.5f",exp(ub_pooled)))
    ) %>%
    mutate(
      prob_from_OR = sandwich_OR/(1+sandwich_OR),
      lb_prob = exp(lb_pooled)/(1+exp(lb_pooled)),
      ub_prob = exp(ub_pooled)/(1+exp(ub_pooled))
    ) %>%
    as.data.frame()
  
  return(pooled_estimates)
  
}
