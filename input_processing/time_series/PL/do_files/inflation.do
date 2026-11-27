/*******************************************************************************
* PROJECT:       	SimPaths EU
* SECTION:        	Additional series
* OBJECT:         	Inflation
* AUTHORS:        	Ashley Burdett
* LAST UPDATE:    	3/11/2026
* COUNTRY:        	Poland
********************************************************************************
* NOTES:          	Constructs the inflation alignment series for Poland using
*                 	Eurostat Harmonised Index of Consumer Prices (HICP).
*
*                 	Observed data are taken from Eurostat dataset
*                 	prc_hicp_aind using the annual average all-items HICP
*                 	index (INX_A_AVG, CP00).
*
*
*                 	Eurostat metadata:
*                 	https://ec.europa.eu/eurostat/cache/metadata/en/prc_hicp_esms.htm
* 				  	https://ec.europa.eu/eurostat/data/database?node_code=prc_hicp_aind
*******************************************************************************/
clear all
set more off
capture log close 


* Load data 
import delimited using "$dir_input_data/estat_prc_hicp_aind.tsv", ///
	delimiters(tab) clear

* Organize dataset	
forvalues i = 1/35 {
	
	local y = 1994 + `i'
	capture rename v`i' y`y'
	
}
	
	
rename y1995 freq_unit_coicop_geo	
	
* Select country of interest 
keep if substr(freq, -2, 2) == "${country}" 	

* Select all items 
keep if substr(freq, -7, 4) == "CP00" 	

* Select chain-linked volumnes series for RGDP
keep if substr(freq, 3, 9) == "INX_A_AVG" 	

* Prep formatting 
drop freq
	
* Convert year values to numeric
destring y*, replace	
	
* Transpose 
xpose, clear 

gen Year = 1996
replace Year = Year[_n-1] + 1 if Year[_n-1] != . 
	
rename v1 CPI 

save "$dir_work/data/inflation", replace 

rename CPI Value 

order Year Value

drop if Value == . 


******************************* EXPORT TO EXCEL ********************************

export excel Year Value using "$dir_work/time_series_factor${country}.xlsx", ///
    sheet("inflation") sheetmodify firstrow(variables)
