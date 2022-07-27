#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function creates a loveplot for immunization confounders
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# NOTES: In the syntropy environment, functions can only return one output
# As such, there exists a unique script for every plot produced

# As noted in 3_ps-covariate-balance/main_covariate_balance.R, 
# output can be found in 3_ps-covariate-balance/figures

love.plot.vaccines <- function(model_selection, vaccine_covariates) {
  df = model_selection
  
  plot_covs <- df %>%
    select(vaccine_covariates)
  
  love_plot<- love.plot(
    plot_covs, 
    treat = df$treatment_group, 
    weights = df$weight_ATE, 
    thresholds = c(m = .1, ks=.05),
    wrap=5, 
    size=2.5, 
    title = "Balance of Vaccine Covariates",
    colors = c("#E0AFCA", "#66C5AB"),
    sample.names = c("Unweighted", "After Inverse PS Weighting"),
    stats=c("mean.diffs", "ks.statistics"), 
    position = "top",
    themes = list(
      m = theme(
        text = element_text(size=9),
      ), 
      ks =  theme(
        text = element_text(size=9)
      )
    )
  ) 

  return(love_plot)
}