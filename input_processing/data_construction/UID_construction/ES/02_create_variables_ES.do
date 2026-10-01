/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         02_create_variables.do
* DESCRIPTION:          Creates variables from SILC.  
* COUNTRY:              ES
* DATA:         	    EU-SILC panel dataset  
* AUTHORS: 				Claire Fenwick, Daria Popova, Ashley Burdett, 
* 						Aleksandra Kolndrekaj
* LAST UPDATE:          24 September 2026
********************************************************************************
* NOTES:				
* 
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
* 	This do-file creates the main variables used in SimPaths from the 
*	  variables in SILC. The file also imposes consistency with simulation 
* 	  assumptions as noted in the master file. 
*
*   -----------------------------------------------------------------------
*   Variables constructed 
*   -----------------------------------------------------------------------
*   Identifiers, panel setup & demographics
*     Data collection wave, interview date, household/person IDs, set
*     panel, deceased flag, gender, parent/partner IDs, age, region, country
*
*   Partnership & family relationships
*     Union status, partner's age, enter/exit partnership, partner age
*     difference, partnership duration
*
*   Health
*     Own and partner's health status (imputed - see dhe above)
*
*   Economic activity, work & disability
*     Activity status, long-term sick/disabled, unemployment, hours of
*     work, employment experience, disability benefit
*
*   Education
*     Initial education spell, educational attainment (deh_c3/deh_c4),
*     parent's education, return to/leave education
*
*   Retirement & pensions
*     Retired flag, enter retirement, pension age (own and spouse)
*
*   Children & household composition
*     Fertility, number/timing of children, adult child flag, exit
*     parental home, household composition, OECD equivalence scale
*
*   Income, wages & weights
*     CPI, real hourly wages, personal/household income variables,
*     home ownership, survey weights (line 4216)
*
*   Final checks & save
*     Consistency checks, keep relevant waves/variables, recode missing
*     values, save ${country}-SILC_pooled_all_obs_02.dta
*
*   -----------------------------------------------------------------------
*    Variable imputation
*   -----------------------------------------------------------------------
*   To preserve our sample size, the following are imputed:
*
*   - Health (dhe) and partner's health - generalized ordered logit
*   - Educational attainment (deh_c3, deh_c4) - generalized ordered logit,
*     with deductive logic used first where monotonicity of education
*     allows it
*   - Partner's educational attainment - ordered probit
*   - Age of individuals top-coded in SILC (78+) - deductive logic where
*     possible, otherwise a regression model informed by the SHARE dataset.
*     Now age top-coded at 100 to align with population projections
*   - Hours of work (lhw) when missing - hot-deck imputation by donor
*     strata
*   - Wages (obs_earnings_hourly) when missing - carried forward from an
*     adjacent panel cell where available, otherwise hot-deck imputation
* 	- Years of experience in paid work 
*
*   Each imputed variable has a corresponding flag (e.g. flag_dhe_imp,
*   flag_wage_hotdeck) - see the "CREATE ASSUMPTION DESCRIPTIVES" section
*   for the full summary of imputation rates.
*
*   -----------------------------------------------------------------------
*    Changes that need to be made for a new country
*   -----------------------------------------------------------------------
*   - CPI
*   - Fertility rate // UPDATE
*   - Check if any bugs in the rotation groups when constructing the weights
*   - NUTS1 regions (check if they have remained constant throughout the
*     observation window)
*   - Country code
*   - Pension age
*   - Max age a female can have a child
*
* TO DO:
*******************************************************************************/

* Set off log 
cap log close 
log using "${dir_log}/02_create_variables.log", replace

* Set seed
set seed 98765


* Obtain values of variables that change between 2020 and 2024 from the earlier 
* panel 
do "$dir_do/vars_05_20/01_prepare_pooled_data_2020_${country}.do"

do "$dir_do/vars_05_20/02_vars_05_20_${country}.do"


* Load data main panel
use "$dir_data/${country}-SILC_pooled_all_obs_01.dta", clear

lab def dummy 1 "yes" 0 "no"


/**************************** DATA COLLECTION WAVE ****************************/
/* 
swv >> used to set the panel. The variable 'year' is unique to this 
cumulative dataset made by GESIS, not the EU-SILC panel. pb010/hb010/db010/rb010 
is the original 'year of the survey' variable. 
*/
gen swv = year

lab var swv "Data collection wave"

fre swv


/*********************** YEAR OF THE PERSONAL INTERVIEW ***********************/
/* 
stm: year of the personal interview (pb110) or year of the household 
interview could be used (hb060) 
*/
gen stm = pb110

lab var stm "Interview year"

sort upid uhid year 

* Assign missings year of the personal interview
sort uhid upid year

bysort uhid year: egen pb110_max = max(pb110)
replace stm = pb110_max if missing(stm)

drop pb110_max

* Any futher missing values are filled in using the household interview variable
replace stm = hb060 if missing(stm)

fre stm

tab stm swv 

* To avoid duplicates force common years to be survey year (2019, 2020)
replace stm = year if stm != swv 

assert swv == stm 


/******************************** INTERVIEW DATE ******************************/
/* 
The exact date of interview is not available in EU-SILC (no day recorded, only 
the quarter and the year of the personal interview). Therefore date is made so 
that all interviews happened on the 1st of the last month in the quarter. e.g. 
an interview recorded as taking place in January, February, March, 2015 is 
recorded in Int_Date as 1st March 2005. Any missing variables in the quarter 
have been reported as 06 (June) as it is in the middle of the year, and any 
missing variables in the year have been recorded as the year the survey 
took place. 
*/
gen intdatd_dv = 01 

gen intdatm_dv = 00
replace intdatm_dv = 03 if pb100 == 1
replace intdatm_dv = 06 if pb100 == 2
replace intdatm_dv = 06 if pb100 == .
replace intdatm_dv = 09 if pb100 == 3
replace intdatm_dv = 12 if pb100 == 4

gen intdaty_dv = 0000
replace intdaty_dv = pb110
replace intdaty_dv = year if intdaty_dv == .
gen Int_Date = mdy(intdatm_dv, intdatd_dv, intdaty_dv) 
format Int_Date %d

lab var Int_Date "Interview Date"

fre Int_Date
// Mar 2004 - June 2024


/**************************** HOUSEHOLD IDENTIFIER ****************************/
/* 
In the original EU-SILC longitudinal wave files, a household is identified 
with the Household ID variable px030/db030/hb030/rb040, in this dataset - 
created from the cumulative longitidutional dataset by GESIS - the variable 
uhid uniquely identifies households.

uhid = country + rotation_group + {enter_year+3} + hid

*/
clonevar idhh = uhid 

lab var idhh "Household identifier"

destring idhh, replace ignore($country)
format idhh %-18.0g

bysort year: sum idhh 


/********************************* INDIVIDUALS ID *****************************/ 
/* 
In the original EU-SILC longitudinal wave files, a person is identified with 
the variable rb030/pb030 (their personal ID) in this dataset - the cumulative 
longitidutional dataset - the created variable upid uniquely identifies 
observations. 

upid = country + rotation_group + {enter_year+3} + pid

Can have multiple observations in a given year if changed living circumstances.
*/
clonevar idperson = upid
 
lab var idperson "Unique cross wave identifier"

destring idperson, replace ignore($country)
format idperson %-20.0g

bysort year: sum idperson


/******************************** SET PANEL ***********************************/
duplicates report year idperson 

/* 
Duplicates in terms of year idperson

--------------------------------------
   Copies | Observations       Surplus
----------+---------------------------
        1 |       816409             0
        2 |         5504          2752
--------------------------------------

The unique identifier of observations is idperson idhh and year not just 
idperson year. This is because different dimensions of the survey may be 
conducted at different times in the year and the individual may have changed 
household. Therefore need a standard rule to rule out people residing in two 
household in a single year, generating two observations for the individual for 
that year. 		
The duplicates command in Stata preserves the first occurence of each duplicate, 
so sorting uniquely before runing the duplicates command should ensure the same 
dataset is generated everytime the do file is run. 
*/	

sort idperson year uhid 

duplicates drop swv idperson, force // (2,752 observations deleted)

isid idperson swv

xtset idperson swv 

sort idperson year 


/***************************** DECEASED FLAG **********************************/

gen flag_deceased = 0 
replace flag_deceased = 1 if rb110 == 6 

lab var flag_deceased "FLAG: Individual died in the previous year"

tab flag_deceased	// 2,995


/********************************* GENDER *************************************/
gen dgn = rb090
recode dgn 2 = 0 	//dgn = 0 is female, 1 is male

lab var dgn "Gender" 
lab define dgn 1 "male" 0 "female"
lab val dgn dgn

sort idperson swv

* Impute as time invariant characteristic 
* Individual panel max length 5 years
forvalues i = 1/6 {
	
	replace dgn = l`i'.dgn if missing(dgn) & ///
		!missing(l`i'.dgn) & idperson == l`i'.idperson 
		
}

fre year dgn
bysort year: sum dgn  


/********************************* ID PARTNER *********************************/ 
/* 
Dataset quirks: the original variable that identifies an individual's
partner in the EU-SILC is rb240/pb180. However, GESIS made a new unique personal 
identifier (upid) for all individuals in this cumulative longitudional dataset, 
and as a result rb240 may no longer be unique and does not match-up with upid 
(required for future merging). As upid is simply a combination of urtgrp 
(a variable made by GESIS that identifies the country, rotational group and 
dropout year an individual belongs to) and the original unique personal 
identifier (rb030) it is possible to update rb240 to be consistent with GESIS's
new unique personal identifier. Thus, I combine urtgrp and rb240 to ensure 
idpartner aligns with upid and do the same for idfather and idmother. 

Note on the variable: rb240 includes married people and partners in a 
consensual union (with or without a legal basis).
*/
tostring rb240, replace format(%18.0g) 
gen idpartner = (urtgrp + rb240)
destring rb240, replace
destring idpartner, replace ignore($country)
replace idpartner = . if rb240 == .

lab var idpartner "Unique cross wave identifier of partner"
recode idpartner . = -9
format idpartner %18.0g


/**************** ID FATHER (includes natural/step/adoptive) ******************/
/*
Same logic applies to father id and partner id; will align with idperson if 
combine urtgrp with the relevant id variable. 

Only captures the id of parents that live in the same household. 
*/

tostring rb220, replace format(%18.0g)   
gen idfather = (urtgrp + rb220)
destring rb220, replace
destring idfather, replace ignore($country)
replace idfather = . if rb220 == .

lab var idfather "Father unique identifier"
format idfather %18.0g
recode idfather . = -9


/******************* ID MOTHER (includes natural/step/adoptive) ***************/
/*
Same logic applies to mother id and partner id; will align with idperson if 
combine urtgrp with the relevant id variable. 

Only captures the id of parents that live in the same household. 
*/
tostring rb230, replace format(%18.0f)  
gen str30 idmother = (urtgrp + rb230)
destring rb230, replace
destring idmother, replace ignore($country)
replace idmother = . if rb230 == .

lab var idmother "Mother unique identifier"
recode idmother . = -9
format idmother %18.0g

sort idperson year 


/******************************* AGE ******************************************/ 
/* 
EU-SILC has a number of possible variables that could be used to create age. 
Age at end of inc ref period (px020), age at the time of the interview (rx010), 
as well as year of birth (rb080). 

The choice implies depends on the number of missing values and when you want to 
measure age. 
- px020 Age at the beginning of the calender year of the interview 
- rb080 Age at the end of the calender year of the interview 
- rx010 Age at the interview

Choice will impact the age at which we have information about personal data 
variables and how we deal with new borns. 

If born in the current year and use age at the beginning of the year will get 
individuals with age = -1.
If use age at the end of the calender year, don't get any information for 
individuals with stated age of 16. 

Note that most personal interviews occur in the second quarter of the calender 
year for ES. 

Note that looks like to have a personal interview have to be 16 at the end of 
the previous calender as when rx010 == 16 & px020 is missig so are all fo the 
activity variable. Min(px020) = 16. 

This suggests it is prefereable to use variable rx010 where possible and then 
allow for an upward bias by using the age at the end of the calender year as the 
back up when rx010 is not available. 

Also note that age is top coded at 78.We address this by imposing longitudinal 
consistency for those observed turning 78 within their individual panel. For 
those who are at least 78 across in all of thier observations, we impute age 
randomly drawing from a gender-specific log-normal distribution, with parameters 
informed by SHARE data. Longitudinal consistency is also imposed in these 
cases.  
*/

gen dag = stm - rb080
replace dag = rx010 if rx010 != . 
	
lab var dag "Age"

fre dag
tab dag year 

* Enforce 78 top coding 
sort idperson swv

gen flag_age_topcoded = (dag == 78 & dag[_n-1] != 77 & ///
	idperson == idperson[_n-1])

lab var flag_age_topcoded "FLAG: Age top-coded." 

replace dag = 78 if dag > 78 & dag != . 

* Check age
sort idperson swv 
gen age_dif = dag - dag[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1
	
tab age_dif	
tab rb080 if age_dif > 2 & age_dif != . 
/*
Almost all big jumps are due to a sudden change in birth year to be <= 1942
*/

drop age_dif 

* Impose panel consistency to help overcome possible repeat ages due to 
* interview timing
gen dag_new = dag 
replace dag_new = dag_new[_n-1] + 1 if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1

* Enforce top coding	
replace dag_new = 78 if dag_new > 78 

gen age_dif = dag_new - dag_new[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1
	
tab age_dif	

twoway ///
    (hist dag, color(blue%40) lcolor(blue%80)) ///
    (hist dag_new, color(red%40) lcolor(red%80)), ///
    legend(order(1 "dagm" 2 "dag_new" )) ///
    title("Comparison of Age Variables") ///
    xtitle("Age") ///
    ytitle("Density") ///
    graphregion(color(white))

graph drop _all	

/*
The comparison of the distributions shows they are very close - the main 
disparity is a slightly lower mass at the max age which is consistent with 
the error being driven by potential mislabeling of year of birth to year <= 1942
*/

replace dag = dag_new 

drop dag_new age_dif 
	
tab dag 
fre dag 
bys swv: sum dag 
	

* Impute age of those whose age is top-coded at 78
	
* For those that turn 78 in the panel let their age naturally evolve
sort idperson swv 
gen turn_78 = (idperson == idperson[_n-1] & dag[_n-1] == 77 & dag == 78)	
	
* Populate all subsequent observations	
replace turn_78 = 1 if idperson == idperson[_n-1] & turn_78[_n-1] == 1

replace dag = dag[_n-1] + 1 if turn_78 == 1 
	
* For the remaining top-coded cases
/*
We will impute the ages by randomly drawing from a log normal charactersized by 
parameters obtained from SHARE data. 

Mean and standard deviation of log age of males and females aged 78+ ES
			0. male		1. female		
    Mean	4.414		4.405
    SD		0.046		0.040
	 
*/	
	
* Flag remaining top-coded observations 
gen topcoded78 = 1 if dag == 78 & turn_78 == 0 

* Define gender specific log-normal distribution parameters
gen meanlog = .
gen sdlog   = .

replace meanlog = 4.414 if dgn == 1 & topcoded78 == 1
replace sdlog   = 0.046 if dgn == 1 & topcoded78 == 1

replace meanlog = 4.405 if dgn == 0 & topcoded78 == 1
replace sdlog   = 0.040 if dgn == 0 & topcoded78 == 1

* Simulate skewed ages imposing truncation

* Calculate the lower bound probability to ensure impute at least age 78
gen lower_prob = normal((ln(78) - meanlog) / sdlog) if topcoded78 == 1

* Draw a uniform random number between lower_prob and 1
sort idperson swv 
gen u_truncated = lower_prob + (1 - lower_prob) * runiform() if topcoded78 == 1

* Generate imputed age
gen dag_sim = floor(exp(meanlog + sdlog * invnormal(u_truncated))) if ///
	topcoded78 == 1
	
* Impose panel consistency 
replace dag_sim = dag_sim[_n-1] + 1 if idperson == idperson[_n-1] & ///
	dag_sim[_n-1] != . 
	// could add swv == swv[_n-1] + 1 to ensure observed in every way 
	
* Populate main age var
replace dag = dag_sim if topcoded78 == 1 & dag_sim >= 78	

* Enforce top-coding at 100 in line with population projections
replace dag = 100 if dag > 100 & dag != . 
	
drop  meanlog sdlog lower_prob u_truncated 	

count if dag == . 
tab dag 
hist dag, discrete

graph drop _all 


/************************* REGION (NUTS 1) ************************************/ 
/*
NUTS 1 regions are constant in Spain over this period
*/

clonevar drgn1 = db040 
destring drgn1, replace ignore($country)

replace drgn1 = 1 if inrange(drgn1,10,19)
replace drgn1 = 2 if inrange(drgn1,20,29)
replace drgn1 = 3 if inrange(drgn1,30,39)
replace drgn1 = 4 if inrange(drgn1,40,49)
replace drgn1 = 5 if inrange(drgn1,50,59)
replace drgn1 = 6 if inrange(drgn1,60,69)
replace drgn1 = 7 if inrange(drgn1,70,79)

lab var drgn1 "Region"
lab define drgn1 ///
	1 "Noroeste" ///
	2 "Noreste" ///
	3 "Madrid" ///
	4 "Centro" ///
	5 "Este" ///
	6 "Sur" ///
	7 "Canarias" 
	
lab values drgn1 drgn1

recode drgn1 (. = -9)

fre drgn1
tab drgn1 year, col
bys swv: sum drgn1 if drgn1 > 0 


/******************************** COUNTRY *************************************/
gen dct = .
lab var dct "Country code: ${country}"


/******************************** UNION ***************************************/
/* 
Generate union variable to indicate if there is a partner in the hh; dun should 
not distinguish between partners with and without legal recognition and thus 
include both cohabiting couples and married couples. 

PB200 - Consensual union 
	1	Yes, on a legal basis	
	2	Yes, without a legal basis	
	3	No

In EU-SILC: a family `nuclei' is constituted when two persons (of either sex) 
choose to live together as a married couple, in a registered partnership, or in 
a consensual union, whether or not they have children; single parents with 
children also constitute a family unit, while people living alone do not, nor do 
groups of unrelated people who choose to share a house together (for example, 
students).
  
Consensual union with a legal basis includes both married couples and registered
partners and without refers to a "de facto" partner. 
Both modalities have to live in the same household in both instances.  
From my understanding, this includes same sex couples. 

In variable construction assume that not married if missing information unless
partner information is missing. 
*/

gen dun = (idpartner > 0)

lab var dun "Has a partner"

* Check if consistent with simulation assumption form relationship is 16+
tab dag if dun == 1 

gen flag_young_partnership = (dag < ${age_form_partnership} & dun == 1)

replace dun = 0 if dag < ${age_form_partnership}  

fre dun 
tab dun year, col 
bys dun: sum idpartner if idpartner == -9 
bys dun: sum idpartner if idpartner > 0 


/**************************** PARTNER'S AGE ***********************************/ 
/*
To preserve the the empirical relationship between partners ages, we adjust the 
individual age imputations using the distribution of the age gap take from SHARE 
data. Logic of code:  
- Merge in individual age relabelled as partner's age 
- Adjust individual age if in a parnership and for one or both partners all 
observations are top-coded. Three cases: 
	Case A: Female partner top-coded, male partner not/observed turning 78 
				-> Resimulate female age
	Case B: Male partner top-coded, female partner not/observed turning 78 
				-> Resimulate male partner gap 
	Case C: Both partner's top-coded
				-> Resimulate female partner age using simulatd male age as 
				anchor
Impose longitudinal consistency. 
- Merge in new individual ages to update partner age variable. 	

Note, in the future may want to adjust the distributions used to draw from. 
*/

* Merge in individual age relabelled as partner age
preserve

	keep swv idperson dag turn_78 topcoded78
	rename idperson idpartner
	rename dag dagsp 
	rename turn_78 turn_78sp 
	rename topcoded78 topcoded78sp
	save "$dir_data/temp_age", replace

restore

merge m:1 swv idpartner using "$dir_data/temp_age"

lab var dagsp "Partner's age"

keep if _merge == 1 | _merge == 3
drop _merge

sort idperson swv 
fre dagsp if idpartner > 0  
bys swv: sum dagsp 

hist dag, discrete 
hist dagsp, discrete

hist dag if dgn == 0, discrete 
hist dagsp if dgn == 1, discrete 

sort idperson swv 


* Tidy up partner and parent ids

* Problematic case flag 
gen byte same_mother = (idpartner == idmother ///
    & idpartner != -9 & idmother != -9)

gen byte same_father = (idpartner == idfather ///
    & idpartner != -9 & idfather != -9)

gen same = same_mother 
replace same = 1 if same_father == 1 
	
tab same 	
tab same_mother 
tab same_father 

* Use age and persistence of response to dertmine which is correct
sort idperson swv

gen age_diff = dag - dagsp if same == 1 

tab age_diff


* Flag partner persistent (backward looking)
gen part_pers = (same == 1 & same[_n-1] != 1 & ///
    idpartner == idpartner[_n-1] & idperson == idperson[_n-1] & ///
    idpartner != -9)	
	
* Flag mother persistent 
gen mother_pers = (same_mother == 1 & same[_n-1] != 1 & ///
	idmother == idmother[_n-1] & idperson == idperson[_n-1] & idmother != -9)

* Flag father persistent 
gen father_pers = (same_father == 1 & same[_n-1] != 1 & ///
	idfather == idfather[_n-1] & idperson == idperson[_n-1] & idfather != -9) 

tab part_pers
tab mother_pers
tab father_pers

tab part_pers mother_pers
tab part_pers father_pers

/*
If a parent id is more persistent and the age diff is reasonable assume 
parent not partner
*/
* Mother
tab age_diff if mother_pers == 1 & part_pers == 0 

replace idpartner = -9 if mother_pers == 1 

* Update partnership variable
replace dun = 0 if mother_pers == 1  


* Father
tab age_diff if father_pers == 1 & part_pers == 0 

replace idpartner = -9 if father_pers == 1 

* Update partnership variable
replace dun = 0 if father_pers == 1  


/*
If a partner id is more persistent and the age diff is reasonable assume 
partner not parent
*/
tab age_diff if part_pers == 1 & mother_pers == 0 & father_pers == 0 

replace idmother = -9 if part_pers == 1 & same_mother == 1 
replace idfather = -9 if part_pers == 1 & same_father == 1 


* Remaining cases 
tab age_diff if part_pers == 0 & mother_pers == 0 & father_pers == 0 

replace idmother = -9 if part_pers == 0 & mother_pers == 0 & ///
	father_pers == 0 & same_mother == 1 
replace idfather = -9 if part_pers == 0 & mother_pers == 0 & ///
	father_pers == 0 & same_father == 1 

drop same 

* Check 
gen same = 0 
replace same = 1 if idpartner == idmother | idpartner == idfather 
replace same = 0 if idpartner == -9 

tab same 

drop same same_mother same_father age_diff part_pers mother_pers father_pers

* Update top-coded ages to account for empirical joint age distribution 
/*
Statistics related to partnership age difference for couples 
age 78+ in the SHARE data. 

(Gap = own age - partner's age)
			
			Mean							Standard	deviation     
			dif_age_female   dif_age_male	dif_age_female	dif_age_male
			
29. ES  	-4.496     	 	4.496			4.639			4.639

NOTE: Could adjust parameters to be the age gap for those 70 to empirically 
account for Cases A and B below. 

*/


* Define spouse gap parameters as variables (gap = husband age - wife age)
gen mean_gap = 4.496
gen sd_gap   = 4.639

* Adjust imputed own age accounting for empirical distribution of age gap 

gen dag_sim2 = . 

bysort idperson (turn_78sp): gen turn_78sp_panel = (turn_78sp[_N] == 1)

sort idperson swv 

* Case A: Female top-coded (all obs), Male is NOT 
* 	Update: female age = male age - gap
/*
Note, doesn't impose a lower bound of 78 to imputation update. Could create
a loop to keep drawing until obtain 78+ or could alter the distribution drawn 
from. 
*/

* Male partner always < 78
replace dag_sim2 = round(dagsp + rnormal(mean_gap, sd_gap)) if ///
    topcoded78 == 1 & dgn == 0 & dun == 1 & dagsp < 78 
	
* Male partner turns 78	
replace dag_sim2 = round(dagsp + rnormal(mean_gap, sd_gap)) if ///
    topcoded78 == 1 & dgn == 0 &  dun == 1 & dagsp == 78 & turn_78sp == 1	

* Impose lower bound, brute force
replace dag_sim2 = 78 if topcoded78 == 1 & dgn == 0 & dun == 1 & ///
	dagsp < 78 & dagsp != . & dag_sim2 < 78 
	
replace dag_sim2 = 78 if topcoded78 == 1 & dgn == 0 & dun == 1 & ///
	dagsp == 78 & turn_78sp == 1 & dagsp != . & dag_sim2 < 78 	
			
* Case B: Male top-coded, Female is NOT 
* 	Update: male age = female age + gap

* Female partner always < 78
replace dag_sim2 = round(dagsp + rnormal(mean_gap, sd_gap)) if ///
    topcoded78 == 1 & dgn == 1 &  dun == 1 & dagsp < 78 
	
* Female partner turns 78	
replace dag_sim2 = round(dagsp + rnormal(mean_gap, sd_gap)) if ///
    topcoded78 == 1 & dgn == 1 &  dun == 1 & dagsp == 78 & turn_78sp == 1
	
* Impose lower bound 	
replace dag_sim2 = 78 if topcoded78 == 1 & dgn == 1 & dun == 1 & ///
	dagsp < 78 & dagsp != . & dag_sim2 < 78 
	
replace dag_sim2 = 78 if topcoded78 == 1 & dgn == 1 & dun == 1 & ///
	dagsp == 78 & turn_78sp == 1 & dagsp != . & dag_sim2 < 78 
	
sort idperson swv 

	
* Impose longitudinal consistency 
replace dag_sim2 = dag_sim2[_n-1] + 1 if idperson == idperson[_n-1] & ///
	idpartner == idpartner[_n-1] & dag_sim2[_n-1] != . & topcoded78 == 1 & ///
	turn_78sp_panel == 0 

replace dag_sim2 = dag_sim2[_n-1] + 1 if idperson == idperson[_n-1] & ///
	idpartner == idpartner[_n-1] & dag_sim2[_n-1] != . & topcoded78 == 1 & ///
	turn_78sp == 1 & dagsp > 78
	
* Impose longitudinal consistency for own age for those whose partner turns 78 
* Lagged observations 
replace dag_sim2 = dag_sim2[_n+1] - 1 if idperson == idperson[_n+1] & ///
	idpartner == idpartner[_n+1] & dag_sim2[_n+1] != . & turn_78sp[_n+1] == 1
	
replace dag_sim2 = dag_sim2[_n+2] - 2 if idperson == idperson[_n+2] & ///
	idpartner == idpartner[_n+2] & dag_sim2[_n+2] != . & ///
	turn_78sp[_n+2] == 1 & turn_78sp[_n+1] == 0
	
replace dag_sim2 = dag_sim2[_n+3] - 3 if idperson == idperson[_n+3] & ///
	idpartner == idpartner[_n+3] & dag_sim2[_n+3] != . & ///
	turn_78sp[_n+3] == 1 & turn_78sp[_n+2] == 0
	
replace dag_sim2 = dag_sim2[_n+4] - 4 if idperson == idperson[_n+4] & ///
	idpartner == idpartner[_n+4] & dag_sim2[_n+4] != . & ///
	turn_78sp[_n+4] == 1 & turn_78sp[_n+3] == 0		
	
	
* Case C: Both all obs top-coded 78+
* 	Take male partner's imputed age as given and update female partner's age
replace dag_sim2 = round(dagsp - rnormal(mean_gap, sd_gap)) if ///
    topcoded78 == 1 & topcoded78sp == 1 &  dgn == 0 &  dun == 1 & dagsp != .	

* Impose ower bound 
replace dag_sim2 = 78 if topcoded78 == 1 & topcoded78sp == 1 & dgn == 0 & ///
	dun == 1 & dagsp != . & dag_sim2 < 78 	

* Impose longitudinal consistency 	
replace dag_sim2 = dag_sim2[_n-1] + 1 if idperson == idperson[_n-1] & ///
	idpartner == idpartner[_n-1] & dag_sim2[_n-1] != . & /// 
	topcoded78 == 1 & topcoded78sp == 1 & dgn == 0 &  dun == 1 

* Impose longitudinal consistency if partnership breaks up 
gen x = 1 if idperson == idperson[_n-1] & ///
	idpartner != idpartner[_n-1] & dag_sim2[_n-1] != . & /// 
	topcoded78[_n-1] == 1 & topcoded78sp[_n-1] == 1 & dgn == 0 & ///
	dun[_n-1] == 1 & dun == 0 
	
replace x = 1 if x[_n-1] == 1 & idperson == idperson[_n-1]

replace dag_sim2 = dag_sim2[_n-1] + 1 if idperson == idperson[_n-1] & ///
	x == 1
	
* Update spouse age information so that it is consistent with these updates
* Repeat the above merging process using updated age variable 

replace dag = dag_sim2 if dag_sim2 != . 

preserve

	keep swv idperson dag turn_78 topcoded78
	rename idperson idpartner
	rename dag dagsp2 
	rename turn_78 turn_78sp 
	rename topcoded78 topcoded78sp
	save "$dir_data/temp_age", replace

restore

merge m:1 swv idpartner using "$dir_data/temp_age"

lab var dagsp "Partner's age"

keep if _merge == 1 | _merge == 3
drop _merge

sort idperson swv 

replace dagsp = dagsp2 if dagsp2 != . 


* Impose top-code at 100 
replace dag = 100 if dag > 100 & dag != . 
replace dagsp = 100 if dagsp > 100 & dagsp != . 

* Consistency check
tab dag 
tab dagsp 

hist dag, discrete 
hist dagsp, discrete

hist dag if dgn == 0, discrete 
hist dagsp if dgn == 1, discrete 


count if dag == . 

graph drop _all 

* Age squared 
gen dagsq = dag^2

lab var dagsq "Age squared"
				
drop dag_sim dag_sim2 dagsp2 mean_gap sd_gap x			

sum dagsq
count if dun == 1 & dagsp == .


/************************** PARTNERSHIP STATUS ********************************/
/* 
Construct a variable that only indicates whether the individual is single or 
partnered, we don't differenciate between those that have previosuly been in a 
partnership and those that have never. 

For consistency utilize idpartner variable. 
*/
gen dcpst = -9 
replace dcpst = 1 if idpartner > 0 // partnered 
replace dcpst = 2 if idpartner < 0 // single
	
lab var dcpst "Partnership status"
lab def dcpst 1 "partnered" 2 "single" 
lab val dcpst dcpst 

fre dcpst // no missing values 
tab dcpst year, col
bys swv: sum dcpst if dcpst > 0 

* Impose min partnership formation age (own and partner)
replace flag_young_partnership = 1 if dcpst == 1 & dag < ${age_form_partnership}
replace flag_young_partnership = 1 if dcpst == 1 & ///
	dagsp < ${age_form_partnership}

lab var flag_young_partnership ///
	"FLAG: Made single because stated in a partnership below the age permitted to form in simulation"
		
replace dcpst = 2 if dag < ${age_form_partnership}
//replace idpartner = -9 if dag < ${age_form_partnership}

count if dcpst == . 
tab dcpst 

tab dcpst stm, col

* Check consistency 
tab dun dcpst


/****************************** WIDOW STATUS **********************************/

gen widow = 1 if pb190 == 4 
replace widow = 0 if pb190 != . & pb190 != 4
replace widow = -9 if pb190 == .

lab var widow "Widow flag" 

* Check consistency 
tab dcpst widow

replace widow = 0 if dcpst == 1		// let idpartner over rule widow status 

tab widow stm, col


/***************************** PARTNER'S GENDER *******************************/

duplicates report idpartner swv if idpartner > 0 

preserve

	keep swv idperson dgn
	rename idperson idpartner
	rename dgn dgnsp
	save "$dir_data/temp_dgn", replace 

restore

merge m:1 idpartner swv using "$dir_data/temp_dgn" 
	//m:1 because some people have idpartner = -9
	
lab var dgnsp "Partner's gender"
keep if _merge == 1 | _merge == 3
drop _merge

* Impose partnership age restriction 
replace dgnsp = . if dag < ${age_form_partnership}

lab values dgnsp dgn
recode dgnsp (. = -9)

fre dgnsp if idpartner > 0 
tab dgnsp year, col 


/******************************* HEALTH STATUS ********************************/
fre ph010
/* 
ph010 -- General health
-----------------------------------------------------------------
                    |      Freq.    Percent      Valid       Cum.
--------------------+--------------------------------------------
Valid   1 Very good |     109573      13.38      16.57      16.57
        2 Good      |     352154      42.99      53.26      69.84
        3 Fair      |     140731      17.18      21.29      91.12
        4 Bad       |      45688       5.58       6.91      98.03
        5 Very bad  |      13000       1.59       1.97     100.00
        Total       |     661146      80.71     100.00           
Missing .           |     158015      19.29                      
Total               |     819161     100.00                      
-----------------------------------------------------------------

Reverse code so 5 = excellent and higher number means better health

Have many missing values so (stochastically) impute using an generalised 
ordered logit model.
*/

* Reverse code
recode ph010 (5 = 1 "Poor") ///
	(4 = 2 "Fair") ///
	(3 = 3 "Good") ///
	(2 = 4 "Very good") ///
	(1 = 5 "Excellent") ///
	, into(dhe)
	
lab var dhe "Health status"
fre dhe 
tab dhe year, col 

* Investigate missing values
fre dag if missing(dhe) 

tab dhe year 
gen dhe_2 = dhe
replace dhe_2 = -9 if dhe_2 == . 
tab dhe_2 year if dag > 16 , col

// only about 3 % missing each year of those age 16 + 

* Impute 
* Generalized ordered logit model
recode dgn dag dagsq drgn1 (-9 = .), gen (dgn2 dag2 dagsq2 drgn12)
fre dgn2 dag2 dagsq2 drgn12
xi: gologit2 dhe i.dgn2 dag2 dagsq ib3.drgn12 i.swv if dhe < .

predict p1 p2 p3 p4 p5

* Create CDF
gen p1p2 = p1 + p2 
gen p1p2p3 = p1p2 + p3
gen p1p2p3p4 = p1p2p3 + p4 

sort idperson swv 

* Add heterogenity
gen rnd = runiform()

* Create imputation
gen imp_dhe = cond((rnd < p1), 1, cond(rnd < p1p2, 2, ///
	cond(rnd < p1p2p3, 3, cond(rnd < p1p2p3p4, 4, 5))))

sum imp_dhe if missing(dhe) & dag > 0 & dag < 16 // all children missing data
sum imp_dhe if !missing(dhe) & dag > 0 & dag < 16
sum imp_dhe if missing(dhe) & dag >= 16
sum imp_dhe if !missing(dhe) & dag >= 16

* Comparison plot
	
* Observed vs predicted all adults	
twoway ///
    (hist dhe if dag >= 16, color(blue%40) lcolor(blue%80)) ///
    (hist imp_dhe if dag >= 16, color(red%40) lcolor(red%80)), ///
    legend(order(1 "dhe" 2 "imputed dhe" )) ///
    title("Comparison of Health Variables") ///
    xtitle("Age") ///
    ytitle("Density") ///
    graphregion(color(white))	

graph drop _all

* Add imputation flag 
gen flag_dhe_imp = missing(dhe)
lab var flag_dhe_imp "FLAG: =1 if dhe is imputed"
replace dhe = round(imp_dhe) if missing(dhe) & dag >= 16
replace dhe = -9 if dag < 16

bys flag_dhe_imp: fre dhe if dag <= 16
bys flag_dhe_imp: fre dhe if dag > 16 

drop dgn2 dag2 dagsq2 drgn12 _Idgn2_1 _Iswv_* p1* p2 p3 p4 p5 rnd imp_dhe

fre dhe 
tab dhe year if dag >= 16, col 
bys swv: sum dhe 


/************************** PARTNER'S HEALTH STATUS ***************************/
preserve

	keep swv idperson dhe flag_dhe_imp

	rename idperson idpartner
	rename dhe dhesp
	rename flag_dhe_imp flag_dhesp_imp

	save "$dir_data/temp_dhe", replace

restore

merge m:1 swv idpartner using "$dir_data/temp_dhe"

lab var dhesp "Partner's health status"
keep if _merge == 1 | _merge == 3
drop _merge

cap lab define dhe 1 "Poor" 2 "Fair" 3 "Good" 4 "Very good" 5 "Excellent"
lab values dhesp dhe 

* Impose partnership age restriction 
replace dhesp = . if dag < ${age_form_partnership}

replace dhesp = -9 if missing(dhesp) & idpartner > 0

fre dhesp if idpartner > 0 
tab dhesp year, col 
bys swv: sum dhesp 


/**************************** ENTER PARTNERSHIP *******************************/
/*
Only populated if able to transition into a relationship
*/
sort idperson swv 
xtset idperson swv 

gen dcpen = -9
replace dcpen = 0 if (l.dcpst == 2)
replace dcpen = 1 if (dcpst == 1 & l.dcpst == 2)
replace dcpen = 1 if dcpst == 1 & dag == ${age_form_partnership}

lab val dcpen dummy
lab var dcpen "Enter partnership, only populated if eligable"

* Impose partnership age restriction 
replace dcpen = -9 if dag < ${age_form_partnership}

fre dcpen // 67% missing
tab dcpen year, col
bys swv: sum dcpen if dcpen >= 0 

/*
* Check why there are so many missing values : all good  
preserve 
xtset idperson swv
bysoplrt idperson: egen interview_count = count(swv)
bysort idperson (swv): gen first_appearance = (swv == swv[1])

tab2 dcpst dcpen if swv>=2011, m
tab2 dcpst dcpen if swv>=2011, m r nof 
tab2 dcpst dcpen if swv>=2011 & interview_count>=2 & first_appearance!=1, m
tab2 dcpst dcpen if swv>=2011 & interview_count>=2 & first_appearance!=1, ///
	m r nof
restore 
*/


/****************************** NEW PARTNERSHIP *******************************/
gen new_rel = 0 if dcpst == 1
replace new_rel = 1 if dcpen == 1

lab var new_rel "Partnership in first year"

* Impose partnership age restriction 
replace new_rel = 0 if dag < ${age_form_partnership}

tab new_rel year, col 
bys swv: sum new_rel if new_rel >= 0 


/**************************** EXIT PARTNERSHIP ********************************/
/*
Only populated if can transition out of a partnership (not because of death 
of a partner). 
*/
sort idperson swv 
xtset idperson swv 

gen dcpex = -9
replace dcpex = 0 if l.dcpst == 1
replace dcpex = 1 if dcpst == 2 & l.dcpst == 1 
replace dcpex = -9 if widow == 1 & dcpex == 1 & l.pb190 != 4

// are there old people that remain married but their partner disappears? 
count if dag >= 65 & pb190 == 2 & idpartner == -9 
count if dag >= 65 & pb200 == 1 & idpartner == -9 
count if dag >= 65 & pb200 == 2 & idpartner == -9 

count if dag >= 65 & pb190 == 2 & idpartner == -9 & dcpex == 1 
count if dag >= 65 & pb200 == 1 & idpartner == -9 & dcpex == 1 
count if dag >= 65 & pb200 == 2 & idpartner == -9 & dcpex == 1 

preserve 

	keep idperson swv rb120 flag_deceased

	rename idperson idpartner 
	rename flag_deceased flag_deceased_sp
	rename rb120 sp_movee_to 

	replace swv = swv - 1

	save "$dir_data/temp_rel_end", replace 

restore 

merge m:1 idpartner swv using "$dir_data/temp_rel_end"
 
sort idperson swv 

drop if _merge == 2 

* Eliminate incorrect exits due to deceased partner entry 
replace dcpex = -9 if flag_deceased_sp[_n-1] == 1 & idperson == idperson[_n-1] 

drop _merge

* Check for decreasing pattern at later stage in life
hist dag if dcpex == 1

graph drop _all 

lab val dcpex dummy
lab var dcpex "Exit partnership, only populated if eligable" 

* Impose partnership age restriction 
replace dcpex = -9 if dag < ${age_form_partnership}

fre dcpex //65% missing 
tab dcpex year, col
bys swv: sum dcpex if dcpex >= 0 

* Check consistency 
tab dun dcpex


/**************************** PARTNER AGE DIFFERENCE **************************/
gen dcpagdf = dag - dagsp if dagsp != . & idpartner != -9

lab var dcpagdf "Partnership age difference"

fre dcpagdf // 
tab dcpagdf year, col
bys swv: sum dcpagdf

hist dcpagdf
graph drop _all 

tab dag if dcpagdf > 20 & dcpagdf != . 

* Impose partnership age restriction 
replace dcpagdf = . if dag < ${age_form_partnership}


/************************ ECONOMIC ACTIVITY STATUS ****************************/
/* 
Activity status is coded very differently in EU-SILC to Understanding Society
** pl030/pl031 is "self-defined economic status" and has the most detail but 
many missings, 
I use rb210 "basic activity status", which is less granular (i.e. information 
on students is not available), to fill in some of the missings 
*/

/* AB: In 2021 pl032 replaced pl031. However for ES the values for earlier years 
in which pl031 was collected have not been converted into pl032 and pl031 is not 
in the dataset. Therefore many values for 2018-2020 missing for the later 
panels. Merge in observations from the 2005-2020 panel which include the 
previous versions of the perconal data adn register activity variables.

PL031 - Self defined current economic status 
	1	Employee working full-time	
	2	Employee working part-time	
	3	Self-employed working full-time (including family worker)	
	4	Self-employed working part-time (including family worker)	
	5	Unemployed	2427	
	6	Pupil, student, further training, unpaid work experience	
	7	In retirement or in early retirement or has given up business	
	8	Permanently disabled or/and unfit to work	
	10	Fulfilling domestic tasks and care responsibilities	
	11	Other inactive person	
	
RB210 - Basic activity status
	1	At work	
	2	Unemployed	
	3	In retirement or early retirement	
	4	Other inactive person	

PL032 - Self defined current economic status 	
	1	Employed	
	2	Unemployed	
	3	Retired	
	4	Unable to work due to long-standing health problems	
	5	Student, pupil	
	6	Fulfilling domestic tasks	
	7	Compulsory military or civilian service	
	8	Other

RB211 - Main activity status (self-defined)
	1	Employed	
	2	Unemployed	
	3	Retired	
	4	Unable to work due to long-standing health problems	
	5	Student, pupil	
	6	Fulfilling domestic tasks	
	8	Other	

PL040A - Status in employement 	
	1	Self-employed with employees	
	2	Self-employed without employees	
	3	Employee	
	4	Family worker (unpaid)
	
KNOWN DATA GAP — ES rotation group 4, year 2020:
	This cohort entered the panel in 2020 but could not be surveyed due to
    COVID-19 lockdowns in Spain. The group appears in post-2021 longitudinal
    releases with household income (hy020) obtained from administrative sources
    (tax/social security records) and register-based demographics, but the
    individual interview module (P file) was never conducted. All individual
    survey variables — pl031, pl032, rb210, rb211 — are absent. les_c3 is
    assigned -9 for this group in 2020. N = 12,940 observations affected.
    These observations have valid data from 2021 onwards.	
*/

* Add in values of variables from 2005-2020 for individuals where post-2021
  * setup files do not carry forward pl031/rb210 under old variable names
merge 1:1 upid uhid year using "$dir_data/temp_orig_econ_status_${country}"
//merge 1:1 upid year using "$dir_data/temp_orig_econ_status_${country}"

* Diagnostics 
tab year _merge
tab rotation_group if year == 2020 & _merge == 1

bysort upid (year): gen int _entry_year = year[1]
tab _entry_year if year == 2020 & _merge == 1
drop _entry_year

/*
2005-2020: master observations fully matched; small number in using only 
			because the 2005-2020 panel files does not remove upid duplicates. 
2021-2024: all master-only (shorter panel stops at 2020, as intended)
2020: some observations not merged, all from the same rotation group and the 
	   first year in the sample is missing. Consistent with the data from 
	   the entry rotation group missing in the panel data. 
*/

replace pl031 = pl031_orig if pl031 == . & pl031_orig != . 
replace rb210 = rb210_orig if rb210 == . & rb210_orig != . 

drop if _merge == 2 
drop _merge *_orig

* 2009-2020
recode pl031 (1 2 3 4 = 1 "Employed or self-employed") ///
	(6 = 2 "Student") /// 
	(5 7 8 10 11 = 3 "Not employed") /// 
	, into(les_c3)
	
lab var les_c3 "LABOUR MARKET: Activity status"

* 2005-2008 
replace les_c3 = 1 if (pl030 == 1 | pl030 == 2) & les_c3 == .
replace les_c3 = 2 if (pl030 == 4) & les_c3 == .
replace les_c3 = 3 if (pl030 == 3 | pl030 == 5 | pl030 == 6 | pl030 == 8 | ///
	pl030 == 9) & les_c3 == .

* 2021-2024
replace les_c3 = 1 if les_c3 == . & pl032 == 1
replace les_c3 = 2 if les_c3 == . & pl032 == 5
replace les_c3 = 3 if les_c3 == . & inrange(pl032,2,4)
replace les_c3 = 3 if les_c3 == . & inrange(pl032,6,8)

replace les_c3 = 1 if les_c3 == . & pl040a == 1
replace les_c3 = 1 if les_c3 == . & pl040a == 2
replace les_c3 = 1 if les_c3 == . & pl040a == 3

* pl040a == 4 (family worker, unpaid) intentionally left as missing. Treating
* as employed is problematic in the simulation as they have no earnings. In
* pl031 years (2009-2020) this group was folded into self-employed (values 3,4)
* and coded as employed, but the inconsistency is minor as pl040a is only a
* last-resort fallback.

* Utilizing alternative raw variables from register dataset
* 2005-2020 
replace les_c3 = 1 if rb210 == 1 & les_c3 == .
replace les_c3 = 3 if inrange(rb210,2,4) & les_c3 == .

* 2021-2024
replace les_c3 = 1 if rb211 == 1 & les_c3 == .
replace les_c3 = 2 if rb211 == 5 & les_c3 == . 	
replace les_c3 = 3 if (inrange(rb211,2,4) | rb211 == 6 | rb211 == 8 ) & ///
	les_c3 == .
		
* For people under the age of 16 set activity status to student
replace les_c3 = 2 if dag < ${age_leave_school} 
 
tab year if !missing(les_c3) 
tab year if missing(les_c3) 

tab rotation_group if missing(les_c3) & year == 2020 & ///
	dag >= ${age_leave_school} 	
	// from that one rotation group

fre les_c3 // 3.18% missing 
tab les_c3 year, col
bys swv: sum les_c3

replace les_c3 = -9 if les_c3 == . 
tab les_c3 year, col
tab rotation_group if les_c3 == -9 & year == 2020
 

/******************** ECONOMIC ACTIVITY STATUS WITH RETIREMENT ****************/ 
/*
Conditions imposed to make consistent with SimPaths: 
	- Can not retire below a given age 
	- Retirement is an absorbing stated
	- Force retirement above a given age
*/

xtset idperson swv

clonevar les_c4 = les_c3

replace les_c4 = 4 if pl031 == 7 | pl030 == 5 | pl032 == 3 
replace les_c4 = 4 if pl031 == . &  pl030 == . & rb210 == 3 
replace les_c4 = 4 if pl032 == . & rb211 == 3 

lab var les_c4 "LABOUR MARKET: Activity status, inc retirement"
lab define les_c4  1 "Employed or self-employed"  2 "Student"  ///
	3 "Not employed"  4 "Retired"
lab val les_c4 les_c4

tab2 les_c3 les_c4

* Impose consistency across les_c3 and les_c4
replace les_c3 = 3 if les_c4 == 4  // 0 changes

* Rule out retirement before a certain age 
gen flag_no_retire_young = (dag < ${age_can_retire} & les_c4 == 4) 

lab var flag_no_retire_young ///
	"FLAG: Made non-employed because stated to retire before the age of 50"

replace les_c4 = 3 if dag < ${age_can_retire} & les_c4 == 4 	// 888 changes


* Make retirement an absorbing state - primarily eliminates returning to 
* education among the retired 
sort idperson swv 

gen flag_retire_absorb = 0 if les_c4 == 4
replace flag_retire_absorb = 0 if idperson == idperson[_n-1] & ///
	flag_retire_absorb[_n-1] == 0
	
replace flag_retire_absorb = 1 if les_c4 != 4 & flag_retire_absorb == 0 	
replace flag_retire_absorb = 0 if flag_retire_absorb == . 

lab var flag_retire_absorb ///
	"FLAG: Changed activity status due to retirement absorbing assumption"

replace les_c4 = 4 if idperson == idperson[_n-1] & les_c4[_n-1] == 4 & ///
	les_c4 != 4  // 7,689 changes 

* Force retirement above a certain age 
gen flag_retire_force = 0 
replace flag_retire_force = 1 if dag >= ${age_force_retire} & les_c4 != 4
	// 6,440 changes

lab var flag_retire_force ///
	"FLAG: Forced into retirement due to age (after absorbign assumption)"

replace les_c3 = 3 if dag >= ${age_force_retire}	
replace les_c4 = 4 if dag >= ${age_force_retire}	
	
* Make les_c3 consistent with change made to les_c4
replace les_c3 = 3 if les_c4 == 4 	// 1,050 changes 	

* Check consistency 
tab2 les_c3 les_c4, row

fre les_c4 	// 2.6% missing 
tab les_c4 year, col
bys swv: sum les_c4


/************************ LONG-TERM SICK OR DISABLED **************************/
/*
Effectively treat disabled/long-term sick as a mututlly exclusive activity 
status.
*/

gen dlltsd = 0 
replace dlltsd = 1 if pl030 == 6 | pl031 == 8 | pl032 == 4

lab var dlltsd "DEMOGRAPHIC: LT sick or disabled"

* Check consistency with les_c3
tab dlltsd les_c3 
tab dlltsd les_c4

* Impose consistency 
replace dlltsd = -9 if les_c3 == -9 

* Check consistency with les_c4
* Assume mutual exclusivity, retirement and disabled
tab dlltsd les_c4

gen flag_disabled_to_retire = (les_c4 == 4 & dlltsd == 1)

lab var flag_disabled_to_retire ///
"FLAG: Replaced disabled status with 0 due to conflict with imposed retirement"

replace dlltsd = 0 if les_c4 == 4	// 2,195 changes
	
tab les_c3 les_c4
	
fre dlltsd 
tab dlltsd year, col 
bys swv: sum dlltsd

tab les_c3 dlltsd 
tab les_c4 dlltsd


/******************* PARTNER LONG-TERM SICK OR DISABLED ***********************/
preserve

	keep swv idperson dlltsd
	rename idperson idpartner
	rename dlltsd dlltsd_sp

	save "$dir_data/temp_dlltsd", replace

restore

merge m:1 swv idpartner using "$dir_data/temp_dlltsd"

lab var dlltsd_sp "Partner's long-term sick"

keep if _merge == 1 | _merge == 3
drop _merge

* Impose partnership age restriction 
replace dlltsd_sp = . if dag < ${age_form_partnership}

fre dlltsd_sp if idpartner > 0 
tab dlltsd_sp year, col 


/******************************* UNEMPLOYMENT *********************************/
fre pl020 pl031

gen unemp = (pl030 == 3 | pl031 == 5 | pl032 == 2)
replace unemp = 1 if rb211 == 2 | rb210 == 2

* Impose priority to the pl variable 
replace unemp = 0 if les_c3 != 3

replace unemp = -9 if les_c3 == -9

lab var unemp "Unemployed dummy"
 
fre unemp
tab unemp year, col 
bys swv: sum unemp

* Check consistency 
tab unemp les_c3 
tab unemp les_c4 

* Impose consistency with retirement 
gen flag_unemp_to_retire = (les_c4 == 4  & unemp == 1)

lab var flag_unemp_to_retire ///
	"FLAG: Replaced unemployed with 0 due to retirement status enforcement"

replace unemp = 0 if les_c4 == 4 & unemp == 1 	// 568 changes

tab unemp dlltsd

tab unemp les_c3 
tab unemp les_c4 


/*********************** IN INITIAL EDUCATION SPELL ***************************/
/* 
In the understanding society data notes from codebook differ from the code 
below: In education from jbstat variable, where jbstat = 7 then in education. 
If missing then used previous or next wave's labour force status and dates left
education to fill in.
If have returned to education following a break then ded = 0.

sort idperson swv 
cap gen ded = 0 
replace ded = 1 if pl031 == 6 & (l.pl031==6 ) //| l.pl031 == .
replace ded = 1 if pl030 == 4 & (l.pl030==4 ) //| l.pl030 == .

/*is a full-time student now and was full-time student in previous wave*/

la val ded dummy
la var ded "DEMOGRAPHIC : In Continuous Education"
//fre ded
//bys ded: fre dag 
*/

/*
Assume in intital education spell if observed in education in first waves and at 
most 25 years old. 
*/
sort idperson swv 
xtset idperson swv

gen ded = 0 

* Everyone under 16 should be in education 
replace ded = 1 if dag < ${age_leave_school} 

replace ded = 1 if pl030 == 4 & idperson != idperson[_n-1] & dag <= 25
replace ded = 1 if pl031 == 6 & idperson != idperson[_n-1] & dag <= 25 
replace ded = 1 if pl032 == 5 & idperson != idperson[_n-1] & dag <= 25 

replace ded = 1 if l.ded == 1 & pl030 == 4 
replace ded = 1 if l.ded == 1 & pl031 == 6 
replace ded = 1 if l.ded == 1 & pl032 == 5 
replace ded = 1 if l.ded == 1 & pl032 == . & rb211 == 5 

* Cannot be in initial education spell above a specific age in simulation
replace ded = 0 if dag >= ${age_force_leave_spell1_edu}

lab var ded "In initial education spell"

fre ded // 22% obs 
tab ded year, col 
tab dag ded, row
bys swv: sum ded

* Ensure don't return to initial education spell once left 
sort idperson swv 

count if ded == 1 & ded[_n-1] == 0 & idperson == idperson[_n-1] 	// 0 obs 

* Check consistency 
tab ded les_c3 
tab ded les_c4 

tab ded unemp
tab ded dlltsd 

tab dag ded 


/******************************** STUDENT *************************************/
gen studentflag = -9 
replace studentflag = 0 if les_c3 == 1 | les_c3 == 3
replace studentflag = 1 if les_c3 == 2 

label var studentflag "Student"

tab les_c3 studentflag 
tab les_c4 studentflag 


/**************************** HOURS OF WORK ***********************************/
/*
PL060 - Number of hours usually worked per week usually worked in current main 
job 
*/
clonevar lhw = pl060

lab var lhw "Hours worked per week"

* Impose age restrictions
* Cannot work when a child
replace lhw = 0 if dag < ${age_seek_employment}

* Cannot work above a certain age
replace lhw = 0 if dag >= ${age_force_retire}	

* Check missing 
count if missing(lhw) & les_c3 == 1

* Check consistency - how many non-workers report positive hours? 
bys les_c3: fre lhw 
bys les_c4: fre lhw 
	
sort idperson swv	
	
/*
Imposing consistency: We decided to assume the "non-working" response is true,
this implies: 
	- zero hours => not working activity status 
	- not working activity status => zero hours

We also have many observations with missing information that require an 
additional rule. 
	- positive hours and missing activity => employed 
	- working and missing hours => impute hours 

Impute hours using surrounding observations for longitudinal consistency and 
then use hot deck imputation by age group and sex. 

*/	
	
* Consistency of zero hours cases
tab les_c3 if lhw == 0 	
tab les_c4 if lhw == 0 	

sum lhw if les_c3 == 2	
sum lhw if les_c3 == 3
sum lhw if les_c3 == -9
	
* Overwrite hours work if report not working 
gen flag_impose_zero_hours_ne = (lhw > 0 & lhw != . & les_c4 == 3)
gen flag_impose_zero_hours_retire = (lhw > 0 & lhw != . & les_c4 == 4)
gen flag_impose_zero_hours_student = (lhw > 0 & lhw != . & les_c3 == 2)

lab var flag_impose_zero_hours_ne ///
	"FLAG: Replaced +ive hours of work with 0 as report not-employed"
lab var flag_impose_zero_hours_retire ///
	"FLAG: Replaced +ive hours of work with 0 as report retired"
lab var flag_impose_zero_hours_student ///
	"FLAG: Replaced +ive hours of work with 0 as report student"

replace lhw = 0 if les_c3 == 2	
replace lhw = 0 if les_c3 == 3	


* Overwrite activity status if report zero hours 
gen flag_not_work_hours = (lhw  == 0 & les_c3 == 1)

lab var flag_not_work_hours ///
	"FLAG: Replaced activity status with non-employed as report 0 hours"

replace les_c3 = 3 if lhw  == 0 & les_c3 == 1 
replace les_c4 = 3 if lhw  == 0 & les_c4 == 1 


* Consistency of missing hours cases 
tab les_c3 if lhw == .
tab les_c4 if lhw == . 
		
* Overwrite les_c* if report hours but missing activity status information
gen flag_missing_act_hours = (lhw > 0 & lhw != . & les_c3 == -9)

lab var flag_missing_act_hours ///
"FLAG: Replaced missing activity status with working as report positive hours"

replace les_c3 = 1 if lhw > 0 & lhw != . & les_c3 == -9		
replace les_c4 = 1 if lhw > 0 & lhw != . & les_c3 == 1 & les_c4 == -9		
		
* Investigate the characteristics of those missing hours and reporting to work
gen x = (lhw == .)
tab swv x if les_c4 == 1, row // up to 11% missing in a year 

tab dag if les_c4 == 1 & lhw == . // distributed across all ages (16-74)

tab pl040 if les_c4 == 1 & lhw == .  // most employees (47%)
count if pl040 == . & les_c4 == 1 & lhw == . & dag >= 16	// 9,059

tab pl145 if les_c4 == 1 & lhw == .  // most full time workers (82%)
count if pl145 == . & les_c4 == 1 & lhw == . & dag >= 16	// 15,956

tab pl141 if les_c4 == 1 & lhw == .  // most have perm written contract (76%)
count if pl141 == . & les_c4 == 1 & lhw == . & dag >= 16	// 16,550

count if les_c4 == 1 & lhw == . & dag >= 16 & pl030 == . & pl031 == . & ///
	pl032 ==.  	// 3,341
		
/*
Below, first impose longitudinal consistency - use own adjacent values. 
For the remaining observations use empirical hot deck imputation within strata. 
(age group and gender)
*/		
		
* Longitudinal consistency 

* Backwards
sort idperson swv

* Direct 
gen flag_missing_hours_act_adj = (lhw == . & les_c3 == 1 & ///
	les_c3[_n-1] == 1 & lhw[_n-1] != . & idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1)

* Fill 	
replace flag_missing_hours_act_adj = 1 if lhw == . & les_c3 == 1 & ///
	flag_missing_hours_act_adj[_n-1] == 1 & idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1	

replace lhw = lhw[_n-1] if lhw == . & les_c3 == 1 & les_c3[_n-1] == 1 & ///
	lhw[_n-1] != . & idperson == idperson[_n-1] & swv == swv[_n-1] + 1
		// 6,009 changes 
		
count if lhw == . & les_c4 == 1  	// 11,624

* Forwards
gsort idperson -swv 

*Direct
replace flag_missing_hours_act_adj = 1 if lhw == . & les_c3 == 1 & ///
	les_c3[_n-1] == 1 & lhw[_n-1] != . & idperson == idperson[_n-1] & ///
	swv == swv[_n-1] - 1

* Fill 	
replace flag_missing_hours_act_adj = 1 if lhw == . & les_c3 == 1 & ///
	flag_missing_hours_act_adj[_n-1] == 1 & idperson == idperson[_n-1] & ///
	swv == swv[_n-1] - 1	

replace lhw = lhw[_n-1] if lhw == . & les_c3 == 1 & les_c3[_n-1] == 1 & ///
	lhw[_n-1] != . & idperson == idperson[_n-1] & swv == swv[_n-1] - 1
		// 5,497 changes
		
sort idperson swv 		
		
lab var flag_missing_hours_act_adj ///
"FLAG: Replaced missing hours with positive amount using info from adjacent cells as report working "

count if lhw == . & les_c4 == 1  	// 6,127


* Imputation - hotdeck 

* Observations to be imputed 
gen need_imp = (les_c4 == 1 & lhw == .)
 
* Strata
gen ageband = floor(dag/10)*10

egen stratum = group(ageband dgn), label   

* Donor pool 
preserve 

	keep if les_c4 == 1 & lhw > 0 & lhw != .
	keep lhw stratum idperson swv
	
	bys stratum (idperson swv): gen draw = _n
	bys stratum (idperson swv): gen n_donors  = _N
	
	rename lhw donor_lhw
	drop idperson
	
	save "$dir_data/temp_lhw_donors", replace

	* Counts lookup (one row per stratum)
	keep stratum n_donors
	bys stratum: keep if _n == 1
	save "$dir_data/temp_donorsN", replace

restore

merge m:1 stratum using "$dir_data/temp_donorsN", nogen

* Assign random donor 
set seed 9876

gen draw = . 

sort stratum idperson swv

bys stratum (idperson swv): replace draw = ceil(runiform()*n_donors[1]) if ///
	need_imp == 1 & n_donors > 0 

merge m:1 stratum draw using "$dir_data/temp_lhw_donors", ///
	keepusing(donor_lhw draw) 

drop if _merge == 2 
drop _merge
	
replace lhw = donor_lhw if need_imp == 1 

tab lhw if need_imp == 1

count if need_imp == 1 & n_donors == 0		// check 		
				
rename need_imp	flag_missing_hours_act_imp

lab var flag_missing_hours_act_imp	///
"FLAG: Replaced hours from missing to positive amount using hot deck imputation"		
			
drop x donor_lhw n_donors draw 			
			
count if lhw == . & les_c3 == -9 	// 16,107 cases
sum lhw if les_c3 == -9 		
		
		
* Update other variables		
replace dlltsd = 0 if les_c3 == 1 
replace unemp = 0 if les_c3 == 1 
		
		
* Check consistency - how many workers do not report hours? 
tab les_c3 if lhw == . 
tab les_c3 if lhw > 0 & lhw != . 
tab les_c3 if lhw == 0 

tab les_c4 if lhw == . 
tab les_c4 if lhw > 0 & lhw != .
tab les_c4 if lhw == 0 

tab les_c3 les_c4

count if les_c3 == .
count if les_c4 == .

count if les_c3 == -9
count if les_c4 == -9 
count if les_c4 == -9  & lhw == . 	// 16,107


/********************* LAGGED ECONOMIC ACTIVITY STATUS ************************/
* Without retirement 
xtset idperson swv
sort idperson swv 

gen l1_les_c3 = l.les_c3 

lab def l1_les_c3 1 "Employed or self_employed" 2 "Student" 3 "Not employed"
lab val l1_les_c3 l1_les_c3
lab var l1_les_c3"LABOUR MARKET: Activity status, t-1"

* With retirement 
xtset idperson swv
sort idperson swv 

gen l1_les_c4 = l.les_c4 

lab def l1_les_c4 1 "Employed or self_employed" 2 "Student" ///
	3 "Not employed" 4 "Retired"
lab val l1_les_c4 l1_les_c4
lab var l1_les_c4 "LABOUR MARKET: Activity status, inc retirement, t-1"


/************************** PARTNER'S ACTIVITY STATUS *************************/
* Without retirement 
preserve

	keep swv idperson idhh les_c3
	rename les_c3 lessp_c3
	rename idperson idpartner
	
	save "$dir_data/temp_lesc3", replace

restore

merge m:1 swv idpartner idhh using "$dir_data/temp_lesc3"
keep if _merge == 1 | _merge == 3

lab var lessp_c3 "Partner's activity status"
drop _merge

* Impose partnership age restriction 
replace lessp_c3 = . if dag < ${age_form_partnership}

fre lessp_c3
tab lessp_c3 year, col 

* With retirement
preserve

	keep swv idperson idhh les_c4
	rename les_c4 lessp_c4
	rename idperson idpartner
	
	save "$dir_data/temp_lesc4", replace

restore

merge m:1 swv idpartner idhh using "$dir_data/temp_lesc4"
keep if _merge == 1 | _merge == 3 

lab var lessp_c4 "LABOUR MARKET: Partner's activity status"
lab val lessp_c4 les_c4
drop _merge

* Impose partnership age restriction 
replace lessp_c4 = . if dag < ${age_form_partnership}

fre lessp_c4
tab lessp_c4 year, col 


/********************** OWN AND SPOUSE ACTIVITY LEVELS ************************/
gen lesdf_c4 = -9

* Both employed
replace lesdf_c4 = 1 if les_c3 == 1 & lessp_c3 == 1 & dcpst == 1 
	
* Employed, spouse not employed	
replace lesdf_c4 = 2 if les_c3 == 1 & (lessp_c3 == 2 | lessp_c3 == 3) & ///
	dcpst == 1 

* Not employed, and spouse employed	
replace lesdf_c4 = 3 if (les_c3 == 2 | les_c3 == 3) & lessp_c3 == 1 & ///
	dcpst == 1 

* Both not employed	
replace lesdf_c4 = 4 if (les_c3 == 2 | les_c3 == 3) & ///
	(lessp_c3 == 2 | lessp_c3 == 3) & dcpst == 1 

lab def lesdf_c4 1 "Both employed" 2 "Employed and spouse not employed" ///
	3 "Not employed and spouse employed" 4 "Both not employed" -9 "Missing"
lab val lesdf_c4 lesdf_c4

lab var lesdf_c4 "LABOUR MARKET: Own and spouse activity status"

* Correct underage partnerships 
replace lesdf_c4 = -9 if dag < ${age_form_partnership}

fre lesdf_c4
tab lesdf_c4 year, col
bys swv: sum lesdf_c4 if lesdf_c4 >= 0


/*************************** EMPLOYMENT EXPERIENCE ****************************/
gen liwwh = -9
replace liwwh = pl200 if pl200 >= 0 & pl200 != . 
replace liwwh = 55 if pl200 > 55 & pl200 != . // make upper censoring consistent

lab var liwwh "LABOUR MARKET: Number of years spent in paid work"

fre liwwh 
tab liwwh year, col 
bys swv: sum liwwh if liwwh >= 0


/************************* EDUCATIONAL ATTAINMENT *****************************/
/* 
Use pe040 variable, code negative values to missing
	Low education: 		Other qualification, no qualification
	Medium education: 	Other higher degree, A-level etc, GCSE etc
	High education: 	Degree
	
EU SILC variables: Variables top coded 
PE040 - Highest ISCED evel attained
	0		Pre-primary education	
	1		Primary education	
	2		Lower secondary education	
	3		(Upper) secondary education	
	4		Post-secondary non-tertiary education	
	5		1st & 2nd stage of tertiary education	
	100		Primary education	
	200		Lower secondary education 
	300		Upper secondary education (not further specified)
	344		Level completion, with direct access to tertiary education	
	353		Level completion, without direct access to tertiary education	
	354		Level completion, with direct access to tertiary education	
	400		Post-secondary non-tertiary education (not further specified) 
	450		Vocational education	
	500		Short cycle tertiary	

PE041- Highest ISCED evel attained
	0		No formal education or below ISCED 1	
	100		ISCED 1 Primary education	161	0.6	1.9
	200		ISCED 2 Lower secondary education 
	340		ISCED 3 Upper secondary education- general
	344		ISCED 3 Upper secondary education (general) 
			- level completion, w/ direct access to tertiary education 
	350		ISCED 3 Upper secondary education - vocational (age 35 and over)	
	353		ISCED 3 Upper secondary education (vocational) 
			- level completion, w/o direct access to tertiary education 
	354		ISCED 3 Upper secondary education (vocational) 
			- level completion, w/ direct access to tertiary education 
	450		ISCED 4 Post-secondary non-tertiary education - vocational	
	500		IT: ISCED 5 
	
AB: Same logic applies as for activity status - the variable changed name in 
2021 therefore we have an issue with missing data in 2020. 
*/

replace pe040 = . if pe040 < 0
sort  idperson swv

* Merge in values from 2005-2020 panel 
merge 1:1 year upid uhid using "$dir_data/temp_orig_edu_${country}"

replace pe040 = pe040_orig if pe040 == . & pe040_orig != . 
 
drop if _merge == 2 
drop _merge pe040_orig

* 2005-2020
gen deh_c3 = .
replace deh_c3 = 3 if pe040 == 0 | pe040 == 1 | pe040 == 2 | pe040 == 100 ///
	| pe040 == 200
replace deh_c3 = 2 if pe040 == 3 | pe040 == 4 | (pe040 >= 300 & pe040 < 500)
replace deh_c3 = 1 if pe040 == 5 | (pe040 >= 500 & pe040 <= 1000)
		
* 2021-2024		
replace deh_c3 = 3 if pe041 == 0 | pe041 == 100 | pe041 == 200
replace deh_c3 = 2 if pe041 >= 300 &  pe041 < 500
replace deh_c3 = 1 if pe041 >= 500 &  pe041 <= 800
		
lab var deh_c3 "Education status, 3 cat"
lab define l_deh_c3 3 "low" 2 "medium" 1 "high" 
lab values deh_c3 l_deh_c3
					
replace deh_c3 = -9 if deh_c3 == . 					
											
					
* Assume in initial education spell until at least 15 
* 	- education not yet assigned impose low for now	
replace deh_c3 = 3 if dag < ${age_leave_school} 

replace deh_c3 = -9 if deh_c3 == . 

fre deh_c3	// 7% missing, 57,794
fre dag if deh_c3 == -9  
fre year if deh_c3 == -9  
tab deh_c3 year, col
bys swv: sum deh_c3 if deh_c3 > 0 

gen deh_orig  = deh_c3 


* Impute missing values 
/* 
Impute missing values using the monotonicity of education. Individuals can only 
increase their education level over time and there is a min and a mix, 
therefore can use lagged and lead values for those who have not been students 
in the intervening period (and sometimes before and after given max/min).
Max of 5 previous observations per indiviudal due to max 6 wave panel for each 
individual. 
*/

sort idperson swv
xtset idperson swv 

* Non-student dummy 
gen non_student = (les_c3 != 2)
replace non_student = . if les_c3 == -9		

* Variable containing imputed values 
gen imp_deh_mono = deh_c3 if deh_c3 > 0 

bysort idperson (swv): gen count = _n

sort idperson swv

* Looking backwards 
forvalues i = 2/5 {
	
	* High in the past, high today (max and monotonic)
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & imp_deh_mono[_n-1] == 1 & ///
		imp_deh_mono == . & count == `i' 
	
	* Populate with previous observation if:
	
	* Remain a non-student 
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == 1 & ///
		non_student == 1 & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 
		
	* Remain a student 	
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == 0 & ///
		non_student == 0 & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 
		
	* Transition into education 	
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == 1 & ///
		non_student == 0 & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i'

	* Student current, missing previous 
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == . & ///
		non_student == 0 & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 		
		
	* Missing current, non-student previous 
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == 1 & ///
		non_student == . & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 	
	
}

* Looking forwards

* Reverse sort
gsort idperson -swv 

forvalues i = 5(-1)1 {
	
	* Low in the future, low today (min and monotonicity)
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & imp_deh_mono[_n-1] == 3 & ///
		imp_deh_mono == . & count == `i' 	
		
	* Populate with future observation if:
	
	* Remain a non-student 
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == 1 & ///
		non_student == 1 & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 
		
	* Remain a student 
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == 0 & ///
		non_student == 0 & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 	
		
	* Transition into education next year
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == 0 & ///
		non_student == 1 & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 		
	
	* Missing current, student next
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == 0 & ///
		non_student == . & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 	
	
	* Non-student current, missing next
	replace imp_deh_mono = imp_deh_mono[_n-1] if ///
		idperson == idperson[_n-1] & non_student[_n-1] == . & ///
		non_student == 1 & imp_deh_mono == . & imp_deh_mono[_n-1] != . & ///
		count == `i' 	
}

sort idperson swv 

tab deh_c3 // 7%

* Missing 
replace imp_deh_mono = -9 if imp_deh_mono == . 

tab imp_deh_mono // 6%

gen flag_deh_imp_mono = 1 if imp_deh_mono!= -9 & deh_c3 == -9 

lab var flag_deh_imp_mono "FLAG: =1, impute age using logical deduction"

* Comparison plot
twoway (histogram deh_c3 if deh_c3 > 0, percent color(blue%50) ///
	barwidth(0.8)) ///
	(histogram imp_deh_mono if imp_deh_mono > 0, percent color(red%50) ///
	barwidth(0.8)), ///
	title("Comparison of Observed vs. Imputed Values") ///
	legend(label(1 "Observed deh_c3") label(2 "Imputed imp_deh") ) ///
	graphregion(color(white))

twoway (histogram deh_c3 if deh_c3 > 0 & dag < 30 & dag > 16, percent ///
	color(blue%50) barwidth(0.8)) ///
	(histogram imp_deh_mono if imp_deh_mono > 0 & dag < 30 & dag > 16, ///
	percent color(red%50) barwidth(0.8)), ///
	title("Comparison of Observed vs. Imputed Values") ///
	legend(label(1 "Observed deh_c3") label(2 "Imputed imp_deh") )	///
	graphregion(color(white))

graph drop _all 	

* Add imputed values to variable 
replace deh_c3 = imp_deh_mono if deh_c3 == -9 
		
fre deh_c3
fre dag if deh_c3 == -9  
fre year if deh_c3 == -9  
tab deh_c3 year, col
bys swv: sum deh_c3 if deh_c3 > 0 

count if deh_c3 == -9  // 22,071

/*
Still missing education level information if: 
- Missing education when transition out of education 
- Individual does not report any education level in their panel 
- Missing activity status and missing education level 
- Missing previous activity status (and now a non-student)

Use regression based imputation at the end of the file to impute the remaining
missing values. 
*/


* Create four category version with an unassigned cat for those in initial edu 
* spell 
gen deh_c4 = deh_c3 

replace deh_c4 = 0 if dag < ${age_leave_school} 
replace deh_c4 = 0 if ded == 1

lab var deh_c4 "Education status, 4 cat"
lab define deh_c4 3 "low" 2 "medium" 1 "high" 0 "na"
lab values deh_c4 deh_c4

count if deh_c4 == -9 	// 22,058
count if deh_c4 == -9 & les_c4 == -9  	// 4,656


/*************************** PARENT'S EDUCATION STATUS ************************/ 
/* 
There is no variable for parent's education status in EU-SILC, but can be 
made for those with parent IDs in the data.
1. Create mothers and fathers education levels in new file with person and hh id 
2. Merge by father and mother id and hh id 

However this requires individuals to live with their parents and therefore isn't
particularly useful for our purposes.

Create variables but leave missing so able to utilize the standard strucuture of 
SimPaths. 
*/

gen dehm_c4 = .
gen dehf_c4 = .
gen dehmf_c4 = . 

/*
preserve
keep swv idperson idhh deh_c3
drop if missing(deh_c3)
rename idperson idmother
rename deh_c3 mother_educ
save "$dir_data/mother_edu", replace

rename idmother idfather
rename mother_educ father_educ
save "$dir_data/father_edu", replace
restore

merge m:1 swv idmother idhh using "$dir_data/mother_edu" 
keep if _merge == 1 | _merge == 3
drop _merge
merge m:1 swv idfather idhh using "$dir_data/father_edu"
keep if _merge == 1 | _merge == 3
drop _merge

replace dehm_c4 = mother_educ
replace dehf_c4 = father_educ

fre dehm_c4 if dgn > 0 & dag > 0
fre dehf_c4 if dgn > 0 & dag > 0

* Identify the highest parental education status 
//recode dehm_c4 dehf_c4 (.=0) 
egen dehmf_c4 = rowmax(dehm_c4 dehf_c4)
lab var dehmf_c4 "highest parental education status"
fre dehmf_c4
//recode dehm_c4 dehf_c4 (0 = .) 
fre dehmf_c4 if dehm_c4 == . 
fre dehmf_c4 if dehf_c4 == . 

/* Only a third of the dataset has an observation for parental education and so 
the following code used to predict the value is not very accurate. 
Perhaps it could be improved using income or other related factors? For now, it 
is coded out.
 
*Predict highest parental education status if missing 
*Recode education level (outcome variable) so 1 = Low education, 
* 2 = Medium education, 3 = High education
recode dehmf_c4 ///
	(1 = 3) ///
	(3 = 1) ///
	, gen(dehmf_c4_recoded)
	
la def dehmf_c4_recoded 1 "Low" 2 "Medium" 3 "High"
la val dehmf_c4_recoded dehmf_c4_recoded
fre dehmf_c4_recoded

*ordered probit model to replace missing values  
recode dgn dag drgn1 (-9=.) , gen (dgn2 dag2 drgn12)
fre dgn2 dag2 drgn12

xi: oprobit dehmf_c4_recoded i.dgn2 dag2 ib8.drgn12 i.swv, vce(robust)
predict pred_probs1 pred_probs2 pred_probs3, pr

//Identify the category with the highest predicted probability
egen max_prob = rowmax(pred_probs1 pred_probs2 pred_probs3)
//Impute missing values based on predicted probabilities
gen imp_dehmf_c4_recoded = .
replace imp_dehmf_c4_recoded = 1 if max_prob == pred_probs1
replace imp_dehmf_c4_recoded = 2 if max_prob == pred_probs2
replace imp_dehmf_c4_recoded = 3 if max_prob == pred_probs3

fre imp_dehmf_c4_recoded if missing(dehmf_c4_recoded) 
fre imp_dehmf_c4_recoded if !missing(dehmf_c4_recoded)

recode imp_dehmf_c4_recoded ///
	(1 = 3) ///
	(3 = 1) ///
	, gen(imp_dehmf_c4)

tab2 imp_dehmf_c4_recoded imp_dehmf_c4

cap gen dehmf_c4_flag = missing(dehmf_c4) 
lab var dehmf_c4_flag "=1 if dehmf_c4 is imputed"
replace dehmf_c4 = round(imp_dehmf_c4) if missing(dehmf_c4) 
lab define dehmf_c4 1 "High" 2 "Medium" 3 "Low"

bys dehmf_c4_flag: fre dehmf_c4

drop dehmf_c4_recoded dgn2 dag2 drgn12 _Idgn2_1 _Iswv_* pred_probs* max_prob ///
	imp_dehmf_c4_recoded imp_dehmf_c4
*/
*/


/*************************** RETURN TO EDUCATION ******************************/
/*
Only populated when at risk of transitioning into education 
*/
xtset idperson swv
sort idperson swv 

cap gen der = -9
replace der = 0 if l.ded == 0 & l.les_c3 != 2 & l.les_c3 != -9  
replace der = 1 if les_c3 == 2 & der == 0 
replace der = -9 if les_c3 == -9 

lab val der dummy
lab var der "Return to education, only populated if eligable"

fre der // 52% of observation missing value 
tab der year, col 
bys swv: sum der if der >= 0

* Can not return to education once retired
sort idperson swv 
replace der = -9 if l.les_c4 == 4 

* Check consistency 
tab der ded 

tab dag der

tab der les_c3
tab der les_c4
	
	
/******************************* LEAVE EDUCATION ******************************/
/*
Only populated if can transition out of education 
Populated if can choose to leave education in the simulation, aged 16-29
*/
sort idperson swv 

gen sedex = -9 
replace sedex = 0 if l.les_c3 == 2 & les_c3 != -9 
replace sedex = 1 if les_c3 != 2 & sedex == 0 & les_c3 != -9 

* Make consistent with the simulation 
* Cannot leave school before turning 16
replace sedex = -9 if dag < ${age_leave_school}
* Do not have the choice to leave or tay in school after the age of 29 (1yr max)
replace sedex = -9 if dag >= ${age_force_leave_spell1_edu}
	
lab val sedex dummy
lab var sedex "Transition out of education"

fre sedex // 95% missing
fre sedex if sedex > -9 // 23% leave
tab sedex year, col

* Check consistency 
tab ded sedex
tab sedex les_c3
tab sedex les_c4

tab dag sedex 


/****************************** RETIRED ***************************************/
gen dlrtrd = 0
replace dlrtrd = 1 if les_c4 == 4

replace dlrtrd = -9 if les_c3 == -9

sort idperson swv 

lab var dlrtrd "DEMOGRAPHIC : Retired"

fre dlrtrd // 31.36% retired
tab dlrtrd year, col

tab les_c3 dlrtrd
tab les_c4 dlrtrd


/**************************** ENTER RETIREMENT ********************************/
/* 
Only populated if at risk of transition.
*/
sort idperson swv 
xtset idperson swv 
gen drtren = -9 

replace drtren = 0 if l.dlrtrd == 0 & dlrtrd != -9 
replace drtren = 1 if dlrtrd == 1 & drtren == 0 

* Impose simulation eligability 
replace drtren = -9 if dag < ${age_can_retire}


lab val drtren dummy
lab var drtren "DEMOGRAPHIC: Enter retirement, only populated if eligable"

fre drtren // 84.5% missing
tab drtren year, col

tab drtren les_c3
tab drtren les_c4


/**************************** PENSION AGE *************************************/
/*
https://www.seg-social.es/wps/portal/wss/internet/Trabajadores/PrestacionesPensionesTrabajadores/10963/28393/28396/28472/6156

NOTE ON PENSION ELIGABILITY: 
In Spain the eligability depends on either just age or age + years of 
contributions. Here we focus on the prior as there is not month of birth var in 
SILC.  

NOTE ON PENSION AGE AGGREGATION:
State pension age in Spain is defined in months and is identical for all genders. 
Because this model operates on an annual time-step, we apply a FLOOR rounding 
assumption (rounding down to the nearest integer). 

RATIONALE:
1. Behavioral Capture: Most individuals exit the labor market at the earliest
   point of eligibility. A floor ensures we capture the 'Entry into Retirement'
   event in the year it first becomes legally possible.
2. Handling Aggregation Bias: To account for the 'noise' created by the
   monthly-to-yearly mismatch (i.e., individuals working part of the first year)
   we include a dummy for the SECOND year of pension age.
3. Interpretation: The 'Year 1' coefficient captures the transition/exit effect,
   while 'Year 2' captures the stable state of full-year retirement.
4. Graduated Reform (2013-2020): During this period the monthly threshold rose
   above 65 (65y+1m to 65y+10m). Under floor rounding, individuals who reached
   65 but not yet the monthly threshold are caught by dagpns_y1 in the following
   year. Both dagpns_y and dagpns_y1 are included in all relevant specifications
   to absorb this marginal misclassification.

State Retirement Ages for Men in the SPAIN (2009-2024):

2005-2006: 65
2006-2007: 65
2007-2008: 65
2008-2009: 65
2009-2010: 65
2010-2011: 65
2011-2012: 65
2012-2013: 65
2013-2014: 65 1m
2014-2015: 65 2m 
2015-2016: 65 3m
2016-2017: 66 4m
2017-2018: 66 5m
2018-2019: 65 6m
2019-2020: 65 8m
2020-2021: 65 10m
2021-2022: 66
2022-2023: 66 2m
2023-2024: 66 4m

*/
gen dagpns = 0

* Men
replace dagpns = 1 if dgn == 1 & dag >= 65 & stm >= 2005 & stm < 2021
replace dagpns = 1 if dgn == 1 & dag >= 66 & stm >= 2021 & stm <= 2024

* Women 
replace dagpns = 1 if dgn == 0 & dag >= 65 & stm >= 2005 & stm < 2021
replace dagpns = 1 if dgn == 0 & dag >= 66 & stm >= 2021 & stm <= 2024

fre dagpns // 20% of retirement age 

* Become eligable for the state pension dummy 
gen dagpns_y = 0 

* Men 
replace dagpns_y = 1 if dgn == 1 & dag == 65 & stm >= 2005 & stm < 2021
replace dagpns_y = 1 if dgn == 1 & dag == 66 & stm >= 2021 & stm <= 2024 

* Women
replace dagpns_y = 1 if dgn == 0 & dag == 65 & stm >= 2005 & stm < 2021
replace dagpns_y = 1 if dgn == 0 & dag == 66 & stm >= 2021 & stm <= 2024 

* Became eligable for state pension last year 
gen dagpns_y1 = 0 

* Men 
replace dagpns_y1 = 1 if dgn == 1 & dag == 66 & stm >= 2005 & stm < 2021
replace dagpns_y1 = 1 if dgn == 1 & dag == 67 & stm >= 2021 & stm <= 2024 

* Women
replace dagpns_y1 = 1 if dgn == 0 & dag == 66 & stm >= 2005 & stm < 2021
replace dagpns_y1 = 1 if dgn == 0 & dag == 67 & stm >= 2021 & stm <= 2024 

lab var dagpns_y "Year became eligable for pension"
lab var dagpns_y1 "Year+1 became eligable for pension"

tab dag dagpns_y
tab dag dagpns_y1


/**************************** PENSION AGE OF SPOUSE ***************************/
* Above state pension age dummy 
preserve

	keep swv idperson idhh dagpns
	rename dagpns dagpns_sp
	rename idperson idpartner

	save "$dir_data/temp_dagpns", replace

restore

merge m:1 swv idpartner idhh using "$dir_data/temp_dagpns"
keep if _merge == 1 | _merge == 3
drop _merge

lab var dagpns_sp "Pension age - partner"

replace dagpns_sp = -9 if idpartner < 0

* At age when can first claim state pension or year after
preserve

	keep swv idperson idhh dagpns_y dagpns_y1 
	rename dagpns_y dagpns_y_sp
	rename dagpns_y1 dagpns_y1_sp
	rename idperson idpartner

	save "$dir_data/temp_dagpns_y", replace

restore

merge m:1 swv idpartner idhh using "$dir_data/temp_dagpns_y"
keep if _merge == 1 | _merge == 3
drop _merge

lab var dagpns_y_sp "Year became eligable for pension - partner"
lab var dagpns_y1_sp "Year+1 became eligable for pension - partner"

replace dagpns_y_sp = -9 if idpartner < 0
replace dagpns_y1_sp = -9 if idpartner < 0

* Correct underage partnerships 
replace dagpns_y_sp = -9 if dag < ${age_form_partnership}
replace dagpns_y1_sp = -9 if dag < ${age_form_partnership}

fre dagpns_sp 
fre dagpns_y_sp
fre dagpns_y1_sp


/*************************** NOT RETIRED WORK STATUS **************************/
gen lesnr_c2 = -9 

replace lesnr_c2 = 0 if les_c4 == 1
replace lesnr_c2 = 1 if inrange(les_c4,2,3)
	
lab var lesnr_c2 "Not retired work status"
lab define lesnr_c2 0 "in work" 1 "not in work"
lab val lesnr_c2 lesnr_c2 

fre lesnr_c2 
tab lesnr_c2 year, col


/*************************** SAME SEX PARTNERSHIP *****************************/
gen ssscp = 0 if idpartner > 0
replace ssscp = 1 if dcpst == 1 & dgn == dgnsp & dgnsp != .

lab val ssscp dummy
lab var ssscp "Partnership is same sex"

fre ssscp //0.22%
tab ssscp year, col


/*************************** PARTNERSHIP DURATION *****************************/
/*
There are no equivalent variables in EU-SILC for partnership duration 
prior to the entry into the panel.
Max duration is 4 years due to individual panel length
*/
preserve 

	keep idperson idpartner swv 
	replace idpartner = . if idpartner < 0

	xtset idperson swv 
	tsspell idpartner 
	rename _seq partnershipDuration 
	replace partnershipDuration = . if idpartner == .

	keep swv idperson partnershipDuration 

	save "$dir_data/temp_partnershipDuration", replace

restore

merge 1:1 swv idperson using "$dir_data/temp_partnershipDuration", keep(1 3) ///
	nogen 

gen dcpyy = partnershipDuration if idpartner > 0
lab var dcpyy "Years in partnership"

by swv: fre dcpyy

* Alternative - observed with partnered status for x consecutive years
sort idperson swv 
gen dcpyy_st = 1 if dcpst == 1 
replace dcpyy_st = dcpyy_st + dcpyy_st[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 & dcpyy_st != . & dcpyy_st[_n-1] != . 
	
lab var dcpyy_st "Observed with partnered status for x consecutive years"

replace dcpyy = -9 if dcpyy == . 
replace dcpyy_st = -9 if dcpyy_st == . 

* Correct underage partnerships 
replace dcpyy = -9 if dag < ${age_form_partnership}

tab dcpyy_st swv, col

tab dcpst dcpyy_st


/*********************** YEAR PRIOR TO ENDING RELATIONSHIP ********************/
/* 
Impossible to know for the most recent wave so set to 0 to keep the variable.
All observations populated, not just those in a relationship 
*/
sort idperson swv 

gen scpexpy = 0
replace scpexpy = 1 if f.dcpex == 1 
replace scpexpy = -9 if swv == 2024

lab val scpexpy dummy
lab var scpexpy "Year prior to exiting partnership"

* Correct underage partnerships 
replace scpexpy = 0 if dag < ${age_form_partnership}

fre scpexpy // 1%
tab scpexpy year, col 


/*************************** FEMALE FERTILE DUMMY *****************************/
gen sprfm = 0
replace sprfm = 1 if dgn == 0 & dag >= ${age_have_child_min} & ///
	dag <= ${age_have_child_max}

lab val sprfm dummy
lab var sprfm "Woman in fertility range dummy (18-49)"

fre sprfm 
tab sprfm year, col


/**************************** NUMBER OF CHILDREN ******************************/
/* 
Note idmother and idfather are not just reported if the bioloigcal parent but 
also the step parent etc. 
Doesn't account for the age of the mother, therefore permits teenage and old
mothers. 
*/

* Flag identifying children aged 0-17 
gen depChild = 1 if dag <= ${age_max_dep_child} & (idfather > 0 | idmother > 0)
gen depChild02 = 1 if depChild == 1 & inrange(dag,0,2)

* Mother
preserve 

	drop if idmother <= 0
	drop if depChild != 1 

	keep idmother depChild depChild02 swv 

	rename depChild has_child
	rename depChild02 has_child02
	rename idmother idperson 

	bysort swv idperson : egen dnc_m = sum(has_child)
	bysort swv idperson : egen dnc02_m = sum(has_child02)

	sort idperson swv
	drop if idperson == idperson[_n-1] & swv == swv[_n-1] 

	drop has_child*

	save "$dir_data/temp_depChild_mother", replace 

restore 

merge 1:m idperson swv using "$dir_data/temp_depChild_mother"
drop _merge

* Father 
preserve 

	drop if idfather <= 0
	drop if depChild != 1 

	keep idfather depChild depChild02 swv 

	rename depChild has_child
	rename depChild02 has_child02
	rename idfather idperson 

	bysort swv idperson : egen dnc_f = sum(has_child)
	bysort swv idperson : egen dnc02_f = sum(has_child02)

	sort idperson swv
	drop if idperson == idperson[_n-1] & swv == swv[_n-1] 

	drop has_child*

	save "$dir_data/temp_depChild_father", replace 

restore 


merge 1:m idperson swv using "$dir_data/temp_depChild_father"

drop if _merge == 2
drop _merge

gen dnc = 0 
gen dnc02 = 0 

replace dnc = dnc_m if dgn == 0 & dnc_m < . 
replace dnc02 = dnc02_m if dgn == 0 & dnc_m < . 

replace dnc = dnc_f if dgn == 1 & dnc_f < . 
replace dnc02 = dnc02_f if dgn == 1 & dnc_f < . 

lab var dnc "Number of own dependent children 0-${age_max_dep_child} in hh"
lab var dnc02 "Number of own dependent children aged 0-2 in hh"

drop dnc_* dnc02_*


fre dnc dnc02
tab dnc year, col
tab dnc02 year, col
bys year: sum dnc 
bys year: sum dnc02 

sum dag if dnc != 0 , de

tab dag year if dgn == 0 & dnc > 0 , col
tab dag year if dgn == 1 & dnc > 0 , col

/*
No age consistency imposed here 
*/
count if dag > 42 & dgn == 0 & dnc02 > 0 & dnc02 != . // 713 cases 
count if dag > 44 & dgn == 0 & dnc02 > 0 & dnc02 != . // 101 cases 


/*********************** NUMBER OF NEW BORN CHILDREN **************************/
gen child0 = 0
replace child0 = 1 if dag < 1 
bysort idmother swv: egen dchpd = total(child0) if idmother > 0

fre dchpd

preserve 

	keep swv idmother dchpd
	rename idmother idperson 
	rename dchpd mother_dchpd

	drop if idperson <= 0

	collapse (max) mother_dchpd, by(idperson swv)
	duplicates report idperson swv

	save "$dir_data/mother_dchpd", replace

restore 

merge 1:1 swv idperson using "$dir_data/mother_dchpd", keepusing (mother_dchpd)
keep if _merge == 1 | _merge == 3

replace mother_dchpd = 0 if dgn == 1
replace mother_dchpd = 0 if dgn == 0 & _merge == 1

drop _merge
drop dchpd

rename mother_dchpd dchpd

lab var dchpd "Women's number of new born children"

fre dchpd 
tab dchpd year, col

tab dchpd dnc02 if dgn == 0 

tab dag dchpd if dgn == 0 

tab dag if dgn == 0 & dchpd != 0 & dag >= 45

/*
        Age |      Freq.     Percent        Cum.
------------+-----------------------------------
         45 |         19       42.22       42.22
         46 |         10       22.22       64.44
         48 |          1        2.22       66.67
         49 |          3        6.67       73.33
         50 |          3        6.67       80.00
         51 |          1        2.22       82.22
         52 |          2        4.44       86.67
         54 |          1        2.22       88.89
         56 |          2        4.44       93.33
         59 |          1        2.22       95.56
         68 |          1        2.22       97.78
         72 |          1        2.22      100.00
------------+-----------------------------------
      Total |         45      100.00
*/

* Remove infeasible births (too old)
gen flag_old_mother = (dchpd == 1 & dag > ${age_have_child_max} & dgn == 0)

lab var flag_old_mother "FLAG: Have a new born child above the max fertile age"

replace dchpd = -9 if flag_old_mother == 1

* Address young mothers when construct BU

tab dag dchpd if dgn == 0, row


/***************************** GIVE BIRTH DUMMY *******************************/

* Give birth 
gen give_birth = (dchpd > 0 & dchpd < 10)

* Check consistency 
tab dag give_birth if dgn == 0, col
hist dag if give_birth == 1 &  dgn == 0

graph drop _all


/***************************** ADULT CHILD FLAG *******************************/
/*
Decision 24/10/25: Agreed that to be an adult child the following conditions 
have to hold: 
	- 16-45 years old
	- Not in a partnership 
	- Lives with at least one parent
	- Is at least 15 years younger than both of their parents
	- At least one parent in the hh is working age and not retired. 
*/

* Merge in parental age and activity status information 
preserve 

	keep if dgn == 0
	keep swv idhh idperson dag les_c4 dagpns
	
	rename idperson idmother
	rename dag dagmother
	rename les_c4 les_c4_mother
	rename dagpns dagpns_mother

save "$dir_data/temp_mother_info", replace

restore, preserve

	keep if dgn == 1
	keep swv idhh idperson dag les_c4 dagpns

	rename idperson idfather
	rename dag dagfather
	rename les_c4 les_c4_father
	rename dagpns dagpns_father

save "$dir_data/temp_father_info", replace 

restore

merge m:1 swv idhh idmother using "$dir_data/temp_mother_info"
keep if _merge == 1 | _merge == 3
drop _merge

merge m:1 swv idhh idfather using "$dir_data/temp_father_info"
keep if _merge == 1 | _merge == 3
drop _merge


gen adultchildflag = 0 

* Adult children live with at least one parent, are at least 18 years old and 
* do not have a partner 
replace adultchildflag = 1 if (!missing(dagmother) | !missing(dagfather)) ///
	& dag >= (${age_leave_parental_home} - 1) & idpartner <= 0	

* Not an adult child if both parents are retired and/or at statutory retirement
* age 
replace adultchildflag = 0 if dagpns_mother == 1 & dagpns_father == . 
replace adultchildflag = 0 if dagpns_mother == . & dagpns_father == 1 
replace adultchildflag = 0 if dagpns_mother == 1 & dagpns_father == 1 

replace adultchildflag = 0 if les_c4_mother == 4 & les_c4_father == . 
replace adultchildflag = 0 if les_c4_mother == . & les_c4_father == 4 
replace adultchildflag = 0 if les_c4_mother == 4 & les_c4_father == 4 

replace adultchildflag = 0 if les_c4_mother == 4 & dagpns_father == 1 
replace adultchildflag = 0 if les_c4_father == 4 & dagpns_mother == 1 

* Not an adult child if (both) parents are less than 15 years older than the 
* coresiding child
replace adultchildflag = 0 if dagfather - dag <= 15 & dagmother == . 
replace adultchildflag = 0 if dagfather == .  & dagmother - dag <= 15 
replace adultchildflag = 0 if dagfather - dag <= 15 & dagmother - dag <= 15 

* Age cap of 45
replace adultchildflag = 0 if dag > 45 

* Account for cases missing information
replace adultchildflag = -9 if idmother != -9 & ///
	(dagmother == . | les_c4_mother == .) & ///
	dag >= (${age_leave_parental_home} - 1)
	
replace adultchildflag = -9 if idfather != -9 & ///
	(dagfather == . | les_c4_father == .) & ///
	dag >= (${age_leave_parental_home} - 1)
	
* Check consistency 	
fre adultchildflag
tab adultchildflag year, col

tab adultchildflag dag if dag > 30 

tab dag if adultchildflag == 1 & swv > 2010


/************************ EXIT THE PARENTAL HOME ******************************/
/* 
Only populated if eligable for transition, = 1 means that the individual exits  
the parental home. 
Leaving the parental home corresponds with the defintion of adult child; 
an individual can leave the parental home they move out of the hh or if they 
become the "responsible adult".  
*/
sort idperson swv
xtset idperson swv

gen dlftphm = -9 
 
replace dlftphm = 0 if l.adultchildflag == 1  & adultchildflag != -9 & ///
	idperson == l.idperson & swv == l.swv + 1
	
replace dlftphm = 0 if dag == ${age_leave_parental_home} & adultchildflag == 1 
	
replace dlftphm = 1 if adultchildflag == 0 & l.adultchildflag == 1 & ///
	idperson == l.idperson  & swv == l.swv + 1

* Correct age for adult child flag 
replace adultchildflag = 0 if dag == ${age_leave_parental_home} - 1
	
lab val dlftphm dummy
lab var dlftphm ///
	"DEMOGRAPHIC: Exit the Parental Home, only populated if eligable"

* Check consistency 
bys swv: fre dlftphm 
tab dlftphm year, col

tab dlftphm adultchildflag 


/************************ HOUSEHOLD COMPOSITION *******************************/
/*
Note: For consistency with the simulation adult children and children above
age to become responsible should be assigned "no children" category, even if 
there are some children in the household 

Already corrected for being too young to be in a partnership through dcpst 
(on the underage side).
*/
* Without economic activity 
cap drop dhhtp_c4

gen dhhtp_c4 = -9
replace dhhtp_c4 = 1 if dcpst == 1 & dnc == 0 //Coupled, no children
replace dhhtp_c4 = 2 if dcpst == 1 & dnc > 0 //Coupled, children
replace dhhtp_c4 = 3 if dcpst == 2 & dnc == 0  // | adultchildflag == 1) 
	//Not partnered, no children 
replace dhhtp_c4 = 4 if dcpst == 2 & dnc > 0 & dhhtp_c4 != 3 
	//Not partnered, children

lab def dhhtp_c4_lb 1 "Couple with no dep children" ///
	2 "Couple with dep children" ///
	3 "Single with no dep children" ///
	4 "Single with dep children"
lab val dhhtp_c4 dhhtp_c4_lb
lab var dhhtp_c4 "Household composition"

fre dhhtp_c4 // 1.71% single parents
tab dhhtp_c4 year, col 

* With economic activity 
gen dhhtp_c8 = . 

replace dhhtp_c8 = 1 if dhhtp_c4 == 1 & lessp_c3 == 1
replace dhhtp_c8 = 2 if dhhtp_c4 == 1 & lessp_c3 == 2
replace dhhtp_c8 = 3 if dhhtp_c4 == 1 & lessp_c3 == 3	
replace dhhtp_c8 = 4 if dhhtp_c4 == 2 & lessp_c3 == 1
replace dhhtp_c8 = 5 if dhhtp_c4 == 2 & lessp_c3 == 2
replace dhhtp_c8 = 6 if dhhtp_c4 == 2 & lessp_c3 == 3	
replace dhhtp_c8 = 7 if dhhtp_c4 == 3
replace dhhtp_c8 = 8 if dhhtp_c4 == 4

lab def dhhtp_c8 	1 "Couple with no children, spouse employed" ///
					2 "Couple with no children, spouse student" ///
					3 "Couple with no children, spouse not employed" ///
					4 "Couple with children, spouse employed" ///
					5 "Couple with children, spouse student" ///
					6 "Couple with children, spouse not employed" ///
					7 "Single with no children" ///
					8 "Single with children" 
lab val dhhtp_c8 dhhtp_c8	

lab var dhhtp_c8 "Household composition with economic activity info"

* Check consistency
fre dhhtp_c8 // 1.71% single parents
tab dhhtp_c8 year, col 	
bys swv: sum dhhtp_c8 


/************************** OECD EQUIVALENCE SCALE ****************************/
* Temporary number of children 0-13 and 14-18 to create OECD hh equiv scale
gen depChild_013 = 1 if (dag >= 0 & dag <= 13) & (idmother > 0 | idfather > 0) 

gen depChild_1418 = 1 if (dag >= 14 & dag <= 18) & (idmother > 0 | idfather > 0) 

bys swv idhh: egen dnc013 = sum(depChild_013)
bys swv idhh: egen dnc1418 = sum(depChild_1418)
drop depChild_013 depChild_1418

gen moecd_eq = . //Modified OECD equivalence scale
replace moecd_eq = 1.5 if dhhtp_c4 == 1
replace moecd_eq = 0.3*dnc013 + 0.5*dnc1418 + 1.5 if dhhtp_c4 == 2
replace moecd_eq = 1 if dhhtp_c4 == 3
replace moecd_eq = 0.3*dnc013 + 0.5*dnc1418 + 1 if dhhtp_c4 == 4

drop dnc013 dnc1418


/****************************** REGION OF BIRTH *******************************/
/*
Only available in the panel data from 2021.
*/

gen reg_birth = -9

replace reg_birth = 1 if rb280 == "LOC"
replace reg_birth = 2 if rb280 == "EU"
replace reg_birth = 3 if rb280 == "OTH"

lab def reg_birth 1	"native" 2 "other EU" 3 "non-EU"
lab val reg_birth reg_birth	

label var reg_birth "Region of birth"
 

/******************** IN INITIAL EDUCATION SPELL AGE RANGE ********************/
gen sedag = 1 if dag >= ${age_leave_school} & ///
	dag <= ${age_force_leave_spell1_edu}
replace sedag = 0 if missing(sedag)

lab val sedag dummy
lab var sedag "Initial education spell age range"

* Check consistency
fre sedag 
tab sedag year, col 


/***************** WAS IN INITIAL EDUCATION SPELL SAMPLE **********************/
/* 
Consists of those observed in education in all preceding periods t-1,t-2,t-n, 
where n is the number of observations of a particular individual we have.
1 includes first instance of not being in education.
*/
sort idperson swv 
gen sedcsmpl = 0
replace sedcsmpl = 1 if (dag >= ${age_leave_school} & ///
	dag < ${age_force_leave_spell1_edu}) & l.ded == 1 

lab var sedcsmpl "SYSTEM: Continuous education sample"
lab def sedcsmpl  1 "Aged 16-29 and were in continuous education"	
lab val sedcsmpl sedcsmpl


/********************** RETURN TO EDUCATION SAMPLE ****************************/
/*
Consists of those who have left their initial education spell above the age of 
16 and not retired
*/
gen sedrsmpl = 0 
replace sedrsmpl = 1 if dag >= ${age_leave_school} & les_c4 != 4 & ded == 0 

lab var sedrsmpl "SYSTEM: Return to education sample"
lab def  sedrsmpl  1 "Aged 16+, not retired and not in initial education spell"
lab val sedrsmpl sedrsmpl


/******************* NOT IN INITIAL EDUCATION SPELL SAMPLE ********************/
/* 
Generated from sedcsmpl and ded variables. Sample: Respondents who were in 
initial education spell and left it. 
*/
//fre ded
gen scedsmpl = 0 
replace scedsmpl = 1 if sedcsmpl == 1 & ded == 0 

lab var scedsmpl "SYSTEM : Not in continuous education sample"
lab def scedsmpl  1 "Left continuous education"
lab val scedsmpl scedsmpl


/**************************** INCOME VARIABLES ********************************/
/*
A key difference here appears to be that income in EU-SILC is yearly, whereas 
USoc has monthly income. Further, net income is usually not recorded, so all 
figures are gross. Also the income information covers the previous calender year 
and therefore actually is more relevant for the previous year. 

Note that for wages there is an inconsistency. Details about the adjustment 
below. 

Generate individual income variables:
*/
/* 
UK version: egen ypnb = rowtotal(fimnlabgrs_dv fimnpen_dv fimnmisc_dv ///
	inc_stp inc_tu inc_ma); 
inc_stp, inc_tu and inc_ma generated at the beginning from income file

1 - fimnlabgrs_dv: 	total personal monthly labour income gross: employee 
						cash or near cash income (gross). 
						
DP: Note that in UKHLS the variable fimnlabgrs_dv  contains "labour income" 
(see here: https://www.understandingsociety.ac.uk/documentation/...
mainstage/variables/fihhmnlabgrs_dv/_) 
so my understanding is that self-employment income should also be included here. 
SILC also has a variable py020g – fringe benefits – currently not included here 
(neither included in the EUROMOD definition of original income)  

EU-SILC version: 

py010g py050g py020g
					
py010g :  	Employee cash or near cash income 
py050g :	Cash benefits or losses from self-employment 
py020g : 	Non-cash employee income [Omitted]

These variables correspond to a the previous calender year. 

2 - fimnpen_dv: 	Monthly amount of net pension income		

DP: The Usoc description says that this variable includes receipts reported in 
the income data file where w_ficode equals [2] pension from a previous employer,
or [3]  pension from a spouse's previous employer.  
This is assumed to be reported net of tax. So in the UK these are occupational 
pensions.  
I think it is correct to use py080g in SILC as an equivalent. 
EU-SILC version: 

py080g 
												
py080g: 	Pension from individual	private	plans	

3 - fimnmisc_dv: 	monthly amount of net miscellaneous income

DP: The Usoc description says this includes receipts reported in the income data 
file where w_ficode equals 
-  educational grant (not student loan or tuition fee loan), 
-  payments from a family member not living here, or 
-  any other regular payment (not asked in Wave 1). This is assumed to be 
	reported net of tax. 

During our last discussion it became clear that this variable was meaning to 
approximate EUROMOD market income, which does not include scholarships 
(they are considered as benefits) ==> 
==> they have to be removed from the market income in the UK as well.   

4 -  "inc_stp" "inc_tu" "inc_ma" are generated in the UK  do-file called 
"01_prepare_ukhls_pooled_data" 
gen inc_stp = frmnthimp_dv if ficode == 1 (NI Retirement/State Retirement 
(Old Age) Pension) ==> the decision was not to include state pensions  

gen inc_tu = frmnthimp_dv if ficode == 25 (Trade Union / 
Friendly Society Payment)

gen inc_ma = frmnthimp_dv if ficode == 26 (Maintenance or Alimony)

EU SILC variables: 

hy080g hy081g hy110g hy040g hy090g

hy080g: 	Regular interhousehold cash transfer received
hy081g: 	Alimony and maintenance payments 
hy110g: 	Income received by people aged under 16
hy040g: 	Income frm rental of a property or land 
hy090g: 	Intrst, div, prof frm cptl inv in uncorp bsn

DP: Household level variables so should  be split equally among all adults. 
Could be attributed to individuals by splitting it among all eligible children 
in relation to child income.  (in EUROMOD these types of incomes are split 
between the oldest couple in the household). 
*/


/************************************ CPI *************************************/
/* 
Harmonised index of consumer prices (HICP)
Annual data (annual average index) 2015=100
All-items HICP
Source dataset: Eurostat (prc_hicp_aind)	
Unit Index, base year = 100
Last data update: 13/5/26
Country: Spain
https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_aind/default/...
table?lang=en&category=prc.prc_hicp
*/
gen CPI = .

replace CPI = 83.33  	if stm == 2005
replace CPI = 86.29  	if stm == 2006
replace CPI = 88.75  	if stm == 2007
replace CPI = 92.41  	if stm == 2008
replace CPI = 92.19  	if stm == 2009
replace CPI = 94.08  	if stm == 2010
replace CPI = 96.94  	if stm == 2011
replace CPI = 99.31  	if stm == 2012
replace CPI = 100.83  	if stm == 2013
replace CPI = 100.63  	if stm == 2014
replace CPI = 100    	if stm == 2015
replace CPI = 99.66 	if stm == 2016
replace CPI = 101.69 	if stm == 2017
replace CPI = 103.46 	if stm == 2018
replace CPI = 104.26 	if stm == 2019
replace CPI = 103.91 	if stm == 2020
replace CPI = 107.04 	if stm == 2021
replace CPI = 115.95 	if stm == 2022
replace CPI = 119.89 	if stm == 2023
replace CPI = 123.33 	if stm == 2024

lab var CPI "HICP, all items, base 2015"


/****************************** REAL HOURLY WAGES *****************************/
/*
There are data issues here: 
	- Data is collected at the annual level 
	- The annual information corresponds to the previous calender year 
	- Income from self-employment can be negative 
	
Decided on the following: 

wage_hr 	= Annual employemnt income / Annual # hours worked 
			= Annual employemnt income / (# months worked * # hours worked ...
											a week * 4.33)										
	
Data year:	T-1		T 		T+1
Hrs:		T-1		T		T+1
Income:		T-2		T-1		T
# month: 	T-2		T-1		T

# Months worked last year can be constructed using the PL211* variables 

PY211A - Main activity January 

1	Employee working full-time	
2	Employee working part-time	
3	Self-employed working full-time (including family worker)	
4	Self-employed working part-time (including family worker)	
5	Unemployed	
6	Student, pupil	
7	Retired	
8	Unable to work due to long-standing health problems	
10	Fulfilling domestic tasks	
11	Other

=> Create a measure of hourly wages for year T using hour info from yr T 
and wage info and number of months worked info from T+1
*/

xtset idperson swv
sort idperson swv 

* Create monthly income for T-1 
* Annual gross real labour income in T-1
egen yplgrs_annual = rowtotal(py010g py050g)
	// missing = 0 

* Impose non-negativity 
gen flag_neg_labour_annual = (yplgrs_annual < 0)
lab var flag_neg_labour_annual "FLAG: negative labour income reported"

replace yplgrs_annual = 0 if yplgrs_annual < 0

* Turn into real gross annual labour income using lagged CPI to account for 
* timing (same as above)
gen CPI_5 = 83.33  	
gen CPI_6 = 86.29  	
gen CPI_7 = 88.75  	
gen CPI_8 = 92.41  	
gen CPI_9 = 92.19  	
gen CPI_10 = 94.08  	
gen CPI_11 = 96.94  	
gen CPI_12 = 99.31 
gen CPI_13 = 100.83  	
gen CPI_14 = 100.63  	
gen CPI_15 = 100    	
gen CPI_16 = 99.66 		
gen CPI_17 = 101.69	
gen CPI_18 = 103.46 	
gen CPI_19 = 104.26 
gen CPI_20 = 103.91 	
gen CPI_21 = 107.04 
gen CPI_22 = 115.95 	
gen CPI_23 = 119.89
gen CPI_24 = 123.33 

forvalues i = 6/24 {
	
	local j = `i' - 1
	
	replace yplgrs_annual = yplgrs_annual/(CPI_`j'/100) if swv == 2000 + `i'
	
}

gen flag_missing_lbr_income = (py010g == . & py050g == .)
lab var flag_missing_lbr_income ///
	"FLAG: missing info for both labour income variables"

* Months worked in year T-1
// do not account for ft or pt here
foreach month in a b c d e f g h i j k l {
	
	gen wrk_`month' = (inrange(pl211`month',1,4))
	
	replace wrk_`month' = . if pl211`month' == . 
	
}

egen months_wrk = rowtotal(wrk_a wrk_b wrk_c wrk_d wrk_e wrk_f wrk_g wrk_h ///
	wrk_i wrk_j wrk_k wrk_l) // treats missing as 0
	
egen months_wrk_missing = rowmiss(wrk_a wrk_b wrk_c wrk_d wrk_e wrk_f wrk_g ///
	wrk_h wrk_i wrk_j wrk_k wrk_l)	
	
tab months_wrk_missing 
	//almost all observations that report monthly info, have info for the whole 
	// yr - missing all or missing none 


tab months_wrk if months_wrk_missing == 0 & yplgrs_annual != 0 
/*
 38,442 say they worked no months last year and yet have labour income 
 mainly self-employed income so distribute across the year  
*/

sum months_wrk if months_wrk_missing == 0 & les_c3 == 1, de
tab months_wrk if les_c3 == 1, sort
// mean 11.24 months worked on average across workers
// mode 12 months among the working 

count if yplgrs_annual > 0 & months_wrk_missing != 0 // 69,401
/*
 => many missing values regarding months worked last year 
 => if missing some monthly working information assume not working in the 
	missing months
 => if missing all monthly information assume working the mode number of months
*/

* Monthly gross real labour income T-1	
gen yplgrs_mnth = yplgrs_annual / months_wrk if months_wrk_missing == 0 

* Missing values 
/*
If missing some months assume not working those months
*/
replace yplgrs_mnth = yplgrs_annual / months_wrk if ///
	inrange(months_wrk_missing,1,11)

/*
If missing all monthly information assume the mode number of work months 
*/
tab months_wrk if months_wrk_missing == 0 & les_c3 == 1
replace yplgrs_mnth = yplgrs_annual / 12 if months_wrk_missing == 12 
	// Update

/*
If have annual income and report working zero months assume the mode number of 
work months. Note this income is mainly from self-employed income 
*/
replace yplgrs_mnth = yplgrs_annual / 12 if months_wrk == 0 

* Check 
sum yplgrs_mnth, de

sort idperson swv 

* Hourly wage 
replace lhw = . if lhw == -9 

gen obs_earnings_hourly = .

replace obs_earnings_hourly = f.yplgrs_mnth/(lhw*4.33) if les_c4 == 1

lab var obs_earnings_hourly ///
	"Observed hourly real wages, emp and self-emp, adjusted for timing"

* Impose consistency  
replace obs_earnings_hourly = 0 if les_c3 == 2 | les_c3 == 3 

// at this point les_c3 == -9 and lhw == . align 

count if obs_earnings_hourly == .		// 123,485
count if obs_earnings_hourly == . & idperson != idperson[_n+1] 	// 113,974
count if obs_earnings_hourly == . & idperson == idperson[_n+1] & ///
	les_c3 == -9  // 4,653
count if obs_earnings_hourly == . & idperson == idperson[_n+1] & ///
	les_c3 == 1 & swv != swv[_n+1] - 1 		// 4,858
// accounted for all cases 	
	
count if obs_earnings_hourly == 0 & les_c3 == 1 	// 15,891
count if obs_earnings_hourly == 0 & les_c3 == 1 & idperson == idperson[_n+1]
	// 15,891
count if obs_earnings_hourly == 0 & les_c3 == 1 & yplgrs_annual[_n+1] == 0 & ///
	flag_missing_lbr_income[_n+1] == 1 & idperson == idperson[_n+1] // 10,170
count if obs_earnings_hourly == 0 & les_c3 == 1 & yplgrs_annual[_n+1] == 0 & ///
	flag_missing_lbr_income[_n+1] == 0 & idperson == idperson[_n+1]	// 5,721
// accounted for all cases 	
	
/*
Missing wage observations:
1- almost all due to being the last observation in individual's panel 
2- missing activity information 
3- missing adjacent observation 

Zero wage observations
4- next year is missing labour income information 
5- next year reports zero labour income 

How to address each case:
- up-rate previously reported wages 
- use last years earnings and this years hours
- use next years wages 

- use hot deck imputation

* Up-rate wages series
https://ec.europa.eu/eurostat/databrowser/view/NAMA_10_FTE__custom_21462492/default/table

*/ 
* Average gross annual labour income  
gen avg_wage_5 = 21505
gen avg_wage_6 = 22153
gen avg_wage_7 = 23176
gen avg_wage_8 = 24836
gen avg_wage_9 = 26169
gen avg_wage_10 = 26453
gen avg_wage_11 = 26589
gen avg_wage_12 = 26482
gen avg_wage_13 = 26705
gen avg_wage_14 = 26701
gen avg_wage_15 = 27175
gen avg_wage_16 = 27062
gen avg_wage_17 = 27146
gen avg_wage_18 = 27426
gen avg_wage_19 = 28176
gen avg_wage_20 = 27844
gen avg_wage_21 = 29383
gen avg_wage_22 = 30806
gen avg_wage_23 = 32216
gen avg_wage_24 = 33700

replace obs_earnings_hourly = . if obs_earnings_hourly == 0 & les_c3 == 1 

gen x = 1 if les_c3 == 1 & obs_earnings_hourly == . 

* Imputation 
forvalues i = 6/24 {
	
	local j = `i'-1
	
	gen nwage_growth_`j'`i' = avg_wage_`i'/avg_wage_`j'
	
	gen inflation_change_`j'`i' =  CPI_`i'/CPI_`j'
	
	gen growth_factor_`j'`i' = nwage_growth_`j'`i'/inflation_change_`j'`i'
	
	* Use last years wages
	replace obs_earnings_hourly = ///
		obs_earnings_hourly[_n-1] * growth_factor_`j'`i' ///
		if idperson == idperson[_n-1] & les_c3 == 1 & les_c3[_n-1] == 1 & ///
		swv == 2000 +`i' & obs_earnings_hourly == .	& swv == swv[_n-1] + 1
				
	* Use the next years wages 
	replace obs_earnings_hourly = ///
		obs_earnings_hourly[_n+1] / growth_factor_`j'`i' ///
		if idperson == idperson[_n+1] & les_c3 == 1 & les_c3[_n+1] == 1 & ///
		swv == 2000 +`i' & obs_earnings_hourly == .		
	
	* Use last years earnings and this years hours 
	replace obs_earnings_hourly = ///
		(yplgrs_mnth/(lhw*4.33)) * growth_factor_`j'`i' if ///
		 obs_earnings_hourly == . & swv == 2000 + `i' & yplgrs_mnth != 0 & ///
		 les_c4 == 1
		
}

gen flag_wage_imp_panel = (x == 1 & obs_earnings_hourly != . )

label var flag_wage_imp_panel ///
	"FLAG: wage imputed using surrounding panel information and uprating"
	
count if obs_earnings_hourly == .		// 32,477
count if obs_earnings_hourly == . & idperson != idperson[_n+1] 	// 20,980
count if obs_earnings_hourly == . & idperson == idperson[_n+1] & ///
	les_c3 == -9  // 4,653
count if obs_earnings_hourly == . & idperson == idperson[_n+1] & ///
	les_c3 == 1 & swv != swv[_n+1] - 1 		// 680
	
count if obs_earnings_hourly == . & les_c3 == 1 & yplgrs_annual[_n+1] == 0 & ///
	flag_missing_lbr_income[_n+1] == 1 & idperson == idperson[_n+1] // 4,648
count if obs_earnings_hourly == . & les_c3 == 1 & yplgrs_annual[_n+1] == 0 & ///
	flag_missing_lbr_income[_n+1] == 0 & idperson == idperson[_n+1]	// 1,651
	
count if obs_earnings_hourly == 0 & les_c3 == 1		// 0 
	
	
* Use hot deck imputation for the remaining missing observations among the 
* working

set seed 987

gen flag_wage_hotdeck = (les_c3 == 1 & missing(obs_earnings_hourly))

lab var flag_wage_hotdeck "FLAG: wage imputed using hotdeck imputation"

* Strata
cap drop ageband 
gen ageband = floor(dag/10)*10
replace ageband = 60 if ageband == 70  
	// group 70+ year olds with 60+ to ensure matches 

cap drop stratum 
egen stratum = group(ageband drgn1 dgn swv), label(stratum, replace)  

* Define donor pool
preserve

	keep if les_c3 == 1 & obs_earnings_hourly != . 
	keep obs_earnings_hourly stratum idperson swv 
	
	bys stratum (idperson swv): gen draw = _n
	bys stratum (idperson swv): gen n_donors  = _N
	
rename obs_earnings_hourly donor_wages
	drop idperson swv
	
	save "$dir_data/temp_wages_donors", replace

	keep stratum n_donors
	bys stratum: keep if _n == 1
	save "$dir_data/temp_donorsN", replace

restore

* Attached number of donors in each stratum
merge m:1 stratum using "$dir_data/temp_donorsN", nogen

* Assign random donor 
gen draw = . 

sort stratum idperson swv

by stratum (idperson swv): replace draw = ceil(runiform()*n_donors[1]) if ///
	flag_wage_hotdeck == 1 & n_donors > 0 

* Attach donor	
merge m:1 stratum draw using "$dir_data/temp_wages_donors", ///
	keepusing(donor_wages draw) 

drop if _merge == 2 
drop _merge
	
replace obs_earnings_hourly = donor_wages if flag_wage_hotdeck == 1 

drop donor_wages stratum draw n_donors

count if obs_earnings_hourly == . & les_c3 == 1   // 7


* Check for remaining issing observations among the working
count if obs_earnings_hourly == . & les_c3 == 1

if r(N) > 0 {
	
    di "Handling `r(N)' orphans by dropping Region from criteria..."
    
    cap drop stratum_v2
    egen stratum_v2 = group(swv ageband dgn), label(replace)

    preserve
        keep if les_c3 == 1 & obs_earnings_hourly != .
        keep obs_earnings_hourly stratum_v2
        bys stratum_v2: gen draw_v2 = _n
        bys stratum_v2: gen n_v2 = _N
        tempfile donors2
        save `donors2'
    restore

    * Merge the count of available donors in the broader pool
    * We use a separate merge to avoid the "not unique" error
    preserve
        use `donors2', clear
        bys stratum_v2: keep if _n == 1
        keep stratum_v2 n_v2
        tempfile counts2
        save `counts2'
    restore

    merge m:1 stratum_v2 using `counts2', keep(1 3) nogen
    
    * Randomly select which donor row to take
    gen draw_v2 = ceil(runiform() * n_v2) if obs_earnings_hourly == . & les_c3 == 1
    
    * Now merge the specific wage using BOTH stratum and the random draw number
    * This combination IS unique, so r(459) won't trigger
    merge m:1 stratum_v2 draw_v2 using `donors2', update replace keep(1 3) ///
	nogen keepusing(obs_earnings_hourly)

}

* Clean up
drop ageband stratum* n_v2 draw_v2

count if obs_earnings_hourly == . & les_c3 == 1   // 0

* Lagged wage 
xtset idperson swv 

gen l1_obs_earnings_hourly = .

replace l1_obs_earnings_hourly = l.obs_earnings_hourly 
lab var l1_obs_earnings_hourly ///
	"Observed hourly real wages, emp and self-emp, t-1, adjusted for timing"
	
sum obs_earnings_hourly if les_c3 == 1
sum obs_earnings_hourly if les_c3 == 2
sum obs_earnings_hourly if les_c3 == 3
sum obs_earnings_hourly if les_c3 == -9

drop yplgrs_annual yplgrs_mnth


/******************* RE-CATEGORISATION OF WORKING 0-5 HOURS *******************/

/*
Agreed that those working 0-5 hours inclusive will be considered as non-employed 
in line wiht the labour supply categorisation. 
This section updates the relevant variables, imposing consistency across the 
various related variables: 
	les_c3
	les_c4
	l1_les_c3
	l1_les_c4
	lessp_c3	
	lessp_c4
	lesdf_c4 
	dhhtp_c4
	lhw
	obs_earnings_hourly	
*/

* Activity status 
replace les_c3 = 3 if les_c3 == 1 & inrange(lhw,0,5)
replace les_c4 = 3 if les_c4 == 1 & inrange(lhw,0,5)

xtset idperson swv
sort idperson swv 


* Lagged activity status 
replace l1_les_c3 = 3 if l.les_c3 == 1 & l.lhw >= 0 & l.lhw <= 5 
replace l1_les_c4 = 3 if l.les_c4 == 1 & l.lhw >= 0 & l.lhw <= 5 


* Partner's activity status 
cap drop lessp_c3
cap drop lessp_c4

preserve

	keep swv idperson idhh les_c3
	rename les_c3 lessp_c3
	rename idperson idpartner
	
	save "$dir_data/temp_lesc3", replace

restore

merge m:1 swv idpartner idhh using "$dir_data/temp_lesc3"
keep if _merge == 1 | _merge == 3

lab var lessp_c3 "Partner's activity status"
drop _merge

* Impose partnership age restriction 
replace lessp_c3 = . if dag < ${age_form_partnership}

fre lessp_c3
tab lessp_c3 year, col 
tab dcpst lessp_c3


preserve

	keep swv idperson idhh les_c4
	rename les_c4 lessp_c4
	rename idperson idpartner
	
	save "$dir_data/temp_lesc4", replace

restore

merge m:1 swv idpartner idhh using "$dir_data/temp_lesc4"
keep if _merge == 1 | _merge == 3 

lab var lessp_c4 "LABOUR MARKET: Partner's activity status"
lab val lessp_c4 les_c4
drop _merge

* Impose partnership age restriction 
replace lessp_c4 = . if dag < ${age_form_partnership}


* Partnership activity summary variables 
cap drop lesdf_c4

gen lesdf_c4 = -9

* Both employed
replace lesdf_c4 = 1 if les_c3 == 1 & lessp_c3 == 1 & dcpst == 1 
	
* Employed, spouse not employed	
replace lesdf_c4 = 2 if les_c3 == 1 & (lessp_c3 == 2 | lessp_c3 == 3) & ///
	dcpst == 1 

* Not employed, and spouse employed	
replace lesdf_c4 = 3 if (les_c3 == 2 | les_c3 == 3) & lessp_c3 == 1 & ///
	dcpst == 1 

* Both not employed	
replace lesdf_c4 = 4 if (les_c3 == 2 | les_c3 == 3) & ///
	(lessp_c3 == 2 | lessp_c3 == 3) & dcpst == 1 

lab val lesdf_c4 lesdf_c4

lab var lesdf_c4 "LABOUR MARKET: Own and spouse activity status"

* Impose partnership age restriction 
replace lesdf_c4 = -9 if dag < ${age_form_partnership}


* With family composition with economic activity 
cap drop dhhtp_c8
gen dhhtp_c8 = . 

replace dhhtp_c8 = 1 if dhhtp_c4 == 1 & lessp_c3 == 1
replace dhhtp_c8 = 2 if dhhtp_c4 == 1 & lessp_c3 == 2
replace dhhtp_c8 = 3 if dhhtp_c4 == 1 & lessp_c3 == 3	
replace dhhtp_c8 = 4 if dhhtp_c4 == 2 & lessp_c3 == 1
replace dhhtp_c8 = 5 if dhhtp_c4 == 2 & lessp_c3 == 2
replace dhhtp_c8 = 6 if dhhtp_c4 == 2 & lessp_c3 == 3	
replace dhhtp_c8 = 7 if dhhtp_c4 == 3
replace dhhtp_c8 = 8 if dhhtp_c4 == 4

lab val dhhtp_c8 dhhtp_c8	

lab var dhhtp_c8 "Household composition with economic activity info"


* Hours of work 
replace lhw = 0 if inrange(lhw,0,5)

* Wages 
replace obs_earnings_hourly = 0 if lhw == 0 

xtset idperson swv
sort idperson swv 

replace l1_obs_earnings_hourly = 0 if l.lhw == 0 


* Consistency checks 
tab les_c3 les_c4
tab l1_les_c3 l1_les_c4 
tab les_c4 lesdf_c4
tab lessp_c4 dhhtp_c8

tab lhw if les_c3 == 1 & lhw < 20 
tab obs_earnings_hourly if lhw == 0 


/************** GROSS REAL MONTHLY PERSONAL EMPLOYMENT INCOME *****************/
/*
Use wage and hours worked info instead of reported amounts in py010g py050g
Use real wages therefore already in real terms. 
*/
/*
egen yplgrs = rowtotal(py010g py050g)
replace yplgrs =  yplgrs / 12

fre yplgrs if yplgrs < 0 // 0 obs

* Impose non-negativity
replace yplgrs = 0 if yplgrs < 0 

*/

gen yplgrs = obs_earnings_hourly * lhw * 4.33
assert yplgrs >= 0   

count if yplgrs == . 	// 8,461

* Checks 
assert yplgrs == 0 if les_c4 != 1 & les_c4 > 0  
assert obs_earnings_hourly == 0 if les_c4 != 1 & les_c4 > 0

sum obs_earnings_hourly if les_c3 == 2
count if obs_earnings_hourly == . & les_c3 == 2
count if lhw == . & les_c3 == 2

sum obs_earnings_hourly if les_c3 == 3
count if obs_earnings_hourly == . & les_c3 == 3
count if lhw == . & les_c3 == 3
// all missing for those who are working 

count if obs_earnings_hourly == . & les_c3 < 0 
count if lhw == . & les_c3 < 0 
// if missing some, missing all relevant info 


/**************** GROSS NOMINAL MONTHLY PERSONAL CAPITAL INCOME ***************/
/* 
UK version:  
gen ypncp = ///
	asinh((fimninvnet_dv+fimnmisc_dv+fimnprben_dv)*gross_net_ratio*(1/CPI)) 
	
1 - fimninvnet_dv: 	Investment income

2 -  fimnmisc_dv: 	Net miscellaneous income. Educational grant 
					(not student loan or tuition fee loan), payments from a 
					family member not living here, or any other regular payment 
					(not asked in Wave 1).
					
3 -  fimnprben_dv: 	Net private benefit income. Trade union/friendly society 
					payment, maintenance or alimony, or sickness and accident
					insurance.  

EU SILC version see above. 		
NOTE: The raw variables have no missing or negative values. 			

*/

* Household level variables are assigned to all adult hh members 
* ==> split them equally among all adults in hh
gen adult = (dag >= $age_adult) // 18 yo and over 
bysort stm idhh : egen n_adults = total(adult) 

lab var n_adults "Number of adults in hh" 

gen child = (dag < $age_adult) //below 18 yo 
bysort stm idhh : egen n_child = total(child) 

lab var n_child "Number of children in hh" 

* NOTE: No negative values or missing values 
foreach var in hy080g hy110g hy040g hy090g {
	
	gen `var'_pc = `var'/n_adults
	replace `var'_pc = 0 if child == 1
	
} 

egen ypncp_temp = rowtotal(hy080g_pc hy110g_pc hy040g_pc hy090g_pc)
	// treats missing zeros
gen ypncp = ypncp_temp / 12

* Check for missing values == if missing on all the components 
count if hy080g == . & hy110g == . &  hy040g == . &  hy090g == . // 20,447
count if hy080g == . | hy110g == . |  hy040g == . |  hy090g == . // 20,447
	// if missing, missing all 

	
/*********** GROSS NONMINAL MONTHLY PERSONAL PRIVATE PENSION INCOME ***********/
/*
UK version: 
fimnpen_dv:	 Monthly amount of net pension income	

EU SILC version 
py080g: 	Pension from individual private plans (gross) 

NOTE: The raw variable has many missing (.) values. 
*/

gen ypnoab = py080g / 12

* Code missing as zero 
recode ypnoab (. = 0) 

sum ypnoab
sum ypnoab if year == 2013
sum ypnoab if year == 2016
sum ypnoab if year == 2019
sum ypnoab if year == 2023

count if py080g == . & dag >= 16 	// 40,596

* Set to zero to be consistent with SimPathsEU
replace ypnoab = 0 


/*********** GROSS NOMINAL MONTHLY PERSONAL NON-BENEFIT INCOME ****************/
/*
Note: This is supposed to mirror UKMOD market income 

	=  employment income +  private pensions income +  capital income 
	
Use components instead of raw vars so that changes feed through 
*/
/*
egen ypnb_temp = rowtotal(py010g py050g py080g hy080g_pc hy110g_pc ///
	hy040g_pc hy090g_pc)
gen ypnb = ypnb_temp / 12

fre ypnb if ypnb < 0 
/* obs with negative income (due to negative self-employment income) but many of 
these are close to zero ==> recode them to zero */

* Impose non-negativity 
replace ypnb = 0 if  ypnb < 0 

sum ypnb 
assert ypnb >= 0 
*/

* Adjust gross eomployment income (yplgrs) so in nominal terms 
gen temp_yplgrs = yplgrs * (CPI/100)

egen ypnb = rowtotal(temp_yplgrs ypncp ypnoab)
	// treats missing as zero

sum ypnb if year == 2013
sum ypnb if year == 2016
sum ypnb if year == 2019
sum ypnb if year == 2023

* Check for missing values == if missing on all the components 
count if  py080g >= . & hy080g >= . & ///
	hy110g >= . & hy040g >= . & hy090g >= . 	// 20,447
	
count if (py080g >= . | hy080g >= . | ///
	hy110g >= . | hy040g >= . | hy090g >= .) & dag >= 16 	// 40,596
	
count if dag >= 16 
//=> 6% of adult observations have some missing income information 


/****** GROSS NOMINAL MONTHLY PERSONAL NON-EMPLOYMENT NON-BENEFIT INCOME ******/
/*
 = capital income + private pension income 
 
UK version:  egen yptc = rowtotal(fimnpen_dv fimnmisc_dv inc_stp inc_tu inc_ma)

EU SILC use the same variables as indicated above.  
*/

egen yptc = rowtotal(ypncp ypnoab)
	// treats missing as zero 


/************* SPOUSE GROSS PERSONAL MONTHLY NON-BENEFIT INCOME ***************/
preserve

	keep swv idperson idhh ypnb

	rename ypnb ypnbsp
	rename idperson idpartner
	
	save "$dir_data/temp_ypnb", replace

restore

merge m:1 swv idpartner idhh using "$dir_data/temp_ypnb"
keep if _merge == 1 | _merge == 3
drop _merge


/************* EQUIV HH/BEN UNIT GROSS MONTHLY NON-BENEFIT INCOME *************/
/* 
Couples = sum of partners incomes. Singles = own income 
*/ 
sum ypnb ypnbsp

egen yhhnb = rowtotal(ypnb ypnbsp) if dhhtp_c4 == 1 | dhhtp_c4 == 2 
	// treats missing as zero 
	
replace yhhnb = ypnb if dhhtp_c4 == 3 | dhhtp_c4 == 4 

* Equivalise 
replace yhhnb = (yhhnb/moecd_eq)

sum yhhnb
sum yhhnb if year == 2013
sum yhhnb if year == 2016
sum yhhnb if year == 2019
sum yhhnb if year == 2023


/****************** NOMINAL MONTHLY PERSONAL DISPOSABLE INCOME *****************/

* Create hh value of company car variable 
replace py021g = 0 if py021g == . 
bysort stm idhh : egen hh_comp_car = total(py021g) 

* Hh disp net company car 
gen ydisp_hh = hy020 - hh_comp_car

* Split hh level vars into individual amounts 
gen ydisp = ydisp_hh/n_adults
replace ydisp = 0 if child == 1

* Create monthly amount 
replace ydisp = ydisp / 12


/************************ REAL MONTHLY GROSS INCOMES **************************/
* Adjust for inflation:
* NOTE: yplgrs already in real terms as derived from real wages 
replace ypnb = ypnb/(CPI/100)
replace yptc = yptc/(CPI/100)
replace ypnbsp = ypnbsp/(CPI/100)
replace ypncp  = ypncp/(CPI/100)
replace ypnoab = ypnoab/(CPI/100)
replace yhhnb = yhhnb/(CPI/100)
replace ydisp = ydisp/(CPI/100)

lab var ypnb "Gross real monthly personal non-benefit income" 
lab var yptc "Gross real monthly personal non-employment, non-benefit income"
lab var yplgrs "Gross real monthly personal employment income"	
lab var ypnbsp "Spouse's gross real monthly personal non-benefit income"
lab var ypncp "Gross real monthly personal capital income"
lab var ypnoab "Gross real monthly personal private pension income"
lab var yhhnb "Equivalized gross real monthly non-benefit hh income"
lab var ydisp "Disposable real monthly personal income"

gen ypnoab_lvl = ypnoab


/*********** INVERSE HYPERBOLIC SINE REAL MONTHLY GROSS INCOMES ***************/
/* 
This (monotonic) transformation is useful for data that exhibit highly skewed 
distributions, as it can help stabilize variance and normalise the 
distribution.
*/
gen ypnbihs_dv = asinh(ypnb)
gen yptciihs_dv = asinh(yptc)
gen yplgrs_dv = asinh(yplgrs)
gen ypnbihs_dv_sp = asinh(ypnbsp)
replace ypncp = asinh(ypncp)
replace ypnoab = asinh(ypnoab)
gen yhhnb_asinh = asinh(yhhnb)

lab var ypnbihs_dv 	"Gross real monthly personal non-benefit income, asinh"
lab var yptciihs_dv ///
	"Gross real monthly personal non-employment, non-benefit income, asinh"
lab var yplgrs_dv 	"Gross real monthly personal employment income, asinh"	
lab var ypnbihs_dv_sp ///
	"Spouse's gross real monthly personal non-benefit income, asinh"
lab var ypncp "Gross real monthly personal capital income, asinh"
lab var ypnoab "Gross real monthly personal private pension income, asinh"
lab var yhhnb_asinh "Gross real monthly household non-benefit income, asinh"
	
/*
sum ypnbihs_dv ypnbihs_dv_sp yptciihs_dv yplgrs_dv ypncp ypnoab
*/ 

/************************ LOG CAPTIAL INCOME **********************************/

gen ln_ypncp = ln(sinh(ypncp))
 
lab var ln_ypncp "Gross real monthly personal non-employment capital income, ln"
 

/***** GROSS REAL MONTHLY EQUIV HOUSEHOLD NON-BENEFIT INCOME QUINTILES ********/
sum yhhnb_asinh

/*
cap drop ydses*
forvalues stm=2005/2020 {
	xtile ydses_c5_`stm' = yhhnb_asinh if depChild != 1 & stm==`stm', nq(5)
	bys idhh: egen ydses_c5_tmp_`stm' = max(ydses_c5_`stm') if stm==`stm'
	replace ydses_c5_`stm' = ydses_c5_tmp_`stm' if missing(ydses_c5_`stm')
	drop ydses_c5_tmp_`stm'
} 

egen ydses_c5 = rowtotal(ydses_c5_2005 ydses_c5_2006 ydses_c5_2007 ///
	ydses_c5_2008 ydses_c5_2009 ydses_c5_2010 ydses_c5_2011 ydses_c5_2012 ///
	ydses_c5_2013 ydses_c5_2014 ydses_c5_2015 ydses_c5_2016 ydses_c5_2017 ///
	ydses_c5_2018 ydses_c5_2019 ydses_c5_2020)
recode ydses_c5 (0=-9) 
drop ydses_c5_2*
bys stm: fre ydses_c5
*/

/*
Problem: if many observations in yhhnb_asinh have exactly the same value, 
xtile would group them into a single quintile, causing one or more quintiles to 
have very few observations. 
This results in 2nd quintile being extremely small compared to the first 
quintile, which probably has many similar values 
Adding a very small random amount to yhhnb_asinh can help differentiate tied 
values enough to distribute them more evenly across quintiles without distorting 
the data meaningfully.
*/

set seed 98

sort idperson swv 

gen yhhnb_asinh_jittered = yhhnb_asinh + runiform() * 1e-5

cap drop ydses*
forvalues stm = 2005/2024 {
	
	xtile ydses_c5_`stm' = yhhnb_asinh_jittered if depChild != 1 & ///
		stm == `stm', nq(5)
		
	bys idhh: egen ydses_c5_tmp_`stm' = max(ydses_c5_`stm') if stm == `stm'
	
	replace ydses_c5_`stm' = ydses_c5_tmp_`stm' if missing(ydses_c5_`stm')
	drop ydses_c5_tmp_`stm'
	
} 

egen ydses_c5 = rowtotal(ydses_c5_2005 ydses_c5_2006 ydses_c5_2007 ///
	ydses_c5_2008 ydses_c5_2009 ydses_c5_2010 ydses_c5_2011 ydses_c5_2012 ///
	ydses_c5_2013 ydses_c5_2014 ydses_c5_2015 ydses_c5_2016 ///
	ydses_c5_2017 ydses_c5_2018 ydses_c5_2019 ydses_c5_2020 ydses_c5_2021 ///
	ydses_c5_2022 ydses_c5_2023 ydses_c5_2024)

recode ydses_c5 (0 = -9) 
drop ydses_c5_2*
bys stm: fre ydses_c5

lab var ydses_c5 "Gross real monthly household non-benefit income quintiles"


/***** COUPLE DIFFERENCE IN GROSS REAL MONTHLY PERSONAL NON-BENEFIT INCOME ****/
gen ynbcpdf_dv = ypnbihs_dv - ypnbihs_dv_sp
recode ynbcpdf_dv (. = -999) if idpartner < 0
recode ynbcpdf_dv (. = -999) 
sum ynbcpdf_dv 

lab var ynbcpdf_dv 	///
"Difference between own and spouse's gross personal non-benefit income, asinh"


/****************************** GROSS NET RATIO  ******************************/
/* 
There are no net incomes in EU-SILC, will be computed using EUROMOD anyway.
*/  
gen gross_net_ratio = 1 


/***************************** HOME OWNERSHIP *********************************/
/* 
Dhh_owned is the definition used in the initial population and in the model 
predicting house ownership in the homeownership process of the simulation. 
Thi variable is updated in the benefit unit constrcution do file. 
*/
// bys swv: fre hh021
gen dhh_owned = 0 
replace dhh_owned = 1 if hh021 == 1 | hh021 == 2 

lab var dhh_owned "Home ownership dummy"

fre dhh_owned
tab dhh_owned year, col 


/**************************** DISABILITY BENEFIT ******************************/
/* 
In EU-SILC, the variables 
- py130n: 	(disability benefits net), 
- py130g: 	(disability benefits gross), 
- py131g: 	(contributory and means-tested), 
- py132g: 	(contributory and non means-tested), 
- py133g: 	(non-contributory and means-tested), 
- py134g: 	(non-contributory and non means-tested) 

All may contain information on disability benefits. 

For Poland, py131g only has zero entries

The code below may well be ES specific as some of the coding of these variables 
changes between countries. 
I expect that there is probably a better/more efficient way of constructing this 
code.
*/
recode py130n (0 = -9)(. = -9), gen(py130nr)
recode py130g (0 = -9)(. = -9), gen(py130gr)
recode py132g (0 = -9)(. = -9), gen(py132gr)
recode py133g (0 = -9)(. = -9), gen(py133gr)
recode py134g (0 = -9)(. = -9), gen(py134gr)

gen bdi = 0
replace bdi = 1 if py130nr >= 1 | py130gr >= 1 | py132gr >= 1 | ///
	py133gr >= 1 | py134gr >= 1 
lab val bdi dummy

lab var bdi "Disability benefits (dummy)"

drop py130nr py130gr py132gr py133gr py134gr

fre bdi
tab bdi year, col 


/*********************** EDUCATION STATUS - IMPUTATION 2 **********************/
/* 
AB: At the point missing education level for those that transition out of
education or have all missing observations. 
*/

gen orig_deh = deh_c3

* Investigate characterisitcs - are missing observations plausibly random?
gen missing_edu = (deh_c4 == -9)

recode dgn dag dagsq drgn1 les_c4 dcpst ydses_c5 (-9 = .), ///
	gen (dgn2 dag2 dagsq2 drgn12 les_c42 dcpst2 ydses_c52)
fre dgn2 dag2 dagsq2 drgn12

logit missing_edu i.dgn2 dag2 dagsq ib3.drgn12 i.swv i.les_c42 i.dcpst2 ///
	i.ydses_c52 if dag > 16 

predict p_miss
kdensity p_miss if missing_edu == 1, ///
	addplot(kdensity p_miss if missing_edu == 0)

/* Overlap is good => supports match, but shape is different suggesting that 
ppl missing education cluster at covaraiate combinations that produce higher
probability of missing than observations for which we observe education */

* Generte adjusted weight 
gen p_obs = 1 - p_miss

gen ipw = 1/p_obs if p_obs < . 

* Create addition controls 
gen les_c43 = les_c4 
replace les_c43 = 5 if les_c43 == -9 

sort idperson swv 
gen l_les_c43 = les_c43[_n-1] if idperson == idperson[_n-1]
replace l_les_c43 = 5 if idperson != idperson[_n-1]

gen exit_edu = 0 
replace exit_edu = 1 if idperson == idperson[_n-1] & les_c3[_n-1] == 2 & ///
	les_c3 != 2 & les_c3 != -9 

gen ydses_c53 = ydses_c5
replace ydses_c53 = 6 if ydses_c53 < 0 

* Generalized ordered probit - estimate on those that have left their initial 
* education spell 
gologit2 deh_c3 i.dgn dag2 dagsq ib3.drgn1 swv i.les_c43 i.exit_edu i.dcpst ///
	i.ydses_c53 if deh_c3 != -9 & dag >= 16 & ded == 0 ///
	[pweight = ipw]
	//, autofit 

predict p1 p2 p3

* Create CDF
gen p1p2 = p1 + p2 

sort idperson swv

* Add heterogenity
set seed 9753

gen rnd = runiform() 

* Create imputation
gen imp_deh_pred = cond((rnd < p1), 1, cond(rnd < p1p2, 2, 3))

* Inspection 

* Predicting high education  
twoway ///
    (kdensity p1 if deh_c3 == 1, lcolor(red)) ///
    (kdensity p1 if deh_c3 == 2, lcolor(blue)) ///
    (kdensity p1 if deh_c3 == 3, lcolor(green)) ///
    , title("Density of p1 by true category")

* Predicting medium education  
twoway ///
    (kdensity p2 if deh_c3 == 1, lcolor(red)) ///
    (kdensity p2 if deh_c3 == 2, lcolor(blue)) ///
    (kdensity p2 if deh_c3 == 3, lcolor(green)) ///
    , title("Density of p2 by true category")


* Predicting low education  
twoway ///
    (kdensity p3 if deh_c3 == 1, lcolor(red)) ///
    (kdensity p3 if deh_c3 == 2, lcolor(blue)) ///
    (kdensity p3 if deh_c3 == 3, lcolor(green)) ///
    , title("Density of p3 by true category")

graph drop _all 

foreach k in 1 2 3 {
	
    sum p`k' if deh_c3 == `k'

}

* Impute 
cap drop missing_edu 
gen missing_edu = (deh_c4 == -9)

* All missing
cap drop missing_count
bysort idperson (swv): egen missing_count = sum(missing_edu)
bysort idperson (swv): gen all_missing = 1 if missing_count[_N] == count[_N]

* Populate
gen imp_deh_all = deh_c3 if deh_c3 != -9 

* Impose monotonicity on those with all observations missing 

* Populate first observation with predicted value 
replace imp_deh_all = imp_deh_pred if imp_deh_all == . & count == 1 & ///
	all_missing == 1 

sort idperson swv 
	
forvalues i = 2/6 {

	* Carry forward educaiton if remain a student 
	replace imp_deh_all = imp_deh_all[_n-1] if imp_deh_all == . & ///
		count == `i' & non_student[_n-1] == 0 & non_student == 0 & ///
		all_missing == 1 & idperson == idperson[_n-1]
	
	* Carry forward education if remain a non_student 
	replace imp_deh_all = imp_deh_all[_n-1] if imp_deh_all == . & ///
		count == `i' & non_student[_n-1] == 1 & non_student == 1 & ///
		all_missing == 1 & idperson == idperson[_n-1]	
	
	* Carry forward education if become a student 
	replace imp_deh_all = imp_deh_all[_n-1] if imp_deh_all == . & ///
		count == `i' & non_student[_n-1] == 1 & non_student == 0 & ///
		all_missing == 1 & idperson == idperson[_n-1]	
	
	* Transition out of eduction - min rule 
	* Lagged 
	replace imp_deh_all = imp_deh_all[_n-1] if imp_deh_all == . & ///
		count == `i' & non_student[_n-1] == 0 & non_student == 1 & ///
		all_missing == 1 & imp_deh_all[_n-1] <= imp_deh_pred & ///
		idperson == idperson[_n-1]
		
	* Predcited	
	replace imp_deh_all = imp_deh_pred if imp_deh_all == . & ///
		count == `i' & non_student[_n-1] == 0 & non_student == 1 & ///
		all_missing == 1 & imp_deh_all[_n-1] > imp_deh_pred	& ///
		idperson == idperson[_n-1]
		
}		
				
* Those with some missing observations simply impose monotocity accounting 
* whilst imposing a cap on educaiton level using any future observed level

* Next highest observation variable to enforce consistency 
gsort idperson -count 

gen next_max_deh = imp_deh_all 
replace next_max_deh = next_max_deh[_n-1] if idperson == idperson[_n-1] & ///
	next_max_deh == . 

sort idperson count 

* If no more future observations set to zero 
replace next_max_deh = 0 if next_max_deh == . 


* First observation 

* Use predicted value if predicts lower edu level that in the future 
replace imp_deh_all = imp_deh_pred if imp_deh_all == . & count == 1 & ///
	next_max_deh <= imp_deh_pred 
	
* Use next observed max edu level if lower than predicted 	
replace imp_deh_all = next_max_deh if imp_deh_all == . & count == 1 & ///
	next_max_deh > imp_deh_pred & next_max_deh != . 
		
* Later observations 
forvalues i = 2/6 {	
	
	replace imp_deh_all = imp_deh_pred if imp_deh_all == . & count == `i' & ///
		next_max_deh <= imp_deh_pred & imp_deh_pred <= imp_deh_all[_n-1]
		
	replace imp_deh_all = imp_deh_all[_n-1] if imp_deh_all == . & ///
		count == `i' & next_max_deh <= imp_deh_all[_n-1] & ///
		imp_deh_all[_n-1] <= imp_deh_pred 
		
	replace imp_deh_all = imp_deh_all[_n-1] if imp_deh_all == . & ///
		count == `i' & imp_deh_pred <= next_max_deh & ///
		next_max_deh <= imp_deh_all[_n-1]  
		
	replace imp_deh_all = next_max_deh if imp_deh_all == . & count == `i' 
		
}

count if imp_deh_all == . 
count if imp_deh_all == -9 

count if idperson == idperson[_n-1] & imp_deh_all > imp_deh_all[_n-1]  

* All due observasions breaking the monotoncity rule are due to inconsistencies
* in the raw data 
gen flag_deh_imp_reg = (deh_c3 == -9 & imp_deh_all != .)

lab var flag_deh_imp_reg "FLAG: =1, if education imputed using gologit"

* Impute remaining missing values 
replace deh_c3 = imp_deh_all if deh_c3 == -9 
replace deh_c4 = imp_deh_all if deh_c4 == -9 

count if deh_c3 == -9 	// 0 
count if deh_c4 == -9 	// 0 


* Distributions
twoway ///
    (histogram orig_deh if orig_deh > 0, discrete percent color(blue%40) ///
		lcolor(blue) legend(label(1 "Observed"))) ///
    (histogram deh_c3, discrete percent color(green%40) lcolor(green) ///
        legend(label(2 "Final Distribution"))), ///
    legend(order(1 2)) ///
    title("Observed and Final Education Distributions") ///
    xlabel(1 "High" 2 "Medium" 3 "Low")

graph drop _all 	
	
	
* Tidy up 	
drop dgn2 dag2 dagsq2 drgn12 les_c42 dcpst2 ydses_c52 p1* p2 p3 rnd ///
	les_c43 l_les_c43 exit_edu ydses_c53 next_max_deh missing_count ///
	all_missing ipw p_miss p_obs missing_edu orig_deh imp_deh*


/******************** UPDATE PARTNER'S EDUCATION STATUS ***********************/
preserve

	keep swv idperson deh_c3 deh_c4 flag_deh_imp_mono flag_deh_imp_reg

	rename idperson idpartner
	rename deh_c3 dehsp_c3 
	rename deh_c4 dehsp_c4
	rename flag_deh_imp_mono flag_dehsp_imp_mono
	rename flag_deh_imp_reg flag_dehsp_imp_reg

	save "$dir_data/temp_dehsp", replace

restore

merge m:1 swv idpartner using "$dir_data/temp_dehsp"

lab var dehsp_c3 "Education status partner"
lab var dehsp_c4 "Education status partner"
	
keep if _merge == 1 | _merge == 3
drop _merge

fre dehsp_c3 if idpartner > 0 
tab dehsp_c3 year, col
bys swv: sum dehsp_c3 if dehsp_c3 > 0 

fre dehsp_c4 if idpartner > 0 
tab dehsp_c4 year, col
bys swv: sum dehsp_c4 if dehsp_c4 > 0 

* Impose partnership age restriction 
replace dehsp_c3 = . if dag < ${age_form_partnership}
replace dehsp_c4 = . if dag < ${age_form_partnership}


sort idperson swv 


/******************** EMPLOYMENT EXPERIENCE - IMPUTATION **********************/

* Inspect variable 
count if liwwh == -9
count if missing(liwwh)
count if liwwh == -9 & dag > 15

tab liwwh if dag < 16 
tab liwwh if dag < 20 
tab liwwh if dag < 25
tab liwwh if dag < 30


* Hot-deck imputation of employment experience (liwwh)
* Exact matching on age, sex, education and economic status

* Flag observations requiring imputation
gen byte temp_imp_liwwh = (liwwh == -9 & dag > 15)

tab temp_imp_liwwh

* Construct matching strata
egen long temp_stratum_liwwh = ///
    group(dag dgn deh_c3 les_c4 dnc), missing
	
* Unique observation ID for reproducible donor selection
sort idperson stm
gen long temp_obsid = _n

tempfile donors donor_counts


* Construct donor pool
preserve

    * Valid observed values of employment experience
    * Zero is a valid value
    keep if liwwh >= 0 & liwwh < .

    keep temp_obsid temp_stratum_liwwh liwwh

    * Number donors within each matching stratum
    sort temp_stratum_liwwh temp_obsid
    by temp_stratum_liwwh: gen long temp_draw = _n
    by temp_stratum_liwwh: gen long temp_n_donors = _N

    rename liwwh temp_donor_liwwh

    save `donors'

    * Create lookup containing number of donors in each stratum
    keep temp_stratum_liwwh temp_n_donors
    by temp_stratum_liwwh: keep if _n == 1

    save `donor_counts'

restore


* Merge number of available donors onto recipients
merge m:1 temp_stratum_liwwh using `donor_counts', nogen


* Randomly select one donor within each matching stratum
set seed 9876

sort temp_stratum_liwwh temp_obsid

gen long temp_draw = ceil(runiform() * temp_n_donors) if ///
    temp_imp_liwwh == 1 & temp_n_donors > 0


* Merge selected donor values
merge m:1 temp_stratum_liwwh temp_draw using `donors', ///
    keep(master match) nogen

* Checks
count if temp_imp_liwwh == 1
count if temp_imp_liwwh == 1 & !missing(temp_donor_liwwh)
count if temp_imp_liwwh == 1 & missing(temp_donor_liwwh)

tab liwwh if temp_imp_liwwh == 1

* Rename first-round imputation
rename temp_donor_liwwh temp_donor_liwwh1


* Second-round hot-deck imputation
* Relax matching by dropping number of children (dnc)
* Exact matching on age, sex, education and economic status

egen long temp_stratum_liwwh2 = ///
    group(dag dgn deh_c3 les_c4), missing

tempfile donors2 donor_counts2


* Construct donor pool
preserve

    * Valid observed values of employment experience
    * Zero is a valid value
    keep if liwwh >= 0 & liwwh < .

    keep temp_obsid temp_stratum_liwwh2 liwwh

    * Number donors within each matching stratum
    sort temp_stratum_liwwh2 temp_obsid
    by temp_stratum_liwwh2: gen long temp_draw2 = _n
    by temp_stratum_liwwh2: gen long temp_n_donors2 = _N

    rename liwwh temp_donor_liwwh2

    save `donors2'

    * Create lookup containing number of donors in each stratum
    keep temp_stratum_liwwh2 temp_n_donors2
    by temp_stratum_liwwh2: keep if _n == 1

    save `donor_counts2'

restore


* Merge number of available donors onto recipients
merge m:1 temp_stratum_liwwh2 using `donor_counts2', nogen


* Randomly select one donor within each matching stratum
set seed 9877

sort temp_stratum_liwwh2 temp_obsid

gen long temp_draw2 = ceil(runiform() * temp_n_donors2) if ///
    temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    temp_n_donors2 > 0


* Merge selected donor values
merge m:1 temp_stratum_liwwh2 temp_draw2 using `donors2', ///
    keep(master match) nogen


* Checks
count if temp_imp_liwwh == 1 & missing(temp_donor_liwwh1)
    // Entering second round

count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    !missing(temp_donor_liwwh2)
    // Successfully matched in second round

count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2)
    // Still unmatched after second round

	
* Third-round hot-deck imputation
* Relax exact age matching using narrow age groups
* Exact matching on age group, sex, education and economic status

* Construct narrow age groups
gen byte temp_agegroup_liwwh = .

replace temp_agegroup_liwwh = 1  if inrange(dag,16,19)
replace temp_agegroup_liwwh = 2  if inrange(dag,20,24)
replace temp_agegroup_liwwh = 3  if inrange(dag,25,29)
replace temp_agegroup_liwwh = 4  if inrange(dag,30,34)
replace temp_agegroup_liwwh = 5  if inrange(dag,35,39)
replace temp_agegroup_liwwh = 6  if inrange(dag,40,44)
replace temp_agegroup_liwwh = 7  if inrange(dag,45,49)
replace temp_agegroup_liwwh = 8  if inrange(dag,50,54)
replace temp_agegroup_liwwh = 9  if inrange(dag,55,59)
replace temp_agegroup_liwwh = 10 if inrange(dag,60,64)
replace temp_agegroup_liwwh = 11 if dag >= 65 & dag < .

* Construct matching strata
egen long temp_stratum_liwwh3 = ///
    group(temp_agegroup_liwwh dgn deh_c3 les_c4), missing

tempfile donors3 donor_counts3


* Construct donor pool
preserve

    * Only genuinely observed values are used as donors
    * Zero is a valid value
    keep if liwwh >= 0 & liwwh < .

    keep temp_obsid temp_stratum_liwwh3 liwwh

    * Number donors within each matching stratum
    sort temp_stratum_liwwh3 temp_obsid
    by temp_stratum_liwwh3: gen long temp_draw3 = _n
    by temp_stratum_liwwh3: gen long temp_n_donors3 = _N

    rename liwwh temp_donor_liwwh3

    save `donors3'

    * Create lookup containing number of donors in each stratum
    keep temp_stratum_liwwh3 temp_n_donors3
    by temp_stratum_liwwh3: keep if _n == 1

    save `donor_counts3'

restore


* Merge number of available donors onto recipients
merge m:1 temp_stratum_liwwh3 using `donor_counts3', nogen


* Randomly select one donor within each matching stratum
set seed 9878

sort temp_stratum_liwwh3 temp_obsid

gen long temp_draw3 = ceil(runiform() * temp_n_donors3) if ///
    temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    temp_n_donors3 > 0


* Merge selected donor values
merge m:1 temp_stratum_liwwh3 temp_draw3 using `donors3', ///
    keep(master match) nogen


* Checks
count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2)
    // Entering third round

count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    !missing(temp_donor_liwwh3)
    // Successfully matched in third round

count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3)
    // Still unmatched after third round
	
	
* Fourth-round hot-deck imputation
* Relax economic status for remaining unmatched observations (older students)
* Exact matching on age group, sex and education

* Construct matching strata
egen long temp_stratum_liwwh4 = ///
    group(temp_agegroup_liwwh dgn deh_c3), missing

tempfile donors4 donor_counts4


* Construct donor pool
preserve

    * Only genuinely observed values are used as donors
    * Zero is a valid value
    keep if liwwh >= 0 & liwwh < .

    keep temp_obsid temp_stratum_liwwh4 liwwh

    * Number donors within each matching stratum
    sort temp_stratum_liwwh4 temp_obsid
    by temp_stratum_liwwh4: gen long temp_draw4 = _n
    by temp_stratum_liwwh4: gen long temp_n_donors4 = _N

    rename liwwh temp_donor_liwwh4

    save `donors4'

    * Create lookup containing number of donors in each stratum
    keep temp_stratum_liwwh4 temp_n_donors4
    by temp_stratum_liwwh4: keep if _n == 1

    save `donor_counts4'

restore


* Merge number of available donors onto recipients
merge m:1 temp_stratum_liwwh4 using `donor_counts4', nogen


* Randomly select one donor within each matching stratum
set seed 9879

sort temp_stratum_liwwh4 temp_obsid

gen long temp_draw4 = ceil(runiform() * temp_n_donors4) if ///
    temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3) & ///
    temp_n_donors4 > 0


* Merge selected donor values
merge m:1 temp_stratum_liwwh4 temp_draw4 using `donors4', ///
    keep(master match) nogen


* Checks
count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3)
    // Entering fourth round

count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3) & ///
    !missing(temp_donor_liwwh4)
    // Successfully matched in fourth round

count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3) & ///
    missing(temp_donor_liwwh4)
    // Still unmatched after fourth round	
	

* Replace missing employment experience with hot-deck imputation
* Combine imputations across matching rounds
gen temp_liwwh_imp = temp_donor_liwwh1

replace temp_liwwh_imp = temp_donor_liwwh2 if ///
    temp_imp_liwwh == 1 & missing(temp_liwwh_imp)

replace temp_liwwh_imp = temp_donor_liwwh3 if ///
    temp_imp_liwwh == 1 & missing(temp_liwwh_imp)

replace temp_liwwh_imp = temp_donor_liwwh4 if ///
    temp_imp_liwwh == 1 & missing(temp_liwwh_imp)
	
* All observations requiring imputation should now have a donor
assert !missing(temp_liwwh_imp) if temp_imp_liwwh == 1

* Replace missing employment experience
replace liwwh = temp_liwwh_imp if temp_imp_liwwh == 1

* Label imputation flag
rename temp_imp_liwwh flag_imp_liwwh

label var flag_imp_liwwh ///
    "FLAG: Missing employment experience imputed using hot deck"

* Impose feasibility constraints on observed and imputed employment experience
* Individuals below minimum school-leaving age are assigned zero experience.
* For older individuals, experience cannot exceed the number of years since
* minimum school-leaving age.
replace liwwh = 0 if dag < ${age_leave_school}

replace liwwh = dag - ${age_leave_school} if ///
    liwwh > (dag - ${age_leave_school}) & ///
    liwwh < . & dag >= ${age_leave_school}
	
	
assert liwwh >= 0 if dag >= ${age_leave_school} & liwwh < .

assert liwwh <= dag - ${age_leave_school} if ///
    dag >= ${age_leave_school} & liwwh < .

assert liwwh == 0 if dag < ${age_leave_school}	
	
* Clean up 	
drop temp_stratum_liwwh temp_stratum_liwwh2 ///
    temp_stratum_liwwh3 temp_stratum_liwwh4 ///
    temp_agegroup_liwwh temp_obsid ///
    temp_draw temp_draw2 temp_draw3 temp_draw4 ///
    temp_n_donors temp_n_donors2 temp_n_donors3 temp_n_donors4 ///
    temp_donor_liwwh1 temp_donor_liwwh2 ///
    temp_donor_liwwh3 temp_donor_liwwh4 ///
    temp_liwwh_imp
	

/***************************** WEIGHTS ****************************************/
/*
Clare's notes: 
The EU-SILC panel contains a series of weights to ensure the sample is 
representative. 
The documentation (Eurostat, 2015) and Verma (2006) discuss how these weights 
are calculated. 
Unfortunately, for this cumulative longitudinal dataset created by GESIS, the 
original weights are no longer appropriate. 
However, GESIS discusses how to rescale two of the weights (RB060: individual 
base weight & RB064: individual longitudinal weight)

1. RB060, the so-called "modified base-weight". 
Each observation in the EU-SILC data set (R file) comes with this weight. 
In the first year of observation it equals the design weight, calibrated and 
modified to take non-responses into account. The base-weight of the years that 
follow is given by the previous year's base-weight adjusted for non-response 
rates.

2. RB064, the longitudinal weights.  
Created to be used with datasets made up of one rotational group covering four 
years (within a given release). 
They are built with the intent of making sure that this sub-sample is 
representative of the longitudinal population of the year in which the 
rotational group had been surveyed for the first time. 
RB064 is reported only during the last year of a rotational group covering four 
years. It is constant with respect to the year of observation, but varies across 
individuals. 
Since both weights are built based on single rotational groups, they can be used 
to calculate weights for a larger, cumulative sample. 

RB060 can be simply rescaled. The same goes for RB064, but in this case, one 
must restrict the merged sample to rotational groups that cover 4 years, which 
leads to loss of data. 
Also, RB064 makes sure that the sample is representative with respect to the 
longitudinal population of the year in which the rotational group was first 
surveyed. 
This means that the final result becomes something resembling a "moving sample", 
a set of sub-samples representative of different longitudinal populations. 
In practice, even though RB064 and RB060 take on very different values in some 
cases, on average, the difference is not much.

More information on the rescaling of rb060 and rb064 can be found in the GESIS 
documentation (Marwin Borst & Heike Wirth, EU-SILC Tools: eusilcpanel_2020 
First computational steps towards a cumulative sample based on the EU-SILC 
longitudinal datasets - update. GESIS Papers 2022|10)
*/

/*
DP: We decided to use Individual Cross-sectional Weight rescaled weight, RB060, 
for the initial populations. As can be seen below the popuatlion numbers closely
align with the totals of the resclaed RB060 but not with the rescaled RB062. 
For the regression estimates ==> either RB060 or RB062 or RB064 can be used, or 
no weights at all. 
*/

/* 
Weights available in the original cross-sectional EU-SILC data: 

- RB050: 	Personal cross-sectional weight (from individual roster)
			==> all current household members (of any age)
- DB090:    Household cross-sectional weight 
			==> the final estimation weights. Only the households that are 
			accepted into the database (DB135 = 1) have a cross-sectional 
			weight; the others are assigned a weight of 0. 
			
The calibration is done taking all rotational groups together. [...] (Eurostat 
(2023): Methodological Guidelines and Description of EU-SILC Target Variables. 
2022 operation (Version 7), p. 108).

Weights available in the original longitudinal EU-SILC data: 

- RB060:	 Personal base weight
- RB062:	 Longitudinal weight (two-year duration)
- RB063:	 Longitudinal weight (three-year duration)
- RB064:	 Longitudinal weight (four-year duration)
- DB095:	 Household longitudinal weight
*/ 

/*
Total population figures for Spain from 2011 to 2024 (EUROSTAT demo_gind avg):

Year	Total Population
2011	46,743,697
2012	46,773,055
2013	46,604,197
2014	46,460,733
2015	46,422,303
2016	46,458,139
2017	46,571,232
2018	46,782,011
2019	47,118,501
2020	47,359,424
2021	47,443,821
2022	47,786,102
2023	48,352,528
2024	48,873,996 

*/

* EUROMOD weight based on DB090, sums up to the population of ES, see below: 
/*	

*/

/* 
RB060 - Individual Cross-sectional Weight 

The RB060 weight is referred to as the "modified base-weight" in EU-SILC. It is 
designed to ensure that observations are representative of the sample for a 
specific year and country. 

1/ In the first year of observation, RB060 is equivalent to the design weight. 
This design weight is calibrated and adjusted for non-response rates.
2/ In the following years, RB060 is adjusted based on non-response rates in the 
subsequent waves of the survey. This ensures that the weight reflects the 
participation of individuals over time.
3/ Rescaling Process: When combining multiple waves or rotational groups 
(which cover multiple years), you need to rescale RB060 by multiplying it by a 
scaling factor (rscale) that accounts for the relative size of each rotational 
group compared to the total sample. This helps maintain proportionality across t
he cumulative dataset.

The steps for rescaling RB060:
1. Sort data by rotation group and year 
2. Calculate the sum of RB060 for each rotation group within each year
3. Calculate the total RB060 for each year 
4. Rescale the RB060 weights

This scaling ensures that each rotation group contributes appropriately to the 
overall sample, and helps prevent over-representation or under-representation of
specific groups.

DB075 - Rotation Group  
"This variable must be filled only for the countries using a rotational design.
Rotational design: Refers to any sample selection which is based on a fixed 
number of sub-samples, called replications, each one representative of the 
target population at the time of their selection. 
Each year, one sub-sample rotates out and a new one is drawn as a substitute. 
In the case of a rotational design based on four replications with a rotation of
one replication per year, one of the replications must be dropped immediately 
after the first year, the second must be retained for 2 years, the third for 3 
years, and the fourth for 4 years. 
From the second year onwards, at the start of each new year one replication must 
be introduced and retained for 4 years.
Rotation group: Each replication is called a rotational group and the 
information on the group to which the household belongs is especially useful for
controlling the implementation of the sample over time. 
Regarding the numbering of the rotation groups over time, it is recommended that 
each rotation group keeps the same number throughout the period of the survey." 
[...] (Eurostat (2023): Methodological Guidelines and Description of EU-SILC 
Target Variables. 2022 operation (Version 7), p. 105).
					
 bysort stm: tab db075

--------------------------------------------------------------------------------
-> stm = 2005

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     10,347       27.04       27.04
          2 |      9,217       24.08       51.12
          3 |      9,415       24.60       75.72
          4 |      9,291       24.28      100.00
------------+-----------------------------------
      Total |     38,270      100.00

--------------------------------------------------------------------------------
-> stm = 2006

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,677       24.58       24.58
          2 |     10,171       28.81       53.38
          3 |      8,314       23.55       76.93
          4 |      8,145       23.07      100.00
------------+-----------------------------------
      Total |     35,307      100.00

--------------------------------------------------------------------------------
-> stm = 2007

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,158       23.14       23.14
          2 |      8,822       25.03       48.17
          3 |     10,648       30.21       78.38
          4 |      7,622       21.62      100.00
------------+-----------------------------------
      Total |     35,250      100.00

--------------------------------------------------------------------------------
-> stm = 2008

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      7,934       21.67       21.67
          2 |      8,388       22.91       44.57
          3 |      9,722       26.55       71.12
          4 |     10,575       28.88      100.00
------------+-----------------------------------
      Total |     36,619      100.00

--------------------------------------------------------------------------------
-> stm = 2009

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     10,772       28.78       28.78
          2 |      7,941       21.21       49.99
          3 |      9,033       24.13       74.12
          4 |      9,687       25.88      100.00
------------+-----------------------------------
      Total |     37,433      100.00

--------------------------------------------------------------------------------
-> stm = 2010

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      9,801       26.02       26.02
          2 |     10,407       27.63       53.64
          3 |      8,518       22.61       76.26
          4 |      8,944       23.74      100.00
------------+-----------------------------------
      Total |     37,670      100.00

--------------------------------------------------------------------------------
-> stm = 2011

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,676       24.43       24.43
          2 |      8,898       25.06       49.49
          3 |      9,700       27.32       76.81
          4 |      8,234       23.19      100.00
------------+-----------------------------------
      Total |     35,508      100.00

--------------------------------------------------------------------------------
-> stm = 2012

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      7,860       22.95       22.95
          2 |      8,192       23.92       46.88
          3 |      8,374       24.46       71.34
          4 |      9,815       28.66      100.00
------------+-----------------------------------
      Total |     34,241      100.00

--------------------------------------------------------------------------------
-> stm = 2013

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      9,986       30.52       30.52
          2 |      7,253       22.17       52.69
          3 |      7,183       21.95       74.64
          4 |      8,298       25.36      100.00
------------+-----------------------------------
      Total |     32,720      100.00

--------------------------------------------------------------------------------
-> stm = 2014

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,332       25.93       25.93
          2 |      9,442       29.39       55.32
          3 |      6,582       20.48       75.80
          4 |      7,775       24.20      100.00
------------+-----------------------------------
      Total |     32,131      100.00

--------------------------------------------------------------------------------
-> stm = 2015

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      7,627       23.14       23.14
          2 |      8,362       25.37       48.50
          3 |      9,732       29.52       78.02
          4 |      7,245       21.98      100.00
------------+-----------------------------------
      Total |     32,966      100.00

--------------------------------------------------------------------------------
-> stm = 2016

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      7,076       21.54       21.54
          2 |      7,693       23.42       44.97
          3 |      8,701       26.49       71.46
          4 |      9,374       28.54      100.00
------------+-----------------------------------
      Total |     32,844      100.00

--------------------------------------------------------------------------------
-> stm = 2017

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,461       27.09       27.09
          2 |      7,014       22.46       49.55
          3 |      7,863       25.18       74.73
          4 |      7,892       25.27      100.00
------------+-----------------------------------
      Total |     31,230      100.00

--------------------------------------------------------------------------------
-> stm = 2018

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      6,974       23.15       23.15
          2 |      9,088       30.17       53.32
          3 |      7,106       23.59       76.91
          4 |      6,955       23.09      100.00
------------+-----------------------------------
      Total |     30,123      100.00

--------------------------------------------------------------------------------
-> stm = 2019

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      5,860       16.26       16.26
          2 |      7,173       19.91       36.17
          3 |     16,736       46.45       82.61
          4 |      6,265       17.39      100.00
------------+-----------------------------------
      Total |     36,034      100.00

--------------------------------------------------------------------------------
-> stm = 2020

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      4,597       13.01       13.01
          2 |      5,710       16.16       29.17
          3 |     12,089       34.21       63.38
          4 |     12,940       36.62      100.00
------------+-----------------------------------
      Total |     35,336      100.00

--------------------------------------------------------------------------------
-> stm = 2021

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     21,268       41.38       41.38
          2 |      5,519       10.74       52.12
          3 |     11,598       22.57       74.69
          4 |     13,006       25.31      100.00
------------+-----------------------------------
      Total |     51,391      100.00

--------------------------------------------------------------------------------
-> stm = 2022

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     18,101       30.55       30.55
          2 |     19,188       32.38       62.93
          3 |     10,342       17.45       80.39
          4 |     11,620       19.61      100.00
------------+-----------------------------------
      Total |     59,251      100.00

--------------------------------------------------------------------------------
-> stm = 2023

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     17,446       25.53       25.53
          2 |     17,544       25.67       51.20
          3 |     22,104       32.34       83.54
          4 |     11,251       16.46      100.00
------------+-----------------------------------
      Total |     68,345      100.00

--------------------------------------------------------------------------------
-> stm = 2024

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     16,519       31.38       31.38
          2 |     16,194       30.77       62.15
          3 |     19,924       37.85      100.00
------------+-----------------------------------
      Total |     52,637      100.00
	  
*/

* Distribution of RB060 before rescaling  
preserve 

	collapse (sum) rb060, by(stm)
	format rb060 %15.0f
	list stm rb060
	
restore 
/*		
     +------------------+
     |  stm       rb060 |
     |------------------|
  1. | 2004    95061233 |
  2. | 2005   168301048 |
  3. | 2006   169831600 |
  4. | 2007   172765225 |
  5. | 2008   175883343 |
     |------------------|
  6. | 2009   178536355 |
  7. | 2010   180696301 |
  8. | 2011   182883397 |
  9. | 2012   183948867 |
 10. | 2013   184406938 |
     |------------------|
 11. | 2014   184210772 |
 12. | 2015   184181121 |
 13. | 2016   183375467 |
 14. | 2017   183538393 |
 15. | 2018   183218915 |
     |------------------|
 16. | 2019   183776376 |
 17. | 2020   184972804 |
 18. | 2021   185331552 |
 19. | 2022   185874498 |
 20. | 2023   186330902 |
     |------------------|
 21. | 2024   140050147 |
     +------------------+

*/

* Rescaling RB060
order stm db075 rb060, last

sort stm db075 

bys stm db075 (idperson): egen total_group_rb060 = total(rb060)
bys stm (idperson): egen total_rb060 = total(rb060)

cap drop rscale
gen rscale = total_group_rb060/total_rb060

//replace rscale  = rscale/2 if stm == 2011 & db075 == 2 
/*
!!! bug in db075 in 2011 - as can be seen above, two rotational groups have the 
same id so need to adjust the rescaling factor 
*/

tab rscale 

bys stm db075: sum rscale 

gen dimxwt = rb060 * rscale 
lab var dimxwt ///
	"DEMOGRAPHIC : Individual Cross-sectional Weight based on rb060, rescaled"	

	
* Distribution after rescaling 
preserve 

	collapse (sum) dimxwt, by(stm)
	format dimxwt %15.0f
	list stm dimxwt

restore 

/*		
    +-----------------+
     |  stm     dimxwt |
     |-----------------|
  1. | 2004   38717584 |
  2. | 2005   42083477 |
  3. | 2006   42475744 |
  4. | 2007   43210996 |
  5. | 2008   43990323 |
     |-----------------|
  6. | 2009   44650333 |
  7. | 2010   45183010 |
  8. | 2011   45724430 |
  9. | 2012   45988793 |
 10. | 2013   46102483 |
     |-----------------|
 11. | 2014   46053507 |
 12. | 2015   46046121 |
 13. | 2016   45844824 |
 14. | 2017   45885009 |
 15. | 2018   45805980 |
     |-----------------|
 16. | 2019   45947179 |
 17. | 2020   46247289 |
 18. | 2021   46337437 |
 19. | 2022   46472938 |
 20. | 2023   46589159 |
     |-----------------|
 21. | 2024   46688063 |
     +-----------------+

*/

* Household Cross-sectional Weight	
/*
Cross-sectional household weight created by combining individual rescaled 
cross-sectional weights 
*/
gen one = 1 
bysort stm idhh (idperson): egen hhsize = total(one)

cap drop dhhwt
bysort stm idhh (idperson): egen dhhwt = total(dimxwt)
replace dhhwt = dhhwt/hhsize
lab var dhhwt "DEMOGRAPHIC : Household Cross-sectional Weight based on rb060"

* Distribution 
preserve 

	collapse (sum) dhhwt, by(stm)
	format dhhwt %15.0f
	list stm dhhwt

restore 
/*
     +-----------------+
     |  stm      dhhwt |
     |-----------------|
  1. | 2004   38717584 |
  2. | 2005   42083477 |
  3. | 2006   42475744 |
  4. | 2007   43210996 |
  5. | 2008   43990323 |
     |-----------------|
  6. | 2009   44650333 |
  7. | 2010   45183010 |
  8. | 2011   45724430 |
  9. | 2012   45988793 |
 10. | 2013   46102483 |
     |-----------------|
 11. | 2014   46053507 |
 12. | 2015   46046121 |
 13. | 2016   45844824 |
 14. | 2017   45885009 |
 15. | 2018   45805980 |
     |-----------------|
 16. | 2019   45947179 |
 17. | 2020   46247289 |
 18. | 2021   46337437 |
 19. | 2022   46472938 |
 20. | 2023   46589159 |
     |-----------------|
 21. | 2024   46688063 |
     +-----------------+
*/


* Individual Longitudinal Weight RB064
/*
The GESIS documentation paper suggests how to rescale RB064 
(four-year duration weight) : 
The same rescaling logic applies to RB064 with a minor tweak: RB064 is
reported only in the last year of panel covering four years. So, the first step 
is to copy RB064 to all years of all rotational groups that come with RB064. 
Second, analysts should drop all observations with RB064s missing to make sure 
that only rotational groups covering four years are in the sample.

Since we estimate models with one lag max I tried to use RB062 
(two-year duration weight) instead of RB064
*/
count if rb062 < . 

* Copy rb062 to all years of the rotational group
cap drop rb062_imputed
bys idperson db075 (stm idperson): gen rb062_imputed  = rb062[_N] if ///
	missing(rb062)
replace rb062_imputed = rb062 if !missing(rb062) & missing(rb062_imputed)

* Compute rescaling factor 
cap drop total_rb062_group total_rb062
bys stm db075 (idperson): egen total_rb062_group = total(rb062_imputed)
bys stm (idperson): egen total_rb062 = total(rb062_imputed)

cap drop rscale 
gen rscale = total_rb062_group / total_rb062
fre rscale 

* Rescale as in rb060
cap drop dimlwt
gen dimlwt = rb062_imputed *rscale  

lab var dimlwt "DEMOGRAPHIC : Individual Longitudinal Weight based on rb062"	

* Distribution after rescaling
preserve 

	collapse (sum) dimlwt, by(stm)
	format dimlwt %15.0f
	list stm dimlwt

restore 

/*	
    +-----------------+
     |  stm     dimlwt |
     |-----------------|
  1. | 2004   13522100 |
  2. | 2005   13170627 |
  3. | 2006   13452938 |
  4. | 2007   13961128 |
  5. | 2008   14501327 |
     |-----------------|
  6. | 2009   14821560 |
  7. | 2010   14837633 |
  8. | 2011   14506103 |
  9. | 2012   14629859 |
 10. | 2013   14517491 |
     |-----------------|
 11. | 2014   14758510 |
 12. | 2015   15855002 |
 13. | 2016   15556686 |
 14. | 2017   15654046 |
 15. | 2018   15656015 |
     |-----------------|
 16. | 2019   14222888 |
 17. | 2020   14371038 |
 18. | 2021   14851274 |
 19. | 2022   15211561 |
 20. | 2023   15889781 |
     |-----------------|
 21. | 2024   15721444 |
     +-----------------+


Using the rescaled longitudinal weight did not work => use the rescaled base 
weight
*/

* Cross-sectional Grossing Up Weight
gen dwt = dimxwt 
lab var dwt "DEMOGRAPHIC : Grossing-up Weight"


/*************************** CONSISTENCY CHECKS *******************************/
* Economic activity 
tab les_c3 les_c4 
tab dag if les_c3 == 2 
count if les_c3 == . 
count if les_c4 == . 

tab les_c3 ded
tab les_c4 ded

tab les_c3 der
tab les_c4 der

tab les_c3 non_student 
tab les_c4 non_student 

tab ded der 
tab ded non_student 

sum lhw if les_c3 == 1
sum lhw if les_c3 != 1
sum lhw if les_c4 == 1
sum lhw if les_c4 != 1
sum lhw if les_c4 == -9 

tab les_c3 dlltsd
tab les_c4 dlltsd

tab les_c3 dlrtrd
tab les_c4 dlrtrd

tab les_c3 sedex
tab les_c4 sedex

tab les_c3 unemp 
tab les_c4 unemp 

sum obs_earnings_hourly if les_c3 == 1 
sum obs_earnings_hourly if les_c3 != 1
sum obs_earnings_hourly if les_c3 == -9
sum obs_earnings_hourly if les_c4 == 1 
sum obs_earnings_hourly if les_c4 != 1

sum yplgrs_dv if les_c3 == 1 
sum yplgrs_dv if les_c3 != 1

* Partnership 
tab dun dcpst

gen temp_idp_pop = (idpartner > -9)

tab dun temp_idp_pop 
tab dcpst temp_idp_pop 

* Fertility 


* Education 
tab ded deh_c3
tab ded deh_c4 

tab deh_c3 deh_c4


/*************************** KEEP RELEVANT WAVES ******************************/
/* 
Initial populations: x-sections of longitudinal SILC for 2011-2023 
Estimation sample: longitudinal SILC with observations from 2010-2024 
 (income 2009-2022) 
*/
keep if swv >= 2010

save "$dir_data/02_pre_drop.dta", replace


/*********************** CREATE ASSUMPTION DESCRIPTIVES ***********************/

* Health imputation 
tab flag_dhe_imp if dag >= 16, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") replace
putexcel B1 = ("Count") C1 = ("Percent") D1 = ("Sample")
putexcel A2 = ("Health imputed using generalized ordered logit")
putexcel A3 = matrix(names) B3 = matrix(freq) C3 = matrix(percent) 
putexcel D3 = ("16+")

* Health imputation partner 
tab flag_dhesp_imp if dag >= 16 & idpartner > 0, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A5 = ("Partner's health imputed")
putexcel A6 = matrix(names) B6 = matrix(freq) C6 = matrix(percent) 
putexcel D6 = ("16+, has a partner")

* Report retiring too young  
tab flag_no_retire_young if dag >= 16 & dag < 50, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A8 = ("Report being retired too young")
putexcel A9 = matrix(names) B9 = matrix(freq) C9 = matrix(percent) 
putexcel D9 = ("16-49")

* Forced to remain retired 
tab flag_retire_absorb if dag >= 50, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A11 = ("Forced to remain retired")
putexcel A12 = matrix(names) B12 = matrix(freq) C12 = matrix(percent) 
putexcel D12 = ("50+")

* Force into retirement 
tab flag_retire_force if dag >= 75, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A15 = ("Forced into retirement")
putexcel A16 = matrix(names) B16 = matrix(freq) C16 = matrix(percent) 
putexcel D16 = ("75+")

*  Replaced > 0 hours of work with 0 as report not-employed
tab flag_impose_zero_hours_ne if dag >= 16 & dag < 75, matcell(freq) ///
	matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A18 = ("Replaced >0 hours of work with 0 as report not-employed")
putexcel A19 = matrix(names) B19 = matrix(freq) C19 = matrix(percent) 
putexcel D19 = ("16-75")

*  Replaced > 0 hours of work with 0 as report retired
tab flag_impose_zero_hours_retire if dag >= 16 & dag < 75, matcell(freq) ///
	matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A21 = ("Replaced >0 hours of work with 0 as report retired")
putexcel A22 = matrix(names) B22 = matrix(freq) C22 = matrix(percent) 
putexcel D22 = ("16-75")

*  Replaced > 0 hours of work with 0 as report student
tab flag_impose_zero_hours_student if dag >= 16 & dag < 75, matcell(freq) ///
	matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A24 = ("Replaced >0 hours of work with 0 as report student")
putexcel A25 = matrix(names) B25 = matrix(freq) C25 = matrix(percent) 
putexcel D25 = ("16-75")

* Replaced activity status as report 0 hours
tab flag_not_work_hours if dag >= 16 & dag < 75, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A27 = ("Replaced activity status as report 0 hours")
putexcel A28 = matrix(names) B28 = matrix(freq) C28 = matrix(percent) 
putexcel D28 = ("16-75")

* Replaced activity status from missing to working as report >0 hours
tab flag_missing_act_hours if dag >= 16 & dag < 75, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A30 = ///
	("Replaced activity status from missing to working as report >0 hours")
putexcel A31 = matrix(names) B31 = matrix(freq) C31 = matrix(percent) 
putexcel D31 = ("16-75")

* Replaced missing hours with >0 amount using adjacent cells as report working
tab flag_missing_hours_act_adj if dag >= 16 & dag < 75, matcell(freq) ///
	matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A33 = ///
("Replaced missing hours with >0 amount using adjacent cells as report working")
putexcel A34 = matrix(names) B34 = matrix(freq) C34 = matrix(percent) 
putexcel D34 = ("16-75")

* Replaced hours from missing to >0 amount using hot deck imputation
tab flag_missing_hours_act_imp if dag >= 16 & dag < 75, matcell(freq) ///
	matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A36 = ///
	("Replaced hours from missing to >0 amount using hot deck imputation")
putexcel A37 = matrix(names) B37 = matrix(freq) C37 = matrix(percent) 
putexcel D37 = ("16-75")

* Replaced disabled status with 0 due to retirement status
tab flag_disabled_to_retire if dag >= 50, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A39 = ("Replaced disabled status with 0 due to retirement status")
putexcel A40 = matrix(names) B40 = matrix(freq) C40 = matrix(percent) 
putexcel D40 = ("50+")

* Replaced unemployed with 0 due to retirement status enforcement
tab flag_unemp_to_retire if dag >= 50, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A42 = ///
	("Replaced unemployed with 0 due to retirement status enforcement")
putexcel A43 = matrix(names) B43 = matrix(freq) C43 = matrix(percent) 
putexcel D43 = ("50+")

* Old mother to new born 
tab flag_old_mother if dag >= 50 & dgn == 0, matcell(freq) ///
	matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A45 = ///
	("Reports being a new mother but above max fertile age")
putexcel A46 = matrix(names) B46 = matrix(freq) C46 = matrix(percent) 
putexcel D46 = ("Females, 50+")

* Education level imputed using regresssion model
tab flag_deh_imp_reg if dag >= 16 & ded == 0, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A48 = ("Education level imputed using generalized ordered logit predicted value")
putexcel A49 = matrix(names) B49 = matrix(freq) C49 = matrix(percent) 
putexcel D49 = ("16+, not in initial education spell")

* Education level imputed using deductive reasoning 
tab flag_deh_imp_mono if dag >= 16 & ded == 0, matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A51 = ("Education level imputed using deductive logic")
putexcel A52 = matrix(names) B52 = matrix(freq) C52 = matrix(percent) 
putexcel D52 = ("16+, not in initial education spell")

* Partner's education level imputed using regression model 
tab flag_dehsp_imp_reg if dag >= 16 & idpartner != . & idpartner != -9, ///
	matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A54 = ///
	("Partner's education level imputed using ordered probit predicted value")
putexcel A55 = matrix(names) B55 = matrix(freq) C55 = matrix(percent) 
putexcel D55 = ("16+, has a partner")

* Partner's education level imputed using deductive reasoning
tab flag_dehsp_imp_mono if dag >= 16 & idpartner != . & idpartner != -9, ///
	matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A57 = ///
	("Partner's education level imputed using ordered probit predicted value")
putexcel A58 = matrix(names) B58 = matrix(freq) C58 = matrix(percent) 
putexcel D58 = ("16+, has a partner")

* Wage imputed using adjacent observations in panel 
tab flag_wage_imp_panel if les_c3 == 1 , matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A60 = ("Wage imputed using adjacent cell in individual panel")
putexcel A61 = matrix(names) B61 = matrix(freq) C61 = matrix(percent) 
putexcel D61 = ("Employed")

* Wage imputed using hot deck imputation 
tab flag_wage_hotdeck if les_c3 == 1 , matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A63 = ("Wage imputed using hot deck imputation")
putexcel A64 = matrix(names) B64 = matrix(freq) C64 = matrix(percent) 
putexcel D64 = ("Employed")

* Age imputed using deductive logic
tab flag_deh_imp_mono , matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A66 = ("Age imputed using deductive logic")
putexcel A67 = matrix(names) B67 = matrix(freq) C67 = matrix(percent) 
putexcel D67 = ("All")

* Age imputed using regression model
tab flag_deh_imp_reg , matcell(freq) matrow(names)

scalar total = r(N)

matrix percent = (freq/total)*100

putexcel set "$dir_work/flag_descriptives", sheet("${country}") modify
putexcel A69 = ("Age imputed using regrssion model")
putexcel A70 = matrix(names) B70 = matrix(freq) C70 = matrix(percent) 
putexcel D70 = ("All")
*/

/*************************** KEEP REQUIRED VARIABLES **************************/
keep idhh idperson idpartner idfather idmother dct drgn1 dnc02 dnc dgn dgnsp ///
	dag dagsq dhe dhesp dcpst ded deh_c3 deh_c4 der dehsp_c3 dehm_c4 dehf_c4 ///
	dehmf_c4 dcpen dcpyy dcpex dcpagdf dlltsd dlrtrd drtren dlftphm ///
	dhhtp_c4 dimlwt dimxwt dhhwt dwt les_c3 les_c4 lessp_c3 lessp_c4 ///
	lesdf_c4 ydses_c5 ypnbihs_dv yptciihs_dv yplgrs_dv ynbcpdf_dv ypncp ///
	ln_ypncp ypnoab swv sedex ssscp sprfm sedag stm dagsp lhw der ///
	adultchildflag sedcsmpl sedrsmpl scedsmpl dhh_owned dchpd dagpns ///
	dagpns_sp CPI dlltsd_sp ypnoab_lvl ydisp flag_* Int_Date unemp yplgrs ///
	liwwh dagpns_y dagpns_y1 dagpns_y_sp dagpns_y1_sp obs_earnings_hourly ///
	l1_obs_earnings_hourly l1_les_c3 l1_les_c4 new_rel dcpyy_st studentflag ///
	dcpyy_st dhhtp_c8 dehsp_c4 widow rb110 flag_deceased flag_deceased_sp ///
	reg_birth

sort swv idhh idperson 


/************************* RECODE MISSING VALUES ******************************/
foreach var in idhh idperson idpartner idfather idmother dct drgn1 dnc02 ///
	dnc dgn dgnsp dag dagsq dhe dhesp dcpst ded deh_c3 deh_c4 der dehsp_c3 ///
	dehm_c4 dehf_c4 dehmf_c4 dcpen dcpyy dcpex dlltsd dlrtrd drtren ///
	dlftphm dhhtp_c4 les_c3 les_c4 lessp_c3 lessp_c4 lesdf_c4 ydses_c5 ///
	swv sedex ssscp sprfm sedag stm dagsp lhw der dhh_owned ///
	dchpd dagpns dagpns_sp CPI dlltsd_sp flag* unemp liwwh ///
	dagpns_y dagpns_y1 dagpns_y_sp dagpns_y1_sp obs_earnings_hourly ///
	l1_obs_earnings_hourly l1_les_c3 l1_les_c4 new_rel dcpyy_st new_rel ///
	dcpyy_st dhhtp_c8 studentflag dehsp_c4 widow flag_deceased ///
	flag_deceased_sp reg_birth {
	
		qui recode `var' (-9/-1 = -9) (. = -9) 

}

* Recode missings in weights to zero 
foreach var in dimlwt dimxwt dhhwt dwt {
	
	qui recode `var' (. = 0) (-9/-1 = 0) 
	sum `var' if `var' < 0 
	
} 
	
* Initialise wealth to missing 
gen liquid_wealth = -9
gen smp = -9
gen rnk = -9
gen mtc = -9

* Check for duplicates in the pooled dataset 
duplicates tag idperson idhh swv, gen(dup)
fre dup
drop if dup == 1 // 0 duplicates 
drop dup
isid idperson idhh swv	


/*********************************** SAVE *************************************/
save "$dir_data/${country}-SILC_pooled_all_obs_02.dta", replace 

* Check create same dataset each time 
* Only differences should come from stochastic imputation variables 
sort idperson swv 

// cf _all using "$dir_data/${country}-SILC_pooled_all_obs_02.dta"


/***************************** CLEAN UP AND EXIT ******************************/
#delimit ;
local files_to_drop 
	temp_age.dta
	temp_dagpns.dta
	temp_dgn.dta
	temp_dhe.dta
	temp_dlltsd.dta
	temp_lesc3.dta
	temp_lesc4.dta
	temp_ypnb.dta
	temp_partnershipDuration.dta
	mother_dchpd.dta
	temp_dehsp.dta
	temp_dagpns_y.dta
	temp_depChild_mother.dta
	temp_depChild_father.dta
	temp_mother_info.dta
	temp_father_info.dta
	temp_donorsN.dta
	temp_lhw_donors.dta
	temp_wages_donors.dta
	temp_rel_end.dta
	;
#delimit cr 

foreach file of local files_to_drop { 
	
	erase "$dir_data/`file'"

}

cap log close 

/*
	temp_orig_econ_status_${country}.dta
	temp_orig_edu_${country}.dta
	temp_orig_occu_${country}.dta
*/
