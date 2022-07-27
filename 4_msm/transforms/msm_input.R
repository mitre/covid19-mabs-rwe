##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function performs preprocessing before fitting the Marginal Structural Model
## Date: May 2022
## Developers: Fraser Gaspar, Lauren D'Arinzo, Max Olivier
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

# Merge the propensity scores onto the original data set.
msm_input <- function(best_model_pscores, make_category_effect_modifiers) {
  
  require(dplyr)
  is_integer64 <- function(x){
    class(x)=='integer64'
  }
  
  # Pull out the identifiers (person and impute id) and propensity scores from the best propensity model. 
  best_model_pscores <- best_model_pscores %>% select(person_id, impute_id, prop_score)
  
  # Make sure the person ID's can join across imputed and propensity data by giving them the same format.
  best_model_pscores$person_id <- tolower(best_model_pscores$person_id)
  make_category_effect_modifiers$person_id <- tolower(make_category_effect_modifiers$person_id)
  
  # Bin race-ethnicity
  make_category_effect_modifiers$race_ethnicity <- ifelse(grepl('[wW]hite', make_category_effect_modifiers$race), 
                                                          ifelse(is.na(make_category_effect_modifiers$ethnicity), 'White-nonHispanic',
                                                                 ifelse(grepl('[nN]ot', make_category_effect_modifiers$ethnicity), 'White-nonHispanic', 'White-Hispanic')),
                                                          ifelse(grepl('[bB]lack', make_category_effect_modifiers$race), 'African_American', 'Other'))
  
  # Define immunocompromised status
  immuno_vars = c('condition_other_immune_deficiency_vs', 'condition_acquired_immune_deficiency_syndrome_vs', 'immunosuppressant_prev90days', 'condition_solid_organ_or_blood_stem_cell_transplantation_vs')
  make_category_effect_modifiers <- make_category_effect_modifiers  %>%
    mutate_if(is_integer64, as.integer) %>%
    mutate(immunocompromised = rowSums(.[immuno_vars]) >= 1)

  
  # Do an inner join of the relevant variables from the raw imputed data (person and impute identifiers, 
  # outcome variables and effect modifers, the latter two of which are defined in the config file) with 
  # the propensity data from above to create a merged data set that will be used going forward.
  # make_category_effect_modifiers <- make_category_effect_modifiers %>% inner_join(., bin_drs, by = c('person_id', 'impute_id'))
  
  multi_effect_dat <- make_category_effect_modifiers %>% 
    as.data.frame() %>% inner_join(., best_model_pscores, by = c('person_id', 'impute_id'))
  
  # We isolated two periods as potentially anomalous periods at the time of analysis
  # Label January 2022 as Omicron and Label Dec 2021 as mixed Delta/Omicron
  multi_effect_dat$pandemic_phase = ifelse(multi_effect_dat$diagnosis_epoch == '202201', 'omicron',
                                           ifelse(multi_effect_dat$diagnosis_epoch == '202112', 'delta_omicron', multi_effect_dat$pandemic_phase))
  
  multi_effect_dat$pandemic_phase_immunization = paste(multi_effect_dat$pandemic_phase, multi_effect_dat$immunized_sarscov2_status)
  multi_effect_dat$pandemic_phase_drs = paste(multi_effect_dat$pandemic_phase, multi_effect_dat$drs_cat)
  
  # Recode empty strings as missing
  # These instances are patients who did not receive mAbs
  multi_effect_dat$mab_product[multi_effect_dat$mab_product == ""] = NA
  
  return(multi_effect_dat)
}