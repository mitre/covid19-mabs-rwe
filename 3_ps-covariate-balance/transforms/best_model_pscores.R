#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Function to  select relevant columns as input to downstream MSM after PS model selection
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

best_model_pscores <- function(model_selection) {
  print(mean(model_selection$weight_ATE))
  return(model_selection %>%
           # only select primary keys (primary key, impute_id), treatment group indicator, ropensity scores and stabilized inverse propensity weight
           select(c("person_id", "impute_id", "treatment_group", starts_with("model"), "weight_ATE"))%>% rename(prop_score = 4))
}