#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This script executes the functions defined in the RScripts found in 4_msm/scripts
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# load all relevant functions
source("4_msm/transforms/config.R")
source("4_msm/transforms/group_vectors/pandemic_phase_group_vectors.R")
source("4_msm/transforms/group_vectors/vaccine_status_group_vectors.R")
source("4_msm/transforms/group_vectors/ATE_group_vectors.R")
source("4_msm/transforms/msm_input.R")

source("4_msm/transforms/msm_effect_wgraph_vals.R")
source("4_msm/transforms/msm_effect_wgraph_vals_pooled.R")
source("4_msm/transforms/format_results/probability_results.R")
source("4_msm/transforms/format_results/msm_prob_results.R")
source("4_msm/transforms/evalues.R")


source("4_msm/transforms/msm_effect_timevarying.R")
source("4_msm/transforms/msm_effect_timevarying_pooled.R")
source("4_msm/transforms/format_results/prob_timevarying.R")
source("4_msm/transforms/format_results/msm_product_prob_results.R")

source("4_msm/transforms/plotting/ATE_plot.R")
source("4_msm/transforms/plotting/immunized_status_plot.R")
source("4_msm/transforms/plotting/pandemic_phase_plot.R")

# set seed
set.seed(123)

# read in relevant inputs
impute_pmm <- read.csv("1_imputation/data/mab_patient_effect_imputed.csv")
best_model_pscores <- read.csv("3_ps-covariate-balance/data/best_model_pscores.csv")

# execute pipeline

# preprocessing
pandemic_phase_group_vectors_df <- pandemic_phase_group_vectors()
vaccination_status_group_vectors_df <- vaccination_status_group_vectors()
ATE_group_vectors_df <- ATE_group_vectors()
msm_input_df <- msm_input(best_model_pscores,impute_pmm)

# ATE and effect modifier results 
msm_effect_wgraph_vals_df <- msm_effect_wgraph_vals(msm_input_df, pandemic_phase_group_vectors_df,
                                                    vaccination_status_group_vectors_df, ATE_group_vectors_df, 
                                                    outcome_vars, whole_population_em, immunized_subpo, effect_modifiers)

msm_effect_wgraph_vals_pooled_df <- msm_effect_wgraph_vals_pooled(msm_effect_wgraph_vals_df) 
probability_results_df <- probability_results(msm_effect_wgraph_vals_pooled_df)
msm_prob_results_df <- msm_prob_results(probability_results_df, effect_modifier_order, treatment_status_order, effect_modifier_value_order, model_order)
evalues_df <- evalues(msm_effect_wgraph_vals_pooled_df)

# write out results
write.csv(msm_prob_results_df, "4_msm/data/msm_prob_results.csv", row.names = FALSE)
write.csv(evalues_df, "4_msm/data/evalues.csv", row.names = FALSE)

# Time-varying effect modifier results
msm_effect_timevarying_df <- msm_effect_timevarying(msm_input_df)
msm_effect_timevarying_pooled_df <- msm_effect_timevarying_pooled(msm_effect_timevarying_df)
prob_timevarying_df <- prob_timevarying(msm_effect_timevarying_pooled_df)
mab_product_prob_results_df <- mab_product_prob_results(prob_timevarying_df)
write.csv(mab_product_prob_results_df, "4_msm/data/mab_product_prob_results_df.csv", row.names = FALSE)

# create and save plots
ggsave('4_msm/figures/ATE_plot.png', plot = ATE_plot(probability_results_df, outcome_order, treatment_status_order, effect_modifier_value_order), bg='white')
ggsave('4_msm/figures/immunized_status_plot.png', plot = immunized_status_plot(probability_results_df, outcome_order, treatment_status_order, effect_modifier_value_order), bg='white')
ggsave('4_msm/figures/pandemic_phase_plot.png', plot = pandemic_phase_plot(probability_results_df, outcome_order, treatment_status_order, effect_modifier_value_order), bg='white')

