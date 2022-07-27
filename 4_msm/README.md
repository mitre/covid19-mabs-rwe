# 4. Marginal Structural Models (MSM)

The scripts here are used fit the marginal structural model, compute effect estimates, and perform sensitivity analysis. MSMs are a generalized approach to inverse propensity score weighting methods for controlling confounding in observational studies[(Joffe et al. 2004, ](https://www.jstor.org/stable/27643582?seq=1)[VanderWeele 2012)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4249691/).

- Effect estimates are computed using weighted logistic regression
    - Input variables of the regression model are the treatment, the effect modifiers of interest, and products of the treatment and the effect modifiers
    - Output of the logistic regression model is presence or absence of an adverse outcome (i.e. Inpatient stay within 14 days of COVID-19 diagnosis)
- The MSM stabilized weight formula does not apply to mAbs treatment type, because treatment type is not defined for untreated patients 
    - The probability distribution of treatment types also changed over the course of the pandemic
        - Because this variable is dependent upon epoch, time-varying effect modifiers are analyzed within each epoch strata 
- Term coefficients of the fitted logistic regression are log odds. Log odds and their associated standard errors are converted to probabilities for more interpretable final results. In order to parse raw coefficients from logistic regression model terms into effect estimates that directly compare untreated and treated populations, grouping vectors were created to combine the appropriate model terms. See `transforms/group_vectors` for an example. Grouping vectors are unique to the factor levels of each effect modifiers. This repository contains example results for several effect modifiers, but if interested in additional effect modifiers, see `transforms/group_vectors/create_group_vectors.py` for a function that provides a template for making additional group vector scripts that can be used in an adapted `transforms/msm_effect_wgraph_vals.R` function.

- Effect estimates between impute groups are pooled to capture variation due to missing data in final results. Pooling is conducted according to [Rubin's Rules](https://bookdown.org/mwheymans/bookmi/rubins-rules.html).
- E-Values [(VanderWeele & Ding 2017)](https://www.acpjournals.org/doi/10.7326/M16-2607?doi=10.7326%2FM16-2607) were computed to evaluate the susceptibility of the results to unmeasured confounding.


## Code requirements and process
`main_msm.R` expects inputs matching the schemas of `1_imputation/data/mab_patient_effect_imputed.csv` and `3_ps-covariate-balance/data/best_model_pscores.csv`, respectively. The script reads in the imputed covariate distribution and propensity scores from best selected model, joins them, and computes effect estimates using weighted logistics regression. `main_msm.R` outputs csvs of effect estimates as the adjusted probability of outcome (with confidence intervals), formatted for easy comparison between treated and control patients. Time-varying effect modifier results are written to `4_msm/data/mab_product_prob_results_df.csv`, and all other effect modifiers and ATE results are written to `4_msm/data/msm_prob_results.csv`. E-Value results are written to `4_msm/data/evalues.csv`.  Also output from `main_msm.R` are plots for visualizing these results, found in `4_msm/figures/`.
