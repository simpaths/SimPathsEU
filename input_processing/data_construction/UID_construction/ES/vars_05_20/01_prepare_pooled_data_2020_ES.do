/*******************************************************************************
* PROJECT:              SimPaths EU 
* DO-FILE NAME:         01_prepare_pooled_data_2020_ES.do
* DESCRIPTION:          Compiles panel dataset from EU-SILC  
********************************************************************************
* COUNTRY:              Poland
* DATA:         	    EU-SILC panel based on the EU-SILC longitudinal datasets 
* 						created using GESIS Stata script: 
* 						https://www.gesis.org/gml/european-microdata/eu-silc.
******************************************************************************** 
* AUTHORS: 				Daria Popova, Ashley Burdett
* LAST UPDATE:          March 2025 
* NOTE:					Used to constructed country specific panel (05-20) to 
* 						obtain non-updated variables in the set-ups.  
*						This file is the same as 01_prepare_pooled_data_ES it 
* 						it just calls different data. 
*******************************************************************************/


* Load Personal Register (R-FILE), i.e. all people incl children 
use "$dir_eusilc_2020/MasterR", clear
keep if country == "$country" 
drop *_f
sort year uhid upid
count 
save "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta", replace


* Load and merge Personal Data (P-FILE), i.e. people aged 16 and above 
use "$dir_eusilc_2020/MasterP", clear
keep if country == "$country"
drop *_f *_i
duplicates report year upid
count

merge 1:1 year upid uhid using ///
	"$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta", force
fre _merge	// have more observations in R because R also contains children
drop if _merge == 1	 // drop observations only in the personal data (= 0)
drop _merge

sort year uhid upid
save "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta", replace


* Load and merge Household Register (D-FILE), i.e. all hhs selected for survey
use "$dir_eusilc_2020/MasterD", clear
keep if country == "$country"
drop *_f
sort year uhid
duplicates report year uhid
count 

merge 1:m year uhid using "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta"
fre _merge
keep if _merge == 3 // only keep households that responded to the survey 
drop _merge		

sort year uhid upid
save "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta", replace
	
	
* Load and merge Household Data (H-FILE), i.e. all hhs with responses 
use "$dir_eusilc_2020/MasterH", clear
keep if country == "$country"
drop *_f *_i
		
duplicates report year uhid
count 	

merge 1:m year uhid using "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta"
fre _merge
drop _merge

drop db050 //db050 -- Primary strata (Only CH)
sort year uhid upid
save "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta", replace
	
* Tidy up 	
lab var db010 "year"
lab var db020 "country"
lab var db040 "region"
lab var db090 "household cross-sectional weight"

display "Compiled EU-SILC 2005-2020 panel for ${country}!"


