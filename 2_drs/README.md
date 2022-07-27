# 2. Disease Risk Score (DRS)

The scripts here are used calculate the disease risk score (DRS).

- A patient’s DRS is the risk of the combined study outcome (30-day hospitalization or death) if the COVID-19 patient did not receive mAb treatments
- This DRS model was developed with the purpose of stratifying groups in the study population in the absence of mAbs treatment; it has not been rigorously tested for predictive value and accuracy on datasets outside of the original study and should not be used as a raw predictor of COVID-19 risk in other settings
- Logistic regression was chosen over other methods for the final implementation since is less likely to over-train the model, is generally well-calibrated, and the results and coefficients of a logistic regression model are interpretable
- The logistic regression coefficients constitute a fixed set of model parameters that are estimated from the data; as it is limited to a fixed set of considered features, this model may not necessarily capture all possible real-world interactions. While logistic regression was chosen based on the data we used for this study, your own data might produce different results.

## Code requirements and process
`main_drs.py` expects input matching the schema of `1_imputation/data/mab_patient_effect_imputed_no_treatment.csv`. The script performs preprocessing, followed by a robust grid-search for model selection, with all models trained on the untreated population. Evaluation metrics are printed to console output and Matthews correlation coefficient is used for final model selection. The disease risk scores for all person_id, impute_id combinations is written out to `2_drs/data/agg_results.csv`, which can be used downstream as an additional effect modifier in the marginal structural model.

Note: A hardcoded seed is included in `2_drs/transforms/model.py` for study reproducibility; this should potentially be removed or changed for other studies that leverage this code.