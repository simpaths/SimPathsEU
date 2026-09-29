/*******************************************************************************
* PROJECT:  		SimPaths EU
* SECTION:			Validation
* OBJECT: 			Master file - longitudinal SILC 
* AUTHORS:			Ashley Burdett, Mariia Vartuzova
* LAST UPDATE:		05/2026 (AB)
* COUNTRY: 			Poland
********************************************************************************
* NOTES: 			This master do file organises do files used for validating
* 					SimPaths model using EU-SILC data for Poland. This version
* 					utilizes the unique input dataset to create the targets. 
*
* 					*** Latest addition
* 					Adds a new "Plot alignment targets" section that calls
* 					06_18_plot_alignment_targets.do to produce simulated-vs-
* 					target time-series plots (with run variability shown as a
* 					shaded area band) based on AlignmentStatistics.csv.
*					The corresponding output folder alignment_targets is also
*					created.
*
* 					Copy and paste the relevant simulated output data files into
* 					the data subfolder.
*******************************************************************************/
clear all

/*******************************************************************************
* Ensure required user-written packages are installed
*******************************************************************************/
local ssc_pkgs "ineqdeco fre unique grc1leg2"
foreach pkg of local ssc_pkgs {
    capture which `pkg'
    if _rc ssc install `pkg', replace
}

* grc1leg lives on Vince Wiggins' site, not SSC
capture which grc1leg
if _rc net install grc1leg, from("http://www.stata.com/users/vwiggins/")
/*******************************************************************************/

set logtype smcl
set more off
set mem 200m
set type double


/*******************************************************************************
* 1 - STATIC SET UP
*******************************************************************************/

/*******************************************************************************
* DEFINE GLOBALS
*******************************************************************************/

global country = "PL"
global country_lower = "pl"
display in y "Country selected: ${country}"

global silc_UDB = "UDB_c"


/*******************************************************************************
* DEFINE DIRECTORIES
*******************************************************************************/

* Individual path
global dir_ind "/Users/ashleyburdett/Library/CloudStorage/Box-Box/CeMPA shared area/_SimPaths/_SimPathsEU"

* Main folder path
global path "${dir_ind}/validation/02_simulation_output_validation/PL/longitudinal_SILC"

global dir_do_files "$path/do_files_refactored"  //folder where do-files are stored

global dir_work "$path/data"
global dir_data "$path/data"

global dir_init_pop_data "$dir_ind/input_processing/initial_populations/PL/data"


/*******************************************************************************
* DEFINE SAMPLE PARAMETERS
*******************************************************************************/

global use_assert "0"

* Trim outliers
global trim_outliers true

* Min age of individuals included in plots
global min_age 18

* Max age of individuals included in plots
global max_age 65

* Observations up to and including this simulated year will be kept in the sample
global min_year 2011
global max_year 2023
global min_sim_year ${min_year}
global max_sim_year ${max_year}

* Define age to become responsible as defined in the simulation
global age_become_responsible 16

* Set labour supply categories
global ls_cat "ZERO TWENTY FORTY FIFTY"
global ls_cat_labour "TWENTY FORTY FIFTY"

* Number of runs
global max_n_runs 3


/*******************************************************************************
* CALL WORKER DO FILES
*******************************************************************************/

* Prepare SILC data
do "${dir_do_files}/03_create_EU_SILC_validation_targets.do"


/*******************************************************************************
* 2 - DYNAMIC SET UP
*******************************************************************************/

* List of SimPath Set ups to loop through
global alignments "alignment_00_populationOFF alignment_01_population alignment_02a_population_fertility alignment_02b_population_cohabitation alignment_02c_population_disability alignment_02d_population_inschool alignment_02e_population_retirement alignment_03_population_fertility_cohabitation alignment_04_population_fertility_cohabitation_employment"

foreach align in $alignments {


/*******************************************************************************
* DEFINE DIRECTORIES
*******************************************************************************/

	* Simulated data CSV files folder
	global dir_simulated_data "$path/simulated_data/`align'/csv"

	* Graphs folder
	global dir_output_files "$path/graphs/`align'"

	
/*******************************************************************************
* CREATE OUTPUT FOLDERS
*******************************************************************************/

	capture mkdir "$path/graphs"
	capture mkdir "$path/graphs/`align'"
	capture mkdir "$path/graphs/`align'/alignment_targets"
	capture mkdir "$path/graphs/`align'/children"
	capture mkdir "$path/graphs/`align'/correlations"
	capture mkdir "$path/graphs/`align'/disability"
	capture mkdir "$path/graphs/`align'/economic_activity"
	capture mkdir "$path/graphs/`align'/education"
	capture mkdir "$path/graphs/`align'/health"
	capture mkdir "$path/graphs/`align'/hours_worked"
	capture mkdir "$path/graphs/`align'/income"
	capture mkdir "$path/graphs/`align'/income/capital_income"
	capture mkdir "$path/graphs/`align'/income/pension_income"
	capture mkdir "$path/graphs/`align'/income/disposable_income"
	capture mkdir "$path/graphs/`align'/income/equivalised_disposable_income"
	capture mkdir "$path/graphs/`align'/income/gross_income"
	capture mkdir "$path/graphs/`align'/income/gross_labour_income"
	capture mkdir "$path/graphs/`align'/income/income_shares"
	capture mkdir "$path/graphs/`align'/inequality"
	capture mkdir "$path/graphs/`align'/partnership"
	capture mkdir "$path/graphs/`align'/poverty"
	capture mkdir "$path/graphs/`align'/wages"

/*******************************************************************************
* RUN DO FILES
*******************************************************************************/

	* Prepare simulated data
	do "${dir_do_files}/01_prepare_simulated_data.do"
	do "${dir_do_files}/02_create_simulated_validation_targets.do"

	* Prepare EUROMOD data
	//do "${dir_do_files}/07_create_euromod_validation_targets.do"

	* Plot figures
	do "${dir_do_files}/04_01_plot_activity_status.do"
	do "${dir_do_files}/04_02_plot_education_level.do"
	do "${dir_do_files}/04_03_plot_gross_income.do"
	do "${dir_do_files}/04_04_plot_gross_labour_income.do"
	do "${dir_do_files}/04_05_plot_capital_income.do"
	do "${dir_do_files}/04_07_plot_disposable_income.do"
	do "${dir_do_files}/04_08_plot_equivalised_disposable_income.do"
	do "${dir_do_files}/04_09_plot_hourly_wages.do"
	do "${dir_do_files}/04_10_0_plot_hours_worked.do"
	do "${dir_do_files}/04_10_1_plot_hours_worked_discrete.do"
	do "${dir_do_files}/04_11_plot_income_shares.do"
	do "${dir_do_files}/04_12_plot_partnership_status.do"
	do "${dir_do_files}/04_13_plot_health.do"	
	do "${dir_do_files}/04_14_plot_at_risk_of_poverty.do"
	do "${dir_do_files}/04_15_plot_inequality.do"
	do "${dir_do_files}/04_16_plot_number_children.do"
	do "${dir_do_files}/04_17_plot_disability.do"

	do "${dir_do_files}/04_18_plot_alignment_targets.do"
	
}	
	
