/*******************************************************************************
* PROJECT:  		SimPaths EU 
* SECTION:			Additional series
* OBJECT: 			Fertility rate
* AUTHORS:			Ashley Burdett
* LAST UPDATE:		3/11/26
* COUNTRY: 			PL  
********************************************************************************
* NOTES:            This file imports and cleans observed and projected
*                   fertility data downloaded from EUROSTAT.
*
* 					Data accessed: 6/9/26
* 
*                   Observed total fertility rates (TFR) are taken from the
*                   EUROSTAT series demo_find (2011-2024):
*                   https://ec.europa.eu/eurostat/databrowser/explore/all/popul?sort=category&lang=en&subtheme=demo.demo_fer&display=list
*
*                   Projected total fertility rates are taken from the
*                   EUROSTAT series proj_23naasfr (2022-2100):
*                   https://ec.europa.eu/eurostat/databrowser/view/proj_23naasfr/default/table?lang=en
*
*                   Inspection of the overlap (2022-2024) indicated that the
*                   projected series lay consistently above the observed
*                   series. To ensure continuity, the projected TFR is rebased
*                   to the final observed year (2024) while preserving the
*                   projected year-to-year trajectory.
*
*                   The rebased TFR is converted into an approximate General
*                   Fertility Rate (GFR), expressed as births per 1,000 women
*                   aged 18-49, for use in SimPaths.
*******************************************************************************/
clear all
set more off
capture log close 


****************************** TFR Historic Data *******************************

* Import data 
import delimited using "$dir_input_data/estat_demo_find.tsv", ///
	delimiters(tab) clear

* Organize data	
forvalues i = 1/66 {
	
	local y = 1958 + `i'
	capture rename v`i' y`y'
	
}

rename y1959 freq_indic_de_geo

drop if freq == "freq,indic_de,geo\TIME_PERIOD"


* Keep only Spanish observations 
keep if substr(freq, -2, 2) == "${country}"

* Keep only total fertility rate 
keep if substr(freq, 3, 8) == "TOTFERRT"

* Only keep relevant years 
keep y2011-y2024

* Remove Eurostat flags 
forvalues i = 2011/2024 {
	
	replace y`i' = "" if y`i' == ": "
	destring y`i', replace ignore("abcdefghijklmnopqrstuvwxyz ")

}


* Reshape from one observation with years in columns to 1 observation per year
gen id = 1
reshape long y, i(id) j(year)
drop id 

rename y tfr 

destring tfr, replace


save "$dir_data/total_fertility_rate", replace 


****************************** TFR Projections *********************************

* Code of country of interest 
local country "${country}" 	


* Import data 
import delimited using "$dir_input_data/estat_proj_23naasfr.tsv", ///
	delimiters(tab) clear

* Organize data	
forvalues i = 1/80 {
	
	local y = 2020 + `i'
	capture rename v`i' y`y'
	
}

rename y2021 freq_projection_age_unit_geo

drop if freq == "freq,projection,age,unit,geo\TIME_PERIOD"


* Keep only Spanish observations 
keep if substr(freq, -2, 2) == "${country}"

* Keep total fertility rate 
* This uniquely identifies the baseline projection series in the dataset
keep if substr(freq, 7, 5) == "TOTAL"

* Tidy up  
drop freq 

* Reshape from years in columns to one observation per year
gen id = 1
reshape long y, i(id) j(year)
drop id 

* Flag projection observations for subsequent merge with the observed series
gen x = 1 


******************************* Combine Series *********************************

* Add historic series 
append using "$dir_data/total_fertility_rate"

sort year x
 
* Inspect 
summ tfr if year == 2024 & missing(x), meanonly
local tfr_obs = r(mean)

summ y if year == 2024 & x == 1, meanonly
local tfr_proj = r(mean)

local scale = `tfr_obs' / `tfr_proj'

display "Observed TFR 2024:  `tfr_obs'"
display "Projected TFR 2024: `tfr_proj'"
display "Scaling factor:      `scale'"
 
list year tfr y if inrange(year,2022,2024)

/*
Inspection of the 2022-2024 overlap shows that projected TFR is below 
the observed series in each year, with the gap widening over time as observed
fertility declines more rapidly than assumed in the projection. .
*/


********************************* Rebase ***************************************

/*
To ensure continuity between the historical and projected series, the
projection is rebased to the final observed year (2024). The projected
year-to-year trajectory is retained, while the level is adjusted to match the
last observed value.
*/
summ tfr if year == 2024 & missing(x), meanonly
local tfr_obs = r(mean)

summ y if year == 2024 & x == 1, meanonly
local tfr_proj = r(mean)

local scale = `tfr_obs' / `tfr_proj'

gen tfr_final = tfr
replace tfr_final = y * `scale' if x == 1 & year >= 2025


* Tidy up   
drop if inrange(year,2022,2024) & x == 1  
drop y x tfr 

rename tfr_final tfr  
 
format tfr  %9.2f 

 
************************************ GFR ***************************************

/*
SimPaths aligns fertility using the General Fertility Rate (GFR). The GFR is
approximated from the Total Fertility Rate (TFR) by assuming births are
distributed uniformly across the modelled fertility ages (18-49 years).
Expressed as births per 1,000 women aged 18-49.
*/
gen gfr = tfr/(49-18+1)*1000 


******************************* Export to Excel ********************************
	 
putexcel set "$dir_work/projections_fertility${country}.xlsx", ///
    sheet("Info") replace

putexcel A1 = "Purpose:" ///
    B1 = "This file stores the observed and projected fertility series used by SimPaths."

putexcel A2 = "Developers:" ///
    B2 = "Poland series prepared by Ashley Burdett (AB)."

putexcel A3 = "First version:" ///
    B3 = "2025"

putexcel A4 = "Last version:" ///
    B4 = "3/11/2026 (AB)"

putexcel A5 = "Created using:" ///
    B5 = "Do-file fertility_rate.do contained in time_series/${country}/do_files."

putexcel A6 = "Source - observed fertility:" ///
    B6 = "Eurostat fertility indicators (demo_find). The observed Total Fertility Rate (TFR) series (totferrt) is used for 2011-2024."

putexcel A7 = "Source - projected fertility:" ///
    B7 = "Eurostat population projections (proj_25naasfr). The baseline Total Fertility Rate (A, BSL, TOTAL, NR) series is used."

putexcel A8 = "Coverage in current workbook:" ///
    B8 = "Observed TFR: 2011-2024; projected TFR: 2025-2100 after rebasing."

putexcel A9 = "Rebasing method:" ///
    B9 = "The projected TFR is rebased to the final observed year (2024). A single adjustment factor is calculated from the ratio of the observed and projected TFR in 2024 and applied to all projected years, removing the discontinuity at the join while preserving the projected trajectory."

putexcel A10 = "Transformation:" ///
    B10 = "The rebased Total Fertility Rate (TFR) is converted into an approximate General Fertility Rate (GFR), expressed as births per 1,000 women aged 18-49, for use in SimPaths."

putexcel A11 = "NOTE:" ///
    B11 = "All cells read by the model should contain plain numeric year/value data only. Remove formulas, merged headers and non-numeric values from active sheets."


putexcel set "$dir_work/projections_fertility${country}.xlsx", ///
	sheet("${country}") modify 

putexcel A1 = "Fertility"
putexcel A2 = "Value"	 
	
local col = 2

forvalues y = 2011/2045 {

    quietly summarize gfr if year == `y', meanonly
    local mean = r(mean)

    // Convert column number to Excel letters
    local c = `col'
    local letter ""

    while (`c' > 0) {
        local rem = mod(`c' - 1, 26)
        local letter = char(`rem' + 65) + "`letter'"
        local c = floor((`c' - 1) / 26)
    }

    putexcel `letter'1 = `y'
    putexcel `letter'2 = `mean'

    local ++col
}
