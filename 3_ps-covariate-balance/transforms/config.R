#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This script imports relevant libraries and defines global features names used in covariate_balance.R
## Date: May 2022
## Developers: Lauren D'Arinzo
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# load packages
library(arrow, warn.conflicts = FALSE)
library(cobalt)
library(tidyverse)
library(ggplot2)
library(data.table)

# the following confounders used to fit the propensity score were subdivided for plotting purposes
# see 2_ps/README.md for a diagram of all confounders that were used to fit the propensity model

# demographic confounders
demos = c("age_group", "birthsex", "race", "ethnicity")

# socioeconomic status confounders
ses = c("zip3_adi", "zip3_pop_density","marital_status", "insurance_category")

# health system confounders
health_system_covariates = c("health_system", "total_visits", "diagnosis_epoch", "pandemic_phase", "out_of_state")

# immunization-related confounders
vaccine_covariates = c("most_recent_sarscov2_immunization_cat", "immunized_sarscov2_status")

# top 10 conditions
# NOTE: All available conditions were used to fit the PS model, but viewing 60+ covariates in one plot was not optimal
top10_conditions = c("condition_hypertension_uncomplicated_vs","condition_diabetes_without_chronic_complications_vs",
                     "condition_cardiac_arrythmia_vs",
                     "condition_depression_vs",
                     "condition_other_chronic_respiratory_disease_vs",
                     "condition_hypothyroidism_vs",
                     "condition_diabetes_with_chronic_complications_vs",
                     "condition_deficiency_anemias_vs",
                     "condition_cad_vs",
                     "condition_hypertension_complicated_vs", "obese", "pregnant", "smoke_status", "immunosuppressant_prev90days")