/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         01_prepare_pooled_data.do
* DESCRIPTION:          Compiles the EU-SILC panel dataset.
* COUNTRY:              ES
* DATA:                 EU-SILC longitudinal datasets
* AUTHORS:              Daria Popova, Ashley Burdett
* LAST UPDATE:          1 October 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   This do-file combines the EU-SILC longitudinal datasets for 2005-2024
*   into a single panel dataset for subsequent initial population
*   construction.
*
*   The input files are created using the programs in:
*   "input_processing/data_construction/SILC_panel_construction".
*   These programs are based on the GESIS EU-SILC Stata routines.
*
*   -----------------------------------------------------------------------
*    File structure
*   -----------------------------------------------------------------------
*   Files are merged in the following order, with R as the base:
*
*   R (Personal Register)
*     Loaded first as the base dataset. Contains all sampled individuals,
*     including children under 16. Key identifiers are upid, uhid and year.
*
*   P (Personal Data)
*     Merged 1:1 on year + upid + uhid. Contains income and other personal
*     variables for individuals aged 16 and above. Following the merge:
*       - Individuals in both R and P retain variables from both files
*       - Children in R but not P are retained with R variables only
*       - Records in P but not R are dropped
*
*   D (Household Register)
*     Merged 1:m on year + uhid. As D is household-level, one D observation
*     maps to multiple individuals. Only individuals belonging to households
*     present in D are retained.
*
*     A small number of households may not merge. This is suspected to be
*     related to cross-release deduplication in 01_create_masterD.do but has
*     not yet been fully investigated.
*
*   H (Household Data)
*     Merged 1:m on year + uhid using the same household-level merge logic
*     as the D file.
*
*   -----------------------------------------------------------------------
*    Key identifiers
*   -----------------------------------------------------------------------
*   upid
*     Unique person identifier across releases, constructed from country,
*     rotation group, dropout year and pid. This differs from the raw pid
*     in the source data.
*
*   uhid
*     Unique household identifier across releases, constructed using the
*     corresponding cross-release identification procedure.
*
*   year
*     Income reference year.
*
*******************************************************************************/

* Set log 
cap log close 
log using "$dir_log/01_prepare_pooled_data.log", replace


/********************* LOAD PERSONAL REGISTER (R-FILE) ************************/
* i.e. all people incl children 
use "$dir_eusilc/20 L-2024/MasterR", clear
keep if country == "$country" 
drop *_f
sort year uhid upid
count 

save "$dir_data/${country}-SILC_pooled_all_obs_01.dta", replace


/****************** LOAD AND MERGE PERSONAL DATA (P-FILE) *********************/ 
* i.e. people aged 16 and above ****/
use "$dir_eusilc/20 L-2024/MasterP", clear
keep if country == "$country"
drop *_f *_i
duplicates report year upid
count 

merge 1:1 year upid uhid using ///
	"$dir_data/${country}-SILC_pooled_all_obs_01.dta", force
fre _merge	// have more observations in R because R also contains children
drop if _merge == 1	 // drop observations only in the personal data (= 0)
drop _merge

sort year uhid upid

save "$dir_data/${country}-SILC_pooled_all_obs_01.dta", replace


/**************** LOAD AND MERGE HOUSEHOLD REGISTER (D-FILE) ******************/
use "$dir_eusilc/20 L-2024/MasterD", clear
keep if country == "$country"
drop *_f
sort year uhid
duplicates report year uhid
count 

merge 1:m year uhid using "$dir_data/${country}-SILC_pooled_all_obs_01.dta"
fre _merge
keep if _merge == 3 // only keep households that responded to the survey 
drop _merge		

sort year uhid upid

save "$dir_data/${country}-SILC_pooled_all_obs_01.dta", replace
	
	
/***************** LOAD AND MERGE HOUSEHOLD DATA (H-FILE) *********************/
use "$dir_eusilc/20 L-2024/MasterH", clear
keep if country == "$country"
drop *_f *_i
		
duplicates report year uhid
count 

merge 1:m year uhid using "$dir_data/${country}-SILC_pooled_all_obs_01.dta"
fre _merge
drop _merge

drop db050 //db050 -- Primary strata (Only CH)
sort year uhid upid


/*********************************** SAVE *************************************/
save "$dir_data/${country}-SILC_pooled_all_obs_01.dta", replace

	
/***************************** CLEAN UP AND EXIT ******************************/
lab var db010 "year"
lab var db020 "country"
lab var db040 "region"
lab var db090 "household cross-sectional weight"

display "Compiled EU-SILC panel for ${country}!"

capture log close

