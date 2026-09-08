/**************************************************************************************************
* PROJECT:         Poland EM Data (PL_2019_b3.txt)
* DO-FILE:         Labour supply EUROMOD input and output data generation
*
* PURPOSE:
*   - Prepare EUROMOD input/output data for labour supply estimation.
**************************************************************************************************/

/**************************************************************************************************
* FILE DESCRIPTION
**************************************************************************************************

This .do file prepares data for labour supply estimation and generates EUROMOD input & output data.

(1) Household composition adjustment
(2) Definition of temp_singles, temp_couples, temp_not_flexible
(3) Wage estimation using Heckman selectivity model; predicted wages assigned in two ways:
        • wage1 – to everyone
        • wage2 – only to non-workers
(4) Expansion to labour supply alternatives
(5) Benefit counterfactual allocation adjustments
(6) Run EUROMOD for disposable income
(7) Split sample for estimation: singles vs couples

==========================
DATA FILTER – "SINGLES"
==========================
Singles are individuals who:
1. Have no partner (idpartner == 0), OR have a partner who is:
      - a student, OR
      - sick/disabled, OR
      - outside working age (<16 or >75), OR
      - a pensioner.
AND who themselves satisfy:
2. Working age (16 ≤ dag ≤ 75)
3. Not student (les != 6), not disabled/sick (les != 8), not pensioner (les != 4).

==========================
DATA FILTER – "COUPLES"
==========================
Both partners satisfy the flexible worker conditions above.

==========================
DATA FILTER – "NOT FLEXIBLE"
==========================
All individuals who are neither singles nor couples according to above definitions.

---------------------------
BENEFITS COUNTERFACTUALS
---------------------------
ASSUMPTION #1:
For singles with student/disabled partners: partner’s benefits are held constant across choices.

ASSUMPTION #2(A):
Simulated benefits – EUROMOD calculates correctly.

ASSUMPTION #2(B1):
Not simulated, compatible with work, depend on YEM/LHW → set to zero.

ASSUMPTION #2(B2):
Not simulated, NOT compatible with work, do not depend on YEM/LHW → set to observed amount.

ASSUMPTION #2(B3):
Not simulated, NOT work-compatible, received in observed state → individual excluded from sample.

---------------------------
INCOME COUNTERFACTUALS
---------------------------
Workers: assume income equals major source (yem or yse).
If yem == yse: use yem.
Non-workers: assume income = employed income.

---------------------------
WAGE IMPUTATION METHODS
---------------------------
wage1 – predicted wages for everyone  
wage2 – predicted wages only for non-workers
*/

global file_log      "Input_output_data"

/**************************************************************************************************
* IMPORT DATA
**************************************************************************************************/

cd "$local_data"
pwd

capture log close
log using "$file_log", replace

clear all
set seed 1                                             // ensure replicability across runs

run "${do_files}/add_original_SILC_vars.do"

// capture confirm file "$em_original/$file_input.txt"     // original confirmation step (kept)
import delimited "$em_original/$file_input.txt", clear delim(tab)   // import raw SILC-based file

drop *_f                                  // important! They will mess up the ls alternatives if not dropped here

*=======================================================================
*                           CORRECT ANOMALIES
*=======================================================================

// individuals aged < 18 in couples
tab dag if dag < 18 & idpartner > 0
replace dag = 18 if dag < 18 & idpartner > 0    /* (3 real changes made) */
                                                // Ensures no minor is recorded as part of a couple
                                                // (required for microsim consistency)


*----------------------------------------------------------------------------------------------------------------
*   NUMBER OF CHILDREN IN HOUSEHOLD & DUMMIES FOR CHILDREN BY AGE GROUP
*----------------------------------------------------------------------------------------------------------------

// RMK: these flag names do not follow convention but variables are then dropped
gen byte ch    = (dag < 18)                      // child indicator, 0–17 inclusive
gen byte ch2   = (dag <= 2)                      // children aged 0–2
gen byte ch6   = (dag >= 3 & dag <= 6)           // children aged 3–6
gen byte ch12  = (dag >= 7 & dag <= 12)          // children aged 7–12
gen byte ch17  = (dag >= 13 & dag <= 17)         // children aged 13–17

sum ch*                                          // check plausibility of distribution of flags

sort idhh idperson
tempfile input                                   // create temporary storage of current dataset
save `input'


foreach childgr of varlist ch* {

    noi di "Children age group: `childgr'", _newline

    keep if `childgr' == 1                       // keep only children in this age group
    keep idhh idmother idfather dag              // keep identifiers and age for checks

    gen long temp_parent = idmother              // assign idmother as primary parent
    replace temp_parent = idfather if temp_parent==0  
                                                  // if mother missing, fallback to father
                                                  // !!! ISSUE: if both are 0 → temp_parent remains 0
                                                  //            This creates a pseudo-parent with id=0
                                                  //            Later dropped, but confirm intended behaviour.

    rename temp_parent idperson                  // parent becomes the “person” to whom child is assigned

    bysort idperson: gen int temp_n_`childgr' = _N   // count children in this age group per parent
    bysort idperson: gen int temp_d_`childgr' = (temp_n_`childgr' > 0)
                                                      // dummy: parent has ≥1 children in this group

    duplicates drop idperson, force                 // !!! FORCE deletes information without inspection  
                                                     //     Should check number dropped to avoid data loss

    drop dag idmother idfather                      // clean temporary dataset
    sort idhh idperson

    merge m:1 idhh idperson using `input'           // attach parent back to full dataset

    drop if _merge == 1                             // drop rows created artificially (idperson==0)
                                                     // but check counts in case of unintended loss
    drop _merge

    recode temp_n_`childgr' (. = 0)                 // set missing counts to zero
    recode temp_d_`childgr' (. = 0)                 // set missing dummies to zero

    save `input', replace                           // update working dataset for next iteration

}   // foreach childgr


drop ch*                                            // drop temporary raw child flags

label variable temp_d_ch    "1(children aged 0-17)"
label variable temp_d_ch2   "1(children aged 0-2)"
label variable temp_d_ch6   "1(children aged 3-6)"
label variable temp_d_ch12  "1(children aged 7-12)"
label variable temp_d_ch17  "1(children aged 13-17)"

label variable temp_n_ch    "number of children aged 0-17"
label variable temp_n_ch2   "number of children aged 0-2"
label variable temp_n_ch6   "number of children aged 3-6"
label variable temp_n_ch12  "number of children aged 7-12"
label variable temp_n_ch17  "number of children aged 13-17"

sum temp_d_ch* temp_n_ch*                          // quick sanity check of result


*----------------------------------------------------------------------------------
*     ASSIGN TO EACH PARTNER THE SUM OF HIS/HER CHILDREN & PARTNER'S CHILDREN
*     CREATE CHILDREN DUMMIES BY AGE GROUP
*----------------------------------------------------------------------------------

// Problem 1: children variables are attributed only to one parent
// Problem 2: partners might have different children variables

// Attribute the same values of children variables to the partner
foreach var of varlist temp_n_ch* temp_d_ch* {
    rename `var' partner_`var'                     // rename own child variables to partner_* to prepare for merge
}

keep idhh idpartner partner_temp_n_ch* partner_temp_d_ch*
rename idpartner idperson                         // !!! Replaces idperson with partner’s id
                                                  //     OK if idpartner=0 already dropped later
sort idhh idperson

// Merge the new dataset with the old one. Now each person has values for own kids and partner's kids
merge m:1 idhh idperson using `input'

drop if _merge == 1                                // individuals without partner (idpartner==0)
drop _merge


foreach var of varlist temp_n_ch* temp_d_ch* {

    assert `var' != .                              // ensures own child vars have no missing
                                                   // !!! may break if a parent genuinely has missing parent link

    recode partner_`var' (. = 0)                   // partners without children get a zero

    replace `var' = `var' + partner_`var'          // combine counts: own + partner's
                                                   // !!! POTENTIAL DOUBLE-COUNTING:
                                                   //     if the dataset incorrectly lists a child twice,
                                                   //     both parents might already have counted them
}

drop partner_temp_n_ch* partner_temp_d_ch*

egen test = rowtotal(temp_n_ch?*)                  // compute total children across age groups
noi di in y "Check number of children: these variables should be equal"
noi compare test temp_n_ch
assert test == temp_n_ch                           // ensures that age-specific counts sum to total
drop test

assert temp_d_ch != .                              // ensures no missing in dummies
                                                   // !!! If dataset contains no children at all,
                                                   //     this will still pass, but good to double check


*--------------------------------------------------------------------------------------------------------------------------
* Economic status
* 
*--------------------------------------------------------------------------------------------------------------------------
label var les "economic status"
label define temp_lab_les 0 " 0 - Pre-school" 1 " 1 - Farmer" 2 "2 - Employer or self-employed" 3 "3 - Employee" ///
4 "4 - Pensioner" 5 "5 - Unemployed" 6 "6 - Student" 7 "7 - Inactive" 8 "8 - Sick or disabled" 9 "9 - Other"
label values les temp_lab_les

*------------------------------------------------------------
*   Education
*------------------------------------------------------------

label define temp_lab_deh 0 "Not completed Primary" 1 "Primary" 2 "Lower Secondary" 3 "Upper Secondary" 4 "Post Secondary" 5 "Tertiary"
label values deh temp_lab_deh

gen byte temp_d_deh_L = (deh == 0 | deh == 1)
label variable temp_d_deh_L "1(low education (up to lower secondary School; deh = 0-1))"
gen byte temp_d_deh_M = (deh == 2 | deh == 3 | deh == 4)      
label variable temp_d_deh_M "1(middle education (up to post secondary school; deh = 2-4))"
gen byte temp_d_deh_H = (deh == 5)
label variable temp_d_deh_H "1(high education (tertiary school; deh = 5))"

*--------------------------------------------------------------------------------------------------------------------------
* Marital status
* 
*--------------------------------------------------------------------------------------------------------------------------
//DP: dms is useful to distinguish singles and previously partnered, otherwise living with a partner should prevail over civil status  
label var dms "marital status"
label def lab_dms 1 "single" 2 "married" 3 "separated" 4 "divorced" 5 "widowed"
label val dms lab_dms
*marital status dummies
tab dms   
gen partnered=(idpartner>0)
tab2 dms partnered

//Single never married 
gen temp_single=((dms==1) & idpartner==0) //define dummy of single
//gen temp_married=(dms==2)             //define dummy of married (this is not useful when the target is singles)
//gen temp_separated=(dms==3)                //define dummy of separated
//gen temp_divorced=(dms==4)             //define dummy of divorced
//gen temp_widowed=(dms==5)                //define dummy of widowed

//labels
label variable temp_single "single"
//label variable temp_married "married"
//label variable temp_separated "separated"
//label variable temp_divorced "divorced"
//label variable temp_widowed "widowed"


//Cohabiting/married
gen temp_partnered=( idpartner>0)     //(include all those who have a partner in hh)
label variable temp_partnered "partnered (married & partner in hh)"


//Separated / Divorced / Widowed to Previously partnered 
gen temp_pre_partnered=((dms==2|dms==3|dms==4|dms==5) & idpartner==0) //define dummy of previously partnered (this is not useful when the target is singles)
label variable temp_pre_partnered "previously partnered"

tab2 temp_single temp_partnered
tab2 temp_single temp_pre_partnered
tab2 temp_partnered temp_pre_partnered

*--------------------------------------------------------------------------------------------------------------------------
* Regions
* 
*--------------------------------------------------------------------------------------------------------------------------
/*
drgn1 = 2 if db040 == ""PL2""   
drgn1 = 4 if db040 == ""PL4""
drgn1 = 5 if db040 == ""PL5""
drgn1 = 6 if db040 == ""PL6""
drgn1 = 7 if db040 == ""PL7""
drgn1 = 8 if db040 == ""PL8""
drgn1 = 9 if db040 == ""PL9""

fre drgn1
					
		Freq.	Percent	Valid	Cum.
					
Valid	2	7479	14.79	14.79	14.79
	    4	8661	17.12	17.12	31.91
	    5	5131	10.14	10.14	42.05
	    6	8766	17.33	17.33	59.38
	    7	5285	10.45	10.45	69.83
	    8	9424	18.63	18.63	88.46
	    9	5835	11.54	11.54	100.00
	Total	50581	100.00	100.00	          
*/	


cap label define temp_lab_region ///
2	"South Poland" ///
4	"North Poland" ///
5	"West Poland" ///
6   "Lodz Voivodeship" ///
7   "Mazovia (except Warsaw)" ///
8   "Warsaw Capital Region" ///
9   "Swietokrzyskie Voivodeship"

label values drgn1 temp_lab_region
tab drgn1, gen(temp_region)

label variable temp_region1	"South Poland (Makroregion Południowy)"
label variable temp_region2	"North Poland (Makroregion Północny)" 
label variable temp_region3	"West Poland (Makroregion Południowo-Zachodni)"
label variable temp_region4	"Łódź Voivodeship"
label variable temp_region5	"Mazovia (except Warsaw)" 
label variable temp_region6	"Warsaw Capital Region"
label variable temp_region7	"Świętokrzyskie Voivodeship"

//fre drgn1
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
gen temp_drgn1 = drgn1
replace temp_drgn1 = 10 if inlist(temp_drgn1, 1, 3, 7, 8, 9)

lab var temp_drgn1 "Region"
lab define temp_drgn1 ///
    2 "Poludniowy (South)" ///
    4 "Polnocno-Zachodni (North-West)" ///
    5 "Poludniowo-Zachodni (South-West)" ///
    6 "Polnocy (North)" ///
    10 "Central + East (Central/East)", replace

lab values temp_drgn1 temp_drgn1

fre temp_drgn1

*dummies 
tab temp_drgn1, gen(temp_drgn1_)
lab var temp_drgn1_1 "South"
lab var temp_drgn1_2 "North-West"
lab var temp_drgn1_3 "South-West"
lab var temp_drgn1_4 "North"
lab var temp_drgn1_5 "Central + East"


*--------------------------------------------------------------------------------------------------------------------------
* Health status 
* 
*-------------------------------------------------------------------------------------------------------------------------
merge 1:1 idhh idperson using "temp_dhe.dta"
lab var dhe "Health status - imputed" 
fre dhe 
drop _merge 

*impute missing values
gen dagsq = dag^2
fre dag if missing(dhe) 

*ordered probit model
recode dgn dag dagsq drgn1 (-9=.) , gen (dgn2 dag2 dagsq2 drgn12)
fre dgn2 dag2 dagsq2 drgn12
xi: oprobit dhe i.dgn2 dag2 dagsq ib3.drgn12 if dhe < ., vce(robust)
predict pred_probs1 pred_probs2 pred_probs3 pred_probs4 pred_probs5, pr

*Identify the category with the highest predicted probability
egen max_prob = rowmax(pred_probs1 pred_probs2 pred_probs3 pred_probs4 pred_probs5)
*Impute missing values of dhe based on predicted probabilities
gen imp_dhe = .
replace imp_dhe = 1 if max_prob == pred_probs1
replace imp_dhe = 2 if max_prob == pred_probs2
replace imp_dhe = 3 if max_prob == pred_probs3
replace imp_dhe = 4 if max_prob == pred_probs4
replace imp_dhe = 5 if max_prob == pred_probs5

sum imp_dhe if missing(dhe) & dag>0 & dag<16
sum imp_dhe if !missing(dhe) & dag>0 & dag<16
sum imp_dhe if missing(dhe) & dag>=16
sum imp_dhe if !missing(dhe) & dag>=16

gen dhe_flag = missing(dhe)
lab var dhe_flag "=1 if dhe is imputed"
replace dhe = round(imp_dhe) if missing(dhe)

bys dhe_flag: fre dhe if dag<=16
bys dhe_flag: fre dhe if dag>16 

drop dgn2 dag2 dagsq2 drgn12 _Idgn2_1 pred_probs* max_prob imp_dhe
		
/***************************** ADULT CHILD FLAG *******************************/
/*
Decision 24/10/25: Agreed that to be an adult child the following conditions 
have to hold: 
    - 18+ years old
    - Not in a partnership 
    - Lives with at least one parent
    - Is at least 15 years younger than both of their parents
    - At least one parent in the hh is working age and not retired. 
*/

/* Retirement status */
gen retired = (les == 4)
fre retired

/* Statutory retirement age (PL: women 60, men 65) */
gen dagpns = 0
replace dagpns = 1 if dgn == 1 & dag >= 65
replace dagpns = 1 if dgn == 0 & dag >= 60
fre dagpns

/* Merge in mother/father information */
add_mother_variables "retired dagpns dag"
add_father_variables "retired dagpns dag"

/* NEW variable name */
gen temp_adultchildflag = 0

/* Adult child basic definition */
replace temp_adultchildflag = 1 if (idmother > 0 | idfather > 0) ///
    & dag >= 17 & idpartner <= 0    

/* Exclude if both parents retired or at statutory retirement age */
replace temp_adultchildflag = 0 if mother_dagpns == 1 & father_dagpns == .
replace temp_adultchildflag = 0 if mother_dagpns == . & father_dagpns == 1
replace temp_adultchildflag = 0 if mother_dagpns == 1 & father_dagpns == 1

replace temp_adultchildflag = 0 if mother_retired == 1 & father_retired == .
replace temp_adultchildflag = 0 if mother_retired == . & father_retired == 1
replace temp_adultchildflag = 0 if mother_retired == 1 & father_retired == 1

replace temp_adultchildflag = 0 if mother_retired == 1 & father_dagpns == 1
replace temp_adultchildflag = 0 if father_retired == 1 & mother_dagpns == 1

/* Exclude if both parents < 15 years older than child */
replace temp_adultchildflag = 0 if father_dag - dag <= 15 & mother_dag == .
replace temp_adultchildflag = 0 if father_dag == . & mother_dag - dag <= 15
replace temp_adultchildflag = 0 if father_dag - dag <= 15 & mother_dag - dag <= 15

//fre temp_adultchildflag

*--------------------------------------------------------------------------------------------------------------------------
* work history
* 
*--------------------------------------------------------------------------------------------------------------------------
/* liwwh： LABOUR MARKET : In work : Work history (length of time in months) Number of months spent in employment*/
replace liwwh =liwwh /12 
label variable liwwh "work history (length of time in years)"


*------------------------------------------------------------
* Hours worked
*------------------------------------------------------------
label variable lhw "labour market : hours worked per week"
fre lhw 
replace lhw = $max_lhw if lhw > $max_lhw //ensure lhw doesn't go above weekly max 168 minus 42=(6*7) hours of sleep.
//(0 real changes made)
fre lhw 

histogram lhw, percent bin(20)
histogram lhw if dgn==1, percent bin(20)
histogram lhw if dgn==0, percent bin(20)


*lhw discretisation

* chosen hrs bracket
*female hrs bracket
gen byte temp_bracket_0 = 0
replace temp_bracket_0 = 1 if lhw >= $min_hours_1_0 &dgn==0
replace temp_bracket_0 = 2 if lhw >= $min_hours_2_0 &dgn==0
replace temp_bracket_0 = 3 if lhw >= $min_hours_3_0 &dgn==0
//replace temp_bracket_0 = 4 if lhw >= $min_hours_4_0 &dgn==0

*male hrs bracket
gen byte temp_bracket_1 = 0
replace temp_bracket_1 = 1 if lhw >= $min_hours_1_1 &dgn==1
replace temp_bracket_1 = 2 if lhw >= $min_hours_2_1 &dgn==1
replace temp_bracket_1 = 3 if lhw >= $min_hours_3_1 &dgn==1
//replace temp_bracket_1 = 4 if lhw >= $min_hours_4_1 &dgn==1

*female discretised hrs 
gen temp_lhw_dobs_0=0
replace temp_lhw_dobs_0=20 if temp_bracket_0 == 1
replace temp_lhw_dobs_0=40 if temp_bracket_0 == 2
replace temp_lhw_dobs_0=50 if temp_bracket_0 == 3
//replace temp_lhw_dobs_0=50 if temp_bracket_0 == 4

//male discretised hrs 
gen temp_lhw_dobs_1=0
replace temp_lhw_dobs_1=20 if temp_bracket_1 == 1
replace temp_lhw_dobs_1=40 if temp_bracket_1 == 2
replace temp_lhw_dobs_1=50 if temp_bracket_1 == 3
//replace temp_lhw_dobs_1=50 if temp_bracket_1 == 4

fre temp_lhw_dobs_0 if dgn==0
fre temp_lhw_dobs_1 if dgn==1

*part-time hours 
gen pt = (lhw> 0 & lhw<.) * (lhw<40)
lab var pt "part-time employed (<40 hours per week)"

*full-time or more hours  
gen ft = (lhw>0 & lhw<.) * (lhw>=40)
lab var ft "full-time employed (>=40 hours per week)"

 
*------------------------------------------------------------
* ln(hourly wage)
*------------------------------------------------------------
//v6: define discritized hours of work as median hours in the choice category 
//update in v7: define discritized hours of work as a particular no. (close to mid-point)
*Update in v6: discritize lhw before generating hourly wages, in order to reduce the "division bias"
* wages	

/*
fre yempj //employment income, permanent job (employment contract)
fre yemtj //employment income, temporary job (different than employment contract)
fre yseag //self-employment income from agriculture
fre ysebs //self-employment income from business (non-agricultural)

. fre yemmy ysemy

yemmy
-----------------------------------------------------------
              |      Freq.    Percent      Valid       Cum.
--------------+--------------------------------------------
Valid   0     |      32870      64.98      64.98      64.98
        1     |        296       0.59       0.59      65.57
        2     |        255       0.50       0.50      66.07
        3     |        258       0.51       0.51      66.58
        4     |        278       0.55       0.55      67.13
        5     |        232       0.46       0.46      67.59
        6     |        313       0.62       0.62      68.21
        7     |        425       0.84       0.84      69.05
        8     |        438       0.87       0.87      69.92
        9     |        394       0.78       0.78      70.70
        10    |        389       0.77       0.77      71.47
        11    |        393       0.78       0.78      72.24
        12    |      14040      27.76      27.76     100.00
        Total |      50581     100.00     100.00           
-----------------------------------------------------------

ysemy
-----------------------------------------------------------
              |      Freq.    Percent      Valid       Cum.
--------------+--------------------------------------------
Valid   0     |      46447      91.83      91.83      91.83
        1     |        793       1.57       1.57      93.39
        2     |        167       0.33       0.33      93.72
        3     |        101       0.20       0.20      93.92
        4     |         87       0.17       0.17      94.10
        5     |         91       0.18       0.18      94.28
        6     |        102       0.20       0.20      94.48
        7     |         52       0.10       0.10      94.58
        8     |         68       0.13       0.13      94.72
        9     |         44       0.09       0.09      94.80
        10    |         67       0.13       0.13      94.93
        11    |        106       0.21       0.21      95.14
        12    |       2456       4.86       4.86     100.00
        Total |      50581     100.00     100.00           
-----------------------------------------------------------
*/

/*update 2/2/2021: Note: we do not know the divide of lhw between employment income and self-employed income
//gen temp_obs_wage=temp_y/(lhw*4.3)    //observed wages
replace temp_y=temp_y*12/yemmy if yem>0  //this adjustment magnifies the original total monthly income if yemmy<12 & yem>0
gen temp_obs_wage=temp_y/(lhw*4.3)    //observed wages
*/ 
/* Employment income in PL model 
yempj	INCOME : Employment: permanent
yemtj	INCOME : Employment temporary
yseag	INCOME : Self Employment : Agriculture
ysebs	INCOME : Self Employment : Business
*/

*------------------------------------------------------------
* Separate employment and self-employment income
*------------------------------------------------------------
gen temp_yem = yempj + yemtj    // monthly employment income
gen temp_yse = yseag + ysebs    // monthly self-employment income

sum temp_yem if temp_yem < 0    
sum temp_yse if temp_yse < 0    

*------------------------------------------------------------
* Adjust income to an annual-equivalent based on months worked
*------------------------------------------------------------
* not that in EUROMOD annual wages are divided by 12 so we need to multiply by 12 to get back to annual wages 
* This adjustment magnifies the income if yemmy < 12
replace temp_yem = temp_yem * 12 / yemmy if temp_yem > 0

* Same for self-employment income
replace temp_yse = temp_yse * 12 / ysemy if temp_yse > 0

* Combine adjusted income
gen temp_y = temp_yem + temp_yse

sum temp_y if temp_y < 0

* Calculate observed hourly wage 
gen temp_obs_wage=temp_y/(lhw*4.3)   

drop temp_yem temp_yse
*------------------------------------------------------------
* remove outliers of wages (1% and 99% percentiles)
*------------------------------------------------------------	
count if temp_obs_wage==0 &lhw>0
//drop if temp_y==0 & lhw>0  //drop obs who have lhw>0 but temp_y=0
//If wage is zero but hours > 0, treat them as non-workers (lhw = 0). Then remove wage (set to missing).
replace lhw=0 if temp_obs_wage==0 //DP: this allows to keep these obs in the sample  
replace temp_obs_wage=. if lhw==0 //(1,015 real changes made, 1,015 to missing)

duplicates report idperson  //count how many unique individuals there are
// still 50581 obs
su temp_obs_wage if lhw>0
su temp_obs_wage if lhw==0 

***Trim wages instead of chopping????
/*
gen keepwage=(inrange(temp_obs_wage, r(p1), r(p99)))   //dummy of temp_obs_wage within 1st-99th percentiles
keep if keepwage==1 |lhw==0   //keep workers with wage within 1st-99th percentiles and non-workers
drop keepwage
*/
centile temp_obs_wage if lhw>0,  centile(1 2 3 4 5 95 96 97 98 99)  
return list
replace temp_obs_wage = `r(c_1)' if temp_obs_wage <= `r(c_1)' & lhw>0
replace temp_obs_wage = `r(c_10)' if temp_obs_wage >= `r(c_10)' & temp_obs_wage != . & lhw>0

duplicates report idperson  //count how many unique individuals 
//still  50581  obs 
su temp_obs_wage if lhw>0 
/* Variable	Obs	Mean	Std. Dev.	Min	Max
					
temp_obs_w~e	20,864	22.55925	15.3138	.7588967	94.7368
*/
/*the mean looks about right. In 2019, the average gross monthly wage in Poland was approximately 4,918.17 PLN. Given that full-time employees typically work around 160 hours per month, 
this translates to an average gross hourly wage of about 30.74 PLN. The minimum gross monthly wage in 2019 was 2,250 PLN, equating to a minimum gross hourly rate of 14.70 PLN */

//Now restore temp_y using trimmed version of hourly wage 
replace temp_y = temp_obs_wage * lhw * 4.3
sum temp_y if temp_y>0
/*
Variable	Obs	Mean	Std. Dev.	Min	Max
					
temp_y	20,864	3930.793	2720.384	16.99983	30552.62
*/

//female ln(wage)
gen temp_lnwage=log(temp_y/(temp_lhw_dobs_0*4.3))	if temp_y>0	&dgn==0	//logarithm of hourly wage (yem: monthly employment income; temp_lhw_dobs: discritized Hours worked per week) 4.3=365/(7*12) 
//male ln(wage)
replace temp_lnwage=log(temp_y/(temp_lhw_dobs_1*4.3))	if temp_y>0	&dgn==1	//logarithm of hourly wage (yem: monthly employment income; temp_lhw_dobs: discritized Hours worked per week) 4.3=365/(7*12) 
label variable temp_lnwage "log(hourly wage)"
sum temp_obs_wage
sum temp_lnwage

//CHECK
assert lhw>0 if temp_y<.
su lhw if lhw<=0 &temp_y>0 //no obs 
//drop if lhw<=0 &temp_y>0 //to eliminate the above outliers
duplicates report idperson  //count how many unique individuals there are
//50581 obs 

*------------------------------------------------------------
* participation (binary: work and not work)
*------------------------------------------------------------	

gen temp_work=1 if temp_y<. //worker, either employed or self-employed
replace temp_work=0 if temp_y==.   //non-worder
fre temp_work 
*------------------------------------------------------------
* age squared
*------------------------------------------------------------
label variable dag "age"
	
gen temp_age2=dag^2 
label variable temp_age2 "age^2"
*------------------------------------------------------------
* household size
*------------------------------------------------------------
gen sizecount=1
bysort idhh:egen temp_hhsize=total(sizecount)
label variable temp_hhsize "household size"
drop sizecount


*=======================================================================
*           Target samples classification
*           
*=======================================================================
*keep working age people only (aged 16-75)
gen temp_workage=(dag>=16 & dag <=75)   		//dummy of working age (aged 16 to 75)
count if temp_workage==1

//@@@ DATA FILTER -"singles" @@@
add_partner_variables "les temp_workage dag" 
sum partner_*

gen temp_p_student=(partner_les==6) //dummy of having a student partner
label variable temp_p_student "1(with a student partner)"

gen temp_p_sick_dis=(partner_les==8) //dummy of having a sick or disabled partner
label variable temp_p_sick_dis "1(with a sick or disabled partner)"

gen temp_p_pensioner=(partner_les==4) //dummy of having partner being a pensioner (updated 3 July 2020)
label variable temp_p_sick_dis "1(with a pensioner partner)"

gen temp_p_workage=(partner_temp_workage==1) //dummy of having a partner with working age (aged 16-75)

gen temp_p_elderly=(partner_dag>=70) //dummy of having a partner aged 70 or above
label variable temp_p_elderly "1(with partner aged 70+)"

drop partner_les partner_temp_workage partner_dag

*--------------------------------------------------------------------------------------------------------------------------
* Inclusion in the "singles" sample: single member in the household, working age, not student (les!=6),  not sick or disabled (les!=8), not pensioner (les!=4)
* Note: temp_singles includes two mutually exclulsive groups: temp_singles_indep and temp_singles_dep
*--------------------------------------------------------------------------------------------------------------------------
//(updated 3 July 2020):les!=4 (not pensioner)
//update 16/2/2021 (idpartner>0&(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0|temp_p_pensioner==1))
gen byte temp_singles = ((idpartner==0|(idpartner>0&(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0|temp_p_pensioner==1))) & temp_workage == 1  & les != 6 & les != 8 & les != 4)  //dummy of target sample
//gen byte temp_singles = ((idpartner==0|temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0|temp_p_pensioner==1) & temp_workage == 1  & les != 6 & les != 8 & les != 4)  //dummy of target sample

label variable temp_singles "flag: Heckman sample (singles, working age, not student, not sick or disabled, not pensioner )"

tab les temp_singles
qui count if temp_singles==1
noi di in y "Target sample singles: number of observations, i.e  singles at working age, not student (les!=6), not sick or disabled (les!=8), not pensioner (les!=4): " r(N)  //Notice they can be of any marital status
// 10277 obs 
*Note that here the definition of "singles" is either those with no partners (not the same as marital status), or with a student partner or sick or disabled partner or out-of-working-age partner
tab les if temp_singles==1

*--------------------------------------------------------------------------------------------------------------------------
* Inclusion in the "singles_indep" sample: single member in the household, working age, not student (les!=6),  not sick or disabled (les!=8), not pensioner (les!=4)
* 
*--------------------------------------------------------------------------------------------------------------------------
gen temp_singles_indep=(idpartner==0 & temp_workage == 1  & les != 6 & les != 8 & les != 4)
label variable temp_singles "flag: Heckman sample (singles, working age, not student, not sick or disabled, not pensioner )"
duplicates report idperson  //count how many unique individuals there are
//50581 obs 

*--------------------------------------------------------------------------------------------------------------------------
* Inclusion in the "singles_dep" sample: within work age, not student (les!=6),  not sick or disabled (les!=8), not pensioner (les!=4),
*                                      with a partner who is student, sick or disabled, or out of working age 
* 
*--------------------------------------------------------------------------------------------------------------------------
//gen temp_singles_dep=(idpartner>0&(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0) & temp_workage == 1  & les != 6 & les != 8 & les != 4)
gen temp_singles_dep=(idpartner>0&(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0|temp_p_pensioner==1) & temp_workage == 1  & les != 6 & les != 8 & les != 4)  //update 16/2/2021
label variable temp_singles "flag: Heckman sample (with non-flexible partner, working age, not student, not sick or disabled, not pensioner )"
tab les if temp_singles_dep==1
//double check temp_singles includes two mutually exclulsive groups: temp_singles_indep and temp_singles_dep
assert temp_singles==temp_singles_indep+temp_singles_dep


//@@@ DATA FILTER -"couples" @@@
*--------------------------------------------------------------------------------------------------------------------------
* Inclusion in the sample: individuals in couples with both partners at working age, not student (les!=6),  not sick or disabled (les!=8)
* (Both partners are flexible in labour supply)
*--------------------------------------------------------------------------------------------------------------------------
//(updated 3 July 2020):les!=4 (not pensioner)
gen byte temp_couples = (idpartner>0 & temp_p_student==0 & temp_p_sick_dis==0 & temp_p_workage==1 &temp_p_pensioner==0 & temp_workage == 1  & les != 6 & les != 8& les != 4)  //dummy of target sample for "couples"
label variable temp_couples "flag: Heckman sample (couples, working age, not student, sick or disabled, not pensioner)"
tab les temp_couples
qui count if temp_couples==1
noi di in y "Target sample couples: number of observations, i.e  couples at working age, not student (les!=6), not sick or disabled (les!=8), not pensioner (les!=4): " r(N)  //Notice they can be of any marital status
tab les if temp_couples==1
tab dms	if temp_couples==1


//@@@ DATA FILTER -"not_flexible" @@@
gen temp_not_flexible=(temp_singles==0 &temp_couples==0)

tab lhw if temp_not_flexible==1
assert temp_singles+temp_couples+temp_not_flexible==1  //check the 3 categories are exclusive
su temp_singles_indep temp_singles_dep temp_couples temp_not_flexible
duplicates report idperson  //count how many unique individuals there are
// 50581  obs 

//check hours of work 
fre temp_lhw_dobs_0 if dgn==0 & temp_couples ==1 //24.3% with zero hours 
fre temp_lhw_dobs_1 if dgn==1 & temp_couples ==1 //8.6% with zero hours

fre temp_lhw_dobs_0 if dgn==0 & temp_singles_indep==1 //33.9% with zero hours 
fre temp_lhw_dobs_1 if dgn==1 & temp_singles_indep==1 //24.3% with zero hours

fre temp_lhw_dobs_0 if dgn==0 & temp_singles_dep==1 //48.2% with zero hours 
fre temp_lhw_dobs_1 if dgn==1 & temp_singles_dep==1 //26.5% with zero hours
/*In 2019, Poland's economic inactivity rates among individuals aged 15 to 64 were as follows:
Women: 37%
Men: 26%
This is higher than EU average but the data looks about right*/

save beforeheckman,replace

*------------------------------------------------------------
* Heckman wage equations for male and female, respectively
*------------------------------------------------------------	
use beforeheckman,clear
//drop if temp_obs_wage<14 & lhw>0  

duplicates report idperson  //count how many unique individuals there are

* dgn: female 0, male 1
*Assumption: people don't distinguish being employed and self-employed when making both participation choices and hours of work choices
	label variable temp_d_ch "1(children aged 0-17)"
	label variable temp_d_ch2 "1(children aged 0-2)"
	label variable temp_d_ch6 "1(children aged 3-6)"
	label variable temp_d_ch12 "1(children aged 7-12)"
	label variable temp_d_ch17 "1(children aged 13-17)"

	
	label variable temp_n_ch "number of children aged 0-17"
	label variable temp_n_ch2 "number of children aged 0-2"
	label variable temp_n_ch6 "number of children aged 3-6"
	label variable temp_n_ch12 "number of children aged 7-12"
	label variable temp_n_ch17 "number of children aged 13-17"
		
//add interactions of education with age 
gen temp_int_dehH_dag = temp_d_deh_H*dag 
gen temp_int_dehM_dag = temp_d_deh_M*dag 
gen temp_int_dehL_dag = temp_d_deh_L*dag 
lab var temp_int_dehH_dag "high education*age"
lab var temp_int_dehM_dag "medium education*age"
lab var temp_int_dehL_dag "low education*age"
	
//Add occupational class dummies =A collapsed versin of ISCO = skill level 
/*LABOUR MARKET : Occupation (ISCO 1-Digit)
 0 Armed forces
 1 Senior officials and managers
 2 Professionals
 3 Technicians and associate professionals
 4 Clerks
 5 Service and sales workers
 6 Skilled agricultural
 7 Craft and trades workers
 8 Plant and machine operators
 9 Elementary  occupations
 -1 Not Applicable*/
recode loc (1/2 = 4) (3=3) (4/8=2) (9=1) (0=0) (10=0) (-1=0), gen(loc2)
lab var loc2 "Occupation (skill level) - 4 categories + never worked" 
cap label define loc2  4 "level 4" 3 "level 3" 2 "level 2" 1 "level 1" 0 "never worked"
label values loc2 loc2 
fre loc2
gen temp_loc2_0 =(loc2==0)	
gen temp_loc2_1 =(loc2==1)
gen temp_loc2_2 =(loc2==2)	
gen temp_loc2_3 =(loc2==3)	
gen temp_loc2_4 =(loc2==4)
replace temp_lnwage=. if loc2==0	
lab var temp_loc2_1 "skill level 1 (ISCO 9)"
lab var temp_loc2_2 "skill level 2 (ISCO 4-8)"
lab var temp_loc2_3 "skill level 3 (ISCO 3)"
lab var temp_loc2_4 "skill level 4 (ISCO 1-2)"

bysort deh: sum temp_obs_wage
bysort loc2: sum temp_obs_wage

*health status dummies
tab dhe, gen (temp_dhe_)


//////////////////////////////////////////// 
/*Run wage regression for the whole sample*/
////////////////////////////////////////////

foreach gender in 0 1{ //beginning of gender loop 
//local gender=0 //for debugging
capture drop temp_lnw_`gender' 
capture drop temp_heckman_`gender'
capture drop temp_u_`gender'
capture drop temp_wage_`gender'
*note: region 6 is Warsaw 
*****************************************************************************************************************************************************
	local covariates "dag temp_age2  temp_loc2_2 temp_loc2_3 temp_loc2_4  liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6" 
	local selection "temp_single temp_pre_partnered temp_n_ch temp_d_ch2 dag temp_age2  temp_loc2_2 temp_loc2_3 temp_loc2_4 liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6" 
	//DP: part-time dummy had a positive effect on wages

heckman temp_lnwage `covariates' if dgn==`gender' & temp_not_flexible==0,	///
select(`selection')  twostep
*******************************************************************************************************************************************************

****************
*output tables *
****************
version 13																

matrix results = r(table)
matrix results = results[1..6,1...]'   //extract the first six rows of results, and then transpose results
if (`gender' == 0){
putexcel set "$results_wi/all/wage", sheet("female wage") replace
}
else{
putexcel set "$results_wi/all/wage", sheet("male wage") modify
}
*putexcel set gender`gender'_wages, replace
putexcel A3 = matrix(results, names) //names nformat(number_d2)  //write estimates in Excel from cell A3 (Stata 13)
//putexcel A3 = matrix(results), names nformat(number_d2)  //write in Excel from cell A3 (Stata 15)
putexcel A45=("sigma")
putexcel B45=(e(sigma))

putexcel A46=("rho")
putexcel B46=(e(rho))

//predicted log wage
predict temp_lnw_`gender', ycon                //predict logwage (ycon option: expected value of the dependent variable conditional on the dependent variable being observed)
gen temp_heckman_`gender'=( e(sample)==1)
			                    
sum temp_lnwage temp_lnw_`gender' if e(sample) & temp_lnwage != . // RMK: average predicted on observed only 
sum temp_lnwage temp_lnw_`gender' if e(sample) // RMK: average predicted on all 
			                    
sum temp_lnwage temp_lnw_`gender' if e(sample) & temp_lnwage != . // RMK: average predicted on observed only 
sum temp_lnwage temp_lnw_`gender' if e(sample) // RMK: average predicted on all 

//R^2
predict temp_lnw2_`gender' if e(sample), ycon
corr temp_lnwage temp_lnw2_`gender' if e(sample)
putexcel A48=("R^2")  
putexcel B48=(r(rho)^2)  //R^2 of wage eqn
gen temp_R2_lnwage_`gender'=r(rho)^2  //store this variable for writing to tex later
 
//RMSE of wage eqn
gen double temp_u_`gender' = temp_lnwage - temp_lnw_`gender' if e(sample)
sum temp_u_`gender'

putexcel A47=("RMSE of wage eqn")  
putexcel B47=(r(sd))  //sd of the residuals of wage eqn

global heckmanwage "`covariates'"
global heckmanselection "`covariates' temp_single temp_pre_partnered  temp_n_ch temp_d_ch2"

macro list heckmanwage
//display labels for covariates of wage eqn & label for the dependent variable temp_lnwage (log(hourly wage))
global n_wagevars: word count $heckmanwage   //count the number of vars in list $heckmanwage

local row = 4
foreach x of varlist $heckmanwage{
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
describe temp_lnwage
local ylabel: var label temp_lnwage
putexcel A`row' = ("`ylabel'")
local row = `row'+1
}
//for _cons
describe temp_lnwage
local ylabel: var label temp_lnwage
local n_wagevars=4+$n_wagevars
putexcel A`n_wagevars'= ("`ylabel'")


//display labels for covariates of selection eqn
macro list heckmanselection
local row = 4+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")

local row = `row'+1
}

//put in variance-covariance matrix of heckman
matrix results=e(V)
if (`gender' == 0){
putexcel set "$results_wi/all/wage_eV", sheet("female wage e(V)") replace
}
else{
putexcel set "$results_wi/all/wage_eV", sheet("male wage e(V)") modify
}
putexcel A3 = matrix(results, names) //names nformat(number_d2)  //write e(V) in Excel from cell A3 (Stata 13)

//display labels for e(V) matrix 
//Labels on the Excel rows (for e(V))
//-labels of covariates for wage eqn
local row = 5
foreach x of varlist $heckmanwage {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
local ylabel: var label temp_lnwage
putexcel A`row' = ("`ylabel'")
local row = `row'+1
}
//-(put the label of "temp_lnwage" for _cons in wage eqn)
local ylabel: var label temp_lnwage
local row=5+$n_wagevars
putexcel A`row'= ("`ylabel'")

//-labels of covariates for selection eqn
local row = 5+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
local row = `row'+1
}

//Labels on the Excel columns (for e(V))
//-labels of covariates for wage eqn

local col=3
foreach x of varlist $heckmanwage {
describe `x'
local varlabel : var label `x'
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel B`row' = ("`varlabel'")
local ylabel: var label temp_lnwage
putexcel `colname'3 = ("`ylabel'")
putexcel `colname'4 = ("`varlabel'")
local col = `col'+1
}
//-(put the label of "temp_lnwage" for _cons in wage eqn)
local ylabel: var label temp_lnwage
local col=3+$n_wagevars
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel `colname'3= ("`ylabel'")
//-labels of covariates for selection eqn

local col=3+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel `colname'4 = ("`varlabel'")
local col = `col'+1
}
//for e(v) matrix row, put "_cons" as the last covariate for selection eqn (strangely, without this, the last covariate label will be the last covariate of the wage eqn, in this case "Northern Ireland". this does not happen in column labels)
//Also strangely, the following commands do not work if I put them before displaying labels for e(V) columns
if (`gender' == 0){
putexcel set "$results_wi/all/wage_eV", sheet("female wage e(V)") modify
}
else{
putexcel set "$results_wi/all/wage_eV", sheet("male wage e(V)") modify
}
global n_selectionvars: word count $heckmanselection   //count the number of vars in list $heckmanselection
local n_selectionvars=5+$n_wagevars+1+$n_selectionvars
putexcel B`n_selectionvars'= ("_cons")
estimates save heckman_`gender',replace  //to save .ster files
eststo heckman_`gender'
estadd scalar R2=temp_R2_lnwage_`gender'
//esttab heckman_`gender' using s_heckman_`gender'.csv, replace  label cells(b(fmt(20)) t(par fmt(2))) plain   //for simulation (plain, including all digits)
esttab heckman_`gender' using heckman_`gender'.csv, replace label cells(b(star fmt(3)) t(par fmt(2))) stats(R2 N) //for writing csv (including at least three non-zero digits)
if (`gender' == 0){
esttab heckman_`gender' using heckman_women.tex, replace label cells(b(star fmt(3)) t(par fmt(2))) stats(R2 N) ///
title(Determinants of hourly wages, women aged 16-75. Source: Our elaboration on EUROMOD 2019 input data for Poland (EU-SILC)\label{tab:wage-F}) //for writing tex(including at least three non-zero digits)
}
else{
esttab heckman_`gender' using heckman_men.tex, replace label cells(b(star fmt(3)) t(par fmt(2))) stats(R2 N) ///
title(Determinants of hourly wages, men aged 16-75. Source: Our elaboration on EUROMOD 2019 input data for Poland (EU-SILC)\label{tab:wage-M}) //for writing tex(including at least three non-zero digits)
}

//capture drop R2
*anti-log transformation
//	gen double temp_u_`gender' = temp_lnwage - temp_lnw_`gender' if e(sample)  //this line was moved forward when entering Excel of RMSE
sum temp_u_`gender'

gen temp_wage_`gender' = exp(temp_lnw_`gender' + rnormal(0,r(sd)))  // to avoid retransformation bias


} //end of gender loop


esttab  heckman_1 heckman_0 using "$results_wi/all/heckman_10.tex", replace label cells(b(star fmt(3))) stats(R2 N) nonumbers mtitles("Men" "Women") ///
collabels(none) ///
title(Determinants of hourly wages, men and women aged 16-75. Source: Our elaboration on EUROMOD 2019 input data for Poland ///
\label{tab:wage-MF}) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing tex including female and male(including at least three non-zero digits)

esttab  heckman_1 heckman_0 using "$results_wi/all/heckman_10.csv", replace label cells(b(star fmt(3))) stats(R2 N) nonumbers mtitles("Men" "Women") ///
title(Determinants of hourly wages, men and women aged 16-75. Source: Our elaboration on EUROMOD 2019 input data for Poland ///
\label{tab:wage-MF}) ///
collabels(none) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing csv including female and male(including at least three non-zero digits)

gen temp_heckman=temp_heckman_0  //dummy of being included in the Heckman sample for female
replace temp_heckman=temp_heckman_1 if dgn==1  //dummy of being included in the Heckman sample for male

*=======================================================================
*           wage imputations
*=======================================================================

*------------------------------------------------------------
* // @@@ WAGE IMPUTATION METHOD #wage1 @@@
* make predicted wage=yivwg for everyone
*------------------------------------------------------------	

replace yivwg=temp_wage_0 if dgn==0   	     //For female, make predicted wage=yivwg (yivwg: name for predicted hourly wage in Euromod)
replace yivwg=temp_wage_1 if dgn==1   	     //For male, make predicted wage=yivwg (yivwg: name for predicted hourly wage in Euromod)

recode yivwg (.=-1)												//not-wages as -1

su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1& yivwg!=-1
bysort dgn:su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1 & yivwg!=-1

bysort dgn:su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1 & yivwg!=-1 & temp_obs_wage<14 



*********************************************
* Graph of predicted wage vs. observed wage *
*********************************************
**************
*scatterplot *
**************
foreach gender in 0 1 { //beginning of gender loop 
    twoway (scatter yivwg temp_obs_wage if dgn==`gender' & temp_heckman_`gender'==1 & yivwg!=.) (line temp_obs_wage temp_obs_wage if dgn==`gender') 
    graph export "$results_wi/all/wages_scatter_`gender'.png", as(png) replace
	
************    
*histogram *
************    
/*DP: In 2019, the average gross monthly wage in Poland was approximately 4,918.17 PLN. Given that full-time employees typically work around 160 hours per month,
this translates to an average gross hourly wage of about 30.74 PLN. The minimum gross monthly wage in 2019 was 2,250 PLN, equating to a minimum gross hourly rate of 14.70 PLN */
 
if (`gender' == 0) {
    twoway ///
    (histogram temp_obs_wage if dgn==`gender' & temp_heckman_`gender'==1 & temp_obs_wage != . & temp_obs_wage<100, ///
        percent color(green) start(0) width(1)) ///
    (histogram yivwg if dgn==`gender' & temp_heckman_`gender'==1 & temp_obs_wage != .& yivwg<100, ///
        percent fcolor(none) lcolor(black) start(0) width(1)) ///
    , legend(order(1 "observed" 2 "predicted")) ///
      subtitle("Women") ///
      ytitle("percent") ///
      xtitle("hourly wage, PLN") ///
      xscale(range(0 100))
}
else {
    twoway ///
    (histogram temp_obs_wage if dgn==`gender' & temp_heckman_`gender'==1 & temp_obs_wage != .& temp_obs_wage<100, ///
        percent color(green) start(0) width(1)) ///
    (histogram yivwg if dgn==`gender' & temp_heckman_`gender'==1 & temp_obs_wage != .& yivwg<100, ///
        percent fcolor(none) lcolor(black) start(0) width(1)) ///
    , legend(order(1 "observed" 2 "predicted")) ///
      subtitle("Men") ///
      ytitle("percent") ///
      xtitle("hourly wage, PLN") ///
      xscale(range(0 100))
}
graph export "$results_wi/all/obs_wage_`gender'.png", as(png) replace
 } //end of gender loop

 
duplicates report 

save afterheckman,replace

////////////////////////////////////////////////////////////////////// 
/*Decision: run wage regression separately for low and high earners */
//////////////////////////////////////////////////////////////////////
/*DP: In 2019, the average gross monthly wage in Poland was approximately 4,918.17 PLN. Given that full-time employees typically work around 160 hours per month, 
this translates to an average gross hourly wage of about 30.74 PLN. The minimum gross monthly wage in 2019 was 2,250 PLN, equating to a minimum gross hourly rate of 14.70 PLN 
*/

histogram temp_obs_wage if deh<3, percent
histogram temp_obs_wage if deh>=3, percent

histogram temp_obs_wage if loc2==1, percent
histogram temp_obs_wage if loc2==2, percent
histogram temp_obs_wage if loc2==3, percent
histogram temp_obs_wage if loc2==4, percent

histogram temp_obs_wage , percent
histogram temp_obs_wage if temp_obs_wage<10, percent
histogram temp_obs_wage if temp_obs_wage>=10, percent

//low wages group
gen group1 = .
replace group1 = 1 if temp_obs_wage>0 & temp_obs_wage<10
replace group1 = 0 if temp_obs_wage==.
fre group1

//high wages group 
gen group2 = . 
replace group2 = 1 if temp_obs_wage>=10 & temp_obs_wage<. 
replace group2 = 0 if temp_obs_wage==.
fre group2  

gen nonworking = temp_obs_wage==.  
fre group1 group2 nonworking 

histogram temp_obs_wage if group1<., percent
histogram temp_obs_wage if group2<., percent
 
****************************************************************************************************************
*** 1) Heckman estimated on the sub-sample of individuals with low wages   
****************************************************************************************************************

foreach gender in 0 1{ //loop for women and men 
*local gender=0 //for debugging
capture drop temp_lnw_`gender'_group1 
capture drop temp_heckman_`gender'_group1
capture drop temp_u_`gender'_group1
capture drop temp_wage_`gender'_group1

************************************************************************************************************************************************************
    local covariates "dag temp_age2  temp_loc2_2 temp_loc2_3 temp_loc2_4  liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag
	local selection "temp_single temp_pre_partnered temp_n_ch temp_d_ch2 dag temp_age2  temp_loc2_2 temp_loc2_3 temp_loc2_4 liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag

	heckman temp_lnwage `covariates' if dgn==`gender' & temp_not_flexible==0 & group1<.,	///
select(`selection')  twostep
************************************************************************************************************************************************************

****************
*output tables *
****************
version 13																

matrix results = r(table)
matrix results = results[1..6,1...]'   //extract the first six rows of results, and then transpose results
if (`gender' == 0){
putexcel set "$results_wi/wage", sheet("female wage_group1") replace
}
else{
putexcel set "$results_wi/wage", sheet("male wage_group1") modify
}
*putexcel set hu_gender`gender'_wages, replace
putexcel A3 = matrix(results, names) //names nformat(number_d2)  //write estimates in Excel from cell A3 (Stata 13)
//putexcel A3 = matrix(results), names nformat(number_d2)  //write in Excel from cell A3 (Stata 15)
putexcel A45=("sigma")
putexcel B45=(e(sigma))

putexcel A46=("rho")
putexcel B46=(e(rho))

////////////////////////////////////////predicted log wage////////////////////////////////////////////////////////////////////////////////////////////////////////////////
predict temp_lnw_`gender'_group1, ycon     //predict logwage (ycon option: expected value of the dependent variable conditional on the dependent variable being observed)
gen temp_heckman_`gender'_group1=( e(sample)==1)
			                    
sum temp_lnwage temp_lnw_`gender'_group1 if e(sample) & temp_lnwage != . // RMK: average predicted on observed only 
sum temp_lnwage temp_lnw_`gender'_group1 if e(sample) // RMK: average predicted on all 
			                    
gen double temp_u_`gender'_group1 = temp_lnwage - temp_lnw_`gender'_group1 if e(sample)
sum temp_u_`gender'_group1

//////////////////////////////////////predicted probability of being employed////////////////////////////////////////////////////////////////////////////////////////////// 
* Predict the linear prediction (xbsel) from the selection equation
predict xbsel_`gender'_group1, xbsel
*Convert the linear prediction into a probability of being employed using the normal CDF
gen temp_pr_`gender'_group1 = normal(xbsel_`gender'_group1)
sum temp_pr_`gender'_group1 if e(sample)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

putexcel A47=("RMSE of wage eqn")  
putexcel B47=(r(sd))  //sd of the residuals of wage eqn

global heckmanwage "`covariates'"
global heckmanselection "`selection'"

macro list heckmanwage
//display labels for covariates of wage eqn & label for the dependent variable temp_lnwage (log(hourly wage))
global n_wagevars: word count $heckmanwage   //count the number of vars in list $heckmanwage

local row = 4
foreach x of varlist $heckmanwage{
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
describe temp_lnwage
local ylabel: var label temp_lnwage
putexcel A`row' = ("`ylabel'")
local row = `row'+1
}
//for _cons
describe temp_lnwage
local ylabel: var label temp_lnwage
local n_wagevars=4+$n_wagevars
putexcel A`n_wagevars'= ("`ylabel'")


//display labels for covariates of selection eqn
macro list heckmanselection
local row = 4+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")

local row = `row'+1
}


//put in variance-covariance matrix of heckman
matrix results=e(V)
if (`gender' == 0){
putexcel set "$results_wi/wage_eV", sheet("female wage e(V)_group1") replace
}
else{
putexcel set "$results_wi/wage_eV", sheet("male wage e(V)_group1") modify
}
putexcel A3 = matrix(results, names) //names nformat(number_d2)  //write e(V) in Excel from cell A3 (Stata 13)

//display labels for e(V) matrix 
//Labels on the Excel rows (for e(V))
//-labels of covariates for wage eqn
local row = 5
foreach x of varlist $heckmanwage {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
local ylabel: var label temp_lnwage
putexcel A`row' = ("`ylabel'")
local row = `row'+1
}
//-(put the label of "temp_lnwage" for _cons in wage eqn)
local ylabel: var label temp_lnwage
local row=5+$n_wagevars
putexcel A`row'= ("`ylabel'")

//-labels of covariates for selection eqn
local row = 5+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
local row = `row'+1
}

//Labels on the Excel columns (for e(V))
//-labels of covariates for wage eqn

local col=3
foreach x of varlist $heckmanwage {
describe `x'
local varlabel : var label `x'
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel B`row' = ("`varlabel'")
local ylabel: var label temp_lnwage
putexcel `colname'3 = ("`ylabel'")
putexcel `colname'4 = ("`varlabel'")
local col = `col'+1
}
//-(put the label of "temp_lnwage" for _cons in wage eqn)
local ylabel: var label temp_lnwage
local col=3+$n_wagevars
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel `colname'3= ("`ylabel'")
//-labels of covariates for selection eqn

local col=3+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel `colname'4 = ("`varlabel'")
local col = `col'+1
}
//for e(v) matrix row, put "_cons" as the last covariate for selection eqn (strangely, without this, the last covariate label will be the last covariate of the wage eqn, in this case "Northern Ireland". this does not happen in column labels)
//Also strangely, the following commands do not work if I put them before displaying labels for e(V) columns
if (`gender' == 0){
putexcel set "$results_wi/wage_eV", sheet("female wage e(V)_group1") modify 
}
else{
putexcel set "$results_wi/wage_eV", sheet("male wage e(V)_group1") modify
}
global n_selectionvars: word count $heckmanselection   //count the number of vars in list $heckmanselection
local n_selectionvars=5+$n_wagevars+1+$n_selectionvars
putexcel B`n_selectionvars'= ("_cons")
estimates save "$results_wi/heckman_`gender'_group1",replace  //to save .ster files


eststo heckman_`gender'_group1
//esttab heckman_`gender' using s_heckman_`gender'.csv, replace  label cells(b(fmt(20)) t(par fmt(2))) plain   //for simulation (plain, including all digits)
esttab heckman_`gender'_group1 using "$results_wi/heckman_`gender'_group1.csv", replace label cells(b(star fmt(a3)) t(par fmt(2)))  //for writing (including at least three non-zero digits)

*anti-log transformation
//	gen double temp_u_`gender' = temp_lnwage - temp_lnw_`gender' if e(sample)  //this line was moved forward when entering Excel of RMSE
sum temp_u_`gender'_group1

gen temp_wage_`gender'_group1 = exp(temp_lnw_`gender'_group1 + rnormal(0,r(sd)))  // to avoid retransformation bias

//R^2
predict temp_lnw2_`gender'_group1 if e(sample), ycon
corr temp_lnwage temp_lnw2_`gender'_group1 if e(sample)
putexcel A48=("R^2")  
putexcel B48=(r(rho)^2)  //R^2 of wage eqn
gen temp_R2_lnwage_`gender'_group1=r(rho)^2  //store this variable for writing to tex later

estadd scalar R2=temp_R2_lnwage_`gender'_group1

} //end of a loop for gender 


//esttab heckman_0 heckman_1 using heckman_01.csv, replace label cells(b(star fmt(a3)) t(par fmt(2)))  //for writing (including at least three non-zero digits)
esttab  heckman_1_group1 heckman_0_group1 using "$results_wi/heckman_10_group1.tex", replace label cells(b(star fmt(3))) stats(R2 N) nonumbers mtitles("Men" "Women") ///
collabels(none) ///
title(Determinants of hourly wages, men and women aged 16-75 (group 1: low wages). Source: Our elaboration on PL EU-SILC input data for 2019 ///
\label{tab:wage-MF}) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing tex including female and male(including at least three non-zero digits)

esttab  heckman_1_group1 heckman_0_group1 using "$results_wi/heckman_10_group1.csv", replace label cells(b(star fmt(3))) stats(R2 N) nonumbers mtitles("Men" "Women") ///
title(Determinants of hourly wages, men and women aged 16-75 (group 1: low wages). Source: Our elaboration on PL EU-SILC input data for 2019 ///
\label{tab:wage-MF}) ///
collabels(none) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing csv including female and male(including at least three non-zero digits)


//dummy of being included in the Heckman sample
gen     temp_heckman_group1=temp_heckman_0_group1 if dgn==0 & group1<.   
replace temp_heckman_group1=temp_heckman_1_group1 if dgn==1 & group1<.   




***********************************************************************************************************
*** 2) Heckman estimated on the sub-sample of individuals with high wages  
***    Wage equation controls for lagged wage
***********************************************************************************************************
foreach gender in 0 1{ //loop for women and men 
*local gender=0 //for debugging
capture drop temp_lnw_`gender'_group2 
capture drop temp_heckman_`gender'_group2
capture drop temp_u_`gender'_group2
capture drop temp_wage_`gender'_group2


************************************************************************************************************************************************************
    local covariates "dag temp_age2  temp_loc2_2 temp_loc2_3 temp_loc2_4  liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag
	local selection "temp_single temp_pre_partnered temp_n_ch temp_d_ch2 dag temp_age2  temp_loc2_2 temp_loc2_3 temp_loc2_4 liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag

	local filter "dgn==`gender' & temp_not_flexible==0 & group2<." 
	heckman temp_lnwage `covariates' if `filter', select(`selection')  twostep
************************************************************************************************************************************************************

****************
*output tables *
****************
version 13																

matrix results = r(table)
matrix results = results[1..6,1...]'   //extract the first six rows of results, and then transpose results
if (`gender' == 0){
putexcel set "$results_wi/wage", sheet("female wage_group2") modify
}
else{
putexcel set "$results_wi/wage", sheet("male wage_group2") modify
}
*putexcel set hu_gender`gender'_wages, replace
putexcel A3 = matrix(results, names) //names nformat(number_d2)  //write estimates in Excel from cell A3 (Stata 13)
//putexcel A3 = matrix(results), names nformat(number_d2)  //write in Excel from cell A3 (Stata 15)
putexcel A45=("sigma")
putexcel B45=(e(sigma))

putexcel A46=("rho")
putexcel B46=(e(rho))

//////////////////////////////////////predicted log wage//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
predict temp_lnw_`gender'_group2, ycon     //predict logwage (ycon option: expected value of the dependent variable conditional on the dependent variable being observed)
gen temp_heckman_`gender'_group2=( e(sample)==1)
			                    
sum temp_lnwage temp_lnw_`gender'_group2 if e(sample) & temp_lnwage != . // RMK: average predicted on observed only 
sum temp_lnwage temp_lnw_`gender'_group2 if e(sample) // RMK: average predicted on all 
			                    
gen double temp_u_`gender'_group2 = temp_lnwage - temp_lnw_`gender'_group2 if e(sample)
sum temp_u_`gender'_group2

//////////////////////////////////////predicted probability of being employed////////////////////////////////////////////////////////////////////////////////////////////// 
* Predict the linear prediction (xbsel) from the selection equation
predict xbsel_`gender'_group2, xbsel
*Convert the linear prediction into a probability of being employed using the normal CDF
gen temp_pr_`gender'_group2 = normal(xbsel_`gender'_group2)
sum temp_pr_`gender'_group2 if e(sample)
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

putexcel A47=("RMSE of wage eqn")  
putexcel B47=(r(sd))  //sd of the residuals of wage eqn

global heckmanwage "`covariates'"
global heckmanselection "`selection'"

macro list heckmanwage
//display labels for covariates of wage eqn & label for the dependent variable temp_lnwage (log(hourly wage))
global n_wagevars: word count $heckmanwage   //count the number of vars in list $heckmanwage

local row = 4
foreach x of varlist $heckmanwage{
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
describe temp_lnwage
local ylabel: var label temp_lnwage
putexcel A`row' = ("`ylabel'")
local row = `row'+1
}
//for _cons
describe temp_lnwage
local ylabel: var label temp_lnwage
local n_wagevars=4+$n_wagevars
putexcel A`n_wagevars'= ("`ylabel'")


//display labels for covariates of selection eqn
macro list heckmanselection
local row = 4+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")

local row = `row'+1
}


//put in variance-covariance matrix of heckman
matrix results=e(V)
if (`gender' == 0){
putexcel set "$results_wi/wage_eV", sheet("female wage e(V)_group2") modify
}
else{
putexcel set "$results_wi/wage_eV", sheet("male wage e(V)_group2") modify
}
putexcel A3 = matrix(results, names) //names nformat(number_d2)  //write e(V) in Excel from cell A3 (Stata 13)

//display labels for e(V) matrix 
//Labels on the Excel rows (for e(V))
//-labels of covariates for wage eqn
local row = 5
foreach x of varlist $heckmanwage {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
local ylabel: var label temp_lnwage
putexcel A`row' = ("`ylabel'")
local row = `row'+1
}
//-(put the label of "temp_lnwage" for _cons in wage eqn)
local ylabel: var label temp_lnwage
local row=5+$n_wagevars
putexcel A`row'= ("`ylabel'")

//-labels of covariates for selection eqn
local row = 5+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
local row = `row'+1
}

//Labels on the Excel columns (for e(V))
//-labels of covariates for wage eqn

local col=3
foreach x of varlist $heckmanwage {
describe `x'
local varlabel : var label `x'
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel B`row' = ("`varlabel'")
local ylabel: var label temp_lnwage
putexcel `colname'3 = ("`ylabel'")
putexcel `colname'4 = ("`varlabel'")
local col = `col'+1
}
//-(put the label of "temp_lnwage" for _cons in wage eqn)
local ylabel: var label temp_lnwage
local col=3+$n_wagevars
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel `colname'3= ("`ylabel'")
//-labels of covariates for selection eqn

local col=3+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel `colname'4 = ("`varlabel'")
local col = `col'+1
}
//for e(v) matrix row, put "_cons" as the last covariate for selection eqn (strangely, without this, the last covariate label will be the last covariate of the wage eqn, in this case "Northern Ireland". this does not happen in column labels)
//Also strangely, the following commands do not work if I put them before displaying labels for e(V) columns
if (`gender' == 0){
putexcel set "$results_wi/wage_eV", sheet("female wage e(V)_group2") modify
}
else{
putexcel set "$results_wi/wage_eV", sheet("male wage e(V)_group2") modify
}
global n_selectionvars: word count $heckmanselection   //count the number of vars in list $heckmanselection
local n_selectionvars=5+$n_wagevars+1+$n_selectionvars
putexcel B`n_selectionvars'= ("_cons")
estimates save "$results_wi/heckman_`gender'_group2",replace  //to save .ster files


eststo heckman_`gender'_group2
//esttab heckman_`gender' using s_heckman_`gender'.csv, replace  label cells(b(fmt(20)) t(par fmt(2))) plain   //for simulation (plain, including all digits)
esttab heckman_`gender'_group2 using "$results_wi/heckman_`gender'_group2.csv", replace label cells(b(star fmt(a3)) t(par fmt(2)))  //for writing (including at least three non-zero digits)

*anti-log transformation
//	gen double temp_u_`gender' = temp_lnwage - temp_lnw_`gender' if e(sample)  //this line was moved forward when entering Excel of RMSE
sum temp_u_`gender'_group2

gen temp_wage_`gender'_group2 = exp(temp_lnw_`gender'_group2 + rnormal(0,r(sd)))  // to avoid retransformation bias

//R^2
predict temp_lnw2_`gender'_group2 if e(sample), ycon
corr temp_lnwage temp_lnw2_`gender'_group2 if e(sample)
putexcel A48=("R^2")  
putexcel B48=(r(rho)^2)  //R^2 of wage eqn
gen temp_R2_lnwage_`gender'_group2=r(rho)^2  //store this variable for writing to tex later

estadd scalar R2=temp_R2_lnwage_`gender'_group2

} //end of a loop for gender 

//esttab heckman_0 heckman_1 using heckman_01.csv, replace label cells(b(star fmt(a3)) t(par fmt(2)))  //for writing (including at least three non-zero digits)
esttab  heckman_1_group2 heckman_0_group2 using "$results_wi/heckman_10_group2.tex", replace label cells(b(star fmt(3))) stats(R2 N) nonumbers mtitles("Men" "Women") ///
collabels(none) ///
title(Determinants of hourly wages, men and women aged 16-75 (group 2: normal wages). Source: Our elaboration on PL EU-SILC input data for 2019 ///
\label{tab:wage-MF}) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing tex including female and male(including at least three non-zero digits)

esttab  heckman_1_group2 heckman_0_group2 using "$results_wi/heckman_10_group2.csv", replace label cells(b(star fmt(3))) stats(R2 N) nonumbers mtitles("Men" "Women") ///
title(Determinants of hourly wages,  men and women aged 16-75 (group2: normal wages). Source: Our elaboration on PL EU-SILC input data for 2019 ///
\label{tab:wage-MF}) ///
collabels(none) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing csv including female and male(including at least three non-zero digits)

//dummy of being included in the Heckman sample 
gen    temp_heckman_group2 =temp_heckman_0_group2 if dgn==0 & group2<. 
replace temp_heckman_group2=temp_heckman_1_group2 if dgn==1 & group2<.  

*check sensitivity of wage predictions 
sum temp_wage_0_group1 temp_wage_0_group2 if dgn==0 & temp_obs_wage>=800 & temp_obs_wage<900
sum temp_wage_0_group1 temp_wage_0_group2 if dgn==0 & temp_obs_wage>=900 & temp_obs_wage<1000

sum temp_wage_1_group1 temp_wage_1_group2 if dgn==1 & temp_obs_wage>=800 & temp_obs_wage<900
sum temp_wage_1_group1 temp_wage_1_group2 if dgn==1 & temp_obs_wage>=900 & temp_obs_wage<1000


*===============================================================================
*           Output coefficients and VC Matrix to Excel  
*===============================================================================

**********************************************************
* Sample: Working age (16-75) women with low wages  
* DV: Log gross hourly wage 
**********************************************************
* Prep storage 
capture drop pred lwage_hour_hat wage_hour_hat esample pred_hourly_wage
gen lwage_hour_hat = .
gen wage_hour_hat = .
gen esample = .
gen pred_hourly_wage = .


************************************************************************************************************************************************************
local covariates "dag temp_age2 temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_drgn1_2 temp_drgn1_3 temp_drgn1_4 temp_drgn1_5" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag
local selection "temp_partnered temp_n_ch temp_d_ch2 dag temp_age2 temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_drgn1_2 temp_drgn1_3 temp_drgn1_4 temp_drgn1_5" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag

local filter "dgn==0 & temp_not_flexible==0 & group1<." 
heckman temp_lnwage `covariates' if `filter', select(`selection')  twostep

/***************************************************************************/
* Eigenvalue stability check 

* Extract variance-covariance matrix
matrix V = e(V)

* Preserve data state
preserve

* Export V to dataset
clear
svmat double V

* Drop zero rows and columns
forvalues r = 1/2 {
    egen rowsum = rowtotal(*)
    drop if rowsum == 0
    drop rowsum
    xpose, clear
}

* Recreate trimmed VCV matrix
mkmat *, matrix(V_trimmed)

restore

* Eigen decomposition
matrix symeigen X lambda = V_trimmed

* Largest eigenvalue
scalar max_eig = lambda[1,1]

* Smallest-to-largest eigenvalue ratio
scalar min_ratio = lambda[1, colsof(lambda)] / max_eig

* Check 1: near singularity
if max_eig < 1.0e-12 {
    display as error "CRITICAL ERROR: Heckman VCV near singular"
    display as error "Max eigenvalue = " max_eig
    exit 999
}

* Check 2: ill-conditioning
if min_ratio < 1.0e-12 {
    display as error "ERROR: Heckman VCV ill-conditioned"
    display as error "Min/Max eigenvalue ratio = " min_ratio
    exit 506
}

display "VCV stability check passed"
display "Max eigenvalue: " max_eig
display "Min/Max ratio: " min_ratio

/***************************************************************************/
  
* Obtain predicted values (log wage) with selection correction

predict pred if `filter', ycond  // ycond -> include IMR in prediction to account for selection into employment
replace lwage_hour_hat = pred if `filter'

gen in_sample_w1 = e(sample)	

* Correct bias when transforming from log to levels 
cap drop epsilon
gen epsilon = rnormal()*e(sigma) 

replace pred_hourly_wage = exp(lwage_hour_hat + epsilon) if `filter' 


twoway (hist temp_obs_wage if `filter', width(0.5) ///
	lcolor(gs12) fcolor(gs12)) ///
	(hist pred_hourly_wage if `filter' & (!missing(pred_hourly_wage)), width(0.5) ///
		fcolor(none) lcolor(red)), ///
	title("Gross Hourly Wage (Level)") ///
	subtitle("Women, low wages") ///
	xtitle("PLN") ///
	legend(lab(1 "EU-SILC") lab(2 "Prediction")) ///
	note("Notes: Sample condition `filter'", size(vsmall))	

graph export "${results_wi}/W1_hist.png", replace 

graph drop _all 

sum temp_obs_wage if `filter' [aw=dwt]
sum pred_hourly_wage if `filter' & (!missing(pred_hourly_wage)) [aw=dwt]
  
 
* Save sample validation 
save "${local_data}/W1_sample", replace 
	
cap drop pred epsilon	
 
* Formatted results
* Clean up matrix of estimates 
* Note: Zeros values are eliminated 
matrix b = e(b)	
matrix V = e(V)

* Store variance-covariance matrix 
preserve

putexcel set "${results_wi}/var_cov", sheet("var_cov") replace
putexcel A1 = matrix(V)

import excel "${results_wi}/var_cov", sheet("var_cov") clear

describe
local no_vars = `r(k)'	
	
forvalues i = 1/2 {
	egen row_sum = rowtotal(*)
	drop if row_sum == 0 
	drop row_sum
	xpose, clear	
}	
	
mkmat v*, matrix(var)	

* Second stage
putexcel set "${results_wi}/reg_wages_raw", sheet("W1_raw") replace
putexcel C2 = matrix(var)
		
restore	

* Store estimated coefficients 
* Initialize a counter for non-zero coefficients
local non_zero_count = 0
//local names : colnames b

* Loop through each element in `b` to count non-zero coefficients
forvalues i = 1/`no_vars' {
    if (b[1, `i'] != 0) {
        local non_zero_count = `non_zero_count' + 1
    }
}

* Create a new row vector to hold only non-zero coefficients
matrix nonzero_b = J(1, `non_zero_count', .)

* Populate nonzero_b with non-zero coefficients from b
local index = 1
forvalues i = 1/`no_vars' {
    if (b[1, `i'] != 0) {
        matrix nonzero_b[1, `index'] = b[1, `i']
        local index = `index' + 1
    }
}

putexcel set "${results_wi}/reg_wages_raw", sheet("W1_raw") modify 
putexcel B2 = matrix(nonzero_b') //, names nformat(number_d2) 

preserve

import excel "${results_wi}/reg_wages_raw", sheet("W1_raw") /*firstrow*/  ///
	clear
ds 

//define which cells are to be dropped 
drop if C == 0 & D==0 // UPDATE 
//drop A 
drop S-AK // UPDATE


mkmat *, matrix(Women2)
matrix list Women2

putexcel set "${results_wi}/reg_wages", sheet("W1") modify   
putexcel B2 = matrix(Women2)

restore 


* Labelling 
putexcel set "${results_wi}/reg_wages", sheet("W1") modify 

local var_list Dag Dag_sq ///
Deh_c3_Medium Deh_c3_High ///
Deh_c3_Medium_Dag Deh_c3_High_Dag ///
Liwwh ///
Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
PL4 PL5 PL6 PL10 ///
Constant InverseMillsRatio

	
putexcel A1 = ("REGRESSOR")
putexcel B1 = ("COEFFICIENT")

local i = 1 	
foreach var in `var_list' {
	local ++i
	
	putexcel A`i' = ("`var'")
	
} 	

local i = 2 	
foreach var in `var_list' {
    local ++i

    if `i' <= 26 {
        local letter = char(64 + `i')  // Convert 1=A, 2=B, ..., 26=Z
        putexcel `letter'1 = ("`var'")
    }
    else {
        local first = char(64 + int((`i' - 1) / 26))  // First letter: A-Z
        local second = char(65 + mod((`i' - 1), 26)) // Second letter: A-Z
        putexcel `first'`second'1 = ("`var'")  // Correctly places AA-ZZ
    }
}


* First stage
preserve

import excel "${results_wi}/reg_wages_raw", sheet("W1_raw") /*firstrow*/ ///
	clear
ds 

drop if S== 0 // UPDATE
//drop A 
drop C-R // UPDATE
drop AL // UPDATE


mkmat *, matrix(Women2)
matrix list Women2

putexcel set "${results_wi}/reg_employment_selection", sheet("W1-sel") modify   
putexcel B2 = matrix(Women2)

restore 

* Labelling 
putexcel set "${results_wi}/reg_employment_selection", sheet("W1-sel") modify 
	
local var_list Dcpst_Partnered Children D_Children2 ///
Dag Dag_sq ///
Deh_c3_Medium Deh_c3_High ///
Deh_c3_Medium_Dag Deh_c3_High_Dag ///
Liwwh ///
Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
PL4 PL5 PL6 PL10 ///
Constant 

putexcel A1 = ("REGRESSOR")
putexcel B1 = ("COEFFICIENT")

local i = 1 	
foreach var in `var_list' {
	local ++i
	
	putexcel A`i' = ("`var'")
	
} 	

local i = 2 	
foreach var in `var_list' {
    local ++i

    if `i' <= 26 {
        local letter = char(64 + `i')  // Convert 1=A, 2=B, ..., 26=Z
        putexcel `letter'1 = ("`var'")
    }
    else {
        local first = char(64 + int((`i' - 1) / 26))  // First letter: A-Z
        local second = char(65 + mod((`i' - 1), 26)) // Second letter: A-Z
        putexcel `first'`second'1 = ("`var'")  // Correctly places AA-ZZ
    }
}

cap drop lambda


* Calculate RMSE 
cap drop residuals squared_residuals  
gen residuals = temp_lnwage - lwage_hour_hat
gen squared_residuals = residuals^2

preserve 
keep if `filter'
sum squared_residuals 
di "RMSE for women with low wages:  " sqrt(r(mean))
putexcel set "${results_wi}/reg_RMSE_wages.xlsx", sheet("PL") modify
putexcel A1=("REGRESSOR") B1=("COEFFICIENT") ///
A2=("W1") B2=(sqrt(r(mean))) 
restore 


**********************************************************
* Sample: Working age (16-75) men with low wages  
* DV: Log gross hourly wage 
**********************************************************
* Prep storage 
capture drop pred lwage_hour_hat wage_hour_hat esample pred_hourly_wage
gen lwage_hour_hat = .
gen wage_hour_hat = .
gen esample = .
gen pred_hourly_wage = .


************************************************************************************************************************************************************
local covariates "dag temp_age2 temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_drgn1_2 temp_drgn1_3 temp_drgn1_4 temp_drgn1_5" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag
local selection "temp_partnered temp_n_ch temp_d_ch2 dag temp_age2 temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_drgn1_2 temp_drgn1_3 temp_drgn1_4 temp_drgn1_5" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag

local filter "dgn==1 & temp_not_flexible==0 & group1<." 
heckman temp_lnwage `covariates' if `filter', select(`selection')  twostep

/***************************************************************************/
* Eigenvalue stability check 

* Extract variance-covariance matrix
matrix V = e(V)

* Preserve data state
preserve

* Export V to dataset
clear
svmat double V

* Drop zero rows and columns
forvalues r = 1/2 {
    egen rowsum = rowtotal(*)
    drop if rowsum == 0
    drop rowsum
    xpose, clear
}

* Recreate trimmed VCV matrix
mkmat *, matrix(V_trimmed)

restore

* Eigen decomposition
matrix symeigen X lambda = V_trimmed

* Largest eigenvalue
scalar max_eig = lambda[1,1]

* Smallest-to-largest eigenvalue ratio
scalar min_ratio = lambda[1, colsof(lambda)] / max_eig

* Check 1: near singularity
if max_eig < 1.0e-12 {
    display as error "CRITICAL ERROR: Heckman VCV near singular"
    display as error "Max eigenvalue = " max_eig
    exit 999
}

* Check 2: ill-conditioning
if min_ratio < 1.0e-12 {
    display as error "ERROR: Heckman VCV ill-conditioned"
    display as error "Min/Max eigenvalue ratio = " min_ratio
    exit 506
}

display "VCV stability check passed"
display "Max eigenvalue: " max_eig
display "Min/Max ratio: " min_ratio

/***************************************************************************/
  
* Obtain predicted values (log wage) with selection correction

predict pred if `filter', ycond  // ycond -> include IMR in prediction to account for selection into employment
replace lwage_hour_hat = pred if `filter'

gen in_sample_m1 = e(sample)	

* Correct bias when transforming from log to levels 
cap drop epsilon
gen epsilon = rnormal()*e(sigma) 

replace pred_hourly_wage = exp(lwage_hour_hat + epsilon) if `filter' 


twoway (hist temp_obs_wage if `filter', width(0.5) ///
	lcolor(gs12) fcolor(gs12)) ///
	(hist pred_hourly_wage if `filter' & (!missing(pred_hourly_wage)), width(0.5) ///
		fcolor(none) lcolor(red)), ///
	title("Gross Hourly Wage (Level)") ///
	subtitle("Men, low wages") ///
	xtitle("PLN") ///
	legend(lab(1 "EU-SILC") lab(2 "Prediction")) ///
	note("Notes: Sample condition `filter'", size(vsmall))	

graph export "${results_wi}/M1_hist.png", replace 

graph drop _all 

sum temp_obs_wage if `filter' [aw=dwt]
sum pred_hourly_wage if `filter' & (!missing(pred_hourly_wage)) [aw=dwt]
  
 
* Save sample validation 
save "${local_data}/M2_sample", replace 
	
cap drop pred epsilon	
 
* Formatted results
* Clean up matrix of estimates 
* Note: Zeros values are eliminated 
matrix b = e(b)	
matrix V = e(V)

* Store variance-covariance matrix 
preserve

putexcel set "${results_wi}/var_cov", sheet("var_cov") replace
putexcel A1 = matrix(V)

import excel "${results_wi}/var_cov", sheet("var_cov") clear

describe
local no_vars = `r(k)'	
	
forvalues i = 1/2 {
	egen row_sum = rowtotal(*)
	drop if row_sum == 0 
	drop row_sum
	xpose, clear	
}	
	
mkmat v*, matrix(var)	

* Second stage
putexcel set "${results_wi}/reg_wages_raw", sheet("M1_raw") replace
putexcel C2 = matrix(var)
		
restore	

* Store estimated coefficients 
* Initialize a counter for non-zero coefficients
local non_zero_count = 0
//local names : colnames b

* Loop through each element in `b` to count non-zero coefficients
forvalues i = 1/`no_vars' {
    if (b[1, `i'] != 0) {
        local non_zero_count = `non_zero_count' + 1
    }
}

* Create a new row vector to hold only non-zero coefficients
matrix nonzero_b = J(1, `non_zero_count', .)

* Populate nonzero_b with non-zero coefficients from b
local index = 1
forvalues i = 1/`no_vars' {
    if (b[1, `i'] != 0) {
        matrix nonzero_b[1, `index'] = b[1, `i']
        local index = `index' + 1
    }
}

putexcel set "${results_wi}/reg_wages_raw", sheet("M1_raw") modify 
putexcel B2 = matrix(nonzero_b') //, names nformat(number_d2) 

preserve

import excel "${results_wi}/reg_wages_raw", sheet("M1_raw") /*firstrow*/  ///
	clear
ds 

//define which cells are to be dropped 
drop if C == 0 & D==0 // UPDATE 
//drop A 
drop S-AK // UPDATE


mkmat *, matrix(Women2)
matrix list Women2

putexcel set "${results_wi}/reg_wages", sheet("M1") modify   
putexcel B2 = matrix(Women2)

restore 


* Labelling 
putexcel set "${results_wi}/reg_wages", sheet("M1") modify 

local var_list Dag Dag_sq ///
Deh_c3_Medium Deh_c3_High ///
Deh_c3_Medium_Dag Deh_c3_High_Dag ///
Liwwh ///
Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
PL4 PL5 PL6 PL10 ///
Constant InverseMillsRatio

	
putexcel A1 = ("REGRESSOR")
putexcel B1 = ("COEFFICIENT")

local i = 1 	
foreach var in `var_list' {
	local ++i
	
	putexcel A`i' = ("`var'")
	
} 	

local i = 2 	
foreach var in `var_list' {
    local ++i

    if `i' <= 26 {
        local letter = char(64 + `i')  // Convert 1=A, 2=B, ..., 26=Z
        putexcel `letter'1 = ("`var'")
    }
    else {
        local first = char(64 + int((`i' - 1) / 26))  // First letter: A-Z
        local second = char(65 + mod((`i' - 1), 26)) // Second letter: A-Z
        putexcel `first'`second'1 = ("`var'")  // Correctly places AA-ZZ
    }
}


* First stage
preserve

import excel "${results_wi}/reg_wages_raw", sheet("M1_raw") /*firstrow*/ ///
	clear
ds 

drop if S== 0 // UPDATE
//drop A 
drop C-R // UPDATE
drop AL // UPDATE


mkmat *, matrix(Women2)
matrix list Women2

putexcel set "${results_wi}/reg_employment_selection", sheet("M1-sel") modify   
putexcel B2 = matrix(Women2)

restore 

* Labelling 
putexcel set "${results_wi}/reg_employment_selection", sheet("M1-sel") modify 
	
local var_list Dcpst_Partnered Children D_Children2 ///
Dag Dag_sq ///
Deh_c3_Medium Deh_c3_High ///
Deh_c3_Medium_Dag Deh_c3_High_Dag ///
Liwwh ///
Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
PL4 PL5 PL6 PL10 ///
Constant 

putexcel A1 = ("REGRESSOR")
putexcel B1 = ("COEFFICIENT")

local i = 1 	
foreach var in `var_list' {
	local ++i
	
	putexcel A`i' = ("`var'")
	
} 	

local i = 2 	
foreach var in `var_list' {
    local ++i

    if `i' <= 26 {
        local letter = char(64 + `i')  // Convert 1=A, 2=B, ..., 26=Z
        putexcel `letter'1 = ("`var'")
    }
    else {
        local first = char(64 + int((`i' - 1) / 26))  // First letter: A-Z
        local second = char(65 + mod((`i' - 1), 26)) // Second letter: A-Z
        putexcel `first'`second'1 = ("`var'")  // Correctly places AA-ZZ
    }
}

cap drop lambda


* Calculate RMSE 
cap drop residuals squared_residuals  
gen residuals = temp_lnwage - lwage_hour_hat
gen squared_residuals = residuals^2

preserve 
keep if `filter'
sum squared_residuals 
di "RMSE for men with low wages:  " sqrt(r(mean))
putexcel set "${results_wi}/reg_RMSE_wages.xlsx", sheet("PL") modify
putexcel A1=("REGRESSOR") B1=("COEFFICIENT") ///
A3=("M1") B3=(sqrt(r(mean))) 
restore 



**********************************************************
* Sample: Working age (16-75) women with normal wages 
* DV: Log gross hourly wage 
**********************************************************
* Prep storage 
capture drop pred lwage_hour_hat wage_hour_hat esample pred_hourly_wage
gen lwage_hour_hat = .
gen wage_hour_hat = .
gen esample = .
gen pred_hourly_wage = .


************************************************************************************************************************************************************
local covariates "dag temp_age2 temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_drgn1_2 temp_drgn1_3 temp_drgn1_4 temp_drgn1_5" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag
local selection "temp_partnered temp_n_ch temp_d_ch2 dag temp_age2 temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_drgn1_2 temp_drgn1_3 temp_drgn1_4 temp_drgn1_5" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag

local filter "dgn==0 & temp_not_flexible==0 & group2<." 
heckman temp_lnwage `covariates' if `filter', select(`selection')  twostep

/***************************************************************************/
* Eigenvalue stability check 

* Extract variance-covariance matrix
matrix V = e(V)

* Preserve data state
preserve

* Export V to dataset
clear
svmat double V

* Drop zero rows and columns
forvalues r = 1/2 {
    egen rowsum = rowtotal(*)
    drop if rowsum == 0
    drop rowsum
    xpose, clear
}

* Recreate trimmed VCV matrix
mkmat *, matrix(V_trimmed)

restore

* Eigen decomposition
matrix symeigen X lambda = V_trimmed

* Largest eigenvalue
scalar max_eig = lambda[1,1]

* Smallest-to-largest eigenvalue ratio
scalar min_ratio = lambda[1, colsof(lambda)] / max_eig

* Check 1: near singularity
if max_eig < 1.0e-12 {
    display as error "CRITICAL ERROR: Heckman VCV near singular"
    display as error "Max eigenvalue = " max_eig
    exit 999
}

* Check 2: ill-conditioning
if min_ratio < 1.0e-12 {
    display as error "ERROR: Heckman VCV ill-conditioned"
    display as error "Min/Max eigenvalue ratio = " min_ratio
    exit 506
}

display "VCV stability check passed"
display "Max eigenvalue: " max_eig
display "Min/Max ratio: " min_ratio

/***************************************************************************/
  
* Obtain predicted values (log wage) with selection correction

predict pred if `filter', ycond  // ycond -> include IMR in prediction to account for selection into employment
replace lwage_hour_hat = pred if `filter'

gen in_sample_w2 = e(sample)	

* Correct bias when transforming from log to levels 
cap drop epsilon
gen epsilon = rnormal()*e(sigma) 

replace pred_hourly_wage = exp(lwage_hour_hat + epsilon) if `filter' 


twoway (hist temp_obs_wage if `filter', width(0.5) ///
	lcolor(gs12) fcolor(gs12)) ///
	(hist pred_hourly_wage if `filter' & (!missing(pred_hourly_wage)), width(0.5) ///
		fcolor(none) lcolor(red)), ///
	title("Gross Hourly Wage (Level)") ///
	subtitle("Women, normal wages") ///
	xtitle("PLN") ///
	legend(lab(1 "EU-SILC") lab(2 "Prediction")) ///
	note("Notes: Sample condition `filter'", size(vsmall))	

graph export "${results_wi}/W2_hist.png", replace 

graph drop _all 

sum temp_obs_wage if `filter' [aw=dwt]
sum pred_hourly_wage if `filter' & (!missing(pred_hourly_wage)) [aw=dwt]
  
 
* Save sample validation 
save "${local_data}/W2_sample", replace 
	
cap drop pred epsilon	
 
* Formatted results
* Clean up matrix of estimates 
* Note: Zeros values are eliminated 
matrix b = e(b)	
matrix V = e(V)

* Store variance-covariance matrix 
preserve

putexcel set "${results_wi}/var_cov", sheet("var_cov") replace
putexcel A1 = matrix(V)

import excel "${results_wi}/var_cov", sheet("var_cov") clear

describe
local no_vars = `r(k)'	
	
forvalues i = 1/2 {
	egen row_sum = rowtotal(*)
	drop if row_sum == 0 
	drop row_sum
	xpose, clear	
}	
	
mkmat v*, matrix(var)	

* Second stage
putexcel set "${results_wi}/reg_wages_raw", sheet("W2_raw") replace
putexcel C2 = matrix(var)
		
restore	

* Store estimated coefficients 
* Initialize a counter for non-zero coefficients
local non_zero_count = 0
//local names : colnames b

* Loop through each element in `b` to count non-zero coefficients
forvalues i = 1/`no_vars' {
    if (b[1, `i'] != 0) {
        local non_zero_count = `non_zero_count' + 1
    }
}

* Create a new row vector to hold only non-zero coefficients
matrix nonzero_b = J(1, `non_zero_count', .)

* Populate nonzero_b with non-zero coefficients from b
local index = 1
forvalues i = 1/`no_vars' {
    if (b[1, `i'] != 0) {
        matrix nonzero_b[1, `index'] = b[1, `i']
        local index = `index' + 1
    }
}

putexcel set "${results_wi}/reg_wages_raw", sheet("W2_raw") modify 
putexcel B2 = matrix(nonzero_b') //, names nformat(number_d2) 

preserve

import excel "${results_wi}/reg_wages_raw", sheet("W2_raw") /*firstrow*/  ///
	clear
ds 

//define which cells are to be dropped 
drop if C == 0 & D==0 // UPDATE 
//drop A 
drop S-AK // UPDATE


mkmat *, matrix(Women2)
matrix list Women2

putexcel set "${results_wi}/reg_wages", sheet("W2") modify   
putexcel B2 = matrix(Women2)

restore 


* Labelling 
putexcel set "${results_wi}/reg_wages", sheet("W2") modify 

local var_list Dag Dag_sq ///
Deh_c3_Medium Deh_c3_High ///
Deh_c3_Medium_Dag Deh_c3_High_Dag ///
Liwwh ///
Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
PL4 PL5 PL6 PL10 ///
Constant InverseMillsRatio

	
putexcel A1 = ("REGRESSOR")
putexcel B1 = ("COEFFICIENT")

local i = 1 	
foreach var in `var_list' {
	local ++i
	
	putexcel A`i' = ("`var'")
	
} 	

local i = 2 	
foreach var in `var_list' {
    local ++i

    if `i' <= 26 {
        local letter = char(64 + `i')  // Convert 1=A, 2=B, ..., 26=Z
        putexcel `letter'1 = ("`var'")
    }
    else {
        local first = char(64 + int((`i' - 1) / 26))  // First letter: A-Z
        local second = char(65 + mod((`i' - 1), 26)) // Second letter: A-Z
        putexcel `first'`second'1 = ("`var'")  // Correctly places AA-ZZ
    }
}


* First stage
preserve

import excel "${results_wi}/reg_wages_raw", sheet("W2_raw") /*firstrow*/ ///
	clear
ds 

drop if S== 0 // UPDATE
//drop A 
drop C-R // UPDATE
drop AL // UPDATE


mkmat *, matrix(Women2)
matrix list Women2

putexcel set "${results_wi}/reg_employment_selection", sheet("W2-sel") modify   
putexcel B2 = matrix(Women2)

restore 

* Labelling 
putexcel set "${results_wi}/reg_employment_selection", sheet("W2-sel") modify 
	
local var_list Dcpst_Partnered Children D_Children2 ///
Dag Dag_sq ///
Deh_c3_Medium Deh_c3_High ///
Deh_c3_Medium_Dag Deh_c3_High_Dag ///
Liwwh ///
Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
PL4 PL5 PL6 PL10 ///
Constant 

putexcel A1 = ("REGRESSOR")
putexcel B1 = ("COEFFICIENT")

local i = 1 	
foreach var in `var_list' {
	local ++i
	
	putexcel A`i' = ("`var'")
	
} 	

local i = 2 	
foreach var in `var_list' {
    local ++i

    if `i' <= 26 {
        local letter = char(64 + `i')  // Convert 1=A, 2=B, ..., 26=Z
        putexcel `letter'1 = ("`var'")
    }
    else {
        local first = char(64 + int((`i' - 1) / 26))  // First letter: A-Z
        local second = char(65 + mod((`i' - 1), 26)) // Second letter: A-Z
        putexcel `first'`second'1 = ("`var'")  // Correctly places AA-ZZ
    }
}

cap drop lambda


* Calculate RMSE 
cap drop residuals squared_residuals  
gen residuals = temp_lnwage - lwage_hour_hat
gen squared_residuals = residuals^2

preserve 
keep if `filter'
sum squared_residuals 
di "RMSE for women with normal wages:  " sqrt(r(mean))
putexcel set "${results_wi}/reg_RMSE_wages.xlsx", sheet("PL") modify
putexcel A1=("REGRESSOR") B1=("COEFFICIENT") ///
A4=("W2") B4=(sqrt(r(mean))) 
restore 


**********************************************************
* Sample: Working age (16-75) men with normal wages 
* DV: Log gross hourly wage 
**********************************************************
* Prep storage 
capture drop pred lwage_hour_hat wage_hour_hat esample pred_hourly_wage
gen lwage_hour_hat = .
gen wage_hour_hat = .
gen esample = .
gen pred_hourly_wage = .


************************************************************************************************************************************************************
local covariates "dag temp_age2 temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_drgn1_2 temp_drgn1_3 temp_drgn1_4 temp_drgn1_5" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag
local selection "temp_partnered temp_n_ch temp_d_ch2 dag temp_age2 temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag liwwh temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_drgn1_2 temp_drgn1_3 temp_drgn1_4 temp_drgn1_5" //temp_d_deh_M temp_d_deh_H temp_int_dehM_dag temp_int_dehH_dag

local filter "dgn==1 & temp_not_flexible==0 & group2<." 
heckman temp_lnwage `covariates' if `filter', select(`selection')  twostep

/***************************************************************************/
* Eigenvalue stability check 

* Extract variance-covariance matrix
matrix V = e(V)

* Preserve data state
preserve

* Export V to dataset
clear
svmat double V

* Drop zero rows and columns
forvalues r = 1/2 {
    egen rowsum = rowtotal(*)
    drop if rowsum == 0
    drop rowsum
    xpose, clear
}

* Recreate trimmed VCV matrix
mkmat *, matrix(V_trimmed)

restore

* Eigen decomposition
matrix symeigen X lambda = V_trimmed

* Largest eigenvalue
scalar max_eig = lambda[1,1]

* Smallest-to-largest eigenvalue ratio
scalar min_ratio = lambda[1, colsof(lambda)] / max_eig

* Check 1: near singularity
if max_eig < 1.0e-12 {
    display as error "CRITICAL ERROR: Heckman VCV near singular"
    display as error "Max eigenvalue = " max_eig
    exit 999
}

* Check 2: ill-conditioning
if min_ratio < 1.0e-12 {
    display as error "ERROR: Heckman VCV ill-conditioned"
    display as error "Min/Max eigenvalue ratio = " min_ratio
    exit 506
}

display "VCV stability check passed"
display "Max eigenvalue: " max_eig
display "Min/Max ratio: " min_ratio

/***************************************************************************/
  
* Obtain predicted values (log wage) with selection correction

predict pred if `filter', ycond  // ycond -> include IMR in prediction to account for selection into employment
replace lwage_hour_hat = pred if `filter'

gen in_sample_m2 = e(sample)	

* Correct bias when transforming from log to levels 
cap drop epsilon
gen epsilon = rnormal()*e(sigma) 

replace pred_hourly_wage = exp(lwage_hour_hat + epsilon) if `filter' 


twoway (hist temp_obs_wage if `filter', width(0.5) ///
	lcolor(gs12) fcolor(gs12)) ///
	(hist pred_hourly_wage if `filter' & (!missing(pred_hourly_wage)), width(0.5) ///
		fcolor(none) lcolor(red)), ///
	title("Gross Hourly Wage (Level)") ///
	subtitle("Men") ///
	xtitle("PLN") ///
	legend(lab(1 "EU-SILC") lab(2 "Prediction")) ///
	note("Notes: Sample condition `filter'", size(vsmall))	

graph export "${results_wi}/M2_hist.png", replace 

graph drop _all 

sum temp_obs_wage if `filter' [aw=dwt]
sum pred_hourly_wage if `filter' & (!missing(pred_hourly_wage)) [aw=dwt]
  
 
* Save sample validation 
save "${local_data}/M2_sample", replace 
	
cap drop pred epsilon	
 
* Formatted results
* Clean up matrix of estimates 
* Note: Zeros values are eliminated 
matrix b = e(b)	
matrix V = e(V)

* Store variance-covariance matrix 
preserve

putexcel set "${results_wi}/var_cov", sheet("var_cov") replace
putexcel A1 = matrix(V)

import excel "${results_wi}/var_cov", sheet("var_cov") clear

describe
local no_vars = `r(k)'	
	
forvalues i = 1/2 {
	egen row_sum = rowtotal(*)
	drop if row_sum == 0 
	drop row_sum
	xpose, clear	
}	
	
mkmat v*, matrix(var)	

* Second stage
putexcel set "${results_wi}/reg_wages_raw", sheet("M2_raw") replace
putexcel C2 = matrix(var)
		
restore	

* Store estimated coefficients 
* Initialize a counter for non-zero coefficients
local non_zero_count = 0
//local names : colnames b

* Loop through each element in `b` to count non-zero coefficients
forvalues i = 1/`no_vars' {
    if (b[1, `i'] != 0) {
        local non_zero_count = `non_zero_count' + 1
    }
}

* Create a new row vector to hold only non-zero coefficients
matrix nonzero_b = J(1, `non_zero_count', .)

* Populate nonzero_b with non-zero coefficients from b
local index = 1
forvalues i = 1/`no_vars' {
    if (b[1, `i'] != 0) {
        matrix nonzero_b[1, `index'] = b[1, `i']
        local index = `index' + 1
    }
}

putexcel set "${results_wi}/reg_wages_raw", sheet("M2_raw") modify 
putexcel B2 = matrix(nonzero_b') //, names nformat(number_d2) 

preserve

import excel "${results_wi}/reg_wages_raw", sheet("M2_raw") /*firstrow*/  ///
	clear
ds 

//define which cells are to be dropped 
drop if C == 0 & D==0 // UPDATE 
//drop A 
drop S-AK // UPDATE


mkmat *, matrix(Women2)
matrix list Women2

putexcel set "${results_wi}/reg_wages", sheet("M2") modify   
putexcel B2 = matrix(Women2)

restore 


* Labelling 
putexcel set "${results_wi}/reg_wages", sheet("M2") modify 

local var_list Dag Dag_sq ///
Deh_c3_Medium Deh_c3_High ///
Deh_c3_Medium_Dag Deh_c3_High_Dag ///
Liwwh ///
Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
PL4 PL5 PL6 PL10 ///
Constant InverseMillsRatio

	
putexcel A1 = ("REGRESSOR")
putexcel B1 = ("COEFFICIENT")

local i = 1 	
foreach var in `var_list' {
	local ++i
	
	putexcel A`i' = ("`var'")
	
} 	

local i = 2 	
foreach var in `var_list' {
    local ++i

    if `i' <= 26 {
        local letter = char(64 + `i')  // Convert 1=A, 2=B, ..., 26=Z
        putexcel `letter'1 = ("`var'")
    }
    else {
        local first = char(64 + int((`i' - 1) / 26))  // First letter: A-Z
        local second = char(65 + mod((`i' - 1), 26)) // Second letter: A-Z
        putexcel `first'`second'1 = ("`var'")  // Correctly places AA-ZZ
    }
}


* First stage
preserve

import excel "${results_wi}/reg_wages_raw", sheet("M2_raw") /*firstrow*/ ///
	clear
ds 

drop if S== 0 // UPDATE
//drop A 
drop C-R // UPDATE
drop AL // UPDATE


mkmat *, matrix(Women2)
matrix list Women2

putexcel set "${results_wi}/reg_employment_selection", sheet("M2-sel") modify   
putexcel B2 = matrix(Women2)

restore 

* Labelling 
putexcel set "${results_wi}/reg_employment_selection", sheet("M2-sel") modify 
	
local var_list Dcpst_Partnered Children D_Children2 ///
Dag Dag_sq ///
Deh_c3_Medium Deh_c3_High ///
Deh_c3_Medium_Dag Deh_c3_High_Dag ///
Liwwh ///
Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
PL4 PL5 PL6 PL10 ///
Constant 

putexcel A1 = ("REGRESSOR")
putexcel B1 = ("COEFFICIENT")

local i = 1 	
foreach var in `var_list' {
	local ++i
	
	putexcel A`i' = ("`var'")
	
} 	

local i = 2 	
foreach var in `var_list' {
    local ++i

    if `i' <= 26 {
        local letter = char(64 + `i')  // Convert 1=A, 2=B, ..., 26=Z
        putexcel `letter'1 = ("`var'")
    }
    else {
        local first = char(64 + int((`i' - 1) / 26))  // First letter: A-Z
        local second = char(65 + mod((`i' - 1), 26)) // Second letter: A-Z
        putexcel `first'`second'1 = ("`var'")  // Correctly places AA-ZZ
    }
}

cap drop lambda


* Calculate RMSE 
cap drop residuals squared_residuals  
gen residuals = temp_lnwage - lwage_hour_hat
gen squared_residuals = residuals^2

preserve 
keep if `filter'
sum squared_residuals 
di "RMSE for men with normal wages:  " sqrt(r(mean))
putexcel set "${results_wi}/reg_RMSE_wages.xlsx", sheet("PL") modify
putexcel A1=("REGRESSOR") B1=("COEFFICIENT") ///
A5=("M2") B5=(sqrt(r(mean))) 
restore 



*=======================================================================
*           Two ways of wage imputations
*=======================================================================

*------------------------------------------------------------
* // @@@ WAGE IMPUTATION METHOD #wage1 @@@
* make predicted wage=yivwg for everyone
*------------------------------------------------------------	
/*//make predicted wage=yivwg (yivwg: name for predicted hourly wage in UKMOD)
cap gen yivwg=temp_wage_0_group1 if dgn==0 & group1==1    //women with low wages 
replace yivwg=temp_wage_1_group1 if dgn==1 & group1==1    //men with low wages 
replace yivwg=temp_wage_0_group2 if dgn==0 & group2==1    //women with high wages  
replace yivwg=temp_wage_1_group2 if dgn==1 & group2==1    //men with high wages 
for non-working take group 2 prediction 
replace yivwg=temp_wage_0_group2 if dgn==0 & nonworking==1     
replace yivwg=temp_wage_1_group2 if dgn==1 & nonworking==1  
*/

/*Different Wage Structures: By splitting the workers into two wage groups, we are recognizing that the wage determination process might differ significantly between those reporting low wages and those earning higher wages. 
As a result, predicting wages for the non-employed needs to take both structures into account.
Reweighting Using Probabilities:
1/ When we compute the probability of being employed from each subsample, we capture the likelihood that a non-employed individual would "belong" to either group (low-wage or high-wage).
2/ Reweighting the predicted wages using these probabilities can be thought of as a weighted average of the potential wages from both models. 
This accounts for uncertainty about which wage group a non-employed individual might fall into if they were employed.
3/ Normalization: Dividing by the sum of the two probabilities ensures that the weights add up to 1, maintaining the coherence of the predicted wage distribution.
*/

*predicted wages for everyone incl working using predictions from equation 1
cap drop yivwg1
gen yivwg1 =. 
replace yivwg1 = temp_wage_0_group1 if dgn==0  
replace yivwg1 = temp_wage_1_group1 if dgn==1 
sum yivwg1

*predicted wages for everyone incl working using predictions from equation 2
cap drop yivwg2
gen yivwg2 =. 
replace yivwg2 = temp_wage_0_group2 if dgn==0  
replace yivwg2 = temp_wage_1_group2 if dgn==1 
sum yivwg2


*predicted wages for everyone incl working using mixed predictions 
foreach gender in 0 1 {
gen weight_`gender'_group1 = temp_pr_`gender'_group1 / (temp_pr_`gender'_group1 + temp_pr_`gender'_group2)
gen weight_`gender'_group2 = temp_pr_`gender'_group2 / (temp_pr_`gender'_group1 + temp_pr_`gender'_group2)
} 
cap drop yivwg
gen yivwg =. 
replace yivwg = weight_0_group1*temp_wage_0_group1 + weight_0_group2*temp_wage_0_group2 if dgn==0 //weight low * wage low + weight high * wage high 
replace yivwg = weight_1_group1*temp_wage_1_group1 + weight_1_group2*temp_wage_1_group2 if dgn==1 //weight low * wage low + weight high * wage high 

sum yivwg if group1==1
sum yivwg if group2==1
sum yivwg if nonworking==1

assert yivwg!=. 


*Trim predicted wage to get rid of outliers??? 
/*centile yivwg,  centile(1 2 3 4 5 95 96 97 98 99)  
return list
replace yivwg = `r(c_1)'  if yivwg <= `r(c_1)'
replace yivwg = `r(c_10)' if yivwg >= `r(c_10)'
*/
centile temp_obs_wage if lhw>0,  centile(1 2 3 4 5 95 96 97 98 99) 
return list
replace yivwg1 = `r(c_10)' if yivwg1 >= `r(c_10)'
replace yivwg2 = `r(c_10)' if yivwg2 >= `r(c_10)'
replace yivwg = `r(c_10)' if yivwg >= `r(c_10)'
sum yivwg1 if yivwg<. 
sum yivwg2 if yivwg<. 
sum yivwg if yivwg<. 


//gen temp_obs_wage=temp_y/(lhw*4.3)    
//observed wages vs predicted wages  
su temp_obs_wage yivwg if temp_work==1 & temp_heckman_group1==1 & yivwg!=-1
bysort dgn:su temp_obs_wage yivwg if temp_work==1 & temp_heckman_group1==1 & yivwg!=-1
//observed wages vs predicted wages  
su temp_obs_wage yivwg if temp_work==1 & temp_heckman_group2==1 & yivwg!=-1
bysort dgn:su temp_obs_wage yivwg if temp_work==1 & temp_heckman_group2==1 & yivwg!=-1


*********************************************
* Graph of predicted wage vs. observed wage *
*********************************************
version 14
**************
*scatterplot *
**************
*graph for both groups
foreach gender in 0 1 { //beginning of gender loop 

	twoway(scatter yivwg temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group1 == 1 | temp_heckman_`gender'_group2==1) & yivwg>0)(line temp_obs_wage temp_obs_wage if dgn==`gender')
	graph export "$results_wi/wages_scatter_`gender'.png", as(png) replace
*graph for group 1
	twoway(scatter yivwg1 temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group1 == 1) & yivwg1>0)(line temp_obs_wage temp_obs_wage if dgn==`gender')
	graph export "$results_wi/wages_scatter_`gender'_group1.png", as(png) replace
*graph for group 2
	twoway(scatter yivwg2 temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group2 == 1) & yivwg2>0)(line temp_obs_wage temp_obs_wage if dgn==`gender')
	graph export "$results_wi/wages_scatter_`gender'_group2.png", as(png) replace

	
************	
*histogram *
************
*graph for both groups
if (`gender' == 0){
	
	twoway (histogram temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group1 == 1 | temp_heckman_`gender'_group2==1) & temp_obs_wage != .,  ///
	       percent color(green) start(0) width(1)) ///
		   (histogram         yivwg if dgn==`gender' & (temp_heckman_`gender'_group1 == 1 | temp_heckman_`gender'_group2==1) & temp_obs_wage != ., ///
		   percent fcolor(none) lcolor(black) start(0) width(1)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Women") ///
		   ytitle("percent") ///
           xtitle("hourly wage, PLN") ///
           xscale(range(0 100))
}
else{
	
	twoway (histogram temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group1 == 1 | temp_heckman_`gender'_group2==1) & temp_obs_wage != ., ///
	       percent color(green)  start(0) width(1)) ///
		   (histogram         yivwg if dgn==`gender' & (temp_heckman_`gender'_group1 == 1 | temp_heckman_`gender'_group2==1) & temp_obs_wage != ., ///
		   percent fcolor(none) lcolor(black) start(0) width(1)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Men") ///
		   ytitle("percent") ///
           xtitle("hourly wage, PLN") ///
           xscale(range(0 100))
}

graph export "$results_wi/obs_wage_`gender'.png", as(png) replace



*graph for group 1
if (`gender' == 0){
	
	twoway (histogram temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group1 == 1) & temp_obs_wage != .,  ///
	       percent color(green)  start(0) width(1)) ///
		   (histogram        yivwg1 if dgn==`gender' & (temp_heckman_`gender'_group1 == 1) & temp_obs_wage != ., ///
		   percent fcolor(none) lcolor(black) start(0) width(1)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Women") ///
		   ytitle("percent") ///
           xtitle("hourly wage, PLN") ///
           xscale(range(0 100))
}
else{
	
	twoway (histogram temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group1 == 1) & temp_obs_wage != ., ///
	       percent color(green)  start(0) width(1)) ///
		   (histogram        yivwg1 if dgn==`gender' & (temp_heckman_`gender'_group1 == 1) & temp_obs_wage != ., ///
		   percent fcolor(none) lcolor(black) start(0) width(1)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Men") ///
		   ytitle("percent") ///
           xtitle("hourly wage, PLN") ///
           xscale(range(0 100))
}

graph export "$results_wi/obs_wage_`gender'_group1.png", as(png) replace

*graph for group 2
if (`gender' == 0){
	
	twoway (histogram temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group2==1) & temp_obs_wage != ., ///
	       percent color(green)  start(0) width(1)) ///
		   (histogram        yivwg2 if dgn==`gender' & (temp_heckman_`gender'_group2==1) & temp_obs_wage != ., ///
		   percent fcolor(none) lcolor(black) start(0) width(1)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Women") ///
		   ytitle("percent") ///
           xtitle("hourly wage, PLN") ///
           xscale(range(0 100))
}
else{
	
	twoway (histogram temp_obs_wage if dgn==`gender' & (temp_heckman_`gender'_group2==1) & temp_obs_wage != ., ///
	       percent color(green)  start(0) width(1)) ///
		   (histogram        yivwg2 if dgn==`gender' & (temp_heckman_`gender'_group2==1) & temp_obs_wage != ., ///
		   percent fcolor(none) lcolor(black) start(0) width(1)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Men") ///
		   ytitle("percent") ///
           xtitle("hourly wage, PLN") ///
           xscale(range(0 100))
}

graph export "$results_wi/obs_wage_`gender'_group2.png", as(png) replace
} //end of gender loop
 
duplicates report //50581  obs 

sum temp_obs_wage if temp_obs_wage>0, d
sum yivwg if yivwg>0, d

save afterheckman,replace

*--------------------------------------------------------------------------------------------------------------------------
*Drop individuals outside of flexible households (in "singles"' or couples' households)
*For the ease of running EUROMOD
*--------------------------------------------------------------------------------------------------------------------------
/*We keep clean single households (exactly 1 flexible worker) and clean couple households (exactly 2 flexible workers), 
and drop anything that does not match this simple household structure*/

use afterheckman,clear
//already problematic with lhw_f vbl
duplicates report idperson  //count how many unique individuals there are
di r(unique_value) //50581 obs  

bysort idhh: egen temp_with_singles=total(temp_singles), missing  //missing as 0
replace temp_with_singles=(temp_with_singles>0)   //dummy of at least one family member is "singles"

bysort idhh: egen temp_with_couples=total(temp_couples), missing
replace temp_with_couples=(temp_with_couples>0)   //dummy of at least one family member is "couples"

count if temp_singles==1 & temp_n_ch>0 //1,029 obs 

//check whether a not flexible individual can have temp_with_couples=1 and temp_with_singles=1 at the same time 
su dag if temp_with_singles==1 &temp_with_couples==1 &temp_not_flexible==1  
tab les if temp_with_singles==1 &temp_with_couples==1 &temp_not_flexible==1  //they are either pre-school or student or pensioner or disabled 
***
su temp_singles temp_couples temp_not_flexible if temp_with_singles==1 &temp_with_couples==1  //this shows singles, couples, and not flexible individuals can all live together

count if temp_with_singles==1 &temp_with_couples==1  //8,550 obs

//count if there are more than one flexible workers (lone parent+child aged between 16 and 18 and not student) in a "singles"' household
gen worker_count=(temp_not_flexible==0)
bysort idhh: egen number_workers_singleshh=total(worker_count) if temp_singles==1, missing
su number_workers_singles
count if number_workers_singleshh>1 & temp_singles==1   // 4,012 obs
duplicates report idhh if number_workers_singleshh>1 & temp_singles==1  

//check there are no more than TWO flexible workers in a "COUPLES"' household
bysort idhh: egen number_workers_coupleshh=total(worker_count) if temp_couples==1, missing
su number_workers_couples
count if number_workers_coupleshh>2 & temp_couples==1 //1,006 obs 
drop if number_workers_coupleshh>2 & temp_couples==1 //DP: keep them to save sample size  ???
duplicates report idperson  //count how many unique individuals there are
di r(unique_value) //49575 obs 

count if number_workers_coupleshh<2 & temp_couples==1   //no such obs 
drop if number_workers_coupleshh<2 & temp_couples==1 
duplicates report idperson  //count how many unique individuals there are
di r(unique_value)  //49575 obs

//assert number_workers_coupleshh==2 if temp_couples==1
assert number_workers_coupleshh>=2 if temp_couples==1

//dropping mixed hholds with singles and couples 
count if temp_with_singles==1 &temp_with_couples==1 // 8,242 obs
drop if temp_with_singles==1 &temp_with_couples==1  //to remove "mixed hhs" (hhs who are flexible singles but live with flexible couples,
// or hhs who are flexible couples but live with flexible singles)
duplicates report idperson  //count how many unique individuals there are
di r(unique_value) //41,333 obs 

*No. of hhs (lone parent+child aged between 16 and 18 and not student) 
drop if number_workers_singleshh>1 & temp_singles==1   //to remove hhs with multiple ls flexible singles living together
//(2,983 observations deleted)
duplicates report idperson  //count how many unique individuals there are
di r(unique_value) //38350 obs 

assert number_workers_singles==1 if temp_singles==1

gen temp_alt_n=(temp_with_singles==1 & temp_with_couples==0) //dummy of individuals that should have n alternatives
gen temp_alt_nsq=(temp_with_couples==1)   //dummy of individuals that should have n^2 alternatives
gen temp_drop=(temp_with_singles==0 & temp_with_couples==0)  //dummy of individuals that can be dropped from EUROMOD input data 
//because they are neither singles nor couples and do not live with singles or couples
assert temp_not_flexible==1 if temp_drop==1  //check that all individuals who will be dropped are not flexible
assert temp_alt_n+temp_alt_nsq+temp_drop==1

//check hours of work after all the drops 
fre temp_lhw_dobs_0 if dgn==0 & temp_couples ==1 //24.3% with zero hours ==> 23.3%
fre temp_lhw_dobs_1 if dgn==1 & temp_couples ==1 //8.6% with zero hours ==> 6.9% 

fre temp_lhw_dobs_0 if dgn==0 & temp_singles_indep==1 //33.9% with zero hours ==> 29.7% 
fre temp_lhw_dobs_1 if dgn==1 & temp_singles_indep==1 //24.3% with zero hours ==> 21.3% 

fre temp_lhw_dobs_0 if dgn==0 & temp_singles_dep==1 //48.2% with zero hours ==> 47.6%
fre temp_lhw_dobs_1 if dgn==1 & temp_singles_dep==1 //26.5% with zero hours ==> 27.2%


*=======================================================================
*           Labour supply alternatives
*=======================================================================
tab les if temp_drop==1
tab dag if temp_drop==1 &(les==2|les==3)

drop if temp_drop==1  //to reduce the burden of EUROMOD
duplicates report idperson  //count how many unique individuals there are
//(8,810 observations deleted) 29540 obs remain 

* create columns with imputed alternatives (same for everyone who is labour supply flexible)
foreach gender in 0 1{
local i = 0
levelsof temp_lhw_dobs_`gender', local(levels)
foreach l in `r(levels)' {
	gen byte temp_lhw_dobs_`gender'_`i' =  `l' if temp_not_flexible==0
	local i = `i' + 1
}  //loop end of ls alternatives `i'
}  //loop end of gender `gender'
sum temp_lhw_dobs_*


/*
forvalues i = 1 (1) $n_workchoices{
	assert lhw != .
	replace temp_bracket = `i' if lhw > $min_hours_`i'
}
*/

* choice set: generation of $n_choices^2 columns
// first index refers to male choice, second index refers to female choice
// note: couples (both partners flexible) have access to all $n_choices^2 options, 
// note: Although "singles" have access only to $n_choices options, I replicate these $n_choices across all choices of their partners.
// note: not flexible individuals' all options =0 hrs 
// Due to the way to construct fake id* to cheat EUROMOD, the treatment to "singles" and not flexible individuals is only for the purpose 
// of linking with flexible people in the same hh to provide info for EUROMOD.
forvalues m=0/$n_workchoices  {
	forvalues f=0/$n_workchoices  {
	
		capture drop lhw_`m'`f'
		gen byte lhw_`m'`f' = .
		replace lhw_`m'`f'=0 if temp_not_flexible==1  //both genders of not flexible individuals
		// males
		replace lhw_`m'`f' = temp_lhw_dobs_1_`m' if dgn == 1 & (temp_couples==1 |temp_singles==1) 		 //male partner in flexible couples	and male individuals in "singles"	 
		
		// females
		replace lhw_`m'`f' = temp_lhw_dobs_0_`f' if dgn == 0 & (temp_couples==1 |temp_singles==1)  		 //female partner in flexible couples and female individuals in "singles" 	 
	}
}

* choice conversion
// for flexible couples, flag for choice_`m'`f' is switched on only when the male partner chooses `m' and the female partner chooses `f'
// for second type of "singles", the inflexible partner always chooses 1st bracket (ie. 0 hours)
// for first type of "singles" (without a partner), we assume that their virtual partner chooses 1st bracket (ie. 0 hours).
// first index refers to male choice, second index refers to female choice

add_partner_variables "temp_bracket_0 temp_bracket_1 dgn" 
		replace partner_temp_bracket_0 = 0 if idpartner>0 &partner_dgn==0 &(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0) //second type of "singles"' partner must not work
		replace partner_temp_bracket_1 = 0 if idpartner>0 &partner_dgn==1 &(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0) //second type of "singles"' partner must not work


forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
		gen byte temp_choicehh_`m'`f' = .
		// males
		replace temp_choicehh_`m'`f' = (temp_bracket_1 == `m' & partner_temp_bracket_0 == `f') 	if dgn == 1 & temp_couples==1  	 //male partner in flexible couples
		replace temp_choicehh_`m'`f' = (temp_bracket_1 == `m') 							if dgn == 1 & temp_singles==1 & `f' == 0   	//male "singles"
		// females
		replace temp_choicehh_`m'`f' = (temp_bracket_0 == `f' & partner_temp_bracket_1 == `m') 	if dgn == 0 & temp_couples==1  	 //female partner in flexible couples
		replace temp_choicehh_`m'`f' = (temp_bracket_0 == `f') 							if dgn == 0 & temp_singles==1 & `m' == 0   	//female "singles"
	}
}


drop partner_temp_bracket* 
*------------------------------------------------------------
* Earnings
*------------------------------------------------------------	
cap drop yem yse 
gen yem = yempj + yemtj
gen yse = yseag + ysebs
gen temp_em=(yem>yse |(yem==yse & yem!=0))  //assign income to be employed income or self-employed income depending on whether yem>=yse for workers
gen temp_se=(yse>yem)   //assign income to be employed income or self-employed income depending on whether yem>yse for workers

assert temp_em==(1-temp_se) if yem!=0|yse!=0 //checking that non-zero hours working regimes either belong to temp_em or temp_se category
gen temp_nonworker=(yem==0 & yse==0)
assert (temp_em+temp_se+temp_nonworker==1) //checking that all regimes belong to one of the following: temp_em, temp_se, temp_nonworker
//for workers' all states, assume all income are employed income or self-employed income depending which is their major income source in their actual state

forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
gen yem_`m'`f' = .
gen yse_`m'`f' = .

replace yem_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_em==1		   
replace yse_`m'`f'=0 if temp_em==1 

replace yse_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_se==1  
replace yem_`m'`f'=0 if temp_se==1 

// for non-workers' counterfacual states, assume all income are employed income
replace yem_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_nonworker==1	
replace yse_`m'`f'=0 if temp_nonworker==1	

  }
}

gen temp_yem=yem
gen temp_yse=yse
drop yem yse
*NOTE: for both the actual and counter-factural states, yem and yse are computed using wage*discretised hours of work. This now holds automatically because wage is generated as income/discritized hours


*-----------------------------------------------------------------------------------
* Generation of new identifiers for each LS alternative
*-----------------------------------------------------------------------------------
/*
foreach var in idhh idperson idpartner idfather idmother {
	capture drop `var'*
}
*/
forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
		foreach var in idhh idperson idpartner idfather idmother  {
			gen double `var'_`m'`f' = `var' * 100 + `m'*10 + `f'  //fake id to cheat EUROMOD
			replace `var'_`m'`f' = 0 if `var' == 0
		}
	}
}

*check idperson identifies persons uniquely
duplicates r idperson
gen double temp_idorigperson2=idperson		 			//save original id. idorigperson (within hh id) already existed and not the same as idperson
gen temp_idorigpartner=idpartner
gen temp_idorighh=idhh
gen temp_idorigmother=idmother
gen temp_idorigfather=idfather
drop idperson idpartner idhh idmother idfather

format temp_id* %15.0g 
duplicates r temp_idorigperson2
di r(unique_value) //8045 obs
/*
foreach var of varlist idhh idperson idpartner idfather idmother lhw yem yse {
	quietly rename `var' obs_`var'
}

*/
preserve
drop idhh_* idperson_* idpartner_* idfather_* idmother_*  lhw_* yem_* yse_* temp_choicehh_*
save full_info,replace
restore
save beforeReshape.dta,replace


*=======================================================================
*            Reshaping data 
*=======================================================================

use beforeReshape.dta, clear
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) //29540  obs

keep  temp_idorigperson2 idhh_* idperson_* idpartner_* idfather_* idmother_*  lhw_* yem_* yse_* temp_choicehh_*

local reshapevbles = "idhh_ idperson_ idpartner_ idfather_ idmother_  lhw_ yem_ yse_  temp_choicehh_"
reshape long `reshapevbles', i(temp_idorigperson2) j(temp_option) string


format id* %15.0g 
		foreach var in idhh idperson idpartner idfather idmother  lhw yem yse  temp_choicehh  {
		rename `var'_ `var'
}
duplicates report idperson	// no duplicates
duplicates report idhh		

merge m:1 temp_idorigperson2 using full_info
assert _merge==3
drop _merge
gen ind_option = substr(temp_option,1,1) if dgn==1  //alternative bracket for individual male
replace ind_option = substr(temp_option,2,1) if dgn==0 //alternative bracket for individual female
destring ind_option, force replace
gen temp_choice=(ind_option==temp_bracket_0) if dgn==0  //dummy for female individual choice
replace temp_choice=(ind_option==temp_bracket_1) if dgn==1  //dummy for male individual choice

drop ind_option

destring temp_option, force gen (temp_seq)
//check data structure 
gsort temp_idorigperson2 temp_seq //Place observations in ascending order of temp_seq within ascending order of original person id
bysort temp_idorigperson2:egen temp_seq2=seq() //give each working regime a label from 1 to $n_choice^2
replace lhw=0 if temp_not_flexible==1  //not flexible persons should have zero hours of work

bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices)^2 if temp_couples==1 //for an individual in a flexible couple, 1 option is chosen from ($n_choices)^2 options
assert mean_choicehh==1/($n_choices) if temp_singles==1  //for an individual in "singles", 1 option is chosen from $n_choices options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1|temp_couples==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation
drop mean_choicehh

assert temp_choicehh!=. if temp_couples==1  
assert temp_choicehh==. if temp_not_flexible==1
//note: for each individual in "singles", $n_choices out of $n_choices^2 temp_choicehh are non-missing

gen count=1 
bysort temp_idorigperson2: egen sum_option=total(count)  //compute the sum of options
assert sum_option==$n_choices^2   //up to this point, every individual has $n_choices^2 alternatives
drop count sum_option


//update in v8
drop if temp_choicehh==. & temp_singles==1   //drop invalid rows for singles
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)


bysort idhh: egen temp_with_singles2=total(temp_singles)  //the previously generated temp_with_singles may not be useful because up to this point some singles are dropped already 
drop if temp_with_singles2==0 & temp_with_couples==0 & temp_not_flexible==1  //delete not flexible people with no singles or couples to attach to
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) //28235 obs 

gen count=1
bysort temp_idorigperson2: egen sum_option=total(count)  //compute the sum of options

assert sum_option==$n_choices^2 if temp_alt_nsq==1  //yes
assert sum_option==$n_choices if temp_alt_n==1  
su temp_alt_nsq temp_with_singles temp_with_couples if temp_not_flexible==1
drop count sum_option
//check again
assert temp_choicehh!=. if temp_couples==1
assert temp_choicehh!=. if temp_singles==1  //this is new because now singles only have $n_choices kept, solved-contradiction: all aged 16,17,temp_alt_nsq==1, having 12 choices
assert temp_choicehh==. if temp_not_flexible==1

*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
* Correct values for benefits 1/2
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(A) @@@
/*SIMULATED BENEFITS:
Do not worry about them as EUROMOD calculates
the right amount in all choices, given other variables are set correctly.

*the code below is not relevant for PL 
*Notes about bunct_s (unemployment benefit (JSA)): PARTLY SIMULATED, i.e. IT IS SIMULATED BUT THE SIMULATION TAKES SOME VALUES FROM THE DATA. YOU CAN CONSIDER THAT AS "SIMULATED"
//check which variables are used to simulate and manipulate those variables rather than the bunct_s per se, to make bunct_s=0:
preserve
keep id* les bunct
rename les temp_les
rename bunct temp_bunct
save les_bunct,replace //store the original les and bunct for future use if needed
restore
replace les=5 if temp_singles==1|temp_couples==1
replace bunct=0 if temp_singles==1|temp_couples==1
*/

// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B1) @@@
/*BENEFITS NOT SIMULATED, COMPATIBLE WITH A WORKING CONDITION BUT DEPEND ON YEM\LHW:
Set them to zero (Otherwise they are positive only in the observed choice and not modelled in the other choices, 
and this creates a bias in the estimates of the utility function).*/
/*Italy 
drop if (bmals>0|bmase>0)& lhw==0 & (temp_singles==1|temp_couples==1) // bmals:Maternity payments (lump sum); bmase:Maternity payments (only self emp).
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

replace bsa00=0 if temp_singles==1|temp_couples==1   //Social assistance(Minimum Insertion Income )
replace bsa01=0 if temp_singles==1|temp_couples==1   //Social assistance (Basic Needs Debit Card )
*/
/*UK
replace bot=0 if temp_singles==1|temp_couples==1   //other benefits
drop if (bmaer>0|bmana>0)& lhw==0 & (temp_singles==1|temp_couples==1) // bmaer: Statutory maternity pay; bmana: Maternity Allowance (Only 40 obs are dropped from the original whole sample)
*Notes about maternity leave:
// Assume that one who receives at least one of the these benefits (Statutory maternity pay (bmaer) or Maternity Allowance (bmana)) 
//as being on maternity leave but think of them as “working”.
*/

/*DP: No such benefits in HU (materinity ones are simulated)*/

/*PL: 
fre bcc	//Supplement to the family allowance for parents who take unpaid childcare leave to care for a young child.
fre bchunlp //benefit for unemployed lone parents
fre bma	//Maternity allowance
fre ysv	//severance payment
*/
foreach var in bcc bchunlp bma ysv {
replace `var'=0 if temp_singles==1|temp_couples==1   
} 
/*(488 real changes made)
(0 real changes made)
(4,236 real changes made)
(20 real changes made)
*/

// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B2) @@@
/*BENEFITS NOT SIMULATED, NOT COMPATIBLE WITH A WORKING CONDITION AND DO NOT DEPEND ON YEM\LHW:
Set them equal to the amount in the observed choice.*/
/* HU: 
bed: education related income (oktatással kapcsolatos támogatás)
bho: housing benefit
botre: other regular benefits - N/A in the dataset 
bfaot: other family benefits (includes maternity allowance, child care fee and nursing fee) - N/A in the dataset 
*/

/*PL: 
fre bsaot //neither permanent nor temporary social assistance ==> granted once or occasionally for specific urgent needs
fre bed	//scholarships
*/
cap drop mean_*
foreach var in bed bsaot { 
bysort temp_idorigperson2: egen mean_`var'=mean(`var')
//assert `var'==mean_`var'  //make sure `var' is equal to the amount in the observed choice
assert abs(`var' - mean_`var') <= 0.1 
drop mean_`var'
}
 
// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B3) @@@
/*
BENEFITS NOT SIMULATED, NOT COMPATIBLE WITH A WORKING CONDITION AND AN INDIVIDUAL RECEIVES THEM IN THE OBSERVED CHOICE (E.G. A DISABILITY BENEFIT):
Exclude this individual from the sample used for labour supply estimates because it means that, in the observed choice, the individual
has some charateristics incompatible with a working condition
*/
/* Italy 
drop if bunct01>0 & (temp_singles==1|temp_couples==1)  //Unemployment benefit (Cassa Integrazione Guadagni)
drop if bunct02>0 & (temp_singles==1|temp_couples==1)  //Unemployment benefit (Indennita' di Disoccupazione - Mobilita')
drop if bunst>0 & (temp_singles==1|temp_couples==1)  //Unemployment benefit s.t. training
drop if yunsv>0 & (temp_singles==1|temp_couples==1)  //Severance pay (Liquidazioni da lavoro - TFR)
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)
*/
/*UK
drop if bedes>0 & (temp_singles==1|temp_couples==1) //Student payments
drop if bedsl>0 & (temp_singles==1|temp_couples==1) //Student Loan
drop if bdioa>0 & (temp_singles==1|temp_couples==1) //Attendance allowance
drop if bdisc>0 & (temp_singles==1|temp_couples==1) //Disability living allowance
drop if bdimb>0 & (temp_singles==1|temp_couples==1) //Disability living (mobility) allowance
drop if bdiscwa>0 & (temp_singles==1|temp_couples==1) //PIP living allowance
drop if bdimbwa>0 & (temp_singles==1|temp_couples==1) // PIP mobility

drop if bdict0117>0 & (temp_singles==1|temp_couples==1) //Incapacity Benefit 2017
drop if bdict0118>0 & (temp_singles==1|temp_couples==1) //Incapacity Benefit 2018
drop if bdict0217>0  & (temp_singles==1|temp_couples==1) //Contributory ESA 2017
drop if bdict0218>0  & (temp_singles==1|temp_couples==1) //Contributory ESA 2018

drop if bdiwi>0 & (temp_singles==1|temp_couples==1) //Industrial injuries pension
drop if bcrdi>0 & (temp_singles==1|temp_couples==1) //Invalid care allowance
drop if bdisv>0 & (temp_singles==1|temp_couples==1) //Severe disablement allowance
drop if bhlwk>0 & (temp_singles==1|temp_couples==1)  //Statutory sick pay
drop if buntr>0 & (temp_singles==1|temp_couples==1) //Training allowance
*/

/*HU: only pdi - disability pension -  could be classified as such  
drop if pdi>0 & (temp_singles==1|temp_couples==1) */

/*PL: all pensions are compatible with working condition but their earnings are (strictly) limited and may affect their pension. Not sure how to account for that because they are not simulated.  
==> opted for removing people on disability pensions completely 
fre pdi00 //Disability pension (agricultural and non-agricultural)
fre pdinw //Social pension
fre poa00 //Retirement pension (agricultural and non-agricultural)
fre poafr //Farmer's structural pension
fre poaot //pension : old age : other
fre psu00 //Survivors pension (agricultural and non-agricultural)
fre pyr	//Pre-retirement allowance and benefit
*/
drop if pdi00>0 | pdinw>0 & (temp_singles==1|temp_couples==1) //(5,896 observations deleted)

/////////////////////////////////////////////////////////////
//Now after benefit correction, check data structure again //
/////////////////////////////////////////////////////////////
gen d=1
bysort temp_idorigperson2: egen count=total(d)
su count
drop if count!=($n_choices)^2 &temp_alt_nsq==1
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) 

drop if count!=($n_choices) &temp_alt_n==1
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) 

drop d count
gsort temp_idorigperson2 temp_seq //Place observations in ascending order of temp_seq within ascending order of original person id
assert lhw==0 if temp_not_flexible==1  //not flexible persons should have zero hours of work

bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices)^2 if temp_couples==1 //for an individual in a flexible couple, 1 option is chosen from ($n_choices)^2 options
assert mean_choicehh==1/($n_choices) if temp_singles==1  //for an individual in "singles", 1 option is chosen from $n_choices options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1|temp_couples==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation

drop mean_choicehh


/*
//@@@ tax compliance assumption #1@@@
//assume full tax compliance, set yseev and ysenr to 0 and hence set TCA  off in EUROMOD
//NOTE: an additional step to finish this assumption is to set TCA off which means adding -extSwitch "TCA=off" in the command to run EUROMOD later
//      Without this additional step, EUROMOD will still keep the defualt setting, i.e. TCA is on. 
//replace yseev=0 
//replace ysenr=0

//@@@ tax compliance assumption #2@@@
//assume no full tax compliance, fill in yseev, ysenr
//replace yseev=0.5*yse  //50% SE income reported to tax authority under no full tax compliance
//replace ysenr=0.5*yse  //50% SE income not reported to tax authority under no full tax compliance
gen ratio_yseev=yseev/(yseev+ysenr)   //this is how the ratio of total se income reported to tax authority (assume this to be the same in every alternative for the same individual)
gen ratio_ysenr=ysenr/(yseev+ysenr)   //this is how the ratio of total se income not reported to tax authority (assume this to be the same in every alternative for the same individual)
replace yseev=ratio_yseev*yse if yseev!=0|ysenr!=0
replace ysenr=ratio_ysenr*yse if yseev!=0|ysenr!=0
assert yseev!=.
assert ysenr!=.
*/

*------------------------------------------------------------
* Store information not for EUROMOD for later use
*------------------------------------------------------------	
preserve
keep id* temp*
save temp_file.dta, replace
restore
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) //27463
assert temp_singles_indep+temp_singles_dep+temp_couples+temp_not_flexible==1
count if temp_singles_indep==1&temp_choicehh==1 //3,192
count if temp_singles_dep==1 &temp_choicehh==1 //1,457
count if temp_couples==1 &temp_choicehh==1 //11,388
count if temp_not_flexible==1&temp_choicehh==1 //0

/*VERY IMPORTANT: PL model does not use yem and yse as other models do. PL splits these income by type because different tax regimes are applied to different types of earnings  
This needs to be chnaged before data enters the model otherwise there will be no diferences in earnings by alternatives */
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
foreach var in yempj yemtj yseag ysebs {
gen temp_`var'= `var'
} //save original values 

cap drop yempj yemtj
gen yempj = 0
replace yempj = yem if temp_yempj>0 & temp_yemtj==0
gen yemtj = 0
replace yemtj = yem if temp_yempj==0 & temp_yemtj>0

cap drop yseag ysebs 
gen yseag = 0
replace yseag = yse if temp_yseag>0 & temp_ysebs==0
gen ysebs = 0
replace ysebs = yse if temp_yseag==0 & temp_ysebs>0 
*end of correction 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
save individuals.dta,replace

*=======================================================================
*           create EUROMOD input data
*=======================================================================
*----------------------------------------------------------------------------------------------------
* singles_wage1.dta as input data(Predicted wage for everyone), but not in the EM input folder yet
*-----------------------------------------------------------------------------------------------------	
use individuals,clear
drop temp*                                                 //This is because as per EUROMOD conventions, some variables should not appear in the input database.
sort idhh idperson
drop number*  partner_dgn _est* //ratio*

save individuals_wage1.dta, replace

*-------------------------------------------------------------------------------------------------------------
* singles_wage2.dta as input data(Predicted wage for non-workers only), but not in the EM input folder yet
*-------------------------------------------------------------------------------------------------------------	
use individuals,clear
drop number*  partner_dgn _est* //ratio*

***************************************************
* // @@@ WAGE IMPUTATION METHOD #wage2@@@
* make predicted wage=yivwg only for non-workers 
*(before this yivwg=predicted wage for everyone)
****************************************************	
replace yivwg=temp_obs_wage if temp_em==1|temp_se==1 //for workers used for the Heckman estimation, wages=actual wages
/*
//for workers' all states, assume all income are employed income or self-employed income depending which is their major income source in their actual state
replace yem=yivwg*lhw*4.3 if temp_em==1		   
replace yse=0 if temp_em==1 

replace yse=yivwg*lhw*4.3 if temp_se==1                     
replace yem=0 if temp_se==1 

// for non-workers' counterfacual states, assume all income are employed income
replace yem=yivwg*lhw*4.3 if temp_nonworker==1	&temp_choice==0  
*/

/*VERY IMPORTANT: here's an additional correction of earnings specific for PL model */
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//for workers' all states, assume all income are employed income or self-employed income depending which is their major income source in their actual state
replace yempj=yivwg*lhw*4.3 if temp_em==1 &  yempj>0
replace yemtj=yivwg*lhw*4.3 if temp_em==1 &  yemtj>0
replace yseag=0 if temp_em==1 
replace ysebs=0 if temp_em==1 

replace yseag=yivwg*lhw*4.3 if temp_se==1 & yseag>0                 
replace ysebs=yivwg*lhw*4.3 if temp_se==1 & ysebs>0  
replace yempj=0 if temp_se==1 
replace yemtj=0 if temp_se==1 

// for non-workers' counterfacual states, assume all income are employed income
replace yempj=yivwg*lhw*4.3 if temp_nonworker==1	&temp_choice==0 
replace yemtj=yivwg*lhw*4.3 if temp_nonworker==1	&temp_choice==0  
*end of correction 
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

drop temp*                                                 //This is because as per EUROMOD conventions, some variables should not appear in the input database.
sort idhh idperson

save individuals_wage2.dta, replace

*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
* Correct values for benefits 2/2
*To be precise, no actual correction is done here, the point is to replicate benefits to 
*all alternatives to make a data set called special_partners.dta,
*and append this to the "singles" to make EUROMOD input data
// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #1 @@@
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

*loop through wage1, wage2:export as em input file, then run EM, then save output in the result folder for labour supply estimation, 
*named "individuals_output_wage`i'"

foreach i in 1 2{ 
//local i=2  //only do for wage1 
use individuals_wage`i',clear
export delimited "$em_input\$file_input.txt", replace nolabel delim(tab) //create input data for EUROMOD
************************************************************
*						Run EUROMOD with Stata
************************************************************
//note that input data for PL is in national currency - but we want output is euros - this needs to be manually changed in model settings. 
version 13
* Call EUROMOD 

capture erase "${em_output}\$file_output.txt"  //erase previous output file, this is done in case EUROMOD call from Stata fails, to be sure we are not opening an early run of the model
 //2018 earnings (2019 data) and 2018 system                                                          
shell "${em_exe}" -emPath "${em_models}" -sys PL_2018 -data PL_2019_b3 -forceOutputInEuro //call EUROMOD 1:Program to call 2: path for folder 3: system name 4: dataset to use

*import EUROMOD RUN

import delimited "${em_output}\$file_output.txt", clear  //import data from txt file in output folder 

/*drop individuals causing errors 
drop if idperson==1000200 //parts of yse do not sum up 0 <> 9666.6659
drop if idpesron==1000201 //parts of yse do not sum up 0 <> 9666.6659
drop if idperson==1000202 //parts of yse do not sum up 0 <> 9666.6659
drop if idperson==7925000120 //parts of yse do not sum up 1705.46648 <> 2131.8331
drop if idperson==7925000121 //parts of yse do not sum up 1705.46648 <> 2131.8331
*/

save individuals_output_wage`i',replace

}

log close
