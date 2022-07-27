#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function ensures that imputation input data are the correct data types and can be 
##          used to preprocess the raw input data before executing the imputation step.
## Date: May 2022
## Developers: N Welch
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

mab_pt_effect_refactored <- function(mab_pt_effect) {

    dt.all = as.data.table( mab_pt_effect )
    dt.x = dt.all[, lapply(.SD, as.integer), .SDcols=(names(dt.all) %like% "condition_|_prev90days|covid19_")]
    dt.xpid = cbind(dt.all[,.(person_id)], dt.x)

    dt.pt = dt.all[
        ,.( #############################
            ### DEMOGRAPHIC VARIABLES ###
            #############################
            health_system,
            diagnosis_epoch=as.integer(diagnosis_epoch), 
            age_group,
            birthsex,
            pregnant=as.integer(pregnant),
            race,
            ethnicity,
            bmi=as.numeric(bmi),
            obese=as.integer(obese),
            total_visits=as.integer(total_visits),
            insurance_category,
            marital_status,
            smoke_status,
            zip3_pop_density,
            zip3_adi,
            out_of_state=as.integer(out_of_state),
            elixhauser_mortality_index=as.integer(elixhauser_mortality_index),
            ######################
            ### PATIENT VITALS ###
            ######################
            temp_c_mean, 
            temp_c_day,
            heart_rate_mean, 
            heart_rate_day,
            resp_rate_mean, 
            resp_rate_day,
            syst_bp_mean, 
            syst_bp_day,
            diast_bp_mean, 
            diast_bp_day,
            o2_sat_mean, 
            o2_sat_day,
            #######################
            ### COVID VARIABLES ###
            #######################
            symptom_onset=as.numeric(symptom_onset),
            immunized_sarscov2_status=immunized_sarscov2_status,
            #########################
            ### OUTCOME VARIABLES ###
            #########################
            outcome_ed=1*(ed_14d==1 | ed_30d==1),
            outcome_inpt=1*(inpt_14d==1 | inpt_30d==1),
            outcome_death=1*(death_14d==1 | death_30d==1), 
            treatment_group=as.numeric(treatment_group)
            ), 
        by=person_id
    ][!is.na(health_system)]

    # combine data tables and remove anyone with a missing state designation
    dt = merge(dt.pt, dt.xpid, by="person_id")

    dt[,imputed_vitals:=0]
    dt[(temp_c_day!=0 | is.na(temp_c_day) |
        heart_rate_day!=0 | is.na(heart_rate_day) |
        resp_rate_day!=0 | is.na(resp_rate_day) |
        syst_bp_day!=0 | is.na(syst_bp_day) |
        diast_bp_day!=0 | is.na(diast_bp_day) |
        o2_sat_day!=0 | is.na(o2_sat_day)
        ), imputed_vitals:=1
    ]

    # drop vital measurement day
    #dt[,`:=`(temp_c_day=NULL, heart_rate_day=NULL, resp_rate_day=NULL, syst_bp_day=NULL, diast_bp_day=NULL, o2_sat_day=NULL)]

    dt[,imputed_demographics:=0]
    dt[(is.na(age_group) | 
        is.na(birthsex) | 
        is.na(race) | 
        is.na(ethnicity) | 
        is.na(bmi) ), 
        imputed_demographics:=1
    ]

    return( dt )
}
