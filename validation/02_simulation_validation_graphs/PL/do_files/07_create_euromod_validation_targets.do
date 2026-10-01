/*
This file pre-processes observed output data from EUROMOD, which will be used for validation of SimPaths.

Author: Ashley Burdett
Last modified: April 2025



*/
clear all 

local bu_headid = "tu_cbfam_hu_headid"

* Import the data 

forvalues year = 2011/2023 {
	
	insheet using "$dir_euromod_data/${country_lower}_`year'_std.txt", clear

	gen year = `year'
	
	save "$dir_work/${country}_EM_`year'.dta", replace
	
}

* Append data 

use "$dir_work/${country}_EM_2011.dta"

forvalues year = 2012/2023 {

	append using "$dir_work/${country}_EM_`year'.dta"

}

* Formatting of ids
format idhh %-18.0g
format tu_household_hu_headid %-18.0g
format tu_cbfam_hu_headid %-18.0g
format tu_cpfam_hu_headid %-18.0g
format idperson %-18.0g
format idmother %-18.0g
format idfather %-18.0g
format idpartner %-18.0g


* Benefit unit dispoaable income 

* Real terms 
gen CPI = .

replace CPI = 68.98  if year == 2005
replace CPI = 71.76  if year == 2006
replace CPI = 77.45  if year == 2007
replace CPI = 82.12  if year == 2008
replace CPI = 85.43  if year == 2009
replace CPI = 89.47  if year == 2010
replace CPI = 92.98  if year == 2011
replace CPI = 98.24  if year == 2012
replace CPI = 99.92  if year == 2013
replace CPI = 99.94  if year == 2014
replace CPI = 100    if year == 2015
replace CPI = 100.45 if year == 2016
replace CPI = 102.84 if year == 2017
replace CPI = 105.84 if year == 2018
replace CPI = 109.46 if year == 2019
replace CPI = 113.15 if year == 2020
replace CPI = 119.04 if year == 2021
replace CPI = 137.22 if year == 2022
replace CPI = 160.59 if year == 2023

lab var CPI "HICP, all items, base 2015"

gen ind_disp_y = ils_dispy / (CPI/100)


* Collapse by benefit unit head id
preserve 

collapse (sum) ind_disp_y, by(`bu_headid' year) 

rename ind_disp_y em_bu_disp_y

save  "$dir_work/${country}_EM_collapse.dta", replace

restore 

merge m:1 `bu_headid' year using "$dir_work/${country}_EM_collapse.dta"
drop _m


* Equivalised disposable income 
gen depChild = 1 if (dag >= 0 & dag <= 18) 
bys year idhh `bu_headid': egen dnc = sum(depChild)
lab var dnc "Number of dependent children 0 - 18"

* Generate modified-OECD equivalence scale: 1 for the household head, 0.5 for 
* additional adults, 0.3 for children < 14 years old 
bys year idhh `bu_headid': gen people_in_hh = _N
gen child = (dag < 14)
bys year idhh `bu_headid': egen children_in_hh = total(child) 
gen other_adults = people_in_hh - children_in_hh - 1 
	// -1 for the household head

gen equiv_factor = 1 + (0.5 * other_adults) + (0.3 * children_in_hh) 
	// Start with 1 because each household must have at least the head
la var equiv_factor "OECD-modified scale equivalence factor"

gen em_bu_eq_disp_y = em_bu_disp_y / equiv_factor 

drop child people_in_hh child children_in_hh other_adults


rename em_bu_disp_y valid_y_disp_yr_bu

save "$dir_work/${country}_EM_validation_data.dta", replace 
