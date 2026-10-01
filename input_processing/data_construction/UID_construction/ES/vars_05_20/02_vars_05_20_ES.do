/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         vars_05_20_ES.do
* DESCRIPTION:          Collects varaibles from 2005-2020 panel to merge in 
********************************************************************************
* COUNTRY:              ES 
* DATA:         	    EU-SILC panel based on the EU-SILC longitudinal datasets 
* 						created using GESIS Stata script: 
* 						https://www.gesis.org/gml/european-microdata/eu-silc.
******************************************************************************** 
* AUTHORS: 				Daria Popova, Ashley Burdett
* LAST UPDATE:          Feb 2025
* NOTE:					Collects variables from the 2005-2020 panel to merge in 
* 						into 2005-2023 panel. Relevant for variables that were
* 						replace sinces 2020, but the replacements have not 
* 						been backcoded resulting in missing data. 
* 						If input data run "01_prepare_pooled_data_2020_ES.do" 
* 						first. 
*******************************************************************************/


* Collect economic status information from previous panel 
use "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta", clear 

keep  uhid upid year pl030 pl031 rb210 

rename * *_orig
rename  upid_orig upid 
rename  year_orig year 
rename  uhid_orig  uhid

save "$dir_data/temp_orig_econ_status_${country}", replace 


* Collect education information from previous panel 
use "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta", clear 

keep  uhid upid year pe040

rename * *_orig
rename  upid_orig upid 
rename  year_orig year 
rename  uhid_orig  uhid

save "$dir_data/temp_orig_edu_${country}", replace 


* Collect occupation information from previous panel
use "$dir_data/${country}-SILC_pooled_all_obs_01_2020.dta", clear 

keep  uhid upid year pl051

rename * *_orig
rename  upid_orig upid 
rename  year_orig year 
rename  uhid_orig  uhid

save "$dir_data/temp_orig_occu_${country}", replace 




