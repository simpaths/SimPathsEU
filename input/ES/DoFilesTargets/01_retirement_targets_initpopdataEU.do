/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        ALIGNMENT PROCEDURES
*
* AUTHORS:        Mariia Vartuzova (MV)
* LAST UPDATE:    18/08/2026 (MV)
* COUNTRY:        ES (Spain)
*
* DATA:           Initial populations
*
* DESCRIPTION:    This do-file constructs retirement targets using initial
*                population data. It:
*                  - Imports initial population CSV files by year
*                  - Computes the share of retired persons (labC4 == 4)
*                    among those with non-missing labour status
*                  - Exports the results to Excel
*
* NOTE:           This EU version uses refactored variable names from the
*                initial populations (e.g., idPers, labC4, wgtCrossMainSurvey).
*
* STATA REQ:      Stata 13+. `import delimited` uses `case(preserve)` to
*                retain the camelCase column names of the refactored
*                initial-population CSVs.
*
* SET-UP:         1. Update the working directory path (global dir_w)
*                 2. Copy the relevant input data into the /input_data folder
*                    under the country-specific subdirectory
*
*******************************************************************************/

clear all


* --- DEFINE GLOBALS -------------------------------------------------------- *

* Working directory (project root)
global dir_w "~/IdeaProjects/SimPathsEU_AUG"


* Country code and time span for which targets are produced
global country = "ES"
global min_year 2011
global max_year 2023

* Directory structure
global dir_input_data   "$dir_w/input/${country}/InitialPopulations"
global dir_working_data "$dir_w/input/${country}/DoFilesTargets/working_data"
global dir_output       "$dir_w/input/${country}/DoFilesTargets"


* Initialise file that will store retirement shares for all years

capture confirm file "${dir_working_data}/retirement_shares_${country}_initpopdata.dta"
if _rc {
    clear
    save "${dir_working_data}/retirement_shares_${country}_initpopdata.dta", emptyok
}


* ========================================================================== *

// Loop over all years in the requested range
foreach y of numlist $min_year/$max_year {

	* Build file name for the given year and import initial population data
	local file = subinstr("population_initial_${country}_YYYY.csv","YYYY","`y'",.)
	import delimited using "${dir_input_data}/`file'", clear case(preserve)

	bys idPers: keep if _n == 1 // keep one obs per idPers

	// Alignment target: share of retired persons among those with non-missing labC4
	gen byte isRetired = (labC4 == 4)
    collapse (mean) retired_share = isRetired if (labC4 != .) [pw = wgtCrossMainSurvey]

	gen year = `y'

	* Append to cumulative file for all years
	append using "${dir_working_data}/retirement_shares_${country}_initpopdata.dta"
	duplicates drop
	save "${dir_working_data}/retirement_shares_${country}_initpopdata.dta", replace

}

* -------------------------------------------------------------------------- *
* POST-PROCESSING: export aggregated results to Excel
* -------------------------------------------------------------------------- *


use "${dir_working_data}/retirement_shares_${country}_initpopdata.dta", clear

* Sort by year for neat export
sort year

* Create/overwrite Excel file that will hold all sheets
putexcel set "${dir_output}/alignment_targets_retirement.xlsx", replace


* Build separate matrices for year and share (written with explicit Excel formats)
mkmat year,          matrix(Yr)
mkmat retired_share, matrix(Sh)

* Point putexcel at the output file and the group-specific sheet
putexcel set "${dir_output}/alignment_targets_retirement.xlsx", sheet("retirement") modify

* Write headers
putexcel A1=("year") B1=("retired_share")

* Write data: years as integers, shares with 7 decimal places
putexcel A2=matrix(Yr), nformat("0")
putexcel B2=matrix(Sh), nformat("0.000000")

* --- INFO SHEET ------------------------------------------------------------ *
local today "`c(current_date)'"
putexcel set "${dir_output}/alignment_targets_retirement.xlsx", sheet("info") modify
putexcel A1=("Field")       B1=("Value")
putexcel A2=("Target")      B2=("Share of retired persons among adults with non-missing labour status")
putexcel A3=("Population")  B3=("All persons in the initial population with non-missing labC4")
putexcel A4=("Definition")  B4=("labC4 == 4 (Retired)")
putexcel A5=("Age filter")  B5=("None (all ages included)")
putexcel A6=("Weighting")   B6=("Population weights (wgtCrossMainSurvey)")
putexcel A7=("Source")      B7=("EU-SILC-based SimPaths initial populations")
putexcel A8=("Country")     B8=("${country}")
putexcel A9=("Years")       B9=("${min_year}-${max_year}")
putexcel A10=("Do-file")    B10=("01_retirement_targets_initpopdataEU.do")
putexcel A11=("Produced")   B11=("`today'")
