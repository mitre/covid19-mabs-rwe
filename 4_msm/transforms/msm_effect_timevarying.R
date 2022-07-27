##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function fits the marginal structural model for time-varying effect modifiers, like mAb type
## Date: May 2022
## Developers: Fraser Gaspar
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

msm_effect_timevarying <- function(msm_input) {
  
  n_impute = max(msm_input$impute_id)
  time_varying_effect_modifiers = c('mab_product')
  
  msm_output = data.frame()
  graph_values = data.frame()
  
  variant_var = c('pandemic_phase', 'who_variant_cat')
  msm_output = bind_rows(lapply(1:n_impute, function(i){
    impute_dat = msm_input[msm_input$impute_id == i,]
    bind_rows(lapply(variant_var, function(j){
      timeframes = sort(unique(impute_dat[[j]]))
      timeframes = timeframes[!is.na(timeframes)]
      bind_rows(lapply(timeframes, function(k){
        dat = impute_dat[impute_dat[[j]] == k & !is.na(impute_dat[[j]]),]
        prob_treat = mean(dat$treatment_group)
        print('prob of treatment:'); print(prob_treat)
        # Filter on just treated
        treat_dat = dat %>%
          filter(treatment_group == 1)
        # Joint probability of product
        prob_a_q_dat = treat_dat %>%
          group_by(mab_product) %>%
          summarise(prob_a_q = n()/nrow(treat_dat))
        
        print(prob_a_q_dat)
        # Probability of product by diagnosis epoch: p(q|x)
        prob_q_x_dat = treat_dat %>%
          group_by(diagnosis_epoch) %>%
          mutate(n_diagnosis_epoch = n()) %>%
          ungroup() %>%
          group_by(mab_product, diagnosis_epoch) %>%
          summarise(prob_q_x = n()/n_diagnosis_epoch[1])
        
        print(prob_q_x_dat)
        # Make effectiveness dataset with probs; calculate stabilized weights
        effect_dat = left_join(dat, prob_a_q_dat) %>%
          left_join(., prob_q_x_dat) %>%
          mutate(ate_weights = ifelse(treatment_group == 0, (1 - prob_treat)/(1-prop_score),
                                      prob_a_q/(prop_score*prob_q_x)))
        print('stabilized weights:')
        print(summary(effect_dat$ate_weights))
        
        # Refactor mab_product levels
        mabs = sort(unique(effect_dat$mab_product))
        effect_dat$mab_product = ifelse(is.na(effect_dat$mab_product ), 'untreated', effect_dat$mab_product )
        effect_dat$mab_product = factor(effect_dat$mab_product, levels = c('untreated', mabs))
        print('n rows ='); print(nrow(effect_dat))
        bind_rows(lapply(outcome_vars, function(l) {
          print(i); print(j); print(k); print(l)
          # GLM formula
          fmla_char = sprintf("%s ~ mab_product", l)
          fmla = as.formula(fmla_char)
          fit = glm(fmla, data = effect_dat, family='binomial', weights = effect_dat$ate_weights)
          print(fit)
          variable = names(fit$coefficients)
          variable = gsub("[(]|[)]", "", variable)
          summ_fit = summary(fit)
          est = summ_fit$coefficients[,1]
          std_error = summ_fit$coefficients[,2]
          # Get the standard errors for the coefficients from the sandwiched (robust) var/covar matrix
          varcovar_mat = sandwich::sandwich(fit) 
          print(varcovar_mat)
          sand_std_error = sqrt(diag(varcovar_mat))
          
          z_val = est/std_error
          n = length(fit$residuals)
          # Get bootstrapped versions of the robust standard errors.
          boot_sand_std_error = sqrt(diag(sandwich::vcovBS(fit, R=1)))
          
          # Calculate probabilities
          groupings = as.data.frame(matrix(0, nrow(varcovar_mat), ncol(varcovar_mat)))
          groupings[1,] = 1
          diag(groupings) = 1
          colnames(groupings) = levels(effect_dat$mab_product)
          
          bind_rows(lapply(colnames(groupings), function(col){
            subgroup_col <- groupings[[col]]
            
            # Get predicted log odds. Convert it to a numeric to avoid issues with
            # putting it in a data frame.
            logodd_pred <- as.numeric(est %*% subgroup_col)
            
            # And get standard error of that prediciton. Again convert to numeric so
            # that it can be put into data frame.
            logodd_std_err <- sqrt(as.numeric(subgroup_col %*% varcovar_mat %*% subgroup_col))
            
            # Get the treatment status and effect modifier values by splitting the column name.            
            # Put all of this in a row of a data frame and append it to the larger data frame.
            data.frame(
              'timeframe' = k,
              'outcome'=l,
              'variant_variable'=j,
              'treatment_status'= col,
              'log_odds'= logodd_pred,
              'sandwich_std_error'= logodd_std_err,
              'n'=n,
              'n_group' = sum(effect_dat$mab_product == col),
              'impute_id'=i)
          }))
        }))
      }))
    }))
  })
  )
  
  msm_output = msm_output %>%
    as.data.frame()
  
  return(msm_output)
}