/*******************************************************************************
* PROJECT:  		SimPaths EU 
* SECTION:			Additional series
* OBJECT: 			Mortality rate
* AUTHORS:			Ashley Burdett
* LAST UPDATE:		3/11/26
* COUNTRY: 			PL
********************************************************************************
* NOTES: 			Imports historical and projected mortality rates from
* 					Eurostat and constructs the SimPaths mortality input.
*
*					The final output contains the one-year probability of dying
* 					between exact ages x and x+1 (qx), expressed per 100,000.
* 
* 					Data accessed: 6/9/26
* 
* 					Projections series: estat_proj_23naasmr
* 					Years: 2022 - 2100
* 					Metadata for projections: https://ec.europa.eu/eurostat/cache/metadata/en/proj_23n_esms.htm
* 					The EUROPOP2023 projection data provide age-specific central
* 					mortality rates (Mx). These are converted to one-year
* 					probabilities of dying (qx) using the standard life-table
* 					formula:
* 
* 					    qx = 2Mx / (2 + Mx)
* 
* 						for ages 1+, and
*
* 					    q0 = M0 / (1 + 0.8M0)
* 
* 						for age 0.
* 
* 					The resulting probabilities are multiplied by 100,000 to
* 					match the SimPaths input format. 
*
* 					Historic series: estat_demo_mlifetable
* 					Years: 1960 - 2024 
*					Metadata: https://ec.europa.eu/eurostat/cache/metadata/en/demo_mor_esms.htm
* 					Historical central mortality rates are converted to qx in
*                   the same way. Observed data are top-coded at age 95+.
*                   Exact ages 95-100 are extrapolated using a three-age moving
*                   average of age-specific percentage changes, anchored to the
*                   projected mortality profile in 2025.
*******************************************************************************/
clear all
set more off
capture log close 


************************** Mortality Projections *******************************

* Country of interest
local country "${country}" 	

* Load data
import delimited using "$dir_input_data/estat_proj_23naasmr.tsv", ///
	delimiters(tab) clear

	
* Organize dataset	
forvalues i = 1/83 {
	
	local y = 2020 + `i'
	capture rename v`i' y`y'
	
}
	
rename y2021 freq_projection_sex_age_unit_geo

* Keep basleine projection 
keep if substr(freq,3,3) == "BSL"

* Select country 
keep if substr(freq,-2,2) == "${country}"	
	
* Gender 
gen Gender = 0 if substr(freq, 7, 1) == "F" 
replace Gender = 1 if substr(freq, 7, 1) == "M" 
drop if Gender == . 

label def Gender 0 "Female" 1 "Male"
label values Gender Gender 

order Gender	
	
* Age
gen Age = substr(freq,10,2) if substr(freq,12,1) == "," 
replace Age = substr(freq,10,1) if Age == "" 
replace Age = "0" if substr(freq,11,3) == "LT1"
replace Age = "100" if substr(freq,11,5) == "GE100"
destring Age, replace 

order Gender Age 
	
drop freq	
	
destring _all, replace 	
	
sort Gender Age 	

* Convert into probabiility of dying 
forvalues year = 2022/2100 {
	
	replace y`year' = (2*y`year')/(2+y`year') if Age != 0 
	
	replace y`year' = (y`year')/(1+ (0.8 * y`year')) if Age == 0 
	
}

* Convert into rate per 100,000 people 
forvalues year = 2022/2100 {
	
	replace y`year' = y`year' * 100000
	
}

rename y2022 y2022_proj	
rename y2023 y2023_proj	
rename y2024 y2024_proj	
	
save "$dir_data/mortality_rate", replace 
	
	
****************************** Mortality Data **********************************

/* 
This appears to be the central death rate because I get the same probability 
of death as in the data. Use death rate because get decimal places. Also 
indicated in thee 2015 documentation. 
*/

* Country of interest
local country "${country}" 

* Load data 
import delimited using "$dir_input_data/estat_demo_mlifetable.tsv", ///
	delimiters(tab) clear

* Organize dataset	
forvalues i = 1/85 {
	
	local y = 1958 + `i'
	capture rename v`i' y`y'
	
}
	
rename y1959 freq_indic_de_sex_age_geo

* Selec relevant series 
keep if substr(freq,3,9) == "DEATHRATE" 
keep if substr(freq,-2,2) == "${country}"	
	
* Gender 
gen Gender = 0 if substr(freq, 13, 1) == "F" 
replace Gender = 1 if substr(freq, 13, 1) == "M" 
drop if Gender == . 

label def Gender 0 "Female" 1 "Male"
label values Gender Gender 

order Gender	
		
* Age
gen Age = substr(freq,16,2) if substr(freq,18,1) == "," 
replace Age = substr(freq,16,1) if Age == "" 
replace Age = "0" if substr(freq,17,3) == "LT1"
replace Age = "95" if substr(freq,17,4) == "GE95"

drop if substr(freq,17,4) == "GE85"


destring Age, replace 

order Gender Age 
	
drop freq	
	
* Select years 
drop y1960-y1989	
	
* Turn observations into doubles 

* Remove Eurostat flags 
forvalues i = 1990/2024 {
	
	replace y`i' = "" if y`i' == ": "
	destring y`i', replace ignore("abcdefghijklmnopqrstuvwxyz ")

}	
	
sort Gender Age 	
	
* Convert into probability of dying 
forvalues year = 1990/2024 {
	
	cap replace y`year' = (2*y`year')/(2+y`year') if Age != 0 
	
	cap replace y`year' = (y`year')/(1+(0.8*y`year')) if Age == 0
	
}

* Convert into rate per 100,000 people 
forvalues year = 1990/2024 {
	
	replace y`year' = y`year' * 100000
	
}									
	
* Merge in projections 	
merge 1:1 Gender Age using "$dir_data/mortality_rate"
	
drop _m

* Check overlap 
gen diff2022 = y2022 - y2022_proj
gen diff2023 = y2023 - y2023_proj
gen diff2024 = y2024 - y2024_proj

list Age y2022 y2022_proj diff2022 if Gender == 0
list Age y2023 y2023_proj diff2023 if Gender == 0
list Age y2024 y2024_proj diff2024 if Gender == 0

gen pctdiff2022 = 100 * (y2022 - y2022_proj) / y2022_proj
gen pctdiff2023 = 100 * (y2023 - y2023_proj) / y2023_proj
gen pctdiff2024 = 100 * (y2024 - y2024_proj) / y2024_proj

* Comparison plots 
* Absolute difference
twoway ///
    (line diff2024 Age if Gender == 0 & Age < 95, sort), ///
    yline(0, lpattern(dash)) ///
    xtitle("Age") ///
    ytitle("Absolute difference") ///
    title("Absolute difference between obs and proj mortality") ///
    subtitle("Females, 2024")

* Percentage difference
twoway ///
    (line pctdiff2024 Age if Gender == 0, sort), ///
    yline(0, lpattern(dash)) ///
    xtitle("Age") ///
    ytitle("% difference") ///
    title("Percentage difference between obs and proj mortality") ///
	subtitle("Females, 2024")

graph drop _all
/*
Inspection of the 2024 overlap shows that observed and projected mortality 
probabilities are broadly consistent across much of the age distribution. 
Percentage differences are relatively volatile at younger ages, where mortality 
probabilities are low, but correspond to small absolute differences. At older 
ages, observed mortality increasingly exceeds projected mortality, although the 
particularly large difference at age 95 reflects the non-comparability of the 
historical open-ended 95+ category and the projected single-year age category.

For consistency with the other SimPaths EU countries, observed mortality is 
retained through 2024 and EUROPOP2023 projections are used from 2025 onwards 
without rebasing. The treatment of mortality at ages 95 and above is addressed 
separately.
*/	

drop y2022_p y2023_p y2024_p diff202* pctdiff202*

sort Gender Age 
 

******************************* Extrapolation **********************************
/*
The observed life-table data are top-coded at age 85 through 2013 and age 95
from 2014 onwards. Exact-age mortality rates above these thresholds are
constructed by extrapolating the observed series. The extrapolation uses a
three-age moving average of the age-specific percentage change, with the
projected mortality schedule providing the age profile beyond the observed
data.
*/ 
 

* 1990-2013: ages 85+


* Calculate age-to-age percentage change from 2025 projection for ages 85+
bysort Gender (Age): gen perc_change = ///
    (y2025 - y2025[_n-1]) / y2025[_n-1] if Age > 84

forvalues year = 1990/2013 {

    * Start with projected age-to-age changes at ages 85+
    gen perc_change_`year' = perc_change

    * Use observed age-to-age changes where observed data are available
    bysort Gender (Age): replace perc_change_`year' = ///
        (y`year' - y`year'[_n-1]) / y`year'[_n-1] ///
        if Age < 85

    * Three-age moving average around transition and through extrapolated ages
    bysort Gender (Age): gen ma_`year' = ///
        (perc_change_`year' + ///
         perc_change_`year'[_n-1] + ///
         perc_change_`year'[_n-2]) / 3 ///
        if Age > 84

    * Extrapolate mortality recursively from age 84 onwards
    bysort Gender (Age): replace y`year' = ///
        y`year'[_n-1] * (1 + ma_`year') ///
        if Age > 84
}

drop perc_change perc_change_1990-perc_change_2013 ///
    ma_1990-ma_2013 
 
 

* 2014-2024: ages 95+

* Remove the observed 95+ aggregate: this is not mortality at exact age 95
forvalues year = 2014/2024 {
    replace y`year' = . if Age == 95
}

* Calculate age-to-age percentage change from 2025 projection for ages 95+
bysort Gender (Age): gen perc_change = ///
    (y2025 - y2025[_n-1]) / y2025[_n-1] if Age > 94

forvalues year = 2014/2024 {

    * Start with projected age-to-age changes at ages 95+
    gen perc_change_`year' = perc_change

    * Use observed age-to-age changes where observed data are available
    bysort Gender (Age): replace perc_change_`year' = ///
        (y`year' - y`year'[_n-1]) / y`year'[_n-1] ///
        if Age < 95

    * Three-age moving average around transition and through extrapolated ages
    bysort Gender (Age): gen ma_`year' = ///
        (perc_change_`year' + ///
         perc_change_`year'[_n-1] + ///
         perc_change_`year'[_n-2]) / 3 ///
        if Age > 94

    * Extrapolate mortality recursively from age 94 onwards
    bysort Gender (Age): replace y`year' = ///
        y`year'[_n-1] * (1 + ma_`year') ///
        if Age > 94
}

drop perc_change perc_change_2014-perc_change_2024 ///
    ma_2014-ma_2024 
 
* Checks of the extrapolation points 
twoway ///
    (line y2012 Age if Gender == 0 & Age >= 80, sort) ///
    (line y2013 Age if Gender == 0 & Age >= 80, sort) ///
    (line y2014 Age if Gender == 0 & Age >= 80, sort), ///
    xtitle("Age") ///
    ytitle("Probability of death per 100,000") ///
    legend(order(1 "2012" 2 "2013" 3 "2014")) ///
    title("Mortality around change in historical age coverage, females") 
	
twoway ///
    (line y2012 Age if Gender == 1 & Age >= 80, sort) ///
    (line y2013 Age if Gender == 1 & Age >= 80, sort) ///
    (line y2014 Age if Gender == 1 & Age >= 80, sort), ///
    xtitle("Age") ///
    ytitle("Probability of death per 100,000") ///
    legend(order(1 "2012" 2 "2013" 3 "2014")) ///
    title("Mortality around change in historical age coverage, males") 	
 
bysort Gender (Age): gen d2013 = y2013 - y2013[_n-1]
bysort Gender (Age): gen d2024 = y2024 - y2024[_n-1]
list Age d2013 if Gender == 0 & inrange(Age,82,88) 
list Age d2013 if Gender == 1 & inrange(Age,82,88) 


twoway ///
    (line y2024 Age if Gender == 0 & Age >= 90, sort), ///
    xtitle("Age") ///
    ytitle("Probability of death per 100,000") ///
    title("Observed and extrapolated mortality") ///
	subtitle("Females, 2024")
	
twoway ///
    (line y2024 Age if Gender == 1 & Age >= 90, sort), ///
    xtitle("Age") ///
    ytitle("Probability of death per 100,000") ///
    title("Observed and extrapolated mortality") ///
	subtitle("Males, 2024") 
 
list Age d2024 if Gender == 0 & inrange(Age,92,98) 
list Age d2024 if Gender == 1 & inrange(Age,92,98)  
 
drop d2024 d2013

graph drop _all 

/*
Inspection of the extrapolated mortality profiles shows that the transition 
from observed to extrapolated mortality at ages 85 and 95 does not introduce 
obvious discontinuities. The resulting age profiles generally increase smoothly
 with age.

Some variation is evident at the oldest ages, particularly among males. Further 
inspection indicates that this largely reflects volatility in the observed 
mortality rates immediately below the extrapolation threshold, which is carried 
forward into the extrapolated series.

The existing extrapolation methodology is therefore retained for PL, consistent 
with the approach used for the other SimPaths EU countries.
*/
 
 
****************************** Export to Excel *********************************
	
* Sheet name read by SimPaths (Parameters.loadParameters)
export excel using "$dir_work/projections_mortality${country}.xlsx", ///
	firstrow(var) sheet("MortalityByGenderAgeYear") replace


* Replace Excel column headings with calendar years
putexcel set "$dir_work/projections_mortality${country}.xlsx", ///
	sheet("MortalityByGenderAgeYear") modify

local col = 3    // Column C: Gender=A, Age=B

forvalues year = 1990/2100 {

    local c = `col'
    local letter ""

    while (`c' > 0) {
        local rem = mod(`c' - 1, 26)
        local letter = char(`rem' + 65) + "`letter'"
        local c = floor((`c' - 1) / 26)
    }

    putexcel `letter'1 = `year'

    local ++col
}
	
putexcel set "$dir_work/projections_mortality${country}", ///
    sheet("Info") modify

putexcel A1 = "Purpose:" ///
    B1 = "This file stores the observed and projected mortality series used by SimPaths."

putexcel A2 = "Developers:" ///
    B2 = "Poland series prepared by Ashley Burdett (AB)."

putexcel A3 = "First version:" ///
    B3 = "2025"

putexcel A4 = "Last version:" ///
    B4 = "3/1/2026 (AB)"

putexcel A5 = "Created using:" ///
    B5 = "Do-file mortality_rate.do contained in time_series/${country}/do_files."

putexcel A6 = "Source - observed mortality:" ///
    B6 = "Eurostat life tables (demo_mlifetable). The observed central death rate (DEATHRATE) is used for 1960-2024."

putexcel A7 = "Source - projected mortality:" ///
    B7 = "Eurostat mortality assumptions underlying the EUROPOP2023 population projections (proj_23naasmr). The baseline age-specific mortality rate (ASMR) series is used for 2022-2100."

putexcel A8 = "Coverage in current workbook:" ///
    B8 = "Observed mortality: 1960-2024; projected mortality: 2025-2100."

putexcel A9 = "Transformation:" ///
    B9 = "Observed and projected central death rates are converted into the probability of death between exact ages x and x+1 using the Eurostat life-table formula. The resulting probabilities are expressed as deaths per 100,000 population."

putexcel A10 = "Joining method:" ///
    B10 = "Comparison of the observed and projected series over the overlapping period (2022-2024) indicated no systematic discontinuity. Observed data are therefore retained through 2024 and the projected series is used from 2025 onwards without rebasing."

putexcel A11 = "Age extrapolation:" ///
    B11 = "Observed mortality is top-coded at age 85 through 2013 and age 95 from 2014 onwards. Exact-age mortality rates above these thresholds are extrapolated using a three-age moving average of the age-specific percentage change, with the projected mortality schedule providing the age profile beyond the observed data."

putexcel A12 = "NOTE:" ///
    B12 = "All cells read by the model should contain plain numeric year/value data only. Remove formulas, merged headers and non-numeric values from active sheets."
