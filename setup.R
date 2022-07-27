##################################################
## Project: Real World Evidence to Accelerate COVID-19 Therapeutics
## Contract No.: 75FCMC18D0047
## Purpose: Script to install all the required R packages to run the analytic pipeline. 
## Adapted From: https://stackoverflow.com/questions/38928326/is-there-something-like-requirements-txt-for-r?noredirect=1&lq=1
## Date: May 2022
## Copyright 2022, The MITRE Corporation
## Approved for Public Release; Distribution Unlimited. Public Release Case Number 22-1741.
##################################################

##
pkgLoad <- function() {
  
  req.packages <- c("dplyr", "ggplot2", "arrow", "cobalt", "tidyverse", 
                    "boot", "tidyr", "Hmisc", "forcats", "gridExtra", 
                    "gtable", "grid", "sandwich", "EValue", "stringr",
                    "data.table", "magrittr", "reshape2", "cowplot", 
                    "mice", "scales", "Rcpp"
                    )

  
  packagecheck <- match( req.packages, utils::installed.packages()[,1] )
  
  packagestoinstall <- req.packages[ is.na( packagecheck ) ]
  
  if( length( packagestoinstall ) > 0L ) {
    utils::install.packages( packagestoinstall, dependencies = c("Depends", "Imports", "LinkingTo", "Suggests", "Enhances"))
  } else {
    print( "All requested packages already installed" )
  }
  
}

pkgLoad()
