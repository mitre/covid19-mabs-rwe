#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This script creates a vector for producing probability estimate from logistic regression coefficient odds ratios returned from the MSM
## Date: May 2022
## Developers: Lauren D'Arinzo, Max Olivier
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# Create a data frame whose columns are all of the vectors we need to multiply estimated coefficient vector
# and variance/covariance matrices by to get predicted values and standard errors for different subgroups by
# pandemic phase and treatment status. Since Syntropy functions need to return data frames, need to make separate 
# functions for each effect modifier instead of putting them all in a single function and returning a list of 
# data frames. Note that the columns giving the coefficient combinations we want to use to get individual 
# subgroup predictions depend on the ordering of the variables from the loops in the estimation function.
pandemic_phase_group_vectors <- function() {
  # Create vectors for each of the subgroup combinations corresponding to different pandemic phase and
  # and treatment statuses. There are two levels of treatment and 3 pandemic phases, so we have
  # 6 subgroups here.  
  predelta_untreated <- c(1, 0, 0, 0, 0, 0, 0, 0)
  predelta_treated <- c(1, 1, 0, 0, 0, 0, 0, 0)
  delta_untreated <- c(1, 0, 1, 0, 0, 0, 0, 0)
  delta_treated <- c(1, 1, 1, 0, 0, 1, 0, 0)
  deltaomicron_untreated <- c(1, 0, 0, 1, 0, 0, 0, 0)
  deltaomicron_treated <- c(1, 1, 0, 1, 0, 0, 1, 0)
  omicron_untreated <- c(1, 0, 0, 0, 1, 0, 0, 0)
  omicron_treated <- c(1, 1, 0, 0, 1, 0, 0, 1)
  
  # Put them all into a data frame, give it nice row names, and return.
  pandemic_phase_vecs <- data.frame(predelta_untreated, predelta_treated, delta_untreated, delta_treated, deltaomicron_untreated, deltaomicron_treated, omicron_untreated, omicron_treated)
  
  rownames(pandemic_phase_vecs) <- c("intercept", "treated_dummy", "delta_dummy", "deltaomicron_dummy", "omicron_dummy", "treated_delta_interaction", "treated_deltaomicron_interaction", "treated_omicron_interaction")
  
  return(pandemic_phase_vecs)
}