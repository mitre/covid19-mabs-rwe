#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Example multiple imputation for Monoclonal Antibody patient effect data
## Date: May 2022
## Developers: N Welch
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

args = commandArgs(trailingOnly=TRUE)

srcDir = args[1]
imputeDir = file.path(srcDir, "1_imputation")

# set seed
set.seed(123)

cat("\n Load global functions \n")
source(file=file.path(imputeDir, "transforms", "0_global.R") )

cat("\n Refactor mab_pt_effect for imputation functions \n")
source(file=file.path(imputeDir, "transforms", "1_data_refactored.R") )
mab_dt = fread(file=file.path(srcDir, "data", "mab_pt_effect.csv") )
mab_refactored_dt = mab_pt_effect_refactored( mab_pt_effect=mab_dt )

cat("\n Load imputation variables \n")
source(file=file.path(imputeDir, "transforms", "2_impute_vars.R") )
imputevars = impute_vars()

cat("\n Run Predictive Mean Matching (PMM) imputation \n")
source(file=file.path(imputeDir, "transforms", "3_impute_run.R") ) 
mab_pmm_dt = get_imputed_data(mab_pt_effect_refactored=mab_refactored_dt, mab_pt_effect=mab_dt, impute_vars=imputevars, impute_method="pmm", evaluate=FALSE, treatInclude=TRUE) 
fwrite(mab_pmm_dt, file=file.path(imputeDir, "data", "mab_patient_effect_imputed.csv") ) 

cat("\n Run Predictive Mean Matching (PMM) imputation without treatment status for DRS\n")
mab_pmm_drs_dt = get_imputed_data(mab_pt_effect_refactored=mab_refactored_dt, mab_pt_effect=mab_dt, impute_vars=imputevars, impute_method="pmm", evaluate=FALSE, treatInclude=FALSE) 
fwrite(mab_pmm_drs_dt, file=file.path(imputeDir, "data", "mab_patient_effect_imputed_no_treatment.csv") ) 

cat("\n Generate Predictive Mean Matching (PMM) imputation evaluation data and plots \n")
mab_pmm_mcmc_dt = get_imputed_data(mab_pt_effect_refactored=mab_refactored_dt, mab_pt_effect=mab_dt, impute_vars=imputevars, impute_method="pmm", evaluate=TRUE, treatInclude=TRUE) 
fwrite(mab_pmm_mcmc_dt, file=file.path(imputeDir, "data", "mab_pmm_mcmc.csv") ) 

cat("\n Imputation complete. \n")
