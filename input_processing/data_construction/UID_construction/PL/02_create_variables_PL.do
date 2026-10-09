/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         02_create_variables.do
* DESCRIPTION:          Creates individual and hh variables from lonigtudinal 
* 						SILC.  
* COUNTRY:              PL
* DATA:         	    EU-SILC panel dataset  
* AUTHORS: 				Claire Fenwick, Daria Popova, Ashley Burdett, 
* 						Aleksandra Kolndrekaj
* LAST UPDATE:          7 October 2026
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
//log using "${dir_log}/02_create_variables.log", replace


* Set seed 
set seed 98765

* Obtain values of variables that change between 2020 and 2024 from the earlier 
* panel 
do "$dir_do/vars_05_20/01_prepare_pooled_data_05_20_${country}.do"

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
Duplicates	in terms of swv	idperson

--------------------------------------
   Copies | Observations       Surplus
----------+---------------------------
		1 |       752845             0
		2 |         2580          1290
--------------------------------------

The unique identifier of observations is idperson idhh and year not just 
idperson year. Therefore need a standard rule to rule out people residing in two 
household in a single year, generating two observations for the individual for 
that year. 		
The duplicates command in Stata preserves the first occurence of each duplicate, 
so sorting uniquely before runing the duplicates command should ensure the same 
dataset is generated everytime the do file is run. 
*/	

sort upid year uhid // AB: added to ensure drop the same duplicates each time 

duplicates drop swv idperson, force // (1,290 observations deleted)

isid idperson swv

xtset idperson swv 

sort upid year 


/***************************** DECEASED FLAG **********************************/
gen flag_deceased = 0 
replace flag_deceased = 1 if rb110 == 6 

lab var flag_deceased "FLAG: Individual died in the previous year"


/********************************* GENDER *************************************/
gen dgn = rb090
recode dgn 2 = 0 	// dgn = 0 is female, 1 is male

lab var dgn "Gender" 
lab define dgn 1 "male" 0 "female"
lab val dgn dgn

sort idperson swv

* Impute as time invariant characteristic 
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
(a variable made by GESIS that identifies the rotational group and dropout year 
an individual belongs to) and the original unique personal identifier (rb030) it 
is possible to update rb240 to be consistent with GESIS's new unique personal 
identifier. Thus, I combine urtgrp and rb240 to ensure idpartner aligns with 
upid and do the same for idfather and idmother. 

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
year for PL. 

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
Overwhelming majority of big jumps are due to a sudden change in birth year to 
be <= 1942
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

replace dag = dag_new 

drop dag_new age_dif 
	
tab dag 
fre dag 
bys swv: sum dag 
	

* Impute age of those whose age is top-coded at 78
	
* For those that turn 78 in the panel let their age naturally evolve
sort idperson swv 
gen turn_78 = (idperson == idperson[_n-1] & dag[_n-1] == 77 & dag == 78)	
	
replace turn_78 = 1 if idperson == idperson[_n-1] & turn_78[_n-1] == 1

replace dag = dag[_n-1] + 1 if turn_78 == 1 
	
	
* For the remaining top-coded cases
/*
We will impute the ages by randomly drawing from a log normal charactersized by 
parameters obtained from SHARE data. 

Mean and standard deviation of log age of males and females aged 78+. 
			0. male		1. female		
	Mean	4.4			4.4
	SD		0.043		0.037
	 
*/	
	
* Flag remaining top-coded observations 
gen topcoded78 = 1 if dag == 78 & turn_78 == 0 

* Define gender specific log-normal distribution parameters
gen meanlog = .
gen sdlog   = .

replace meanlog = 4.4 if dgn == 1 & topcoded78 == 1
replace sdlog = 0.044 if dgn == 1 & topcoded78 == 1

replace meanlog = 4.4 if dgn == 0 & topcoded78 == 1
replace sdlog = 0.037 if dgn == 0 & topcoded78 == 1

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
ISSUE: The number of NUTS1 regions changes in Poland. 
	2005 - 2014: 6 NUTS1 regions 
	(5 - Polnocno-Zachodni, 6 - Polnocny, 1- Centralny, 3 - Wschodni, 
	2 - Poludniowy, 4 - Poludniowo-Zachodni)
	
	2015 - 2018: 9 NUTS 1 regions (unofficial)
	
	2018 - 2020: 7 NUTS1 regions 
	(4 - Polnocno-Zachodni, 6 - Polnocny, 7 - Centralny,  8 - Wschodni, 
	2 - Poludniowy, 5 - Poludniowo-Zachodni, 
	9 - Wojewodztwo Mazowieckie - parts of centralny and wschodni became 
	Wojewodztwo Mazowieckie)
	
https://stat.gov.pl/en/regional-statistics/classification-of-territorial-...
units/classification-of-territorial-units-for-statistics-nuts/...
the-nuts-classification-in-poland/

To address this, we agreed to merge the 3 regions that changed form in 2018 into 
one constant aggregate region to permit the inclusion of the remaining 
hetereogenity in the data. 	
*/

clonevar drgn1 = db040 
destring drgn1, replace ignore($country)

replace drgn1 = 10 if drgn1 == 1 | drgn1 == 3 | drgn1 == 7 | drgn1 == 8 | ///
	drgn1 == 9  
lab var drgn1 "Region"
lab define drgn1 ///
	2 "Poludniowy" ///
	4 "Polnocno-Zachodni" ///
	5 "Poludniowo-Zachodni" ///
	6 "Polnocy" ///
	10 "Central + East"
	
lab values drgn1 drgn1

recode drgn1 (. = -9)

fre drgn1
tab drgn1 year, col
bys swv: sum drgn1 if drgn1 > 0 


/******************************** COUNTRY *************************************/
gen dct = .
lab var dct "Country code: $country"


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
count if idpartner == . 	// no missing values 

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
			
29. Poland	-4.496     	 	4.496			4.944			4.944

NOTE: Could adjust parameters to be the age gap for those 70 to empirically 
account for Cases A and B below. 
*/

* Define spouse gap parameters as variables (gap = husband age - wife age)
gen mean_gap = 4.496
gen sd_gap   = 4.944

* Adjust imputed own age accounting for empirical distribution of age gap 
gen dag_sim_orig = dag_sim 

gen dag_sim2 = . 

bysort idperson (turn_78sp): gen turn_78sp_panel = (turn_78sp[_N] == 1)

sort idperson swv 


* Case A: Female top-coded in all observations, Male is NOT

/*
Female is known to be older. Assume the age-gap distribution is symmetric and 
apply the SHARE age-gap distribution in the opposite direction.

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

* Impose lower bound 
replace dag_sim2 = 78 if topcoded78 == 1 & topcoded78sp == 1 & dgn == 0 & ///
	dun == 1 & dagsp != . & dag_sim2 < 78 	

* Impose longitudinal consistency 	
replace dag_sim2 = dag_sim2[_n-1] + 1 if idperson == idperson[_n-1] & ///
	idpartner == idpartner[_n-1] & dag_sim2[_n-1] != . & /// 
	topcoded78 == 1 & topcoded78sp == 1 & dgn == 0 &  dun == 1 

* Impose longitudinal consistency if partnership breaks up 
gen break_up = 1 if idperson == idperson[_n-1] & ///
	idpartner != idpartner[_n-1] & dag_sim2[_n-1] != . & /// 
	topcoded78[_n-1] == 1 & topcoded78sp[_n-1] == 1 & dgn == 0 & ///
	dun[_n-1] == 1 & dun == 0 
	
replace break_up = 1 if break_up[_n-1] == 1 & idperson == idperson[_n-1]

replace dag_sim2 = dag_sim2[_n-1] + 1 if idperson == idperson[_n-1] & ///
	break_up == 1	
	
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


* Consistency checks 
tab dag 
tab dagsp 

hist dag, discrete 
hist dagsp, discrete

hist dag if dgn == 0, discrete 
hist dagsp if dgn == 1, discrete 

count if dag == . 	// 13 observations

graph drop _all 


* Age squared 
gen dagsq = dag^2

lab var dagsq "Age squared"
				
drop dag_sim dag_sim2 dag_sim_orig dagsp2 mean_gap sd_gap break_up			

sum dagsq
count if dun == 1 & dagsp == .


/************************** PARTNERSHIP STATUS ********************************/
/* 
Construct a variable that only indicates whether the individual is single or 
partnered, we don't differenciate between those that have previously been in a 
partnership and those that have never. 

For consistency utilize idpartner variable. 
*/
gen dcpst = -9 
replace dcpst = 1 if idpartner > 0 
replace dcpst = 2 if idpartner < 0 
	
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

count if dcpst == . 
tab dcpst 

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
/* Use ph010 (general health) variable: 
-----------------------------------------------------------------
					|      Freq.    Percent      Valid       Cum.
--------------------+--------------------------------------------
Valid   1 Very good |      80935      10.73      14.54      14.54
		2 Good      |     225104      29.85      40.43      54.96
		3 Fair      |     164207      21.77      29.49      84.46
		4 Bad       |      71059       9.42      12.76      97.22
		5 Very bad  |      15491       2.05       2.78     100.00
		Total       |     556796      73.83     100.00           
Missing .           |     197339      26.17                      
Total               |     754135     100.00                      
-----------------------------------------------------------------

Have many missing values so (stochastically) impute using an generalized ordered 
logit model.
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

* Impute missing values
fre dag if missing(dhe) 

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

* Comparison plots
* Observed vs predicted of those with observations
twoway ///
	(hist dhe if dag >= 16, color(blue%40) lcolor(blue%80)) ///
	(hist imp_dhe if dag >= 16 & dhe !=., color(red%40) lcolor(red%80)), ///
	legend(order(1 "dhe" 2 "imputed dhe" )) ///
	title("Comparison of Health Variables") ///
	xtitle("Age") ///
	ytitle("Density") ///
	graphregion(color(white))
	
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

* Add imputed values 
replace dhe = round(imp_dhe) if missing(dhe) & dag >= 16
replace dhe = -9 if dag < 16

drop dgn2 dag2 dagsq2 drgn12 _Idgn2_1 _Iswv_* p1* p2 p3 p4 p5 rnd imp_dhe

bys flag_dhe_imp: fre dhe if dag <= 16
bys flag_dhe_imp: fre dhe if dag > 16 

fre dhe 
tab dhe year, col 
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
lab var dcpen "Enter partnership, only populated if eligible"

* Impose partnership age restriction 
replace dcpen = -9 if dag < ${age_form_partnership}

fre dcpen 
tab dcpen year, col
bys swv: sum dcpen if dcpen >= 0 


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

* Are there old people that remains married but there partner disappears? 
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
lab var dcpex "Exit partnership, only populated if eligible"

* Impose partnership age restriction 
replace dcpex = -9 if dag < ${age_form_partnership} 

fre dcpex 
tab dcpex year, col
bys swv: sum dcpex if dcpex >= 0 

* Check consistency 
tab dun dcpex


/**************************** PARTNER AGE DIFFERENCE **************************/
gen dcpagdf = dag - dagsp if dagsp != . & idpartner != -9

lab var dcpagdf "Partnership age difference"

* Impose partnership age restriction 
replace dcpagdf = . if dag < ${age_form_partnership}

fre dcpagdf // 
tab dcpagdf year, col
bys swv: sum dcpagdf

hist dcpagdf

graph drop _all 

tab dag if dcpagdf > 20 & dcpagdf != . 


/************************ ECONOMIC ACTIVITY STATUS ****************************/
/* 
Activity status is coded very differently in EU-SILC to Understanding Society
** pl030/pl031 is "self-defined economic status" and has the most detail but 
many missings, 
I use rb210 "basic activity status", which is less granular (i.e. information 
on students is not available), to fill in some of the missings 
*/

/* AB: In 2021 pl032 replaced pl031. However for PL the values for earlier years 
in which pl031 was collected have not been converted into pl032 and pl031 is not 
in the dataset. Therefore many values for 2018-2020 missing for the later 
panels. For now merging observations from Clare's original panel which only goes 
up to 2020 and therefore doesn't have this problem because only includes pl031.

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
*/

/*
Add in values of variables from 2005-2020 for individuals where post-2021
setup files do not carry forward pl031/rb210 under old variable names.
*/
merge 1:1 pid hid year using "$dir_data/temp_orig_econ_status"

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

* 2021-2023
replace les_c3 = 1 if les_c3 == . & pl032 == 1
replace les_c3 = 2 if les_c3 == . & pl032 == 5
replace les_c3 = 3 if les_c3 == . & inrange(pl032,2,4)
replace les_c3 = 3 if les_c3 == . & inrange(pl032,6,8)

replace les_c3 = 1 if les_c3 == . & pl040a == 1
replace les_c3 = 1 if les_c3 == . & pl040a == 2
replace les_c3 = 1 if les_c3 == . & pl040a == 3

* Utilizing alternative raw variables from register dataset
* 2005-2020 
replace les_c3 = 1 if rb210 == 1 & les_c3 == .
replace les_c3 = 3 if inrange(rb210,2,4) & les_c3 == .

* 2021-2023
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

fre les_c3 // 1.6% missing 
tab les_c3 year, col
bys swv: sum les_c3

replace les_c3 = -9 if les_c3 == . 
tab les_c3 year, col
tab rotation_group if les_c3 == -9 & year == 2020


/******************** ECONOMIC ACTIVITY STATUS WITH RETIREMENT ****************/ 
/*
Variable construction choice seems to matter here. 
At present, the pl* vars take precedent when constructing les_c3, however this 
precidence was not imposed when coding les_c4. 
Implement precendent here as well. 

Also note that the original method of no priority to pl* vars creates a some 
retired people who are working or students according to les_c3. 

Conditions imposed to make consistent with SimPaths: 
	- Can not retire below a given age 
	- Retirement is an absorbing stated
	- Force retirement above a given age
*/
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

replace les_c4 = 3 if dag < ${age_can_retire} & les_c4 == 4 	


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
	"FLAG: Forced into retirement due to age (after absorbing assumption)"

replace les_c3 = 3 if dag >= ${age_force_retire}	
replace les_c4 = 4 if dag >= ${age_force_retire}	
	
* Make les_c3 consistent with change made to les_c4
replace les_c3 = 3 if les_c4 == 4 	// 2,901 changes 	

* Check consistency 
tab2 les_c3 les_c4, row

fre les_c4 	// 1.1% missing 
tab les_c4 year, col
bys swv: sum les_c4

replace les_c4 = -9 if les_c4 == . 


/************************ LONG-TERM SICK OR DISABLED **************************/
/*
Effectively treat disabled/long-term sick as a mutually exclusive activity 
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

* Create flag 
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

replace unemp = 0 if les_c4 == 4 & unemp == 1 

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

fre ded // 21% obs 
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

* Age in estimation limited to 16-29
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
sum lhw if les_c3 == 4	
	
* Overwrite hours work if report not working (les)
* Create flag 
gen flag_impose_zero_hours_ne = (lhw > 0 & lhw != . & les_c4 == 3)
gen flag_impose_zero_hours_retire = (lhw > 0 & lhw != . & les_c4 == 4)
gen flag_impose_zero_hours_student = (lhw > 0 & lhw != . & les_c3 == 2)

lab var flag_impose_zero_hours_ne ///
	"FLAG: Replaced +ive hours of work with 0 as report not-employed"
lab var flag_impose_zero_hours_retire ///
	"FLAG: Replaced +ive hours of work with 0 as report retired"
lab var flag_impose_zero_hours_student ///
	"FLAG: Replaced +ive hours of work with 0 as report student"

* Consistency of missing hours cases 	
replace lhw = 0 if les_c3 == 3	
replace lhw = 0 if les_c3 == 2	


* Overwrite activity status (les) if report zero hours (lhw)
* Create flag 
gen flag_not_work_hours = (lhw  == 0 & les_c3 == 1)

lab var flag_not_work_hours ///
	"FLAG: Replaced activity status with non-employed as report 0 hours"

replace les_c3 = 3 if lhw  == 0 & les_c3 == 1 
replace les_c4 = 3 if lhw  == 0 & les_c4 == 1 


* Overwrite activity status (les) if report +ive hours but missing activity 
* 	status information
* Consistency of missing hours cases 
tab les_c3 if lhw == .
tab les_c4 if lhw == . 
		
* Create flag 		
gen flag_missing_act_hours = (lhw > 0 & lhw != . & les_c3 == -9)

lab var flag_missing_act_hours ///
"FLAG: Replaced missing activity status with working as report positive hours"

replace les_c3 = 1 if lhw > 0 & lhw != . & les_c3 == -9		
replace les_c4 = 1 if lhw > 0 & lhw != . & les_c3 == 1 & les_c4 == -9		
		
		
* Impute hours if report working (les) but missing hours
		
* Investigate the characteristics 
gen x = (lhw == .)
tab swv x if les_c4 == 1, row // up to 20% missing in a year 

tab dag if les_c4 == 1 & lhw == . // distributed across all ages (16-74)

tab pl040 if les_c4 == 1 & lhw == .  // most employees (69%)
count if pl040 == . & les_c4 == 1 & lhw == . & dag >= 16	// 34,038

tab pl145 if les_c4 == 1 & lhw == .  // most full time workers (88%)
count if pl145 == . & les_c4 == 1 & lhw == . & dag >= 16	// 33,475

tab pl141 if les_c4 == 1 & lhw == .  // most have perm written contract (57%)
count if pl141 == . & les_c4 == 1 & lhw == . & dag >= 16	// 33,732

count if les_c4 == 1 & lhw == . & dag >= 16 & pl030 == . & pl031 == . & ///
	pl032 ==.  	// 33,112 of 34,132 missing pl* variable information 
		
/*
Appears there is an issue with many missing observations in the personal data 
file whilst have information in the register dataset. 
Personal register files contains high level info for individuals currently 
living in the household. The personal data file contains more detailed 
information for all members of the hh 16+ for whom the information could be 
completed. 
Currently don't have the flag variables in the dataset but could investigate 
this is the case to check logic. 

Suggest to impute these missing hours because treating these observations as not
employed would creating a large bias given the magnitude of the issue. 

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
		// 6,074 changes 
		
count if lhw == . & les_c4 == 1  	// 28,058	

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
		// 3,466 changes
		
sort idperson swv 			
	
lab var flag_missing_hours_act_adj ///
"FLAG: Replaced missing hours with positive amount using info from adjacent cells as report working "

count if lhw == . & les_c4 == 1  	// 24,592


/*
Hot-deck imputation of missing hours for individuals classified as employed

The imputation sample consists of individuals with les_c4 == 1 but missing 
weekly hours (lhw). Donors are restricted to individuals who are also classified
as employed and report positive, non-missing hours.

Donors are matched within strata defined by:
    - 10-year age band
    - gender

Within each stratum, all eligible donor observations are numbered. For each
observation requiring imputation, a donor is selected at random (with
replacement) from the available donors in the same stratum. The selected
donor's reported weekly hours are then assigned to the recipient.

A fixed random-number seed is used to ensure that the imputation is
reproducible. Observations are explicitly sorted before the random draw so that
the assignment of random numbers is also reproducible with respect to the
ordering of the data.
*/
sort idperson swv

* Identify recipients: employed individuals with missing weekly hours
gen need_imp = (les_c4 == 1 & lhw == .)
 
* Define imputation strata: 10-year age bands by gender
gen ageband = floor(dag/10)*10

egen stratum = group(ageband dgn), label   

* Construct donor pool: employed individuals reporting positive hours 
preserve 

	keep if les_c4 == 1 & lhw > 0 & lhw != .
	keep lhw stratum idperson swv
	
	* Give each donor a unique number within its stratum
	bys stratum (idperson swv): gen draw = _n
	 
	* Record the number of available donors in each stratum
	bys stratum (idperson swv): gen n_donors  = _N
	
	rename lhw donor_lhw
	drop idperson
	
	save "$dir_data/temp_lhw_donors", replace

	* Create lookup containing the number of available donors in each stratum
	keep stratum n_donors
	bys stratum: keep if _n == 1
	
	save "$dir_data/temp_donorsN", replace

restore

merge m:1 stratum using "$dir_data/temp_donorsN", nogen

* Randomly select one donor (with replacement) from the recipient's stratum
set seed 9876

gen draw = . 

* Fix observation order before generating random numbers for reproducibility
sort stratum idperson swv

bys stratum (idperson swv): replace draw = ceil(runiform()*n_donors[1]) if ///
	need_imp == 1 & n_donors > 0 

* Merge the selected donor's hours onto each recipient	
merge m:1 stratum draw using "$dir_data/temp_lhw_donors", ///
	keepusing(donor_lhw draw) 

drop if _merge == 2 
drop _merge
	
* Impute weekly hours from the selected donor	
replace lhw = donor_lhw if need_imp == 1 

tab lhw if need_imp == 1

count if need_imp == 1 & n_donors == 0		// check
		 		
rename need_imp	flag_missing_hours_act_imp

lab var flag_missing_hours_act_imp	///
"FLAG: Replaced hours from missing to positive amount using hot deck imputation"	
			
drop x donor_lhw n_donors draw 			
			
count if lhw == . & les_c3 == -9 	// 8,461 cases
		
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
count if les_c4 == -9  & lhw == . 	// 8,461


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

// missing values imputed below


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
*/

replace pe040 = . if pe040 < 0
sort  idperson swv

* Merge in values from 2020 panel 
merge 1:1 year pid hid using "$dir_data/temp_orig_edu"

replace pe040 = pe040_orig if pe040 == . & pe040_orig != . 

drop if _merge == 2 
drop _merge pe040_orig

* 2005-2020
gen deh_c3 = .
replace deh_c3 = 3 if pe040 == 0 | pe040 == 1 | pe040 == 2 | pe040 == 100 ///
	| pe040 == 200
replace deh_c3 = 2 if pe040 == 3 | pe040 == 4 | (pe040 >= 300 & pe040 < 500)
replace deh_c3 = 1 if pe040 == 5 | (pe040 >= 500 & pe040 <= 1000)
		
* 2021-2023		
replace deh_c3 = 3 if pe041 == 0 | pe041 == 100 | pe041 == 200
replace deh_c3 = 2 if pe041 >= 300 &  pe041 < 500
replace deh_c3 = 1 if pe041 >= 500 &  pe041 <= 800
		
lab var deh_c3 "Education status, 3 cat"
lab define l_deh_c3 3 "low" 2 "medium" 1 "high" 
lab values deh_c3 l_deh_c3
					
* Assume in initial education spell until at least 15 
* 	- education not yet assigned impose low for now	
replace deh_c3 = 3 if dag < ${age_leave_school} 

replace deh_c3 = -9 if deh_c3 == . 


fre deh_c3	// 10% missing, 74,846
fre dag if deh_c3 == -9  
fre year if deh_c3 == -9  
tab deh_c3 year, col
bys swv: sum deh_c3 if deh_c3 > 0 

gen deh_orig  = deh_c3 

* Impute missing values 
/* 
Impute missing values using the monotonicity of education. Individuals can only 
increase their educaiton level over time and there is a min and a mix, 
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


* Looking backwards 
forvalues i = 2/6 {
	
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

tab deh_c3 // 10%

* Missing 
replace imp_deh_mono = -9 if imp_deh_mono == . 

tab imp_deh_mono // 6%

gen flag_deh_imp_mono = 1 if imp_deh_mono!= -9 & deh_c3 == -9 

lab var flag_deh_imp_mono "FLAG: =1, impute age using logical deduction"

* Comparison plot
twoway (histogram deh_c3 if deh_c3 > 0, percent color(blue%50) ///
	barwidth(0.8)) ///
	(histogram imp_deh if imp_deh > 0, percent color(red%50) barwidth(0.8)), ///
	title("Comparison of Observed vs. Imputed Values") ///
	legend(label(1 "Observed deh_c3") label(2 "Imputed imp_deh") ) ///
	graphregion(color(white))

twoway (histogram deh_c3 if deh_c3 > 0 & dag < 30 & dag > 16, percent ///
	color(blue%50) barwidth(0.8)) ///
	(histogram imp_deh if imp_deh > 0 & dag < 30 & dag > 16, percent ///
	color(red%50) barwidth(0.8)), ///
	title("Comparison of Observed vs. Imputed Values") ///
	legend(label(1 "Observed deh_c3") label(2 "Imputed imp_deh") )	///
	graphregion(color(white))

graph drop _all 	

* Add imputed values to variable 
replace deh_c3 = imp_deh if deh_c3 == -9 
		
fre deh_c3
fre dag if deh_c3 == -9  
fre year if deh_c3 == -9  
tab deh_c3 year, col
bys swv: sum deh_c3 if deh_c3 > 0 

count if deh_c3 == -9  // 44,266

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

count if deh_c4 == -9 	// 44,265
count if deh_c4 == -9 & les_c4 == -9  	// 3,031


/*************************** PARENT'S EDUCATION STATUS ************************/ 
/* 
There is no variable for parent's education status in EU-SILC, but can be 
made for those with parent IDs in the data.
1. Create mothers and fathers education levels in new file with person and hh id 
2. Merge by father and mother id and hh id 

However this requires individuals to live with their parents and therefore isn't
particularly useful for our purposes.

Create variables but leave missing so able to utilize the stadnard strucuture of 
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
lab var der "Return to education"

fre der // 48% of observation missing value 
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
* Cannot leave school before turnign 16
replace sedex = -9 if dag < ${age_leave_school}

* Do not have the choice to leave school after the age of 29 (1 year only)
replace sedex = -9 if dag >= ${age_force_leave_spell1_edu}
	
lab val sedex dummy
lab var sedex "Transition out of education"

fre sedex // 95% missing
fre sedex if sedex > -9 // 27% leave
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

fre dlrtrd 
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
lab var drtren "DEMOGRAPHIC: Enter retirement, only populated if eligible"

fre drtren 
tab drtren year, col

tab drtren les_c3
tab drtren les_c4


/**************************** PENSION AGE *************************************/
/*State Retirement Ages for Men in the POLAND (2009-2024):

2008-2009: 65
2009-2010: 65
2010-2011: 65
2011-2012: 65
2012-2013: 65
2013-2014: 65
2014-2015: 65
2015-2016: 65
2016-2017: 66
2017-2018: 66
2018-2019: 65
2019-2020: 65
2020-2021: 65
2021-2022: 65
2022-2023: 65

State Retirement Ages for Women in the POLAND (2009-2024):

2009-2010: 60
2009-2010: 60
2010-2011: 60
2011-2012: 60
2012-2013: 60
2013-2014: 60
2014-2015: 60
2015-2016: 61
2016-2017: 61
2017-2018: 60
2018-2019: 60
2019-2020: 60
2020-2021: 60
2021-2022: 60
2022-2023: 60

Ages are approximate, Poland had various options for taking early retirement and 
different sources had different ages.
*/
gen dagpns = 0

* Men
replace dagpns = 1 if dgn == 1 & dag >= 65 & stm >= 2005 & stm < 2016
replace dagpns = 1 if dgn == 1 & dag >= 66 & stm >= 2016 & stm < 2018 
replace dagpns = 1 if dgn == 1 & dag >= 65 & stm >= 2018 & stm <= 2024

* Women 
replace dagpns = 1 if dgn == 0 & dag >= 60 & stm >= 2005 & stm < 2016
replace dagpns = 1 if dgn == 0 & dag >= 61 & stm >= 2016 & stm < 2018
replace dagpns = 1 if dgn == 0 & dag >= 60 & stm >= 2018 & stm <= 2024

fre dagpns // 23% of retirement age 

* Become eligible for the state pension dummy 
gen dagpns_y = 0 

* Men 
replace dagpns_y = 1 if dgn == 1 & dag == 65 & stm >= 2005 & stm < 2016
replace dagpns_y = 1 if dgn == 1 & dag == 66 & stm >= 2016 & stm < 2018 
replace dagpns_y = 1 if dgn == 1 & dag == 65 & stm >= 2018 & stm <= 2024 

* Women
replace dagpns_y = 1 if dgn == 0 & dag == 60 & stm >= 2006 & stm < 2016
replace dagpns_y = 1 if dgn == 0 & dag == 61 & stm >= 2016 & stm < 2018 
replace dagpns_y = 1 if dgn == 0 & dag == 60 & stm >= 2018 & stm <= 2024 

* Became eligible for state pension last year 
gen dagpns_y1 = 0 

* Men 
replace dagpns_y1 = 1 if dgn == 1 & dag == 66 & stm >= 2005 & stm < 2016
replace dagpns_y1 = 1 if dgn == 1 & dag == 67 & stm >= 2016 & stm < 2018 
replace dagpns_y1 = 1 if dgn == 1 & dag == 66 & stm >= 2018 & stm <= 2024 

* Women
replace dagpns_y1 = 1 if dgn == 0 & dag == 61 & stm >= 2005 & stm < 2016
replace dagpns_y1 = 1 if dgn == 0 & dag == 62 & stm >= 2016 & stm < 2018 
replace dagpns_y1 = 1 if dgn == 0 & dag == 61 & stm >= 2018 & stm <= 2024

lab var dagpns_y "Age became eligible for pension"
lab var dagpns_y1 "Age+1 became eligible for pension"

tab dag dagpns_y
tab dag dagpns_y


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

lab var dagpns_y_sp "Age became eligible for pension - partner"
lab var dagpns_y1_sp "Age+1 became eligible for pension - partner"

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

fre ssscp //0.02%
tab ssscp year, col


/*************************** PARTNERSHIP DURATION *****************************/
/*
There are no equivalent variables in EU-SILC for partnership duration 
prior to the entry into the panel.
Max duration is 5 years due to individual panel length
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
replace dcpyy = partnershipDuration if (idpartner > 0)
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
replace scpexpy = -9 if swv == 2023

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

	drop if idmother == -9 
	drop if depChild != 1 

	keep idmother depChild depChild02 swv 

	rename depChild has_child
	rename depChild02 has_child02
	rename idmother idperson 

	bysort swv idperson : egen dnc_merge = sum(has_child)
	bysort swv idperson : egen dnc02_merge = sum(has_child02)

	sort idperson swv
	drop if idperson == idperson[_n-1] & swv == swv[_n-1] 

	drop has_child*

	save "$dir_data/temp_depChild_mother", replace 

restore 

merge 1:m idperson swv using "$dir_data/temp_depChild_mother"
drop _m

* Father 
preserve 

	drop if idfather == -9 
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
drop _m

gen dnc = 0 
gen dnc02 = 0 

replace dnc = dnc_merge if dgn == 0 & dnc_merge < . 
replace dnc02 = dnc02_merge if dgn == 0 & dnc_merge < . 

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
count if dag > 42 & dgn == 0 & dnc02 > 0 & dnc02 != . // 246 cases 
count if dag > 44 & dgn == 0 & dnc02 > 0 & dnc02 != . // 101 cases 

// Updated in file 03 to be the number of children in benefit unit


/*********************** NUMBER OF NEW BORN CHILDREN **************************/
gen child0 = 0
replace child0 = 1 if dag < 1 
bysort idmother swv: egen dchpd = total(child0) if idmother > 0

fre dchpd

preserve 

	keep swv idmother dchpd
	rename idmother idperson 
	rename dchpd mother_dchpd

	drop if idperson < 0

	collapse (max) mother_dchpd, by(idperson swv)
	duplicates report idperson swv

	save "$dir_data/temp_mother_dchpd", replace

restore 

merge 1:1 swv idperson using "$dir_data/temp_mother_dchpd", ///
	keepusing (mother_dchpd)
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

tab dag if dgn == 0 & dag > 49 & dchpd > 0 

/*
        Age |      Freq.     Percent        Cum.
------------+-----------------------------------
         84 |          1      100.00      100.00
------------+-----------------------------------
      Total |          1      100.00

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
	- 16+ years old
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
* do not have a partner (have as 17 for the transition below)
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
Only populated if eligible for transition. 1 means that the individual exits the 
parental home. 
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
	
* Correct age fo adult child flag 
replace adultchildflag = 0 if dag == ${age_leave_parental_home} - 1
	
lab val dlftphm dummy
lab var dlftphm ///
	"DEMOGRAPHIC: Exit the Parental Home, only populated if eligible"

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
replace dhhtp_c4 = 1 if dcpst == 1 & dnc == 0 // Coupled, no children
replace dhhtp_c4 = 2 if dcpst == 1 & dnc > 0 // Coupled, children
replace dhhtp_c4 = 3 if dcpst == 2 & dnc == 0  // | adultchildflag == 1) 
	// Not partnered, no children 
replace dhhtp_c4 = 4 if dcpst == 2 & dnc > 0 & dhhtp_c4 != 3 
	// Not partnered, children

lab def dhhtp_c4_lb 1 "Couple with no dep children" ///
	2 "Couple with dep children" ///
	3 "Single with no dep children" ///
	4 "Single with dep children"
lab val dhhtp_c4 dhhtp_c4_lb
lab var dhhtp_c4 "Household composition"

fre dhhtp_c4 // 1.72% single parents
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

fre dhhtp_c8 // 1.87% single parents
tab dhhtp_c8 year, col 	
bys swv: sum dhhtp_c8 

/*
Updated at the bottom of the file after update non-emplpoyment to include those 
working 0-5 hours. 
 
Also updatd in file 03 to account for alternative constrcution of dnc variable. 
*/

/************************** OECD EQUIVALENCE SCALE ****************************/
* Temporary number of children 0-13 and 14-18 to create OECD hh equiv scale
gen depChild_013 = 1 if (dag >= 0 & dag <= 13) & (idmother > 0 | idfather > 0) 

gen depChild_1418 = 1 if (dag >= 14 & dag <= 18) & (idmother > 0 | idfather > 0) 

bys swv idhh: egen dnc013 = sum(depChild_013)
bys swv idhh: egen dnc1418 = sum(depChild_1418)
drop depChild_013 depChild_1418

gen moecd_eq = . // Modified OECD equivalence scale
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
gen sedag = 1 if dag >= $age_leave_school & dag <= $age_force_leave_spell1_edu
replace sedag = 0 if missing(sedag)

lab val sedag dummy
lab var sedag "Initial education spell age range"

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
16 adn not retired
*/
gen sedrsmpl = 0 
replace sedrsmpl = 1 if dag >= ${age_leave_school} & les_c4 != 4 & ded == 0 

lab var sedrsmpl "SYSTEM : Return to education sample"
lab def  sedrsmpl  1 "Aged 16+, not retired and not in initial education spell"
lab val sedrsmpl sedrsmpl


/******************* IN INITIAL EDUCATION SPELL SAMPLE ************************/
/* 
Generated from sedcsmpl and ded variables. Sample: Respondents who were in 
initial education spell and left it. 
*/
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
(neither inlcuded in the EUROMOD definition of original income)  

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
Last data update: 18/1/25
https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_aind/default/...
table?lang=en&category=prc.prc_hicp
*/
gen CPI = .

replace CPI = 80.2  	if stm == 2005
replace CPI = 81.2  	if stm == 2006
replace CPI = 83.3  	if stm == 2007
replace CPI = 86.8  	if stm == 2008
replace CPI = 90.3  	if stm == 2009
replace CPI = 92.7  	if stm == 2010
replace CPI = 96.3  	if stm == 2011
replace CPI = 99.8  	if stm == 2012
replace CPI = 100.6  	if stm == 2013
replace CPI = 100.7  	if stm == 2014
replace CPI = 100    	if stm == 2015
replace CPI = 99.8 		if stm == 2016
replace CPI = 101.4 	if stm == 2017
replace CPI = 102.6 	if stm == 2018
replace CPI = 104.8 	if stm == 2019
replace CPI = 108.6 	if stm == 2020
replace CPI = 114.4 	if stm == 2021
replace CPI = 129.4 	if stm == 2022
replace CPI = 143.5 	if stm == 2023

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

* Turn into real gross annual labour income using lagged CPI to account for timing 
gen CPI_5 = 80.2  	
gen CPI_6 = 81.2  	
gen CPI_7 = 83.3  	
gen CPI_8 = 86.8  	
gen CPI_9 = 90.3  	
gen CPI_10 = 92.7  	
gen CPI_11 = 96.3  	
gen CPI_12 = 99.8 
gen CPI_13 = 100.6  	
gen CPI_14 = 100.7  	
gen CPI_15 = 100    	
gen CPI_16 = 99.8 		
gen CPI_17 = 101.4 	
gen CPI_18 = 102.6 	
gen CPI_19 = 104.8 
gen CPI_20 = 108.6 	
gen CPI_21 = 114.4 
gen CPI_22 = 129.4 	
gen CPI_23 = 143.5 

forvalues i = 6/23 {
	
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
	// almost all observations that report monthly info, have info for the whole 
	// year, in general missing all or missing none 


tab months_wrk if months_wrk_missing == 0 & yplgrs_annual != 0 
/*
 6,440 say they worked no months last year and yet have labour income 
 mainly self-employed income so distribute across the year  
*/

sum months_wrk if months_wrk_missing == 0 & les_c3 == 1, de
tab months_wrk if les_c3 == 1, sort
// mean 11.44 months worked on average across workers
// mode 12 months among the working 

count if yplgrs_annual > 0 & months_wrk_missing != 0 // 89,857 
/*
 => many missing values regarding months worked last year 
 => if missing some monthly working information assume not working in the 
	missing months
 =>  if missing all monthly information assume working the mode number of months
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

/*
If have annual income and report working zero months assume the mode number of 
work months. Note this income is mainly from self-employed income 
*/
replace yplgrs_mnth = yplgrs_annual / 12 if months_wrk == 0 

* Check 
sum yplgrs_mnth 

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

count if obs_earnings_hourly == .		// 98,922
count if obs_earnings_hourly == . & idperson != idperson[_n+1] 	// 97,181
count if obs_earnings_hourly == . & idperson == idperson[_n+1] & ///
	les_c3 == -9  // 408
count if obs_earnings_hourly == . & idperson == idperson[_n+1] & ///
	les_c3 == 1 & swv != swv[_n+1] - 1 		// 1,333
// accounted for all cases 	
	
count if obs_earnings_hourly == 0 & les_c3 == 1 	// 19,434
count if obs_earnings_hourly == 0 & les_c3 == 1 & idperson == idperson[_n+1]
	// 19,434
count if obs_earnings_hourly == 0 & les_c3 == 1 & yplgrs_annual[_n+1] == 0 & ///
	flag_missing_lbr_income[_n+1] == 1 & idperson == idperson[_n+1] // 4,635
count if obs_earnings_hourly == 0 & les_c3 == 1 & yplgrs_annual[_n+1] == 0 & ///
	flag_missing_lbr_income[_n+1] == 0 & idperson == idperson[_n+1]	// 14,799
// accounted for all cases 	
	
/*
Missing wage observations:
	1 - almost all due to being the last observation in individual's panel 
	2 - missing activity information 
	3 - missing adjacent observation 

Zero wage observations
	4 - next year is missing labour income information 
	5 - next year reports zero labour income 

How to address each case:
	- uprate previously reported wages 
	- use last years earnings and this years hours
	- use next years wages 

- use hot deck imputation

https://bdl.stat.gov.pl/bdl/dane/podgrup/tablica

*/ 
* Average gross wages 
gen avg_wage_5 = 2506.93
gen avg_wage_6 = 2636.81
gen avg_wage_7 = 2866.04
gen avg_wage_8 = 3158.48
gen avg_wage_9 = 3315.38
gen avg_wage_10 = 3435.00
gen avg_wage_11 = 3625.21
gen avg_wage_12 = 3744.38
gen avg_wage_13 = 3877.43
gen avg_wage_14 = 4003.99
gen avg_wage_15 = 4150.86
gen avg_wage_16 = 4290.52
gen avg_wage_17 = 4527.89
gen avg_wage_18 = 4834.76
gen avg_wage_19 = 5181.63
gen avg_wage_20 = 5523.32
gen avg_wage_21 = 6001.02
gen avg_wage_22 = 6705.62
gen avg_wage_23 = 7595.30

replace obs_earnings_hourly = . if obs_earnings_hourly == 0 & les_c3 == 1 

gen x = 1 if les_c3 == 1 & obs_earnings_hourly == . 

* Imputation 
forvalues i = 6/23 {
	
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
	
count if obs_earnings_hourly == .	
count if obs_earnings_hourly == . & idperson != idperson[_n+1] 	
count if obs_earnings_hourly == . & idperson == idperson[_n+1] & ///
	les_c3 == -9  
count if obs_earnings_hourly == . & idperson == idperson[_n+1] & ///
	les_c3 == 1 & swv != swv[_n+1] - 1 	
	
count if obs_earnings_hourly == . & les_c3 == 1 & yplgrs_annual[_n+1] == 0 & ///
	flag_missing_lbr_income[_n+1] == 1 & idperson == idperson[_n+1] 
count if obs_earnings_hourly == . & les_c3 == 1 & yplgrs_annual[_n+1] == 0 & ///
	flag_missing_lbr_income[_n+1] == 0 & idperson == idperson[_n+1]	
	
count if obs_earnings_hourl == 0 & les_c3 == 1		
	
	
* Use hot deck imputation for the remaining missing observations among the 
* working
* Use hot deck imputation for the remaining missing observations among the 
* working

/*
Hot-deck imputation of missing hourly wages for individuals classified as 
working.

The imputation is conducted in two stages.

Stage 1:
Individuals with missing hourly wages are matched to donor observations within
strata defined by:
    - survey wave
    - 10-year age band
    - gender
    - region

Individuals aged 70+ are grouped with the 60+ age category to increase the
number of potential donors. The donor pool consists of working individuals with
an observed hourly wage. Within each stratum, one donor observation is selected
at random (with replacement), and the donor's hourly wage is assigned to the
recipient.

Stage 2:
If any working individuals remain without an observed or imputed wage after the
first stage, the matching criteria are relaxed by dropping region. The remaining
observations are therefore matched within strata defined by:
    - survey wave
    - 10-year age band
    - gender

This broader donor pool reduces the likelihood that observations remain
unmatched because no wage donor is available within their region.

A fixed random-number seed is used to make the random donor selection
reproducible. Observations are sorted before the first-stage random draw so that
the assignment of random numbers is reproducible with respect to the ordering
of the data.
*/

set seed 987

* Identify recipients: working individuals with missing hourly wages
gen flag_wage_hotdeck = (les_c3 == 1 & missing(obs_earnings_hourly))

lab var flag_wage_hotdeck "FLAG: wage imputed using hotdeck imputation"

* Define first-stage matching strata
cap drop ageband 
gen ageband = floor(dag/10)*10

* Pool individuals aged 70+ with the 60+ to increase donor availability
replace ageband = 60 if ageband == 70  

cap drop stratum 
egen stratum = group(ageband drgn1 dgn swv), label(strutum, replace)  

* Construct first-stage donor pool: working individuals with observed wages
preserve

	keep if les_c3 == 1 & obs_earnings_hourly != . 
	keep obs_earnings_hourly stratum idperson swv 
	
	* Number donor observations within each stratum
	bys stratum (idperson swv): gen draw = _n
	
	* Record number of available donors within each stratum
	bys stratum (idperson swv): gen n_donors  = _N
	
	rename obs_earnings_hourly donor_wages
	drop idperson swv
	
	save "$dir_data/temp_wages_donors", replace

	* Create lookup containing number of available donors in each stratum
	keep stratum n_donors
	bys stratum: keep if _n == 1
	
	save "$dir_data/temp_donorsN", replace

restore

* Attach number of available donors to each recipient's stratum
merge m:1 stratum using "$dir_data/temp_donorsN", nogen

* Randomly select one donor observation from the recipient's stratum
gen draw = . 

sort stratum idperson swv

by stratum (idperson swv): replace draw = ceil(runiform()*n_donors[1]) if ///
	flag_wage_hotdeck == 1 & n_donors > 0  & !missing(n_donors)

* Attach hourly wage from selected donor	
merge m:1 stratum draw using "$dir_data/temp_wages_donors", ///
	keepusing(donor_wages draw) 

drop if _merge == 2 
drop _merge
	
* Impute hourly wage using selected donor	
replace obs_earnings_hourly = donor_wages if flag_wage_hotdeck == 1 

* Clean up variables specific to first-stage matching
drop donor_wages draw n_donors

* Check for working individuals remaining without an hourly wage after Stage 1
count if obs_earnings_hourly == . & les_c3 == 1


* Stage 2: relax matching criteria by dropping region for unmatched recipients
if r(N) > 0 {
    
	* Define broader strata using survey wave, age and gender only
    cap drop stratum_v2
    egen stratum_v2 = group(swv ageband dgn), label(replace)

	* Construct second-stage donor pool
    preserve
	
        keep if les_c3 == 1 & obs_earnings_hourly != .
        keep obs_earnings_hourly stratum_v2
		
		* Number donors and record donor-pool size within each broader stratum
        bys stratum_v2: gen draw_v2 = _n
        bys stratum_v2: gen n_v2 = _N
		
        tempfile donors2
        save `donors2'
		
    restore

	* Create lookup containing number of donors in each broader stratum
    preserve
	
        use `donors2', clear
        bys stratum_v2: keep if _n == 1
        keep stratum_v2 n_v2
    
		tempfile counts2
        save `counts2'
    
	restore

	* Attach number of available second-stage donors
    merge m:1 stratum_v2 using `counts2', keep(1 3) nogen
    
    * Randomly select one donor from the broader stratum
    gen draw_v2 = ceil(runiform() * n_v2) if obs_earnings_hourly == . & ///
		les_c3 == 1 & n_v2 > 0 & !missing(n_v2)
    
    * Attach hourly wage from selected second-stage donor
    merge m:1 stratum_v2 draw_v2 using `donors2', update replace keep(1 3) ///
		nogen keepusing(obs_earnings_hourly)

}

* Clean up
cap drop ageband stratum* n_donors draw n_v2 draw_v2 donor_wages

* Final check: all working individuals should now have an hourly wage
count if obs_earnings_hourly == . & les_c3 == 1		// 0 obs


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
	dhhtp_c8
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
hy080g: 	Regular interhousehold cash transfer received
hy110g: 	Income received by people aged under 16
hy040g: 	Income frm rental of a property or land 
hy090g: 	Intrst, div, prof frm cptl inv in uncorp bsn

NOTE: The raw variables have no missing or negative values. 			
*/

* Household level variables are assigned to all adult hh members 
* 	==> split them equally among all adults in hh
gen adult = (dag >= $age_adult) //18 yo and over 
bysort stm idhh : egen n_adults = total(adult) 

lab var n_adults "Number of adults in hh" 

gen child = (dag < $age_adult) // below 18 yo 
bysort stm idhh : egen n_child = total(child) 

lab var n_child "Number of children in hh" 

* No negative values or missing values 
foreach var in hy080g hy110g hy040g hy090g {
	
	gen `var'_pc = `var'/n_adults
	replace `var'_pc = 0 if child == 1
	
} 

egen ypncp_temp = rowtotal(hy080g_pc hy110g_pc hy040g_pc hy090g_pc)
gen ypncp = ypncp_temp / 12

* Check for missing values == if missing on all the components 
count if hy080g == . & hy110g == . &  hy040g == . &  hy090g == . // 0 obs 
count if hy080g == . | hy110g == . |  hy040g == . |  hy090g == . 

	
/*********** GROSS NONMINAL MONTHLY PERSONAL PRIVATE PENSION INCOME ***********/
/*
py080g: 	Pension from individual private plans (gross) 

The raw variable has many missing (.) values. 
*/
gen ypnoab = py080g / 12

* Code missing as zero 
recode ypnoab (. = 0) 

sum ypnoab
sum ypnoab if year == 2013
sum ypnoab if year == 2016
sum ypnoab if year == 2019
sum ypnoab if year == 2023

count if py080g == . & dag >= 16 

* Set to zero to be consistent with SimPathsEU
replace ypnoab = 0 


/*********** GROSS NOMINAL MONTHLY PERSONAL NON-BENEFIT INCOME ****************/
/*
Note: This is supposed to mirror UKMOD market income 

	=  employment income +  private pensions income +  capital income 
	
Use components instead of raw vars so that changes feed through 


*/
* Adjust gross eomployment income (yplgrs) so in nominal terms 
gen temp_yplgrs = yplgrs * (CPI/100)

egen ypnb = rowtotal(temp_yplgrs ypncp ypnoab)

sum ypnb if year == 2013
sum ypnb if year == 2016
sum ypnb if year == 2019
sum ypnb if year == 2023

* Check for missing values == if missing on all the components 
count if  py080g >= . & hy080g >= . & ///
	hy110g >= . & hy040g >= . & hy090g >= . 
	
count if (py080g >= . | hy080g >= . | ///
	hy110g >= . | hy040g >= . | hy090g >= .) & dag >= 16 
	
count if dag >= 16 
//=> 20% of adult observations have some missing income information 


/****** GROSS NOMINAL MONTHLY PERSONAL NON-EMPLOYMENT NON-BENEFIT INCOME ******/
/*
 = capital income + private pension income 
 
UK version:  egen yptc = rowtotal(fimnpen_dv fimnmisc_dv inc_stp inc_tu inc_ma)

EU SILC use the same variables as indicated above.  
*/

egen yptc = rowtotal(ypncp ypnoab)


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

replace yhhnb = ypnb if dhhtp_c4 == 3 | dhhtp_c4 == 4 

* Equivalise 
replace yhhnb = (yhhnb/moecd_eq)

sum yhhnb
sum yhhnb if year == 2013
sum yhhnb if year == 2016
sum yhhnb if year == 2019
sum yhhnb if year == 2023


/****************** NOMINAL MONTHLY PERSONAL DISPOSABLE INCOME *****************/
/*
hy020: 		Total disposable household income 

py021g: 	Company car
*/
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
* Adjust for inflation
* Note, yplgrs already in real terms as derived from real wages 
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
sort idperson swv 

gen yhhnb_asinh_jittered = yhhnb_asinh + runiform() * 1e-5

cap drop ydses*
forvalues stm = 2005/2023 {
	
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
	ydses_c5_2022 ydses_c5_2023)
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
There are no net incomes in EU-SILC, will be computed using EUROMOD anyway
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

// updated in file 03

/**************************** DISABILITY BENEFIT ******************************/
/* 
py130n: 	(disability benefits net), 
py130g: 	(disability benefits gross), 
py131g: 	(contributory and means-tested), 
py132g: 	(contributory and non means-tested), 
py133g: 	(non-contributory and means-tested), 
py134g: 	(non-contributory and non means-tested) 

All may contain information on disability benefits. 

For Poland, py131g only has zero entries

The code below may well be PL specific as some of the coding of these variables 
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

/* 
Overlap is good => supports match, but shape is different suggesting that 
ppl missing education cluster at covaraiate combinations that produce higher
probability of missing than observations for which we observe education 
*/

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
set seed 123567
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
	
forvalues i = 2/5 {

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
/*				
Those with some missing observations simply impose monotocity accounting 
whilst imposing a cap on education level using any future observed level
*/

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
forvalues i = 2/5 {	
	
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

* All due observatsions breaking the monotoncity rule are due to inconsistencies
* in the raw data 
gen flag_deh_imp_reg = (deh_c3 == -9 & imp_deh_all != .)

lab var flag_deh_imp_reg "FLAG: -1, if education imputed using gologit"

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
	
drop dgn2 dag2 dagsq2 drgn12 les_c42 dcpst2 ydses_c52 p1* p2 p3 rnd imp_deh*


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


/*
Hot-deck imputation of missing employment experience (liwwh).

Employment experience is imputed for individuals aged 16+ with missing values
(liwwh == -9) and non-missing age information. Donors are restricted to 
observations with valid reported employment experience, including zero.

Imputation is carried out sequentially using increasingly broad matching strata.
Observations that cannot be matched in one round proceed to the next:

    Round 1: exact age, sex, education, economic status and number of children
    Round 2: exact age, sex, education and economic status
             (drops number of children)
    Round 3: age group, sex, education and economic status
             (replaces exact age with narrow age groups)
    Round 4: age group, sex and education
             (additionally drops economic status)
    Round 5: exact age and sex
             (drops education and returns to exact age matching)

Within each round, one donor observation is selected at random (with
replacement) from the relevant matching stratum. Fixed random-number seeds and
a consistent observation ordering are used to make donor selection reproducible.

Only genuinely observed values of liwwh are used as donors in all rounds.
After combining the five rounds, feasibility constraints are imposed so that
employment experience is non-negative and cannot exceed the number of years
since the minimum school-leaving age.
*/

* Flag observations requiring imputation
gen byte temp_imp_liwwh = ///
    (liwwh == -9 & dag > 15 & !missing(dag))

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
	

* Fifth-round hot-deck imputation
* Relax education for remaining unmatched observations
* Exact matching on age and sex

* Construct matching strata
egen long temp_stratum_liwwh5 = ///
    group(dag dgn), missing

tempfile donors5 donor_counts5


* Construct donor pool
preserve

    * Only genuinely observed values are used as donors
    * Zero is a valid value
    keep if liwwh >= 0 & liwwh < .

    keep temp_obsid temp_stratum_liwwh5 liwwh

    * Number donors within each matching stratum
    sort temp_stratum_liwwh5 temp_obsid
    by temp_stratum_liwwh5: gen long temp_draw5 = _n
    by temp_stratum_liwwh5: gen long temp_n_donors5 = _N

    rename liwwh temp_donor_liwwh5

    save `donors5'

    * Create lookup containing number of donors in each stratum
    keep temp_stratum_liwwh5 temp_n_donors5
    by temp_stratum_liwwh5: keep if _n == 1

    save `donor_counts5'

restore


* Merge number of available donors onto recipients
merge m:1 temp_stratum_liwwh5 using `donor_counts5', nogen


* Randomly select one donor within each matching stratum
set seed 9880

sort temp_stratum_liwwh5 temp_obsid

gen long temp_draw5 = ceil(runiform() * temp_n_donors5) if ///
    temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3) & ///
    missing(temp_donor_liwwh4) & ///
    temp_n_donors5 > 0


* Merge selected donor values
merge m:1 temp_stratum_liwwh5 temp_draw5 using `donors5', ///
    keep(master match) nogen


* Checks
count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3) & ///
    missing(temp_donor_liwwh4)
    // Entering fifth round

count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3) & ///
    missing(temp_donor_liwwh4) & ///
    !missing(temp_donor_liwwh5)
    // Successfully matched in fifth round

count if temp_imp_liwwh == 1 & ///
    missing(temp_donor_liwwh1) & ///
    missing(temp_donor_liwwh2) & ///
    missing(temp_donor_liwwh3) & ///
    missing(temp_donor_liwwh4) & ///
    missing(temp_donor_liwwh5)
    // Still unmatched after fifth round	
	// individuals with missing age or gender information 
	
	
* Replace missing employment experience with hot-deck imputation
* Combine imputations across matching rounds
gen temp_liwwh_imp = temp_donor_liwwh1

replace temp_liwwh_imp = temp_donor_liwwh2 if ///
    temp_imp_liwwh == 1 & missing(temp_liwwh_imp)

replace temp_liwwh_imp = temp_donor_liwwh3 if ///
    temp_imp_liwwh == 1 & missing(temp_liwwh_imp)

replace temp_liwwh_imp = temp_donor_liwwh4 if ///
    temp_imp_liwwh == 1 & missing(temp_liwwh_imp)
	
replace temp_liwwh_imp = temp_donor_liwwh5 if ///
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
	
	
assert liwwh >= 0 if dag >= ${age_leave_school} & liwwh < . & dag != . 

assert liwwh <= dag - ${age_leave_school} if ///
    dag >= ${age_leave_school} & liwwh < .

assert liwwh == 0 if dag < ${age_leave_school}	
	
* Clean up 	
drop temp_stratum_liwwh temp_stratum_liwwh2 ///
    temp_stratum_liwwh3 temp_stratum_liwwh4 temp_stratum_liwwh5 ///
    temp_agegroup_liwwh temp_obsid ///
    temp_draw temp_draw2 temp_draw3 temp_draw4 temp_draw5 ///
    temp_n_donors temp_n_donors2 temp_n_donors3 temp_n_donors4 ///
    temp_n_donors5 ///
    temp_donor_liwwh1 temp_donor_liwwh2 ///
    temp_donor_liwwh3 temp_donor_liwwh4 temp_donor_liwwh5 ///
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
Total population figures for Poland from 2011 to 2021 (EUROSTAT demo_gind):

Year	Total Population
2011	38,062,718
2012	38,063,792
2013	38,062,535
2014	38,017,856
2015	38,005,614
2016	37,967,209
2017	37,972,964
2018	37,976,687
2019	37,972,812
2020	37,958,138
2021	37,073,357 

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
          2 |     12,134       33.22       33.22
          3 |     12,274       33.60       66.83
          4 |     12,117       33.17      100.00
------------+-----------------------------------
      Total |     36,525      100.00

--------------------------------------------------------------------------------
-> stm = 2006

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     12,321       26.87       26.87
          2 |     11,137       24.29       51.16
          3 |     11,233       24.50       75.65
          4 |     11,165       24.35      100.00
------------+-----------------------------------
      Total |     45,856      100.00

--------------------------------------------------------------------------------
-> stm = 2007

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     11,249       25.88       25.88
          2 |     11,401       26.23       52.12
          3 |     10,425       23.99       76.11
          4 |     10,383       23.89      100.00
------------+-----------------------------------
      Total |     43,458      100.00

--------------------------------------------------------------------------------
-> stm = 2008

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     10,629       25.38       25.38
          2 |     10,551       25.19       50.57
          3 |     10,901       26.03       76.59
          4 |      9,804       23.41      100.00
------------+-----------------------------------
      Total |     41,885      100.00

--------------------------------------------------------------------------------
-> stm = 2009

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      9,964       25.39       25.39
          2 |      9,666       24.63       50.01
          3 |      9,769       24.89       74.90
          4 |      9,851       25.10      100.00
------------+-----------------------------------
      Total |     39,250      100.00

--------------------------------------------------------------------------------
-> stm = 2010

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     10,345       27.25       27.25
          2 |      9,180       24.18       51.44
          3 |      9,240       24.34       75.78
          4 |      9,195       24.22      100.00
------------+-----------------------------------
      Total |     37,960      100.00

--------------------------------------------------------------------------------
-> stm = 2011

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      9,678       25.89       25.89
          2 |     10,349       27.68       53.57
          3 |      8,668       23.19       76.76
          4 |      8,689       23.24      100.00
------------+-----------------------------------
      Total |     37,384      100.00

--------------------------------------------------------------------------------
-> stm = 2012

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      9,070       24.02       24.02
          2 |      9,389       24.86       48.88
          3 |     11,111       29.42       78.31
          4 |      8,191       21.69      100.00
------------+-----------------------------------
      Total |     37,761      100.00

--------------------------------------------------------------------------------
-> stm = 2013

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,465       22.82       22.82
          2 |      8,451       22.78       45.60
          3 |      9,884       26.64       72.24
          4 |     10,300       27.76      100.00
------------+-----------------------------------
      Total |     37,100      100.00

--------------------------------------------------------------------------------
-> stm = 2014

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     10,141       27.61       27.61
          2 |      8,030       21.86       49.48
          3 |      9,275       25.25       74.73
          4 |      9,281       25.27      100.00
------------+-----------------------------------
      Total |     36,727      100.00

--------------------------------------------------------------------------------
-> stm = 2015

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,995       26.22       26.22
          2 |      8,310       24.22       50.44
          3 |      8,505       24.79       75.22
          4 |      8,501       24.78      100.00
------------+-----------------------------------
      Total |     34,311      100.00

--------------------------------------------------------------------------------
-> stm = 2016

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,306       25.07       25.07
          2 |      7,535       22.75       47.82
          3 |      9,364       28.27       76.09
          4 |      7,921       23.91      100.00
------------+-----------------------------------
      Total |     33,126      100.00

--------------------------------------------------------------------------------
-> stm = 2017

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      7,788       22.03       22.03
          2 |      6,972       19.72       41.76
          3 |      8,240       23.31       65.07
          4 |     12,348       34.93      100.00
------------+-----------------------------------
      Total |     35,348      100.00

--------------------------------------------------------------------------------
-> stm = 2018

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     16,566       40.85       40.85
          2 |      6,412       15.81       56.67
          3 |      7,296       17.99       74.66
          4 |     10,276       25.34      100.00
------------+-----------------------------------
      Total |     40,550      100.00

--------------------------------------------------------------------------------
-> stm = 2019

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     13,784       26.79       26.79
          2 |     21,620       42.02       68.80
          3 |      6,727       13.07       81.88
          4 |      9,326       18.12      100.00
------------+-----------------------------------
      Total |     51,457      100.00

--------------------------------------------------------------------------------
-> stm = 2020

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     10,871       27.19       27.19
          2 |     16,021       40.07       67.26
          3 |      5,342       13.36       80.62
          4 |      7,748       19.38      100.00
------------+-----------------------------------
      Total |     39,982      100.00

--------------------------------------------------------------------------------
-> stm = 2021

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      9,582       22.36       22.36
          2 |     14,186       33.10       55.46
          3 |     12,150       28.35       83.82
          4 |      6,935       16.18      100.00
------------+-----------------------------------
      Total |     42,853      100.00

--------------------------------------------------------------------------------
-> stm = 2022

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |      8,793       18.04       18.04
          2 |     12,914       26.50       44.55
          3 |     10,621       21.80       66.34
          4 |     16,402       33.66      100.00
------------+-----------------------------------
      Total |     48,730      100.00

--------------------------------------------------------------------------------
-> stm = 2023

 Rotational |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
          2 |     11,288       33.33       33.33
          3 |      9,053       26.73       60.05
          4 |     13,531       39.95      100.00
------------+-----------------------------------
      Total |     33,872      100.00

	  
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
  1. | 2005   112432844 |
  2. | 2006   148450929 |
  3. | 2007   147319355 |
  4. | 2008   148761815 |
  5. | 2009   149981056 |
     |------------------|
  6. | 2010   150007381 |
  7. | 2011   150072241 |
  8. | 2012   149632549 |
  9. | 2013   149773148 |
 10. | 2014   150792374 |
     |------------------|
 11. | 2015   151084193 |
 12. | 2016   150004674 |
 13. | 2017   149595007 |
 14. | 2018   146036127 |
 15. | 2019   109249951 |
     |------------------|
 16. | 2020   109751670 |
 17. | 2021   145453804 |
 18. | 2022   147346011 |
 19. | 2023   111286696 |
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
  1. | 2005   37478548 |
  2. | 2006   37118078 |
  3. | 2007   36846441 |
  4. | 2008   37197520 |
  5. | 2009   37496777 |
     |-----------------|
  6. | 2010   37503179 |
  7. | 2011   37518711 |
  8. | 2012   37411020 |
  9. | 2013   37447367 |
 10. | 2014   37703171 |
     |-----------------|
 11. | 2015   37772642 |
 12. | 2016   37505758 |
 13. | 2017   37408577 |
 14. | 2018   36509516 |
 15. | 2019   36427393 |
     |-----------------|
 16. | 2020   36586305 |
 17. | 2021   36382708 |
 18. | 2022   36869352 |
 19. | 2023   37105037 |
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
  1. | 2005   37478548 |
  2. | 2006   37118078 |
  3. | 2007   36846441 |
  4. | 2008   37197520 |
  5. | 2009   37496777 |
     |-----------------|
  6. | 2010   37503179 |
  7. | 2011   37518711 |
  8. | 2012   37411020 |
  9. | 2013   37447367 |
 10. | 2014   37703171 |
     |-----------------|
 11. | 2015   37772642 |
 12. | 2016   37505758 |
 13. | 2017   37408577 |
 14. | 2018   36509516 |
 15. | 2019   36427393 |
     |-----------------|
 16. | 2020   36586305 |
 17. | 2021   36382708 |
 18. | 2022   36869352 |
 19. | 2023   37105037 |
     +-----------------+
*/		

* Cross-sectional Grossing Up Weight
gen dwt = dimxwt 
lab var dwt "DEMOGRAPHIC : Grossing-up Weight"

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
bys idperson db075 (stm idperson): gen rb062_imputed  = rb062[_N] if missing(rb062)
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

lab var dimlwt "DEMOGRAPHIC : Individual Longitudinal Weight  based on rb062"	

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
  1. | 2005   11967193 |
  2. | 2006   11991123 |
  3. | 2007   12008634 |
  4. | 2008   12179639 |
  5. | 2009   12267654 |
     |-----------------|
  6. | 2010   12256630 |
  7. | 2011   12252703 |
  8. | 2012   12254774 |
  9. | 2013   12240833 |
 10. | 2014   12347560 |
     |-----------------|
 11. | 2015   12258064 |
 12. | 2016   11490051 |
 13. | 2017   10458185 |
 14. | 2018    9963716 |
 15. | 2019    9811145 |
     |-----------------|
 16. | 2020    9787257 |
 17. | 2021   11101337 |
 18. | 2022   12092705 |
 19. | 2023   12322220 |
     +-----------------+

Using the rescaled longitudinal weight did not work => use the rescaled base 
weight
*/


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
sum obs_earnings_hourly if les_c4 == 1 
sum obs_earnings_hourly if les_c4 != 1

sum yplgrs_dv if les_c3 == 1 
sum yplgrs_dv if les_c3 != 1

* Partnership 
tab dun dcpst

gen temp_idp_pop = (idpartner> -9)

tab dun temp_idp_pop 
tab dcpst temp_idp_pop 

* Fertility 


* Education 
tab ded deh_c3
tab ded deh_c4 

tab deh_c3 deh_c4


/*************************** KEEP RELEVANT WAVES ******************************/
/* 
Initial populations: longitudinal SILC for 2011-2023 
Estimation sample: longitudinal SILC with observations from 2010-2023 
 (income 2009-2022) 
*/
keep if swv >= 2010

save "$dir_data/02_pre_drop.dta", replace


/**************************** SENSE CHECK PLOTS *******************************/

//do "$dir_do/02_01_checks"

graph drop _all 


/*********************** CREATE ASSUMPTION DESCRIPTIVES  **********************/

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


sort idperson swv 

/*********************************** SAVE *************************************/
//save "$dir_data/${country}-SILC_pooled_all_obs_02.dta", replace 

* Check create same dataset each time 
* Only differences should come from stochastic imputation variables 
cf _all using "$dir_data/${country}-SILC_pooled_all_obs_02.dta"


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
	temp_mother_dchpd.dta
	temp_orig_econ_status.dta
	temp_orig_edu.dta
	temp_orig_occu.dta
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
