#!/bin/bash

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Execute all pipeline scripts
## Date: May 2022
## Developers: N Welch & L D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# USAGE: bash main.sh 
# RETURN VALUE: NULL

src=$(pwd) 

echo "Imputing missing data"
Rscript 1_imputation/main_imputation.R $src

echo "Estimating disease risk scores"
python 2_drs/main_drs.py $src

echo "Estimating propensity to treat scores"
python 2_ps/main_ps.py $src

echo "Assessing covariate balance"
Rscript 3_ps-covariate-balance/main_covariate_balance.R $src

echo "Fitting marginal structural models"
Rscript 4_msm/main_msm.R $src

echo "Pipeline execution complete"
