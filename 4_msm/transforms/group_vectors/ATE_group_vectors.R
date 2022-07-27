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
# and variance/coviariaince matrices by to get predicted values and standard errors for different subgroups by
# most recent vaccination time and treatment status. Since Syntropy functions need to return data frames, need
# to make separate functions for each effect modifier intead of putting them all in a single function and 
# returning a list of data frames. Note that the columns giving the coefficient combinations we want to use 
# to get individual subgroup predicitions depend on the ordering of the variables from the loops in the 
# estimation function. 
ATE_group_vectors <- function() {
  # Create vectors for each of the subgroup combinations corresponding to different time frames for most
  # recent vaccination and treatment statuses. There are two levels of treatment and 5 groups for most recent
  # vaccination time, so we have 10 subgroups here.  
  none_untreated <- c(1, 0)
  none_treated <- c(1, 1)
  
  # Put them all into a data frame, give it nice row names, and return.
  ATE_vecs <-  data.frame(none_untreated, none_treated)
  
  rownames(ATE_vecs) <-   c("intercept", "treated_dummy")
  return(ATE_vecs)    
}