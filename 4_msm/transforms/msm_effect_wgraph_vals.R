##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function fits the marginal structural model for the ATE and effect modifiers
## Date: May 2022
## Developers: Fraser Gaspar, Lauren D'Arinzo, Max Olivier
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

msm_effect_wgraph_vals <- function(msm_input, pandemic_phase_group_vectors, vaccination_status_group_vectors, ATE_group_vectors, outcome_vars, whole_population_em, immunized_subpop, effect_modifiers) {
  
  ##### FULL POPULATION (no subsetting)#####
  # Select only relevant features for this population
  full_population <- msm_input %>% 
    select('person_id', 'impute_id','treatment_group', 'prop_score', outcome_vars, whole_population_em)
  # Print sample sizes and NA check
  print_checks('FULL POPULATION', full_population)
  # Define ordinal factor levels that correspond to group vectors 
  full_population$pandemic_phase <- factor(full_population$pandemic_phase, levels = c('pre_delta', 'delta', 'delta_omicron', 'omicron'))
 
  ##### IMMUNIZED SUBPOPULATION #####
  # NOTE: Immunization analyses are not conducted on full population 
  # because some patients received non-US authorized vaccines are excluded from these specific analyses
  immunized_subpop <- msm_input %>% filter(!(immunized_sarscov2_status == 'no' & other_count > 0)) %>% select('person_id', 'impute_id','treatment_group', 'prop_score', outcome_vars, immunization_subpop_em)
  print_checks('IMMUNIZATION POPULATION', immunized_subpop)
  # Define ordinal factor levels that correspond to group vectors 
  immunized_subpop$immunized_sarscov2_status <- factor(immunized_subpop$immunized_sarscov2_status, levels=c('no', 'partial', 'full', 'full_boosted'))

  
  ##### EFFECT ESTIMATES FOR EACH IMPUTE GROUP, OUTCOME, EFFECT MODIFIER COMBO #####
  n_impute = max(msm_input$impute_id)
  
  msm_output = data.frame()
  graph_values = data.frame()
  
  for(i in 1:n_impute) {
    for(j in c('none', effect_modifiers)) {
      for(k in outcome_vars) {
        print(i);print(j);print(k)
        
        if (j %in% c('none')) {
          print(paste(" ", "performing ATE weighting routine"))
          # Set effect dat to be the relevant population
          effect_dat = full_population[full_population$impute_id == i, ]
          # Get probability of treatment
          prob_treat = sum(effect_dat$treatment_group)/nrow(effect_dat)
          # Stabilized weights
          ate_weights = ifelse(effect_dat$treatment_group == 1, 
                               prob_treat/effect_dat$prop_score, (1 - prob_treat)/(1-effect_dat$prop_score))
          
          if (j == 'none'){
            fmla_char = sprintf("%s ~ treatment_group", k)
          }
          else if (j == 'days_dx_to_first_mab_cat'){
            fmla_char = sprintf("%s ~ days_dx_to_first_mab_cat", k)
          }
          fmla = as.formula(fmla_char)
        } else {
          print(paste(" ", "performing effect modifier importance weighting routine"))
          # Set effect dat based on correct subpopulation
          if (j %in% whole_population_em){
            print(paste(" ", "full population"))
            effect_dat = full_population[full_population$impute_id == i, ]
          } else if (j %in% immunization_subpop_em){
            print(paste(" ", "immunization subpopulation"))
            effect_dat = immunized_subpop[immunized_subpop$impute_id == i, ]
          } else if (j %in% symptom_onset_subpop_em){
            print(paste(" ", "symptom onset subpopulation"))
            effect_dat = symptom_onset_subpop[symptom_onset_subpop$impute_id == i, ] 
          } else if (j %in% genomics_subpop_em){
            print(paste(" ", "genomics subpopulation"))
            effect_dat = genomics_subpop[genomics_subpop$impute_id == i, ] 
          } else if (j %in% genomics_immunization_subpop_em){
            print(paste(" ", "genomics*immunization subpopulation"))
            effect_dat = genomics_immunization_subpop[genomics_immunization_subpop$impute_id == i, ]
          }
          
          # Get empirical prob of treatment and effect modifier
          prob_dat = effect_dat %>% 
            group_by(.data[[j]]) %>% 
            summarise(
              prob_a0_q = sum(treatment_group == 0)/n(),
              prob_a1_q = sum(treatment_group == 1)/n()
            )
          effect_dat = inner_join(effect_dat, prob_dat)
          
          # Stabilized weights
          ate_weights = ifelse(effect_dat$treatment_group == 1, 
                               effect_dat$prob_a1_q/effect_dat$prop_score, effect_dat$prob_a0_q/(1-effect_dat$prop_score))
          # GLM formula
          fmla_char = sprintf("%s ~ treatment_group + treatment_group*%s", k, j)
          fmla = as.formula(fmla_char)
          
          effect_dat$prob_a1_q = effect_dat$prob_a0_q = NULL
          
        }
        
        print(max(ate_weights))
        
        # Fit logistic regression, capture outputs
        fit = glm(fmla, data = effect_dat, family='binomial', weights = ate_weights)
        variable = names(fit$coefficients)
        variable = gsub("[(]|[)]", "", variable)
        summ_fit = summary(fit)
        est = summ_fit$coefficients[,1]
        std_error = summ_fit$coefficients[,2]
        # Get the standard errors for the coefficients from the sandwiched (robust) var/covar matrix
        varcovar_mat = sandwich::sandwich(fit) 
        sand_std_error = sqrt(diag(varcovar_mat))
        z_val = est/std_error
        n = length(fit$residuals)
        # Get bootstrapped versions of the robust standard errors.
        boot_sand_std_error = sqrt(diag(sandwich::vcovBS(fit, R=1)))
        # If number of patients changes based on effect modifier, need to capture n.
        model_out = data.frame(
          'outcome' = k,
          'effect_modifier' = j,
          'model' = fmla_char,
          'variable' = variable,
          'coefficient' = est,
          'std_error' = std_error,
          'sandwiched_std_error' = sand_std_error,
          'z_val' = z_val,
          'boot_sandwiched_std_error' = boot_sand_std_error,
          'n' = n,
          'impute_id' = i
        )
        
        msm_output <- rbind(msm_output, model_out)
        
        # Pick the correct data frame depending on the effect modifier under consideration.
        groupings <- switch(j, 'none' = ATE_group_vectors,
                            'immunized_sarscov2_status'=vaccination_status_group_vectors,
                            'pandemic_phase'=pandemic_phase_group_vectors
        )
        
        # For each of the columns in the data frame that gives the correct subgroup 
        # identification vectors, get the predicted output and standard error of the 
        # prediction (both in terms of log odds) for the subgroup identified by the 
        # vector. We do this with some matrix multiplication.  
        for(colnum in 1:ncol(groupings)) {
          col = colnames(groupings)[colnum]
          subgroup_col <- groupings[[col]]
          
          # Get predicted log odds. Convert it to a numeric to avoid issues with
          # putting it in a data frame.
          logodd_pred <- as.numeric(est %*% subgroup_col)
          
          # And get standard error of that prediction. Again convert to numeric so
          # that it can be put into data frame.
          logodd_std_err <- sqrt(as.numeric(subgroup_col %*% varcovar_mat %*% subgroup_col))
          
          # We want to get the treatment status and the level of the effect modifer that correspond
          # to this transformed coefficient. We also want a count of the number of people with that
          # treatment status and effect modifier level as well as the number of people with the specific
          # outcome in the treatment status/effect modifier. To do this we can use the structure of the 
          # transformation vectors, which combine coefficients to output results in the order: 
          # untreated-levelA, treated-levelA, untreated-levelB,treated-levelB, etc. The only effect 
          # modifer that this does not apply for is "days_dx_to_first_mab_cat", so we deal with this
          # one separately. Similarly, if the effect modifer given by "j" is "none" we don't have an
          # effect modifer to count.
          #
          # Get initital values of the vartiables to report out. Given the ordering of transformation 
          # vectors described above, the treatment status is determined by whether we are currenty at
          # an even or odd index when looping through the columns of "groupings": odd indices are 
          # untreated (0's) and even ones are treated (1's). These values are final and correct for all
          # effect modifers except "days_dx_to_first_mab_cat". The variables tracking the effect modifer
          # level and number of , "effect_mod_level" and "group_size" are just defaults for now.
          treat_stat = (colnum-1) %% 2
          effect_mod_level = "none"
          group_size = 0
          n_outcome_group = 0
          
          # Get correct "treat-stat" and "effect_mod_level" values by dealing with weird case of days to
          # first mab category and no effect modifer.
          if(j=="days_dx_to_first_mab_cat") {
            # In this case there are only 3 vectors. The level of the treatment is the column number in 
            # the levels list, and the treatment status is 0 for "colnum" 1 and 1 for the other two. So
            # change treatment status if "colnum" is three since that is the only incorrect one.
            effect_mod_level = levels(effect_dat[[j]])[colnum] 
            if(colnum %in% c(3,4)) {
              treat_stat=1
            }
          } else if(j !="none") {
            effect_mod_level = levels(effect_dat[[j]])[floor((colnum+1)/2)]
          }
          
          # Get the group size and number of people with the outcome under consideration with the group. The
          # group size is different if there is an effect modifer or not. 
          if(j=="none") {
            # If there is no effect modifer, we are looking at all treated/untreated.
            group_size = effect_dat %>% filter(treatment_group==treat_stat) %>% count() %>% pull()
            n_outcome_group = sum(effect_dat[effect_dat$treatment_group==treat_stat, k]==1)
          }
          else {
            # When there is an effect modifier, to get the group size create a boolean vector with number of 
            # rows equal to the whole of "effect_dat" that has indicators for locations where the applicable
            # effect modifer column contains the effect modifer level we are looking at and the 
            # treated/non-treated status matches "treat_stat". The sum of this vector is the group size. To
            # get the number of instances of the current outcome for this subset just AND the above boolean 
            # vector with a boolean vector over the whole data frame identifying that the outcome occured 
            # and take the sum. All the boolean comparisons need to be over the whole data set or we end up
            # missing outcome values due to subsetting some out. Unfortunately can't easily use dplyr syntax
            # here to subset.
            bools = (effect_dat[,"treatment_group"]==treat_stat) & (effect_dat[,j] == effect_mod_level)
            group_size = sum(bools)
            n_outcome_group = sum(bools & effect_dat[,k]==1)
          }
          
          print(effect_mod_level)
          
          # Put all of this in a row of a data frame and append it to the larger data frame.
          curr_row = data.frame(
            'outcome'=k,
            'effect_modifier'=j,
            'treatment_status' = treat_stat,
            'effect_modifier_value'= effect_mod_level,
            'log_odds'= logodd_pred,
            'sandwich_std_error'= logodd_std_err,
            'n'=n,
            'total_in_group' = group_size,
            'outcomes_in_group' = n_outcome_group,
            'impute_id'=i)
          graph_values <- rbind(graph_values, curr_row)
        }
        
      }
    }
  }
  graph_values <- graph_values %>% mutate(treatment_status = recode(treatment_status, `1`= "treated", `0`= "untreated"))
  
  return(graph_values)
  }