##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Script to define global variables and imports for PS step
## Date: May 2022
## Developers: Alexander Wood
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

RUN_DEBUG  = 0
RUN_CHECKS = 1

#########################################
#  GLOBAL IMPORTS
#########################################
# Packages or functions used in more than
# one transform are imported globablly
# here.

import re
import warnings

import pandas as pd
import numpy as np

from collections import namedtuple
from itertools import product

from sklearn.base import clone
from sklearn.model_selection import ParameterGrid
from sklearn.metrics import (
    precision_recall_fscore_support,
    confusion_matrix
)


#########################################
#  Dataset Columns
#########################################

# Names of indexing columns. Should not
# be used as features in model training.
INDEX_ID = 'person_id'
INDEX_IMPUTATION_ID = 'impute_id'
INDEX_IMPUTATION_FLAG = [
    'imputed_demographics',
    'imputed_vitals'
]
INDEX_COLUMNS = \
    [INDEX_ID] + \
    [INDEX_IMPUTATION_ID] + \
    INDEX_IMPUTATION_FLAG

# Names of the target column(s). Will
# be used as target in model training.
TARGET_COLUMNS = [
    'treatment_group',
]

# Regex patterns for covid19_*_vs
# and condition_*_vs covariates
CONDITION_COLUMN_PATTERN = r"condition_[\w\d]+_vs"
COVID_COLUMN_PATTERN = r"covid19_[\w\d]+_vs"


#########################################
#  Evaluation reports
#########################################
def display_dict(d):
    """for nicely displaying model params
    """
    print('\n'.join([f'\t{k}:{v}' for k,v in d.items()]))
    return None


def get_report(y_true, y_pred):
    """Print evaluation report.

    Create an evaluation report formatted for printing
    a clean log.
    """
    def _check_inputs(y_true, y_pred):
        """Force inputs to be column vectors
        with same shape."""
        if not isinstance(y_true, np.ndarray):
            y_true = y_true.to_numpy(dtype=np.float64)
        elif y_true.dtype != np.float64:
            y_true = y_true.astype(np.float64)

        if not isinstance(y_pred, np.ndarray):
            y_pred = y_pred.to_numpy(dtype=np.float64)
        elif y_pred.dtype != np.float64:
            y_pred = y_pred.astype(np.float64)

        y_true, y_pred = y_true.ravel(), y_pred.ravel()

        assert y_true.shape == y_pred.shape

        # Assert both arrays are binary.
        assert np.array_equal(y_pred, y_pred.astype('bool')), \
               'y_pred must be binary '
        assert np.array_equal(y_true, y_true.astype('bool')), \
               'y_true must be binary'

        return y_true, y_pred


    # Run input quality checks checks
    y_true, y_pred = _check_inputs(y_true, y_pred)

    # Set headers for display.
    target_names = ['1']
    headers = [
        "tp", "tn", "fp", "fn",
        "precision", "recall", "f1-score", "support"
    ]

    # Calculate evaluation report values.
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    p, r, f1, s = precision_recall_fscore_support(
        y_true,
        y_pred,
        zero_division=0,
    )
    row = [tp, tn, fp, fn, p[-1], r[-1], f1[-1], s[-1]]

    # Find options for report formatting
    indent, digits = 0, 4
    head_fmt = "{:>{indent}s}\n" + " {:>9}" * len(headers)
    row_fmt = " "*indent + " {:>9.0f}"*4 + \
              " {:>9.4f}"*3 + " {:>9}\n"

    # Construct the report
    report = head_fmt.format("", *headers, indent=indent)
    report += "\n"
    report += row_fmt.format(
        *row, indent=indent, digits=digits
    )
    return report, f1[-1]



#########################################
#  Debug report formatters
#########################################
def debug_print(value, split=None, indent=False):
    """
    Input: String or List
    Splits an input string along a given split
        (no split when split=None).
    Then, prints each line in the split list
        with the debug decorator prepended.
    Skip first part if input is already a list.

    ex:
    input: 'ABC', split=None
    prints: '*\tABC'

    ex:
    input: 'A\nB\nC\n', split='\n'
        OR
    input: ['A', 'B', 'C']
    prints: '*\tA\n*\tB\n*\tC\n'


    """
    if indent:
        add_tab = '\t'
    else:
        add_tab = ''

    if isinstance(value, str):
        list_in = value.split(split)
    elif isinstance(value, pd.Index):
        list_in = value.tolist()
    elif isinstance(value, list):
        list_in = value
    else:
        raise TypeError("Please convert value to list.")


    print("\n".join([f'*\t{add_tab}{s}' for s in list_in]))


def print_list(list_in, width=80, debug=False):
    """
    Better way of printing a list for human eyes.
    Prints comma-separated list items to a max
    character width per line. Set debug=True to
    prepend with the debug decorator, '*\t'.
    """
    token='\t'
    if debug:
        token = '*\t'

    list_out, lines_out = list_in.copy(), ''
    list_out.reverse()

    line_len, line_out = 0, []
    while list_out:
        line_out.append(list_out.pop())
        line_len += len(line_out[-1])
        if line_len > width:
            lines_out += token + ', '.join(line_out[:-1]) + '\n'
            line_len, line_out = len(line_out[-1]), line_out[-1:]

    print(lines_out)


def print_setup(lol_in):
    """
    Given a list of lists, return a list
    of column widths for each column
    in order to pretty print (left-aligned).
    """
    # Make sure we have a list of lists of strings.
    list_in = [[str(value) for value in row] for row in lol_in]

    # Get the longest value from each column.
    lens = [max(map(len, col)) for col in zip(*list_in)]
    fmt = '\t'.join('{{:{}}}'.format(n) for n in lens)

    return fmt
