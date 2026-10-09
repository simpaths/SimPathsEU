********************************************************************************
* PROJECT:              ESPON
* DO-FILE NAME:         vars_05_20.do
* DESCRIPTION:          Collects varaibles from 2005-2020 panel to merge in 
********************************************************************************
* COUNTRY:              PL 
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
* 						Temporary fix. 
* 						If input data run "prepare_pooled_data _05_20.do" first. 
********************************************************************************


* Collect economic status information from previous panel 
use "$dir_data_05_20/PL-SILC_pooled_all_obs_01.dta", clear 

keep  hid pid year pl030 pl031 rb210 

rename * *_orig
rename  pid_orig pid 
rename  year_orig year 
rename  hid_orig  hid

save "$dir_data/temp_orig_econ_status", replace 

* Collect education information from previous panel 
use "$dir_data_05_20/PL-SILC_pooled_all_obs_01.dta", clear 

keep  hid pid year pe040

rename * *_orig
rename  pid_orig pid 
rename  year_orig year 
rename  hid_orig  hid

save "$dir_data/temp_orig_edu", replace 

/*
use "$dir_data_05_20/PL-SILC_pooled_all_obs_02.dta", clear 

keep  hid pid year les_c3

rename * *_orig
rename  pid_orig pid 
rename  year_orig year 
rename  hid_orig  hid

save "$dir_data/temp_orig_econ_status2", replace 
*/

* Collect occupation information 

use "$dir_data_05_20/PL-SILC_pooled_all_obs_01.dta", clear 

keep  hid pid year pl051

rename * *_orig
rename  pid_orig pid 
rename  year_orig year 
rename  hid_orig  hid

save "$dir_data/temp_orig_occu", replace 




