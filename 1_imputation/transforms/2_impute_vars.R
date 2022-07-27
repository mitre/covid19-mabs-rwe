#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function sets the number of imputation replicates (impute_number) and number of Gibbs iterations (gibbs_number)
## Date: May 2022
## Developers: N Welch
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

impute_vars <- function() {
    df = data.frame(impute_number=5, gibbs_number=5)
    return( df )
}
