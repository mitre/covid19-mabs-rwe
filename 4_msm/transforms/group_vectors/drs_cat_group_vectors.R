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

# Create a data frame whose columns are all of the vectors we need to multiply estimated coefficient 
# vector and variance/covariance matrices by to get predicted values and standard errors for 
# different subgroups by DRS category and treatment status. Since Syntropy functions need to return 
# data frames, need to make separate functions for each effect modifier instead of putting them all in a 
# single function and returning a list of data frames. Note that the columns giving the coefficient 
# combinations we want to use to get individual subgroup predictions depend on the ordering of the 
# variables from the loops in the estimation function. 
drs_cat_group_vectors <- function() {
  # Create vectors for each of the subgroup combinations corresponding to different DRS categories 
  # and treatment statuses. There are two levels of treatment and 5 DRS categories, so we have 10 
  # subgroups here.  
  veryLow_untreated <- c(1, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  veryLow_treated <- c(1, 1, 0, 0, 0, 0, 0, 0, 0, 0)
  low_untreated <- c(1, 0, 1, 0, 0, 0, 0, 0, 0, 0)
  low_treated <- c(1, 1, 1, 0, 0, 0, 1, 0, 0, 0)
  medium_untreated <- c(1, 0, 0, 1, 0, 0, 0, 0, 0, 0)
  medium_treated <- c(1, 1, 0, 1, 0, 0, 0, 1, 0, 0)
  high_untreated <- c(1, 0, 0, 0, 1, 0, 0, 0, 0, 0)
  high_treated <- c(1, 1, 0, 0, 1, 0, 0, 0, 1, 0)
  veryHigh_untreated <- c(1, 0, 0, 0, 0, 1, 0, 0, 0, 0)
  veryHigh_treated <- c(1, 1, 0, 0, 0, 1, 0, 0, 0, 1)
  # Put them all into a data frame, give it nice row names, and return.
  drs_categories <- data.frame(veryLow_untreated, veryLow_treated, low_untreated, low_treated, 
                               medium_untreated, medium_treated, high_untreated, high_treated, veryHigh_untreated, 
                               veryHigh_treated)
  
  rownames(drs_categories) <- c("intercept", "treat_dummy", "drs_catLow_dummy", 
                                "drs_catMedium_dummy", "drs_catHigh_dummy", "drs_catVeryHigh_dummy", 
                                "treat_drsLow_interacton", "treat_drsMedium_interacton",
                                "treat_drsHigh_interacton", "treat_drsVeryHigh_interacton")
  
  return(drs_categories)    
}