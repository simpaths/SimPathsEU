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
* DESCRIPTION:    This do-file constructs employment targets for different
*                groups of the population using initial population data.
*                It:
*                  - Imports initial population CSV files by year
*                  - Defines benefit-unit (BU) level groups (household types)
*                  - Computes fractional BU-level employment
*                  - Aggregates to employment shares by group and year
*                  - Exports the results to Excel (one sheet per group)
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


* Initialise file that will store BU-level employment shares for all years
clear
save "${dir_working_data}/bu_empl_shares_${country}_allsubgroups_initpopdata.dta", emptyok replace

* ========================================================================== *

// Loop over all years in the requested range
foreach y of numlist $min_year/$max_year {

	* Build file name for the given year and import initial population data
	local file = subinstr("population_initial_${country}_YYYY.csv","YYYY","`y'",.)
	import delimited using "${dir_input_data}/`file'", clear case(preserve)

	bys idPers: keep if _n == 1 // keep one obs per idPers

	* Identify responsible males/females (18+)
	gen byte is_resp_male   = (demAge >= 18 & demMaleFlag == 1)
	gen byte is_resp_female = (demAge >= 18 & demMaleFlag == 0)

	* Adult–child flag by sex for adults only
	gen male_adultchildflag   = 0
	gen female_adultchildflag = 0
	replace male_adultchildflag   = demAdultChildFlag if (demMaleFlag == 1 & demAge >= 18)
	replace female_adultchildflag = demAdultChildFlag if (demMaleFlag == 0 & demAge >= 18)

	* BU-level (benefit-unit) aggregates of adult–child flags
	bys idBu: egen byte bu_male_AC   = max(male_adultchildflag)
	bys idBu: egen byte bu_female_AC = max(female_adultchildflag)

	* BU-level indicators of whether there is a responsible male/female
	bys idBu: egen byte has_resp_male   = max(is_resp_male)
	bys idBu: egen byte has_resp_female = max(is_resp_female)

	* Benefit-unit occupancy type (couples vs single male/female)
	gen str7 occcupancy = ""
	replace occcupancy = "Couples"       if (has_resp_male==1 & has_resp_female==1)
	replace occcupancy = "Single_male"   if (has_resp_male==1 & has_resp_female==0)
	replace occcupancy = "Single_female" if (has_resp_female==1 & has_resp_male==0)

	* Individual "at risk of employment" (working-age, not retired, not permanently disabled)
	gen byte maleAtRisk   = ( (demMaleFlag == 1) & !(labC4 == 2 | labC4 == 4 | healthDsblLongtermFlag == 1 | demAge < 16 | demAge > 75) )
	gen byte femaleAtRisk = ( (demMaleFlag == 0) & !(labC4 == 2 | labC4 == 4 | healthDsblLongtermFlag == 1 | demAge < 16 | demAge > 75) )

	* BU-level indicators of whether there is at least one male/female at risk
	bys idBu: egen byte bu_maleAtRisk   = max(maleAtRisk)
	bys idBu: egen byte bu_femaleAtRisk = max(femaleAtRisk)

	* Group codes for benefit-units (by occupancy and dependency/AC status)
	gen str6 group_code = ""
	replace group_code = "Couples"           if (occcupancy == "Couples"       & bu_maleAtRisk==1   & bu_femaleAtRisk==1)
	replace group_code = "SingleDep_Males"   if (occcupancy == "Couples"       & bu_maleAtRisk==1   & bu_femaleAtRisk!=1)
	replace group_code = "SingleDep_Females" if (occcupancy == "Couples"       & bu_maleAtRisk!=1   & bu_femaleAtRisk==1)

	replace group_code = "Single_male"       if (occcupancy == "Single_male"   & bu_male_AC==0)
	replace group_code = "SingleAC_Males"    if (occcupancy == "Single_male"   & bu_male_AC==1)

	replace group_code = "Single_female"     if (occcupancy == "Single_female" & bu_female_AC==0)
	replace group_code = "SingleAC_Females"  if (occcupancy == "Single_female" & bu_female_AC==1)


	* ---------- BU-LEVEL FRACTIONAL EMPLOYMENT ----------------------------- *
	* Person-level employment indicator (1 if employed)
	gen byte employed = (labC4 == 1)

	* Restrict to the relevant BU groups
	keep if inlist(group_code,"Couples","SingleDep_Males","SingleDep_Females","Single_male","Single_female","SingleAC_Males","SingleAC_Females")

	* Employment of responsible male/female adults
	gen byte male_emp   = employed if (demMaleFlag==1 & demAge>=18)
	gen byte female_emp = employed if (demMaleFlag==0 & demAge>=18)

	* Collapse to BU: whether the responsible male/female (if present) is employed
	bys idBu: egen byte bu_male_emp   = max(male_emp)
	bys idBu: egen byte bu_female_emp = max(female_emp)

	* Replace missing BU employment with 0 (no employed responsible adult of that sex)
	replace bu_male_emp   = 0 if missing(bu_male_emp)
	replace bu_female_emp = 0 if missing(bu_female_emp)

	* Number of responsible adults in the BU
	gen byte bu_nresp = has_resp_male + has_resp_female

	* Fractional BU employment: 0, 0.5, or 1 depending on how many responsible adults work
	gen double bu_fracemployed = .
	replace bu_fracemployed = (bu_male_emp + bu_female_emp) / bu_nresp if bu_nresp>0

	* Safety check: if no responsible adult (should not happen), set to 0
	replace bu_fracemployed = 0 if bu_nresp==0
	* ---------- END BU-LEVEL FRACTIONAL EMPLOYMENT ------------------------ *


	* BU-level weight: sum of person-level weights within each BU
	bys idBu: egen double bu_w = total(wgtCrossMainSurvey)

	* Keep one record per BU (so employment shares are BU-level, not person-level)
	bys idBu: gen byte bu_tag = _n == 1
	keep if bu_tag

	* Compute (weighted) mean employment share by group
	collapse (mean) empl_share = bu_fracemployed [pw = bu_w], by(group_code)
	gen year = `y'

	* Append to cumulative file for all years
	append using "${dir_working_data}/bu_empl_shares_${country}_allsubgroups_initpopdata.dta"
	duplicates drop
	save "${dir_working_data}/bu_empl_shares_${country}_allsubgroups_initpopdata.dta", replace

}

* -------------------------------------------------------------------------- *
* POST-PROCESSING: export aggregated results to Excel
* -------------------------------------------------------------------------- *

* Load aggregated BU-level employment shares for all years
use "${dir_working_data}/bu_empl_shares_${country}_allsubgroups_initpopdata.dta", clear

* Sort by year for neat export
sort year

* Create/overwrite Excel file that will hold all sheets
putexcel set "${dir_output}/alignment_targets_employment.xlsx", replace

* Identify all BU group codes
levelsof group_code, local(groups)

* Loop over groups and export each to its own sheet
foreach g of local groups {
	preserve
	keep if group_code == "`g'"
	sort year

	* Build separate matrices for year and share (written with explicit Excel formats)
	mkmat year,       matrix(Yr)
	mkmat empl_share, matrix(Sh)

	* Point putexcel at the output file and the group-specific sheet
	putexcel set "${dir_output}/alignment_targets_employment.xlsx", sheet("`g'") modify

	* Write headers
	putexcel A1=("year") B1=("empl_share")

	* Write data: years as integers, shares with 7 decimal places
	putexcel A2=matrix(Yr), nformat("0")
	putexcel B2=matrix(Sh), nformat("0.000000")

	restore
}

* --- INFO SHEET ------------------------------------------------------------ *
local today "`c(current_date)'"
putexcel set "${dir_output}/alignment_targets_employment.xlsx", sheet("info") modify
putexcel A1=("Field")       B1=("Value")
putexcel A2=("Target")      B2=("Mean fractional employment by benefit-unit (BU) type group")
putexcel A3=("Population")  B3=("BUs with at least one responsible adult (demAge >= 18) in a recognised group")
putexcel A4=("Groups")      B4=("Couples, SingleDep_Males, SingleDep_Females, Single_male, Single_female, SingleAC_Males, SingleAC_Females")
putexcel A5=("At-risk def") B5=("Age 16-75, not student (labC4 != 2), not retired (labC4 != 4), not disabled (healthDsblLongtermFlag != 1)")
putexcel A6=("Frac employ") B6=("(num employed responsible adults) / (num responsible adults) per BU; 0, 0.5, or 1 for couples")
putexcel A7=("Weighting")   B7=("BU-level weight = sum of person weights (wgtCrossMainSurvey) within the BU")
putexcel A8=("Note")        B8=("Mirrors ActivityAlignmentV2 matchesSubgroup() and BenefitUnit.fracEmployed() logic in SimPaths")
putexcel A9=("Source")      B9=("EU-SILC-based SimPaths initial populations")
putexcel A10=("Country")    B10=("${country}")
putexcel A11=("Years")      B11=("${min_year}-${max_year}")
putexcel A12=("Do-file")    B12=("05_employment_targets_initpopEU.do")
putexcel A13=("Produced")   B13=("`today'")
