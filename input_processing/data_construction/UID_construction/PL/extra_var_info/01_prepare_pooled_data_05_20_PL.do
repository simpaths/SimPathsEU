/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         01_prepare_pooled_data_05_20.do
* DESCRIPTION:          Compiles the EU-SILC panel dataset
* COUNTRY:              PL
* DATA:                 EU-SILC longitudinal datasets
* AUTHORS:              Daria Popova, Ashley Burdett
* LAST UPDATE:          7 October 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   This processing file compiles the EU-SILC panel for PL for years 2005-2020
*	The files is consistent with 01_prepare_pooled_data_PL. See that file for 
* 	further information. 
*
*******************************************************************************/

cap log close 
//log using "$dir_log/01_prepare_pooled_data.log", replace

cd "$dir_data_05_20"

/********************* LOAD PERSONAL REGISTER (R-FILE) ************************/
* i.e. all people incl children 
use "$dir_long_eusilc_05_20/MasterR", clear
keep if country == "$country" 
drop *_f
sort year uhid upid
count 

save "$dir_data_05_20/${country}-SILC_pooled_all_obs_01.dta", replace


/****************** LOAD AND MERGE PERSONAL DATA (P-FILE) *********************/ 
* i.e. people aged 16 and above
use "$dir_long_eusilc_05_20/MasterP", clear
keep if country == "$country"
drop *_f *_i

duplicates drop year upid, force
count 

merge 1:1 year upid uhid using ///
	"$dir_data_05_20/${country}-SILC_pooled_all_obs_01.dta", force
fre _merge
		
drop if _merge == 1
drop _merge

sort year uhid upid

save "$dir_data_05_20/${country}-SILC_pooled_all_obs_01.dta", replace

	
/**************** LOAD AND MERGE HOUSEHOLD REGISTER (D-FILE) ******************/
use "$dir_long_eusilc_05_20/MasterD", clear
keep if country == "$country"
drop *_f
sort year uhid

duplicates drop year uhid, force
count 

merge 1:m year uhid using ///
	"$dir_data_05_20/${country}-SILC_pooled_all_obs_01.dta"
fre _merge
			
keep if _merge == 3 
drop _merge		

sort year uhid upid

save "$dir_data_05_20/${country}-SILC_pooled_all_obs_01.dta", replace
	
	
/***************** LOAD AND MERGE HOUSEHOLD DATA (H-FILE) *********************/
use "$dir_long_eusilc_05_20/MasterH", clear
keep if country == "$country"
drop *_f *_i
		
duplicates drop year uhid, force
count

merge 1:m year uhid using ///
	"$dir_data_05_20/${country}-SILC_pooled_all_obs_01.dta"
fre _merge
		
keep if _merge == 3
drop _merge
drop db050 //db050 -- Primary strata (Only CH)
sort year uhid upid

* Label vars	
label variable db010 "year"
label variable db020 "country"
label variable db040 "region"
label variable db090 "household cross-sectional weight"


/*********************************** SAVE *************************************/
save "$dir_data_05_20/${country}-SILC_pooled_all_obs_01.dta", replace


/***************************** CLEAN UP AND EXIT ******************************/	
display "Run finished on $S_DATE at $S_TIME"

cap log close

