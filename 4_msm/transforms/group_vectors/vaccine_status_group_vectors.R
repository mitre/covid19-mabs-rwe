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
# vaccination and treatment status. Since Syntropy functions need to return data frames, need to make separate 
# functions for each effect modifier instead of putting them all in a single function and returning a list of 
# data frames. Note that the columns giving the coefficient combinations we want to use to get individual 
# subgroup predictions depend on the ordering of the variables from the loops in the estimation function.  
vaccination_status_group_vectors <- function() {
  # Create vectors for each of the subgroup combinations corresponding to different vaccination and
  # and treatment statuses. There are two levels of treatment and 4 levels of vaccination status, so we have
  # 8 subgroups here.  
  none_untreated <- c(1, 0, 0, 0, 0, 0, 0, 0)
  none_treated <- c(1, 1, 0, 0, 0, 0, 0, 0)
  partial_untreated <- c(1, 0, 1, 0, 0, 0, 0, 0)
  partial_treated <- c(1, 1, 1, 0, 0, 1, 0, 0)
  full_untreated <- c(1, 0, 0, 1, 0, 0, 0, 0)
  full_treated <- c(1, 1, 0, 1, 0, 0, 1, 0)
  fullboosted_untreated <- c(1, 0, 0, 0, 1, 0, 0, 0)
  fullboosted_treated <- c(1, 1, 0, 0, 1, 0, 0, 1)
  
  # Put them all into a data frame, give it nice row names, and return.
  vaccine_status <- data.frame(none_untreated, none_treated, partial_untreated, 
                               partial_treated, full_untreated, full_treated,
                               fullboosted_untreated, fullboosted_treated)
  
  rownames(vaccine_status) <- c("intercept", "treat_dummy", "partial_dummy",
                                "full_dummy", "fullboosted_dummy", 
                                "treat_partial_interacton", "treat_full_interacton",
                                "treat_fullboosted_interacton")
  
  #    print(vaccine_status)
  
  return(vaccine_status)
}