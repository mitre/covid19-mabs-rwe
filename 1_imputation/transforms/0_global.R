#!/usr/bin/env Rscript

##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Main imputation & evaluation methods along with global variables
## Date: May 2022
## Developers: N Welch
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

library(data.table)
library(magrittr)
library(dplyr)
library(reshape2)
library(stringr)
library(ggplot2)
library(cowplot)
library(mice)
library(scales)
theme_set( theme_cowplot() )


is_integer64 <- function(x){ class(x)=="integer64" }

treat = rgb(red=102, green=197, blue=171, maxColorValue=255)
notreat = rgb(red=51, green=34, blue=136, maxColorValue=255)


##########################
# IMPUTATION DIAGNOSTICS #
##########################

getMcmcTracePlot = function(data, var){
    dt = as.data.table( data )[variable==var]
    systems = dt[,unique(health_system)] %>% sort()
    nsystems = length( systems )
    meanRange = range( dt$mean )
    varRange = range( dt$variance )
    plots = list()
    for(s in systems){
        meanPlot = 
            ggplot(dt[health_system==s], aes(x=iter, y=mean, col=chain, group=chain)) + 
            geom_line() + 
            scale_x_continuous(breaks= pretty_breaks()) +
            xlab("") +
            coord_cartesian(ylim=meanRange) + 
            theme(legend.position="none")
        varPlot = 
            ggplot(dt[health_system==s], aes(x=iter, y=variance, col=chain, group=chain)) + 
            geom_line() + 
            scale_x_continuous(breaks= pretty_breaks()) +
            xlab("") +
            coord_cartesian(ylim=varRange) + 
            theme(legend.position="none")
        title = ggdraw() + draw_label(paste(s, var), fontface='bold')
        meanVarPlot = plot_grid( meanPlot, varPlot, nrow=1, ncol=2 )
        meanVarPlotTitle = plot_grid(title, meanVarPlot, ncol=1, rel_heights=c(0.1, 1))
        plots[[s]] = meanVarPlotTitle 
    }
    out = plot_grid(plotlist=plots, nrow=nsystems)
    print( out )
}


getDensityPlot = function(imputeData, obsData, var){
    imp = as.data.table( imputeData )
    obs = as.data.table( obsData )
    imp[,impute_name:=factor(impute_id)]
    xrange = range( imp[,get(var)], obs[,get(var)], na.rm=TRUE )

    out = 
        ggplot() + 
        geom_density(data=imp, aes(x=get(var), col=impute_name)) +
        geom_density(data=obs[!is.na(get(var))], aes(x=get(var), col="Observed"), linetype="dashed") +
        xlab(var) + 
        ylab("Density") + 
        coord_cartesian(xlim=xrange) +
        theme(legend.title=element_blank(), legend.position="bottom",
            legend.justification="center") + 
        facet_grid(cols=vars(health_system), rows=vars(treatment_group))
    print(out)
}


######################
# Missing Rate Table #
######################

getImputeFields = function(){

    demographics = 
    c("birthsex", "race", "ethnicity", "marital_status", "insurance_category")

    other = 
    c("bmi", "zip3_pop_density", "zip3_adi", "immunized_sarscov2_status", "symptom_onset")  

    notvitals = c(demographics, other)
    nv = length( notvitals )

    vitals = 
    c( "diast_bp_mean", "heart_rate_mean", "o2_sat_mean", "resp_rate_mean", "syst_bp_mean", "temp_c_mean"
    )
    v = length(vitals)

    # Other variables to check for missingness that have been removed
    # Demographics: "age", "age_group"
    # Other: "pregnant", "smoke_status"

    df = data.table(field=c(notvitals, vitals), vital=c(rep(0, nv), rep(1, v)))

    return( df )

}


#######################
# IMPUTATION "ENGINE" #
#######################

getImputedData = function(rf_data, pt_data, hs, method="pmm", m.iter=2, gibbs.iter=2, eval=FALSE, treatmentIncluded=TRUE){

    dt = as.data.table( rf_data )[ health_system==hs][
        ,`:=`(  birthsex=factor(birthsex, levels=c("Female", "Male")),
                race=factor( race, 
                    levels=c(   "White", 
                                "Black or African American", 
                                "Asian", 
                                "Native Hawaiian or Other Pacific Islander", 
                                "American Indian or Alaska Native", 
                                "Other race")), 
                ethnicity=factor(ethnicity, 
                    levels=c("Not Hispanic or Latino", "Hispanic or Latino")),
                insurance_category=factor(insurance_category, 
                    levels=c(   "private_insurance", 
                                "medicare", 
                                "medicaid", 
                                "self_pay", 
                                "military_va_insurance", 
                                "other")), 
                marital_status=factor(marital_status, 
                    levels=c("Unmarried", "Married", "Divorced", "Widowed")),
                smoke_status=factor(smoke_status, 
                    levels=c("non_smoker", "smoker", "former_smoker")), 
                diagnosis_epoch=factor(diagnosis_epoch, 
                    levels=c(202011, 202012, 202101+0:11, 202201+0:2)
                ), 
                immunized_sarscov2_status=factor(immunized_sarscov2_status, 
                    levels=c("no", "partial", "full", "full_boosted")
                ),
                age_group=factor(age_group, 
                    levels=
                    c("[10-20)","[20-30)", "[30-40)", "[40-50)", "[50-60)", "[60-70)","[70-80)", "80+"           
                    )
                )
            )
    ]

    # Remove any variables that cannot be imputed or cause singularity issues for all health systems
    dt[,`:=`(   
            #day0_lineage=NULL, 
            elixhauser_mortality_index=NULL,
            total_visits=NULL,
            health_system=NULL,
            symptom_onset=NULL,
   	    temp_c_day=NULL,
	    heart_rate_day=NULL,
	    resp_rate_day=NULL,
	    syst_bp_day=NULL,
	    diast_bp_day=NULL,
	    o2_sat_day=NULL
		
        )
    ]

    # remove any variables that cannot be imputed or cause singularity issues for health system ZZ
    #if(hs=="ZZ"){
    #    dt[,`:=`(   
    #            resp_rate_mean=NULL, 
    #            syst_bp_mean=NULL
    #        )
    #    ]
    #}

    # Remove treatment status for DRS if treatmentIncluded=FALSE (default=TRUE)
    if(treatmentIncluded==FALSE) dt[,treatment_group:=NULL]

    # Initialize the imputation algorithm 
    ini = mice( dt, method="pmm", m=1, maxit=0, seed=123, printFlag=FALSE )
    pred = ini$pred
    meth = ini$method

    # Exclude id variables & imputation flags
    pred[,"person_id"] = 0
    pred[,"imputed_vitals"] = 0
    pred[,"imputed_demographics"] = 0

    # PMM imputation run
    if(method=="pmm"){
        imp = mice(dt, m=m.iter, method="pmm", predictorMatrix=pred, maxit=gibbs.iter)
    } 

    # Bayes imputation run
    if(method=="bayes"){
        # Continuous variable imputation method
        meth["bmi"] = "norm"
        meth["zip3_pop_density"] = "norm"
        meth["zip3_adi"] = "norm"
        meth["temp_c_mean"] = "norm"
        meth["heart_rate_mean"] = "norm"
        meth["resp_rate_mean"] = "norm"
        meth["syst_bp_mean"] = "norm"
        meth["diast_bp_mean"] = "norm"
        meth["o2_sat_mean"] = "norm"
        

        # Binary variable imputation method
        meth["birthsex"] = "logreg"
        meth["ethnicity"] = "logreg"

        # Categorical variable imputation method
        meth["race"] = "polyreg"
        meth["insurance_category"] = "polyreg"
        meth["marital_status"] = "polyreg"

        imp = mice(dt, m=m.iter, method=meth, predictorMatrix=pred, maxit=gibbs.iter)
    }

    # Bootstrap imputation run
    if(method=="boot"){
        # Continuous variable imputation method
        meth["bmi"] = "norm.boot"
        meth["zip3_pop_density"] = "norm.boot"
        meth["zip3_adi"] = "norm.boot"
        meth["temp_c_mean"] = "norm.boot"
        meth["heart_rate_mean"] = "norm.boot"
        meth["resp_rate_mean"] = "norm.boot"
        meth["syst_bp_mean"] = "norm.boot"
        meth["diast_bp_mean"] = "norm.boot"
        meth["o2_sat_mean"] = "norm.boot"

        # Binary variable imputation method
        meth["birthsex"] = "logreg.boot"
        meth["ethnicity"] = "logreg.boot"

        # Categorical variable imputation method
        meth["race"] = "polyreg"
        meth["insurance_category"] = "polyreg"
        meth["marital_status"] = "polyreg"

        imp = mice(dt, m=m.iter, method=meth, predictorMatrix=pred, maxit=gibbs.iter)
    }

    # CART imputation run
    if(method=="cart"){
        # Continuous variable imputation method
        meth["bmi"] = "cart"
        meth["zip3_pop_density"] = "cart"
        meth["zip3_adi"] = "cart"
        meth["temp_c_mean"] = "cart"
        meth["heart_rate_mean"] = "cart"
        meth["resp_rate_mean"] = "cart"
        meth["syst_bp_mean"] = "cart"
        meth["diast_bp_mean"] = "cart"
        meth["o2_sat_mean"] = "cart"

        # Binary variable imputation method
        meth["birthsex"] = "cart"
        meth["ethnicity"] = "cart"

        # Categorical variable imputation method
        meth["race"] = "cart"
        meth["insurance_category"] = "cart"
        meth["marital_status"] = "cart"

        imp = mice(dt, m=m.iter, method=meth, predictorMatrix=pred, maxit=gibbs.iter)
    }

    if(eval==FALSE){
        imputed = as.data.table( mice::complete(imp, action="long", include = TRUE) )
        imputed[,`:=`(impute_id=.imp, .imp=NULL, .id=NULL)]

        # Convert factors back to characters as needed
        imputed[,`:=`(  
                birthsex=as.character(birthsex), 
                race=as.character(race),
                ethnicity=as.character(ethnicity), 
                marital_status=as.character(marital_status),
                smoke_status=as.character(smoke_status),
                diagnosis_epoch=as.integer( as.character(diagnosis_epoch) ),
                immunized_sarscov2_status=as.character(immunized_sarscov2_status),  
                age_group=as.character(age_group), 
                insurance_category=as.character(insurance_category)
            )
        ]

        # Which columns are included in the imputed data
        imputeCols = colnames(imputed)
        imputeCols = imputeCols[!(imputeCols %in% c("person_id", "outcome_ed", "outcome_inpt", "outcome_death"))]

        # Get complement of columns in the imputed data
        ptdata = as.data.table( pt_data )[health_system==hs]
        ptCols = colnames( ptdata )
        ptCols = ptCols[!(ptCols %in% imputeCols)]
        ptcomplement = ptdata[,..ptCols]

        ptimputedcols = colnames( ptdata )
        ptimputedcols = ptimputedcols[ !(ptimputedcols %in% c("person_id", "health_system"))]
        ordercols = c("person_id", "health_system", "imputed_vitals", "imputed_demographics", "impute_id", ptimputedcols)
        
        out = 
            merge(imputed, ptcomplement, by="person_id") %>%
            setcolorder( ordercols ) %>%
            as.data.table() %>%
            .[impute_id>0] 

    } else {
        mcmcMean = 
            melt( imp$chainMean ) %>% 
            set_colnames(c("variable", "iter", "chain", "mean")) %>% 
            as.data.table() %>%
            .[!is.na(mean)] %>%
            .[,health_system:=hs]

        mcmcVar = 
            melt( imp$chainVar ) %>% 
            set_colnames(c("variable", "iter", "chain", "variance")) %>% 
            as.data.table() %>%
            .[!is.na(variance)] %>%
            .[,health_system:=hs]

        out = merge(mcmcMean, mcmcVar, by=c("health_system", "variable", "iter", "chain"))
    }

    df = as.data.frame( out )

    return( df )

}


