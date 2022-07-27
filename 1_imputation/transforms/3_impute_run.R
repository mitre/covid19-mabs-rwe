#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Run imputation via 0_global::getImputedData() for health systems A-D
## Date: May 2022
## Developers: N Welch
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

get_imputed_data <- function(mab_pt_effect_refactored, impute_vars, mab_pt_effect, impute_method, evaluate, treatInclude) {

    # check that impute_method is available in 0_global::getImputedData() 
    if( !( impute_method %in% c("pmm", "bayes", "cart") ) ) stop(message="impute_method must be 'pmm', 'bayes', or 'cart'")  

    imputevars = as.data.table( impute_vars )
    m = imputevars$impute_number
    i = imputevars$gibbs_number

    cat("\nImputing A")
    A = getImputedData(rf_data=mab_pt_effect_refactored, pt_data=mab_pt_effect, hs="A", method=impute_method, m.iter=m, gibbs.iter=i, eval=evaluate, treatmentIncluded=treatInclude)

    cat("\nImputing B")
    B = getImputedData(rf_data=mab_pt_effect_refactored, pt_data=mab_pt_effect, hs="B", method=impute_method, m.iter=m, gibbs.iter=i, eval=evaluate, treatmentIncluded=treatInclude)

    cat("\nImputing C")
    C = getImputedData(rf_data=mab_pt_effect_refactored, pt_data=mab_pt_effect, hs="C", method=impute_method, m.iter=m, gibbs.iter=i, eval=evaluate, treatmentIncluded=treatInclude)

    cat("\nImputing D")
    D = getImputedData(rf_data=mab_pt_effect_refactored, pt_data=mab_pt_effect, hs="D", method=impute_method, m.iter=m, gibbs.iter=i, eval=evaluate, treatmentIncluded=treatInclude)


    dt = rbind( A, B, C, D)

    cat("\nImputation complete")

    return( dt )
}
