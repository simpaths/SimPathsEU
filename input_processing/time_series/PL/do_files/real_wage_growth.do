********************************************************************************
* PROJECT:  		SimPaths EU  
* SECTION:			Additional series
* OBJECT: 			Wage growth
* AUTHORS:			Ashley Burdett
* LAST UPDATE:		3/11/26
* COUNTRY: 			PL
********************************************************************************
* NOTES: 			Use the wage information from the EU-SILC panel data set. 
* 					Some calculations aplied to the Excel files after populated 
* 
* 					Useful break down of the codes in the dataset: 
* https://ec.europa.eu/eurostat/databrowser/explore/all/popul?sort=category&lang=en&subtheme=labour.lc.lci&display=list
* 
********************************************************************************
clear all
set more off
capture log close 


* Import data 
import delimited using "$dir_input_data/estat_lc_lci_r2_a.tsv", ///
	delimiters(tab) clear

* Organize data	
forvalues i = 1/31 {
	
	local y = 1994 + `i'
	capture rename v`i' y`y'
	
}

rename y1995 freq_unit_nace_r2_lcstruct_geo

drop if freq == "freq,unit,nace_r2,lcstruct,geo\TIME_PERIOD"
 
	
* Select series 

keep if substr(freq, -2, 2) == "${country}"

* 2020 index 
keep if substr(freq, 3, 3) == "I20" 

* Industry, construction and services 
* (except activities of households as employers and extra-territorial 
* organisations and bodies)
keep if substr(freq, 7, 3) == "B-S" 

* Wages and salaries (total)
keep if substr(freq, 11, 3) == "D11" 

drop freq

* Convert values to numeric
forvalues i = 1996/2025 {
    
    replace y`i' = word(y`i', 1)
    replace y`i' = "" if y`i' == ":"
    destring y`i', replace
	
}

drop y1996-y1999

* Transpose 
xpose, clear 

gen Year = 1999
replace Year = Year[_n-1] + 1 if Year[_n-1] != . 

drop if Year == 1999

rename v1 LCI 
order Year LCI 

* Rebase the index to 2015 
summ LCI if Year == 2015, meanonly
local base = r(mean)

replace LCI = (LCI / `base') * 100
 
* Deflate 
merge 1:1 Year using "$dir_work/data/inflation"
drop if _m != 3 
drop _m

gen r_LCI = . 
replace r_LCI = (LCI / CPI) * 100

* Create growth rate 
* Construct annual growth in real LCI (%)
sort Year

gen r_LCI_growth = 100 * (r_LCI / r_LCI[_n-1] - 1) ///
    if Year == Year[_n-1] + 1


rename r_LCI Value 
rename r_LCI_growth Growth
drop LCI CPI 
	
order Year Value Growth	
	
	
******************************* Export to Excel ********************************

export excel Year Value Growth using ///
	"$dir_work/time_series_factor${country}.xlsx", sheet("wage_growth") ///
	sheetmodify firstrow(variables)


