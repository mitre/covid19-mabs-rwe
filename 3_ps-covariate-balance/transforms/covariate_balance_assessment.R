#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to compute and summarize evaluation metrics for candidate propensity models 
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

covariate_balance_assessment <- function(covariate_balance) {
  df <- covariate_balance
  
  pscore_cols <- colnames(df %>% select(starts_with("model")))
  
  covs <- df %>%
    select(-c(starts_with("model"), "treatment_group", "person_id", "impute_id", "imputed_demographics","imputed_vitals")) 
  
  # Loop through each model, parse ks and smd stats for each covariate, then aggregate across covariates
  i <- 0 
  for (model in pscore_cols){
    print(model)
    
    # compute stabilized ATE weights
    prob_treat = mean(df$treatment_group)
    weights <- ifelse(df$treatment_group == 1, prob_treat/df[[model]], (1-prob_treat)/(1-df[[model]]))
    
    # perform balance tabulation using bal.tab function from cobalt
    # metrics of interest: standardized mean difference and kolmogorov smirnov test statistic,
    # between inverse propensity weighted treated and control populations.
    bal <- bal.tab(covs, treat = df$treatment_group, weights = weights, stats = c("mean.diffs", "ks.statistics"))
    
    # extract stats from Balance object
    metrics <- bal$Balance
    metrics <- cbind(covariate = rownames(metrics), metrics)
    rownames(metrics) <- 1:nrow(metrics)
    ks <- metrics %>% select(covariate, KS.Adj) 
    smd <- metrics %>% select(covariate, Diff.Adj) 
    names(ks)[names(ks)=="KS.Adj"] <-  paste(model)
    names(smd)[names(smd)=="Diff.Adj"] <- paste(model)
    
    # append metrics for each model into a df with all models
    if(i == 0){ks_to_merge <- ks
    smd_to_merge <- smd
    }else{ks_to_merge <- merge(x = ks_to_merge, y = ks, by = "covariate", all = TRUE)
    smd_to_merge <- merge(x = smd_to_merge, y = smd, by = "covariate", all = TRUE)}
    i <- i + 1
  }
  
  smd_abs <- rapply(smd_to_merge, f = abs, classes = c("numeric", "integer"), how = "replace")
  
  # compute aggregate stats for each candidate model
  mean_abs_smd <- as.data.frame(smd_abs %>% summarise_if(is.numeric, c("mean")), 'mean_abs_smd')
  mean_abs_smd <- rownames_to_column(mean_abs_smd, "metric")
  
  max_abs_smd <- as.data.frame(smd_abs %>% summarise_if(is.numeric, c("max")), 'max_abs_smd')
  max_abs_smd <- rownames_to_column(max_abs_smd, "metric")
  
  mean_ks <- as.data.frame(ks_to_merge %>% summarise_if(is.numeric, c("mean")), 'mean_ks')
  mean_ks <- rownames_to_column(mean_ks, "metric")
  
  max_ks <- as.data.frame(ks_to_merge %>% summarise_if(is.numeric, c("max")), 'max_ks')
  max_ks <- rownames_to_column(max_ks, "metric")
  
  comb_df = bind_rows(mean_abs_smd,
                      max_abs_smd, 
                      mean_ks, 
                      max_ks)
  
  # identify which model minimized each metric
  comb_df$best_model <- names(comb_df)[apply(comb_df, MARGIN = 1, FUN = which.min)]
  
  return(comb_df)
}