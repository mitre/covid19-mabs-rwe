##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function compute EValues for Sensitivity Analysis using the EValue R package
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# VanderWeele & Ding (2017) reference paper is available here: https://pubmed.ncbi.nlm.nih.gov/28693043/
# Implemented using EValue package also authored by VanderWeele & Ding: https://cran.r-project.org/web/packages/EValue/index.html

evalues <- function(msm_effect_wgraph_vals_pooled) {
  
  # Define function that will return the evalue of a given OR
  get_evalues <- function(x){
    return(evalue(OR(x, rare = TRUE)))
  }
  
  # NOTE: E-values should not be computed for any effect estimates that have confidence interval bounds of NA
  # E-values are only relevant for effect estimates that have converged and are significantly different from null
  # Death outcomes for this effect modifier interaction has unstable CIs, so do not include in Evalue computation
  # This code chunk will need to be modified based on results from your specific dataset
  msm_effect_wgraph_vals_pooled <- msm_effect_wgraph_vals_pooled %>% 
    filter(!grepl('death_30d : pandemic_phase|death_14d : pandemic_phase', model)) %>% 
    filter(!grepl('death_14d : immunized_sarscov2_status', model)) 
  
  
  # Apply evalue function to ORs and min evalue (evalue of bound closest to OR of 1 which represents no effect)
  for (i in 1:nrow(msm_effect_wgraph_vals_pooled)) {
    this_evalue <- get_evalues(msm_effect_wgraph_vals_pooled$sandwich_OR[i])[2]
    msm_effect_wgraph_vals_pooled$OR_evalue[i] <- this_evalue
    
    ci_bounds <- c(msm_effect_wgraph_vals_pooled$sandwich_OR_lower[i], msm_effect_wgraph_vals_pooled$sandwich_OR_upper[i])
    
    # Store value of the OR ci bound that is closer to 1, then compute its associated evalue
    bound_closer_to_h0 <- ci_bounds[which.min(abs(ci_bounds-1))]
    min_evalue <- get_evalues(bound_closer_to_h0)[2]
    msm_effect_wgraph_vals_pooled$min_evalue[i] <- min_evalue
  }
  
  # Select only relevant columns for output
  evalue_output <- msm_effect_wgraph_vals_pooled %>% select(model, variable, sandwich_OR, sandwich_OR_lower, sandwich_OR_upper, OR_evalue, min_evalue)
  
  return(evalue_output)
}