#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This script executes the functions defined in the RScripts found in 3_ps-covariate-balance/scripts
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# load all relevant functions
source("3_ps-covariate-balance/transforms/config.R")
source("3_ps-covariate-balance/transforms/preprocessing.R")
source("3_ps-covariate-balance/transforms/covariate_balance_assessment.R")
source("3_ps-covariate-balance/transforms/model_selection.R")
source("3_ps-covariate-balance/transforms/best_model_pscores.R")
source("3_ps-covariate-balance/transforms/plotting/demos_loveplot.R")
source("3_ps-covariate-balance/transforms/plotting/top10conditions_loveplot.R")
source("3_ps-covariate-balance/transforms/plotting/healthsystem_loveplot.R")
source("3_ps-covariate-balance/transforms/plotting/ses_loveplot.R")
source("3_ps-covariate-balance/transforms/plotting/vaccines_loveplot.R")

# set seed 
set.seed(123)

# read in relevant inputs
ps_merge_models <- fread('2_ps/data/merge_models.csv')
get_dataframe <- fread('2_ps/data/get_dataframe.csv')

# preprocessing 
covariate_balance_input_df <- preprocessing(ps_merge_models, get_dataframe)

# execute evaluation 
covariate_balance_assessment_df <- covariate_balance_assessment(covariate_balance_input_df)

# write out intermediate model comparison results
write.csv(covariate_balance_assessment_df, '3_ps-covariate-balance/data/aggregate_covariate_balance_model_comparison.csv', row.names=FALSE)

# select best model
model_selection_df <- model_selection(covariate_balance_input_df, covariate_balance_assessment_df)
best_model_pscores_df <- best_model_pscores(model_selection_df)

# write out final outputs for downstream use
write.csv(best_model_pscores_df, '3_ps-covariate-balance/data/best_model_pscores.csv', row.names = FALSE)

# store covariate balance plots
ggsave('3_ps-covariate-balance/figures/demos_loveplot.png', plot = love.plot.demos(model_selection_df, demos), bg='white')
ggsave('3_ps-covariate-balance/figures/top10conditions_loveplot.png', plot = love.plot.top10conditions(model_selection_df, top10_conditions), bg='white')
ggsave('3_ps-covariate-balance/figures/healthsystem_loveplot.png', plot = love.plot.health_system(model_selection_df, health_system_covariates), bg='white')
ggsave('3_ps-covariate-balance/figures/ses_loveplot.png', plot = love.plot.ses(model_selection_df, ses), bg='white')
ggsave('3_ps-covariate-balance/figures/vaccines_loveplot.png', plot = love.plot.vaccines(model_selection_df, vaccine_covariates), bg='white')


