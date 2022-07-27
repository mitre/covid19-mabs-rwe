#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function creates pools results for time-varying effect modifiers across imputation groups
## Date: May 2022
## Developers: Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# Following Rubin's Rules
# Equation references are from this book: https://bookdown.org/mwheymans/bookmi/rubins-rules.html

msm_effect_timevarying_pooled <- function(msm_effect_timevarying) {
  n_impute = max(msm_effect_timevarying$impute_id)
  print(n_impute)
  msm_effect_timevarying$treatment_status = gsub('mab_product', '', msm_effect_timevarying$treatment_status)
  
  # some reformatting for make compatible with current loop structure
  msm_effect_timevarying$model <- paste(msm_effect_timevarying$timeframe, ":", msm_effect_timevarying$outcome)
  msm_effect_timevarying$variable <- paste(msm_effect_timevarying$variant_variable, ":", msm_effect_timevarying$treatment_status)
  
  pooled_estimates = msm_effect_timevarying %>% 
    group_by(model) %>% 
    mutate(k = length(unique(variable))) %>% # number of parameters
    ungroup() %>%
    group_by(model, variable, k) %>% 
    summarise(
      log_odds_pooled = mean(log_odds), # pooled mean difference (9.1)
      Vw = mean(sandwich_std_error^2), # within imputation variance (9.2)
      Vb = sum((log_odds - mean(log_odds))^2)/(n_impute - 1), # between imputation variance (9.3)
      n = mean(n), # sample size
      n_group = mean(n_group) # group size
    ) %>%
    mutate(Vt = Vw + Vb + Vb/n_impute) %>% # total variance (9.4)
    mutate(lambda = (Vb + Vb/n_impute)/Vt) %>% # Fraction of missing information (10.1) 
    mutate(
      sandwich_se_pooled = sqrt(Vt), # pooled standard error (9.4)
      wald_pooled = sqrt(((log_odds_pooled - 0)^2)/Vt), # pooled wald (9.5). Assumes null is 0. 
      df_old = (n_impute - 1)/lambda^2, # 'older' method for caculating degrees of freedom (9.8)
      df_obs = (((n-k[1])+1)/((n-k[1])+3))*(n-k[1])*(1-lambda) #observed degrees of freedom (9.10). Bernard and Rubin (1999)
    ) %>%
    mutate(df_adj = (df_old*df_obs)/(df_old+df_obs)) %>% # adjusted degrees of freedom (9.9)
    mutate(sandwich_p_val = 2*pt(-abs(wald_pooled), df_adj-1)) %>% # p-values (9.6)
    mutate(
      lb_pooled = log_odds_pooled - qt(0.975, df = df_adj-1)*sandwich_se_pooled, # lower bound of confidence intervals (9.11)
      ub_pooled = log_odds_pooled + qt(0.975, df = df_adj-1)*sandwich_se_pooled  # upper bound of confidence intervals (9.11)
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
