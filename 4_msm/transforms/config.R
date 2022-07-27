##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This script imports packages, defines global variables, and plotting utils
## Date: May 2022
## Developers: Lauren D'Arinzo, Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# package imports
library(arrow, warn.conflicts = FALSE)
library(boot)
library(dplyr)
library(tidyr)
library(Hmisc)
library(forcats)
library(gridExtra)
library(gtable)
library(grid)
library(sandwich)
library(EValue)
library(stringr)
library(tidyverse)
library(ggplot2)

# Plotting functions
effect_modifier_plot = function(dat, rm_legend = FALSE){
  p = ggplot(dat, aes(x=effect_modifier_value, y=round(prob,3), color=treatment_status)) + 
    geom_point(position=position_dodge(0.5), size = 1)  + 
    facet_wrap(vars(outcome), ncol=4, scales = "free_y") +
    scale_color_manual(values=c("#332288", "#66C5AB")) +
    geom_errorbar(aes(ymin = round(lb_prob,3), ymax = round(ub_prob,3)), size = 0.8, width = 0.3, 
                  position=position_dodge(width=0.5)) +
    ylab("Probability of Outcome\n") +
    xlab('') +
    scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
    theme_bw() +
    theme(axis.text.x = element_text(size=12, angle = 45, vjust = 1, hjust = 1), axis.text.y = element_text(size=10),
          axis.title = element_text(size=12), 
          legend.title = element_blank(), legend.text = element_text(size = 12),
          legend.direction = "horizontal", legend.position = "top", legend.box = "horizontal", 
          strip.text.x = element_text(size = 8), legend.key.width = unit(1, 'cm'))
  
  if(rm_legend){
    p = p +
      theme(legend.position = 'none')
  }
  
  return(p)
}

time_varying_effect_modifier_plot = function(dat){
  p = ggplot(dat, aes(x=treatment_status, y=round(prob,3), color=treatment_status)) + 
    geom_point(size = 1.2)  + 
    facet_grid(outcome ~ timeframe, scales = "free") +
    scale_color_manual(values=c("#332288", "#66C5AB", '#E0AFCA', '#9AD2F2', '#238C2C')) +
    geom_errorbar(aes(ymin = round(lb_prob,3), ymax = round(ub_prob,3)), size = 1.2, width = 0.3) +
    ylab("Probability of Outcome\n") +
    xlab('') +
    scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
    theme_bw() +
    theme(axis.text.x = element_text(size=12, angle = 45, vjust = 1, hjust = 1),
          axis.text.y = element_text(size=12),
          axis.title = element_text(size=12), legend.position = "none", 
          strip.text = element_text(size = 12), axis.title.y = element_text(size=14)) 
}

# Print sample size and NA checks to console output
print_checks <- function(pop_str, pop_df){
  print(pop_str)
  print(paste("  Patients in population:", nrow(pop_df)/5))
  if (any(is.na(pop_df)) == TRUE) {
    print(paste("  NULL values were found in this population. Review before proceeding"))}
  else if (any(is.na(pop_df)) == FALSE){
    print(paste("  Confirmed that no null values were found in this population"))}
  return(NULL)
}


# Global variables config
outcome_vars = c('ed_14d', 'inpt_14d', 'death_14d','death_inpt_14day', 'ed_30d', 'inpt_30d', 'death_30d', 'death_inpt_30day')
whole_population_em = c('pandemic_phase')
immunization_subpop_em = c('immunized_sarscov2_status')
effect_modifiers = c(whole_population_em, immunization_subpop_em)
effect_modifier_order = c('none', whole_population_em, immunization_subpop_em)

treatment_status_order = c('Non-treated' = 'untreated', 'Treated' = 'treated')

model_order = c('ED' = 'ed', 'Inpatient' = 'inpt', 'Death' = 'death', 'Death or Inpatient' = 'death_inpt')

effect_modifier_value_order = list(
  'pandemic_phase' = c('pre-Delta' = "pre_delta", 
                       'Delta' = "delta", 
                       'Delta/Omicron' = "delta_omicron",
                       'Omicron' = "omicron"),
  
  'immunized_sarscov2_status' = c(
    'No vaccine record' = "no", 
    'Partial' = "partial", 
    'Full' = "full", 
    'Full + boosted' = "full_boosted"),
  
  'most_recent_sarscov2_immunization_cat' = c(
    'No vaccine record'= "unvaccinated", 
    '<2 weeks' = "under_2weeks", 
    '2 weeks to <3 months' = "2weeks_3months", 
    '3 months to <6 months' = "3month_6month", 
    '>=6 months' = "6month+"),
  
  'race_ethnicity' = c(
    'White, Non-Hispanic'= "White-nonHispanic", 
    'White, Hispanic' = "White-Hispanic", 
    'African-American' = "African_American", 
    'Other' = "Other"),
  
  'drs_cat' = c(
    '<=20%'= "VeryLow", 
    '>20-40%' = "Low", 
    '>40-60%' = "Medium", 
    '>60-80%' = "High", 
    '>80%' = "VeryHigh"),
  
  'immunocompromised' = c(
    'Not\nimmunocompromised'= 'FALSE', 
    'Immunocompromised'= 'TRUE'),
  
  
  'who_variant_cat' = c('No WHO Equivalent' = 'no_WHO_equivalent',
                        'Epsilon' = "Epsilon",
                        'Alpha' = 'Alpha',
                        'Other' = 'Other',
                        "Delta 21AI" = "Delta_21AI",
                        "Delta 21J" = "Delta_21J",
                        'Omicron' = "Omicron"),
  
  
  'symptom_onset_cat' = c('Same day' = "0",
                          '1 to 10 days before' = "-10to-1", 
                          '11 to 17 days before' = "-17to-11"),
  
  
  'days_dx_to_first_mab_cat' = c('Non-treated' = "untreated",
                                 'Treated on day 0 or 1' = "ZeroToOne", 
                                 'Treated on day 2 or 3' = "TwoToThree",
                                 'Treated on day 4+' = "FourToNine"), 
  
  'none' = c('Treatment Status' = 'none'),
  
  'pandemic_phase_drs' = c('Pre-Delta Very Low'='pre_delta VeryLow',
                           'Pre-Delta Low' = 'pre_delta Low',
                           'Pre-Delta Medium' = 'pre_delta Medium',
                           'Pre-Delta High' = 'pre_delta High',
                           'Pre-Delta Very High' = 'pre_delta VeryHigh','Delta Very Low'='delta VeryLow',
                           'Delta Low' = 'delta Low',
                           'Delta Medium' = 'delta Medium',
                           'Delta High' = 'delta High',
                           'Delta Very High' = 'delta VeryHigh','Delta/Omicron Very Low'='delta_omicron VeryLow',
                           'Delta Omicron Low' = 'delta_omicron Low',
                           'Delta Omicron Medium' = 'delta_omicron Medium',
                           'Delta Omicron High' = 'delta_omicron High',
                           'Delta Omicron Very High' = 'delta_omicron VeryHigh','Omicron Very Low'='omicron VeryLow',
                           'Omicron Low' = 'omicron Low',
                           'Omicron Medium' = 'omicron Medium',
                           'Omicron High' = 'omicron High',
                           'Omicron Very High' = 'omicron VeryHigh')
)

outcome_order = c(
  'ED\nwithin 14 days' = 'ed_14d',
  'Hospitalized\nwithin 14 days' = 'inpt_14d',
  'Died\nwithin 14 days' = 'death_14d',
  'Hospitalized or died\nwithin 14 days' = 'death_inpt_14d',
  'ED\nwithin 30 days' = 'ed_30d',
  'Hospitalized\nwithin 30 days' = 'inpt_30d',
  'Died\nwithin 30 days' = 'death_30d',
  'Hospitalized or died\nwithin 30 days' = 'death_inpt_30d'
)

product_order = c('Non-treated' = 'untreated', 'Bamlanivimab' = 'bamlanivimab', 'Casirivimab-imdevimab' = 'casirivimab_imdevimab', 'Bamlanivimab-etesevimab' = 'bamlanivimab_etesevimab', 'Sotrovimab' = 'sotrovimab' )

timeframe_order = c('pre-Delta' = "pre_delta", 
                    'Delta' = "delta", 
                    'Delta/Omicron 2021-12' = "delta_omicron",
                    'Omicron 2022-01' = "omicron")

who_variant_immunization = c(
  'No vaccine record' = 'Delta_21AI_no',
  'Partial' = 'Delta_21AI_partial',
  'Full' = 'Delta_21AI_full',
  'Full + boosted' = 'Delta_21AI_full_boosted', 
  'No vaccine record' = 'Delta_21J_no',
  'Partial' = 'Delta_21J_partial',
  'Full' = 'Delta_21J_full',
  'Full + boosted' = 'Delta_21J_full_boosted', 
  'No vaccine record' = 'Omicron_no',
  'Partial' = 'Omicron_partial',
  'Full' = 'Omicron_full', 
  'Full + boosted' = 'Omicron_full_boosted')