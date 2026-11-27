/*******************************************************************************
* PROJECT:              SimPaths EU 
* DO-FILE NAME:         00_master_PL.do
* DESCRIPTION:          Main do-file to set estimates the parameters for 
* 							SimPaths for Poland using EU-SILC.
* COUNTRY:              Poland
* DATA:         	    GESIS - EU SILC			
* AUTHORS: 				Daria Popova, Justin van de Ven, Ashley Burdett, 
* 						Aleksandra Kolndrekaj 
* LAST UPDATE:          November 2026 (AK)
********************************************************************************
* NOTES: 				
* 			
*******************************************************************************/

* Stata packages to install 
/*
ssc install fre
ssc install tsspell 
ssc install carryforward 
ssc install outreg2
*/

clear all
set more off
macro drop _all 
set type double
set maxvar 30000
set matsize 1000


/*******************************************************************************
* DEFINE DIRECTORIES
*******************************************************************************/

* Individual 
global dir_ind "C:/Users/Aleksandra/Box"

//"C:/Users/ak25793/Box"
//"C:/Users/Aleksandra/Box"
//"/Users/ashleyburdett/Library/CloudStorage/Box-Box"

* Working directory which contains sub-folders and will contain formatted output 
global dir_work "$dir_ind/CeMPA shared area/_SimPaths/_SimpathsEU/input_processing/regression_estimates/PL/with_time_trend"

* Directory which contains do files
global dir_do "$dir_work/do_files"

* Directory which contains data files generated in the do files 
global dir_data "$dir_work/data"

* Directory which contains log files 
global dir_log "$dir_work/logs"

* Directory which contains raw results
global dir_raw_results "$dir_work/raw_results"

* Directory which contains EU-SILC input dataset
global dir_input_data "$dir_ind/CeMPA shared area/_SimPaths/_SimPathsEU/input_processing/initial_populations/PL/data"

* Directory containing external input data 
global dir_external_data "$dir_ind/CeMPA shared area/projects - completed/ESPON - OVERLAP/_countries/PL/regression_estimates/external_data"


/*******************************************************************************
* DEFINE PARAMETERS & PROCESS IF CONDITIONS 
*******************************************************************************/

do "$dir_ind/CeMPA shared area/_SimPaths/_SimPathsEU/input_processing/00_master_conditions_PL.do"


/*******************************************************************************
* EXECUTE FILES
*******************************************************************************/

do "$dir_do/01_reg_education_${country}.do"	

do "$dir_do/02_reg_leave_parental_home_${country}.do"

do "$dir_do/03_reg_partnership_${country}.do"

do "$dir_do/04_reg_fertility_${country}.do"
 
do "$dir_do/05_reg_health_${country}.do"	

do "$dir_do/06_reg_home_ownership_${country}.do"

do "$dir_do/07_reg_retirement_${country}.do"

do "$dir_do/08_reg_wages_${country}.do"

do "$dir_do/09_reg_income_${country}.do"

do "$dir_do/10_parametric_matching_process_${country}.do"

do "$dir_do/11_attrition_analysis_${country}.do"

do "$dir_do/90_cleaning_excel_inputs.do"


