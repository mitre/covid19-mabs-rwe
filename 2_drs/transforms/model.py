##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: This function preprocesses, trains, and selects the best DRS model from Grid Search
## Date: May 2022
## Developers: Jerez Te
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.impute import SimpleImputer, KNNImputer
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import GridSearchCV
from sklearn.compose import make_column_transformer, ColumnTransformer
from sklearn.metrics import make_scorer, accuracy_score, matthews_corrcoef
from sklearn.linear_model import LogisticRegression

def MLmodeling_hpo(preprocess_impute_1):
    print("STARTING RUN")
    np.random.seed(0)
    df = preprocess_impute_1.reset_index(drop=True)
    print(df.shape)

    
# define targets
    target_val = 'all_30d'
    if (target_val == 'all_30d'): 
        df['target'] = np.where(((df['inpt_30d'] == 1) | (df['death_30d'] == 1)),1,0)
    elif (target_val == 'all_14d'):
        df['target'] = np.where(((df['ed_14d'] == 1) | (df['inpt_14d'] == 1) | (df['death_14d'] == 1)),1,0)
    elif (target_val in ['ed_30d','inpt_30d','death_30d','ed_14d','inpt_14d','death_14d']):
        df['target'] = np.where((df[target_val] == 1),1,0)
    else:
        df['target'] = np.where(((df['ed_30d'] == 1) | (df['inpt_30d'] == 1) | (df['death_30d'] == 1)),1,0)
    print(df.columns.tolist())

    # convert nulls to nan
    df = df.fillna(value=np.nan)

    # using elixhauser comorbidity index toggle
    use_elixhauser = True
    if use_elixhauser:
        df['elixhauser_mortality_index'] = df['elixhauser_mortality_index'].fillna(0)


    # select features by category (numeric, binary, categorical)
    measurements_features = df.columns[df.columns.str.startswith(('diast_','heart_rate','o2_','resp_rate','syst_','temp_','total_'))].values.tolist()
    measurements_features.remove('total_count_distinct_day_mabs')
    print(measurements_features)
    numeric_features = ['zip3_pop_density','zip3_adi','total_visits']
    print(numeric_features)

    excluded = ['age_group']
    
    categorical_features = ['ethnicity','birthsex','pandemic_phase','most_recent_sarscov2_immunization_cat',
        'health_system','diagnosis_epoch','smoke_status','race','marital_status','insurance_category','age_group'] 

    cond_features = df.columns[df.columns.str.startswith(('condition'))].values.tolist()
    print('--------')
    print(cond_features)
    
    binary_features = ['pregnant','out_of_state','obese','immunosuppressant_prev90days'] + cond_features

    all_features =  numeric_features + categorical_features + binary_features

    target_features = ['days_to_emergency','days_to_inpatient','days_to_death','death_source_enc','ed_14d','inpt_14d',
        'death_14d','ed_30d','inpt_30d','death_30d']
    index_features = ['person_id']
    
    appended_data = []
    for impute_id in df['impute_id'].unique().tolist():
        print(impute_id)

        batch_df = df[df['impute_id'] == impute_id]
        nontreated_df = batch_df[batch_df['treatment_group'] == 0]

        ids_train = nontreated_df.pop('person_id')
        y_train = nontreated_df.pop('target')
        batch_train = nontreated_df.pop('impute_id')
        X_train = nontreated_df[all_features]

        ids_test = batch_df.pop('person_id')
        y_test = batch_df.pop('target')
        treatment = batch_df.pop('treatment_group')
        batch_test = batch_df.pop('impute_id')
        X_test = batch_df[all_features]       

        # Create preprocessing Pipeline
        numeric_transformer = Pipeline(
            steps=[
            ("imputer", SimpleImputer(strategy='constant',fill_value=0)), 
            ("scaler", StandardScaler())
            ]
            )
    
        categorical_transformer = Pipeline(
            steps=[
            ('imputer', SimpleImputer(strategy='constant', fill_value='missing')),
            ('encoder', OneHotEncoder(handle_unknown='error',drop='first'))
            ]
            )

        binary_transformer = Pipeline(
            steps=[
        ('imputer', SimpleImputer(strategy='constant', fill_value=0)),
        ]
        )
    
        preprocessor = ColumnTransformer(
        transformers=[
            ("num", numeric_transformer, numeric_features),
            ("cat", categorical_transformer, categorical_features),
            ("binary",binary_transformer,binary_features),
        ])

        x_train_transform = preprocessor.fit_transform(X_train)
        x_test_transform = preprocessor.transform(X_test)

        print(preprocessor.named_transformers_['cat'].named_steps['encoder'].get_feature_names(categorical_features))

        # Grid search options
        param_grid = [
        {'penalty': ['l1','l2'], 'C': [0.001, 0.1, 1, 10.0], 'solver':['saga','liblinear'], 'class_weight':['balanced'],'max_iter': [500],
            'random_state':[2022]},
        {'solver': ['newton-cg'], 'penalty': ['l2'], 'C': [0.001, 0.1, 1, 10.0], 'max_iter': [500, 1000], 
            'random_state': [2022]},
        {'penalty': ['elasticnet'], 'C': [1, 0.1, 10.0], 'solver':['saga'], 'class_weight':['balanced'],'max_iter': [500],'l1_ratio':[0.25,0.5,0.75],
            'random_state':[2022]}
        ]

        debug = False
        if debug:
            param_grid = [
            {'penalty': ['elasticnet'], 'C': [0.1], 'solver':['saga'], 'class_weight':['balanced'],'max_iter': [500],'l1_ratio':[0.75],
            'random_state':[2022]}
            ]
        
        # Train a logistic regression model
        grid_model = LogisticRegression(random_state=2022)
        scoring = {"MCC":make_scorer(matthews_corrcoef)}
        grid_search = GridSearchCV(grid_model, param_grid, cv=5,
                                scoring=scoring,
                                refit="MCC", return_train_score=True)  #roc_auc
        if not debug:
            grid_search.fit(x_train_transform, y_train)
        
            print(f"BEST PARAM: {grid_search.best_params_}")
        if debug:
            clf = LogisticRegression(penalty='elasticnet', C=0.1, solver='saga', class_weight='balanced', max_iter=500,l1_ratio=0.75, random_state=2022)
        else:
            print(grid_search.best_params_)
            clf = LogisticRegression(**grid_search.best_params_)
            print('printing best params')
            print(clf.get_params())
        
        clf.fit(x_train_transform, y_train)

        scores = clf.predict_proba(x_test_transform)

        final_df = pd.DataFrame()
        final_df['person_id'] = ids_test
        final_df['impute_id'] = batch_test
        final_df['treatment_group'] = treatment 
        final_df['target'] = y_test
        final_df['prediction'] = scores[:,1]
        appended_data.append(final_df)
    appended_data = pd.concat(appended_data)

    return appended_data


    
