/*******************************************************************************
* PROJECT:          SimPaths EU
* SECTION:          Additional series
* OBJECT:           Population projections
* AUTHORS:          Ashley Burdett
* LAST UPDATE:      3/11/26
* COUNTRY:          Poland
********************************************************************************
* NOTES:            This file imports and cleans observed and projected
*                   population data downloaded from EUROSTAT by age, sex and
*                   NUTS1 region for Poland.
*
* 					Data accressed: 6/9/26
* 
*                   Observed population figures are taken from the EUROSTAT
*                   series demo_r_d2jan (2011-2025):
*                   https://ec.europa.eu/eurostat/databrowser/explore/all/popul?lang=en&subtheme=demo.demopreg&display=list&sort=category&extractionId=demo_r_d2jan
*
*                   Population projections are taken from the EUROSTAT series
*                   proj_19rp3 (2019-2060, baseline projection):
*                   https://ec.europa.eu/eurostat/web/population-demography/population-projections/database
*
*                   Population projections are provided at the NUTS3 level and
*                   aggregated to NUTS1. To ensure continuity between the
*                   observed and projected series, the projected population is
*                   rebased to the final observed year (2025) using a
*                   Gender-Age-Region specific scaling factor. This preserves
*                   the projected growth path while removing the discontinuity
*                   at the join.
*
*					Adjust regions so that consistent thorough estimation 
* 					period. 
*******************************************************************************/
clear all
set more off
capture log close 


*************************** Population Projections *****************************

* Import data 
import delimited using "$dir_input_data/estat_proj_19rp3.tsv", ///
	delimiters(tab) clear
// Data at NUTS3 level 	

* Rename variables 
forvalues i = 1/83 {
	
	local y = 2017 + `i'
	rename v`i' y`y'
	
}

drop y2061-y2100
rename y2018 freq_proj_age_sex_unit_geo

drop if freq == "freq,projection,age,sex,unit,geo\TIME_PERIOD"
drop if strpos(freq, "TOTAL") > 0

* Select country of interest 
keep if substr(freq, -5, 2) == "${country}" 

* Keep baseline projections 
keep if substr(freq, 3, 3) == "BSL"

* Gender 
gen Gender = 0 if substr(freq, -11, 1) == "F" 
replace Gender = 1 if substr(freq, -11, 1) == "M" 
drop if Gender == . 

label def Gender 0 "Female" 1 "Male"
label values Gender Gender 

order Gender

* Age
gen Age = substr(freq,8,2) if substr(freq,9,1) != "," 
replace Age = substr(freq,8,1) if Age == "" 
replace Age = "0" if substr(freq,9,3) == "LT1"
replace Age = "100" if substr(freq,9,5) == "GE100"
destring Age, replace 

order Gender Age 

* NUTS 3 region 
gen region_NUTS3 = substr(freq,-5,5) 

order Gender Age region

* NUTS 1  >> EDIT <<
gen Region = 2 if substr(region_NUTS3,3,1) == "2"
replace Region = 4 if substr(region_NUTS3,3,1) == "4"
replace Region = 5 if substr(region_NUTS3,3,1) == "5"
replace Region = 6 if substr(region_NUTS3,3,1) == "6"
replace Region = 10 if ///
	substr(region_NUTS3,3,1) == "I" | substr(region_NUTS3,3,1) == "1" | ///
	substr(region_NUTS3,3,1) == "3" | substr(region_NUTS3,3,1) == "7" | ///
	substr(region_NUTS3,3,1) == "8" | substr(region_NUTS3,3,1) == "9"

label def Region ///
	2 "${country}2" 4 "${country}4" 5 "${country}5" ///
	6 "${country}6" 10 "${country}10" 
label values Region Region 

order Gender Age region Region

drop freq region_NUTS3

* Aggregate NUTS3 projections to NUTS1
collapse (sum) y2019-y2060, by(Gender Age Region)

* Check that Gender-Age-Region uniquely identifies observations >> EDIT <<
isid Gender Age Region
assert _N == 2 * 101 * 5

* Preserve projected 2025 separately for subsequent rebasing
rename y2025 y2025_proj

save "$dir_data/population_projections", replace 


************************* Historic Population Data *****************************

* Import data 
import delimited using "$dir_input_data/estat_demo_r_d2jan.tsv", ///
	delimiters(tab) clear
// Data at NUTS1 and NUTS2 level 
	
* Rename variables 
forvalues i = 1/40 {
	
	local y = 1988 + `i'
	capture rename v`i' y`y'
	
}

rename y1989 freq_unit_age_geo

drop if freq == "freq,unit,sex,age,geo\TIME_PERIOD"

/*
Don't have data for new NUTS regions before the wee formed. Since merge together 
the changing regions together can compute the population of this residual 
aggregated region using the total population of the country and the sum of the 
contant regions for each year-gender-age combination. 
*/

* Select country observations 	 	>> EDIT <<
keep if substr(freq, -3, 3) == "${country}2" | ///	
			substr(freq, -3, 3) == "${country}4" | ///
			substr(freq, -3, 3) == "${country}5" | ///
			substr(freq, -3, 3) == "${country}6" | ///
			substr(freq, -3, 3) == "${country}7" | ///
			substr(freq, -3, 3) == "${country}8" | ///
			substr(freq, -3, 3) == "${country}9" | ///
			substr(freq, -2, 2) == "${country}"
	
* Gender 
gen Gender = 0 if substr(freq, 6, 1) == "F" 
replace Gender = 1 if substr(freq, 6, 1) == "M" 
drop if missing(Gender)

label def Gender 0 "Female" 1 "Male"
label val Gender Gender 
order Gender

* Age
gen Age = substr(freq,9,2) if substr(freq,11,1) == "," 
replace Age = substr(freq,9,1) if Age == "" 
replace Age = "0" if substr(freq,10,3) == "LT1"
replace Age = "100" if substr(freq,10,4) == "OPEN"

drop if Age == "O"
drop if Age == "_"
drop if Age == "NK" 

destring Age, replace 

order Gender Age 

* Construct NUTS1 region 	>> EDIT <<
gen Region = 2 if substr(freq,-1,1) == "2"
replace Region = 4 if substr(freq,-1,1) == "4"
replace Region = 5 if substr(freq,-1,1) == "5"
replace Region = 6 if substr(freq,-1,1) == "6"
replace Region = 10 if substr(freq,-1,1) == "7" | substr(freq,-1,1) == "8" | ///
	substr(freq,-1,1) == "9"

label def Region ///
	2 "${country}2" 4 "${country}4" 5 "${country}5" ///
	6 "${country}6" 10 "${country}10" 
label values Region Region 
	
order Gender Age Region

// Region is missing for observations corresponding to the total population 
// of PL 
	
* Convert population figures to numeric
sort Region Gender Age 

forvalues i = 1990/2025 {
	
	replace y`i' = "" if y`i' == ": "
	destring y`i', replace ignore("abcdefghijklmnopqrstuvwxyz ")

}

count if Region == 7

misstable summarize y1990-y2025 if Region == 7

/*
Construct population for residual region PL10

The original population data do not contain observations for PL7, PL8 and PL9.
These regions have been added as placeholders and are combined into a single
SimPaths region (PL10).

The population of PL10 is calculated as the difference between the national
population and the sum of the populations in the other NUTS1 regions, separately
by gender, age and year.

The residual is assigned to the PL7 observation, while PL8 and PL9 remain zero.
All three observations are coded as Region == 10.

The calculation is only performed where a national population value is
available. Otherwise, the residual remains missing.
*/

forvalues year = 1990/2025 {

    * Set the three placeholder regions (PL7, PL8, PL9) to zero 
    replace y`year' = 0 if Region == 10

    * Sum population across regions within each gender-age group,
    * excluding the national total (Region == .).
    bysort Gender Age: egen total_nce_`year' = ///
        total(y`year') if Region != .

    * Sort so the national observation (Region == .) follows the
    * regional observations within each gender-age group.
    sort Gender Age Region

    * Copy the regional sum to the national observation.
    replace total_nce_`year' = total_nce_`year'[_n-1] ///
        if Region == .

    * Calculate the residual population at the national observation.
    gen leftover = y`year' - total_nce_`year' if Region == .

    * Propagate the residual to all observations within the same
    * gender-age group, provided a national value was available.
    bysort Gender Age (leftover): ///
        replace leftover = leftover[1] if !missing(leftover[1])

	* Assign the residual population to the combined region PL10,
	* representing the original NUTS1 regions PL7, PL8 and PL9.
	replace y`year' = leftover ///
		if Region == 10 & !missing(leftover)
		
    * Remove temporary variables before processing the next year.
    drop total_nce_`year' leftover
}

sort Gender Region Age  

* Remove the two redundant placeholder observations.
* PL7 retains the combined residual population and represents PL10.
drop if inlist(substr(freq_unit_age_geo, -3, 3), "PL8", "PL9")

drop if Region == . 	

isid Gender Age Region
assert _N == 2 * 101 * 5

sort Gender Age Region 


******************************* Combine Series *********************************
	
* Merge in population projections
merge 1:1 Gender Age Region using "$dir_data/population_projections"

* Check merge
tab _merge
assert _merge == 3
drop _merge

* Keep relevant historical period
drop y1990-y2010

* Organize dataset
order Gender Region Age
sort Gender Region Age	
	
	
********************************* Rebase ***************************************

/*
Rebase projected population to the final observed year (2025). A separate
scaling factor is calculated for each Gender-Age-Region cell and applied to
all projected years from 2026 onwards. This preserves the projected growth
path within each cell while removing the discontinuity at the join.
*/

assert y2025_proj > 0
gen factor = y2025 / y2025_proj

* Check scaling factors
summ factor, detail
count if missing(factor)

assert r(N) == 0

* Inspect unusually large adjustments
list Gender Region Age y2025 y2025_proj factor ///
    if factor < 0.8 | factor > 1.2

table Region, statistic(mean factor)	
	
* Apply cell-specific scaling factor to projections
forvalues year = 2026/2060 {

    replace y`year' = round(y`year' * factor)

}

drop factor y2025_proj freq_unit_age_geo	
	
	
******************************* Export to Excel ********************************

export excel using "$dir_work/align_popProjections${country}.xlsx", ///
	firstrow(var) sheet("${country}") replace

* Replace Excel column headings with calendar years	
putexcel set "$dir_work/align_popProjections${country}.xlsx", ///
    sheet("${country}") modify

local col = 4    // A=Gender, B=Region, C=Age, D=2011

forvalues year = 2011/2060 {

    local c = `col'
    local letter ""

    while (`c' > 0) {
        local rem = mod(`c'-1,26)
        local letter = char(`rem'+65) + "`letter'"
        local c = floor((`c'-1)/26)
    }

    putexcel `letter'1 = (`year')

    local ++col
}


putexcel set "$dir_work/align_popProjections${country}.xlsx", ///
    sheet("info") modify 

putexcel A1 = "Purpose:" ///
    B1 = "This file stores the observed and projected population series used by SimPaths for population alignment."

putexcel A2 = "Developers:" ///
    B2 = "Poland series prepared by Ashley Burdett (AB)."

putexcel A3 = "First version:" ///
    B3 = "2025"

putexcel A4 = "Last version:" ///
    B4 = "3/11/2026 (AB)"

putexcel A5 = "Created using:" ///
    B5 = "Do-file population_projections.do contained in time_series/${country}/do_files."

putexcel A6 = "Source - observed population:" ///
    B6 = "Eurostat population on 1 January by age, sex and NUTS 2 region (demo_r_d2jan). Observed values for 2011-2025 are used."

putexcel A7 = "Source - projected population:" ///
    B7 = "Eurostat regional population projections (proj_19rp3). Baseline population projections are used."

putexcel A8 = "Coverage in current workbook:" ///
    B8 = "Observed population: 2011-2025; projected population: 2026-2060 after rebasing."

putexcel A9 = "Dimensions:" ///
    B9 = "Population values are provided by gender, age, region and year."

putexcel A10 = "Projection scenario:" ///
    B10 = "The Eurostat baseline population projection scenario is used."

putexcel A11 = "Rebasing method:" ///
    B11 = "Projected population is rebased to the final observed year (2025). A separate scaling factor is calculated for each gender-age-region cell as the ratio of observed to projected population in 2025. This factor is applied to projected values from 2026 onwards, removing the discontinuity at the join while preserving the projected growth path within each cell."

putexcel A12 = "NOTE:" ///
    B12 = "All cells read by the model should contain plain numeric year/value data only. Remove formulas, merged headers and non-numeric values from active sheets."
