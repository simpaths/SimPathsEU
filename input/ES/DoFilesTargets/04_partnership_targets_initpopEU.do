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
* DESCRIPTION:    This do-file constructs partnership targets using initial
*                population data. It:
*                  - Imports initial population CSV files by year
*                  - Infers partnership from BU co-residency logic
*                    (not idPartner field), consistent with SimPaths
*                    getPartner() — a person is partnered if at least one
*                    other adult (demAge >= 18) shares their benefit unit and
*                    is neither their mother nor their father
*                  - Computes the weighted share of partnered adults aged 18+
*                  - Exports the results to Excel
*
* NOTE:           This EU version uses refactored variable names from the
*                initial populations (e.g., idPers, idBu, idMother, idFather,
*                wgtCrossMainSurvey).
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


* Initialise file that will store partnered shares for all years
clear
save "${dir_working_data}/partnered_shares_${country}_initpopdata.dta", emptyok replace

* ========================================================================== *

// Loop over all years in the requested range
foreach y of numlist $min_year/$max_year {

	* Build file name for the given year and import initial population data
	local file = subinstr("population_initial_${country}_YYYY.csv","YYYY","`y'",.)
	import delimited using "${dir_input_data}/`file'", clear case(preserve)

	bys idPers: keep if _n == 1 // keep one obs per idPers

	* Ensure ID variables are numeric (needed for joinby and merge)
	destring idPers idBu idMother idFather, replace force

	* Keep only adults eligible for partnership and required variables
	keep if demAge >= 18
	keep idBu idPers idMother idFather wgtCrossMainSurvey

	* Save full eligible population for later merge
	tempfile eligible_pop
	save `eligible_pop', replace

	* --- Step A: build list of BU adult members for self-join ---
	keep idBu idPers
	rename idPers other_idPers
	tempfile bu_adults
	save `bu_adults', replace

	* --- Step B: self-join on idBu ---
	* Each person is expanded against all adults in their BU
	use `eligible_pop', clear
	joinby idBu using `bu_adults'

	* Remove self-matches
	drop if other_idPers == idPers

	* Remove cases where the co-resident is this person's parent
	drop if other_idPers == idMother | other_idPers == idFather

	* Each remaining row means a qualifying co-resident exists
	gen byte has_partner = 1

	* Reduce to one row per person: partnered = 1 if any qualifying row
	collapse (max) partnered = has_partner, by(idBu idPers)

	* --- Step C: merge partnered flags back into full eligible population ---
	* joinby silently drops persons with no qualifying co-resident, so we
	* restore them from the saved eligible population and assign partnered = 0
	tempfile partnered_flags
	save `partnered_flags', replace

	use `eligible_pop', clear
	merge 1:1 idBu idPers using `partnered_flags', keep(master match) nogen
	replace partnered = 0 if missing(partnered)

	* Alignment target: weighted share of partnered adults
	collapse (mean) partnered_share = partnered [pw = wgtCrossMainSurvey]
	gen year = `y'

	* Append to cumulative file for all years
	append using "${dir_working_data}/partnered_shares_${country}_initpopdata.dta"
	duplicates drop
	save "${dir_working_data}/partnered_shares_${country}_initpopdata.dta", replace

}

* -------------------------------------------------------------------------- *
* POST-PROCESSING: export aggregated results to Excel
* -------------------------------------------------------------------------- *

use "${dir_working_data}/partnered_shares_${country}_initpopdata.dta", clear

* Sort by year for neat export
sort year

* Create/overwrite Excel file that will hold all sheets
putexcel set "${dir_output}/alignment_targets_partnered_share.xlsx", replace

* Build separate matrices for year and share (written with explicit Excel formats)
mkmat year,            matrix(Yr)
mkmat partnered_share, matrix(Sh)

* Point putexcel at the output file and the sheet
putexcel set "${dir_output}/alignment_targets_partnered_share.xlsx", sheet("partnered") modify

* Write headers
putexcel A1=("year") B1=("partnered_share")

* Write data: years as integers, shares with 7 decimal places
putexcel A2=matrix(Yr), nformat("0")
putexcel B2=matrix(Sh), nformat("0.000000")

* --- INFO SHEET ------------------------------------------------------------ *
local today "`c(current_date)'"
putexcel set "${dir_output}/alignment_targets_partnered_share.xlsx", sheet("info") modify
putexcel A1=("Field")       B1=("Value")
putexcel A2=("Target")      B2=("Share of partnered persons among adults aged 18+")
putexcel A3=("Population")  B3=("All persons aged 18+ in the initial population")
putexcel A4=("Definition")  B4=("Partnered = at least one non-parent adult co-resident in the same benefit unit (BU co-residency logic, not idPartner field)")
putexcel A5=("Age filter")  B5=("demAge >= 18")
putexcel A6=("Weighting")   B6=("Person-level population weights (wgtCrossMainSurvey)")
putexcel A7=("Note")        B7=("Partnership inferred from BU co-residency consistent with SimPaths getPartner() logic; idPartner is not used")
putexcel A8=("Source")      B8=("EU-SILC-based SimPaths initial populations")
putexcel A9=("Country")     B9=("${country}")
putexcel A10=("Years")      B10=("${min_year}-${max_year}")
putexcel A11=("Do-file")    B11=("04_partnership_targets_initpopEU.do")
putexcel A12=("Produced")   B12=("`today'")
