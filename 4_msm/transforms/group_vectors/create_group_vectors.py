# Use this script if you need to produce grouping vectors for additional effect modifiers

def common_member(a, b):
    a_set = set(a)
    b_set = set(b)
    if (a_set & b_set):
        return True 
    else:
        return False

def get_group_vectors(factor_levels):
    '''
    INPUT: factor_levels: list of strings, where the first element is the baseline factor level. Each string should contain only alphanumeric characters
    OUTPUT: strings that can be used to create additional group_vector configuration files if a user wants to analyze additional effect modifiers,
    and be able to directly compare treated and untreated population. Grouping vectors provide a structure for combining the raw coefficient output from the 
    marginal strucutral logistic regression model terms into adjusted effect estimates between treated and untreated patients.

    See any file in 4_msm/transforms/group_vectors for a template for a grouping vectors file

    Example usage for pandemic_phase: get_group_vectors(['predelta', 'delta', 'deltaomicron', 'omicron'])
    '''
    
    dummy_terms = [x+'_dummy' for x in factor_levels[1:]]
    interaction_terms = ['treated_'+x+'_interaction' for x in factor_levels[1:]]
    row_names = ['intercept', 'treated_dummy'] + dummy_terms + interaction_terms
    column_names=[]
    for i in factor_levels:
        for j in ['untreated', 'treated']:
            column_names.append(i+'_'+j)
    

    for col in column_names:
        vector = []
        for term_idx, row in enumerate(row_names):
            # vector will be len(row_names)
            
            # intercept terms are 1 for all columns
            if term_idx == 0:
                vector.append(1)
                
            # treatment group terms are 1 for all treated columns
            # needed to use 'not untreated' because 'treated' is contained in the string 'untreated'
            if term_idx == 1:
                if not 'untreated' in col:
                    vector.append(1)
                else:
                    vector.append(0)
                    
            # for all the other terms
            if term_idx > 1:
                # split the names into list so we can compare elements
                col_list = col.split('_')
                row_list = row.split('_')
                
                # for dummy columns, value is 1 when there is a common element between row and column
                # i.e. 'delta_dummy' and 'delta_untreated'
                if 'dummy' in row: 
                    if common_member(col_list, row_list):
                        vector.append(1)
                    else:
                        vector.append(0)
                        
                # for interaction terms, value is only 1 if we are looking at a treated column
                # that shares a common element other than 'treated'
                # for example 'treat_delta_interaction' and 'delta_treated'
                elif 'interaction' in row:
                    if 'untreated' in col:
                        vector.append(0)
                    else: 
                        row_list = row_list[1:]
                        if common_member(col_list, row_list):
                            vector.append(1)
                        else:
                            vector.append(0)

        vector_output = str(col) + ' <- c'+ str(vector)
        print(vector_output.replace("[", "(").replace("]", ")"))
    print('\n','data.frame('+ str(column_names).replace("'", "").replace("[", "").replace("]", "") + ")")
    print('\n', 'c('+ str(row_names).replace("'", '"').replace("[", "").replace("]", "") + ")")
    return