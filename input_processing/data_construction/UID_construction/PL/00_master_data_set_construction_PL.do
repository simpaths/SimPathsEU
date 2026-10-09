/*******************************************************************************
* PROJECT:             	SimPaths EU
* DO-FILE NAME:        	00_master.do
* DESCRIPTION:         	Main do-file to set the main parameters (country, paths)
*  						and call sub-scripts to construct dataset for 
* 						analysis of Poland. 
* COUNTRY:              PL
* DATA:         	    Longitudinal EU-SILC UDB version, 2005 - 2020 
* AUTHORS: 				Clare Fenwick, Daria Popova, Ashley Burdett, 
* 						Aleksandra Kolndrekaj
* LAST UPDATE:          7 October 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   Sets country/machine parameters and file paths, then runs the full
*   pipeline below that turns the GESIS eusilcpanel cumulative output
*   (MasterR/P/D/H) into the initial populations dataset used by SimPaths
*   for Poland.
*
*   -----------------------------------------------------------------------
*    Prerequisites (must be in place before running)
*   -----------------------------------------------------------------------
*   1. The GESIS eusilcpanel output (MasterR/P/D/H .dta files) available
*      locally, in TWO vintages - one built through 2020, one through
*      2023 (see GESIS Papers 2022/10 and the README in the SILC_panel
*      subfolder for how these are constructed). This file reads that
*      output; it does not construct it.
*   2. This do_files folder saved at the location dir_work points to below
*      (data/, log/, and graphs/ are created as siblings of it
*      automatically).
*   3. The path globals below (e.g. dir_ind, dir_long_eusilc,
*      dir_long_eusilc_05_20) are set to point at wherever those GESIS output
*      files live on your machine.
*   4. 00_master_conditions_PL.do must exist at the path below (lives
*      outside this folder, shared across countries). It sets
*      global country "PL" and the simulation-alignment age thresholds
*      used throughout this pipeline.
*   5. Stata packages installed (see block below): fre, tsspell,
*      carryforward, outreg2, filelist.
*
*   -----------------------------------------------------------------------
*    Pipeline stages (see EXECUTE FILES below, run in this order)
*   -----------------------------------------------------------------------
*   1. vars_05_02/prepare_pooled_data_05_20_PL.do 
* 									   Pools the 2005-2020 vintage panel
*                                       (one-off; produces the patch source
*                                       read by step 3)
*   2. 01_prepare_pooled_data_PL.do    Pools the 2005-2023 vintage panel
*                                       into the main person-level dataset
*   3. 02_create_variables_PL.do       Builds SimPaths model variables;
*                                       opens by merging in patch variables
*                                       from step 1 (pl030, pl031, rb210,
*                                       pe040, pl051 - definitions that
*                                       changed after 2020 and were never
*                                       backcoded)
*   4. 03_create_benefit_units_PL.do   Screens data, constructs benefit units
*   5. 04_reweight_PL.do               Reweights sample for benefit-unit basis
*   6. 05_drop_hholds_slice_and_refactoring_PL.do
*                                       Finalises the UID dataset
*                                       (${country}_pooled_ipop.dta) used
*                                       for estimation, and slices the UID
*                                       into cross-sections to use as the
*                                       initial populations file to set
*                                       up SimPaths.
*   7. 06_check_yearly_data_PL.do      Checks new data against previous release
*
*   -----------------------------------------------------------------------
*    Assumptions imposed to align the SILC data with simulation rules:
*   -----------------------------------------------------------------------
*
* 	During data processing, we impose several restrictions on the SILC data
* 	so that it closely aligns with the assumptions in SimPaths. Specifically: 
*
*   - Retirement:
*       - Treat as an absorbing state
*       - Must retire by a specified maximum age
*       - Cannot retire before a specified minimum age
*
*   - Education:
*       - Leave education no earlier than a specified minimum age
*       - Must leave the initial education spell by a specified maximum age
*       - Cannot return to education after retirement
*
*   - Work:
*       - Can work from a specified minimum age
*       - Activity status and hours of work populated consistently:
*           → Assume not working if report hours = 0 
*           → Assume hours = 0 if not working
* 		- If missing partial information, don't assume the missing is 0 and 
* 			impute (hot-deck)
*
*   - Leaving the parental home:
*       - Can leave from a specified minimum age
* 		- Become the effective head of hh even when living with parents when 
* 			parents retire or reach state retirement age
*
*   - Home ownership:
*       - Can own a home from a specified minimum age
*
*   - Partnership formation:
*       - Can form a partnership from a specified minimum age
*
*   - Disability:
*       - Treated as a subsample of the not-employed population
*
*   The relevant age thresholds are defined in globals defined in "DEFINE 
* 	PARAMETERS" section below. 
* 	Throughout, also construct relevant flags and produce a log file 
* 	"flag_descriptives.xlsx" to see the extent of the adjustments to the raw 
* 	data. 
*
*   -----------------------------------------------------------------------
*    Additional notes on implementation: 
*   -----------------------------------------------------------------------
*
*   - Impute health score (generalised ordered logit model).
*   - Constructing age is not straightforward, as it is not directly reported in  
* 	  the data, therefore: 
*       → Use interview age (RX010) where available
*       → Otherwise, use age at end of interview year (PX020). This results in 
* 			upward bias of age.
*   - Set education = 0 (na) while in initial education spell. 
*
*   -----------------------------------------------------------------------
*   Remaining disparities between initial populations and simulation rules:
*   -----------------------------------------------------------------------
*
*   - Ages at which females can have a child. [Be informed by the sample?]
*	  Permit teenage mothers in this script (deal with in 03_ )
*   - A few higher/older education spells (30+) that last multiple years 
*     in the simulation can only return to education for single-year spells. 
* 	- Number of children vars (all ages or 0-2) don't account for feasibility 
* 		of age at birth of the mother. 
*
*******************************************************************************/

clear all
set more off
set type double
set maxvar 30000
set matsize 1000


/*******************************************************************************
* INSTALL STATA PACKAGES
*******************************************************************************/
ssc install fre
ssc install tsspell 
ssc install carryforward 
ssc install outreg2
ssc install filelist
ssc install gologit2, replace


/*******************************************************************************
* DEFINE DIRECTORIES
*******************************************************************************/
/*
Globals marked >>> EDIT <<< below need adjusting for your machine/setup.
Everything else in this section is derived from them and shouldn't need
changing.
*/

* Individual pathway
* >>> EDIT <<<
/*
Hardcoded per machine - edit this to your own local Box path before running. 
Everything else in this file is relative to this one path.
*/

* Individual
global dir_ind "/Users/ashleyburdett/Library/CloudStorage/Box-Box"


** Output directories

* Working directory
* >>> EDIT <<<
/*
This country's working folder. Edit this to the folder in which the "do_files"
folder containing this do-file is contained.
This is the main folder that will contain the relevant UID construction data and
log files.
*/
global dir_work "$dir_ind/CeMPA shared area/_SimPaths/_SimPathsEU/input_processing/initial_populations/PL"

* Directory containing do-files
global dir_do "$dir_work/do_files"

* Directory containing data output files 
global dir_data "$dir_work/data" 

* Directory containing 2005-2020 PL compiled panel 
global dir_data_05_20 "$dir_data/orig_panel_2005_2020"

* Directory containing log files 
global dir_log "$dir_work/log"

* Directory containing graphs 
global dir_graphs "$dir_work/graphs"


** Input Directories 

* Directory containing 2005-2023 EU-SILC panel data
* >>> EDIT <<<
global dir_long_eusilc "$dir_ind/CeMPA shared area/projects - completed/ESPON - OVERLAP/_countries/Cumulative Longitudional Dataset (all countries)/2005_2023_panel/data"

* Directory containing 2005-2020 EU-SILC panel data
* >>> EDIT <<<
global dir_long_eusilc_05_20 "$dir_ind/CeMPA shared area/projects - completed/ESPON - OVERLAP/_countries/Cumulative Longitudional Dataset (all countries)/2005_2020_panel"


/*******************************************************************************
* DEFINE PARAMETERS & PROCESS IF CONDITIONS
*******************************************************************************/

do "$dir_ind/CeMPA shared area/_SimPaths/_SimPathsEU/input_processing/00_master_conditions_PL.do"


/*******************************************************************************
* EXECUTE FILES
*******************************************************************************/
do "$dir_do/01_prepare_pooled_data_${country}.do"

do "$dir_do/02_create_variables_${country}.do"

do "$dir_do/03_create_benefit_units_${country}.do"

do "$dir_do/04_reweight_${country}.do"

do "$dir_do/05_drop_hholds_slice_and_refactoring_${country}.do"

do "$dir_do/06_check_yearly_data_${country}.do"

