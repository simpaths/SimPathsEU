/*******************************************************************************
* PROJECT:  		SimPaths EU 
* SECTION:			Wage regression 
* OBJECT: 			Heckman selection regressions 
* AUTHORS:			Daria Popova, Justin van de Ven, Ashley Burdett, 
*					Aleksandra Kolndrekaj
* LAST UPDATE:		November 26 AK
* COUNTRY: 			Poland
******************************************************************************** 
* NOTES: 			Strategy: Pooled cross-sectional regressions. 
* 					1) Heckman estimated on the sub-sample of individuals 
* 						who are not observed working in previous period. 
*   					=> Wage equation does not controls for lagged wage
* 					2) Heckman estimated on the sub-sample of individuals who 
* 						are observed working in previous period. 
*    					=> Wage equation controls for lagged wage
* 					Specification of selection equation is the same in the 
* 						two samples
* 					
* 					Import labour cost index to create a measure of wage growth. 
* 					Make sure loaded into the external_data subfolder. 
* 
* 					Update the winsorization process if alter data 
* 					Update CPI if apply to a different country 
*
* TO DO: 			Explore using the centering adjustment when adding 
* 					random draw: -e(sigma)^2/2
*******************************************************************************/

clear all
set more off
set mem 200m
set type double
set maxvar 30000

* Set off log 
cap log close 
log using "$dir_log/reg_wages.log", replace


/********************************* SET EXCEL FILE *****************************/

* Info sheet - first stage 
putexcel set "$dir_work/reg_employmentSelection", sheet("Info") ///
	replace
putexcel A1 = "Description:", bold
putexcel B1 = "This file contains regression estimates from the first stage of the Heckman selection model used to estimates wages."

putexcel A2 = "Authors:", bold
putexcel B2 = "Ashley Burdett, Aleksandra Kolndrekaj" 	
putexcel A3 = "Last edit:", bold
putexcel B3 = "11 Oct 26 AK"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "W1fa-sel"
putexcel B6 = "First stage Heckman selection estimates for women that do not have an observed wage in the previous year"
putexcel A7 = "W1ma-sel"
putexcel B7 = "First stage Heckman selection estimates for women that do not have an observed wage in the previous year"
putexcel A8 = "W1fb-sel"
putexcel B8 = "First stage Heckman selection estimates for women that have an observed wage in the previous year"
putexcel A9 = "W1mb-sel"
putexcel B9 = "First stage Heckman selection estimates for men that have an observed wage in the previous year"

putexcel A12 = "Notes:", bold
putexcel B12 = "Estimated on panel data unlike the labour supply estimates"
putexcel B13 = "Predicted wages used as input into union parameters and income process estimates"
putexcel B14 = "Two-step Heckman command is used which does not permit weights"
putexcel B15 = "Regions: PL4 = Polnocno-Zachodni, PL5 = Poludniowo-Zachodni, PL6 = Polnocy, PL10 = Central + East. Poludniowy is the omitted category."
putexcel B16 = "Estimate the models without the lagged wage observation on the full working age sample. Choice made because otherwise the reduction in the sample size makes the sigma used when correcting the bias when transforming the log wages to wage levels too large."

* Info sheet - second stage 
putexcel set "$dir_work/reg_wages", sheet("Info") replace
putexcel A1 = "Description:", bold
putexcel B1 = "This file contains regression estimates used to calculate potential wages for males and females in the simulation."

putexcel A2 = "Authors:", bold
putexcel B2 = "Ashley Burdett, Aleksandra Kolndrekaj" 	
putexcel A3 = "Last edit:", bold
putexcel B3 = "11 Oct 26 AK"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "W1fa"
putexcel B6 = "Heckman selection estimates using women that do not have an observed wage in the previous year"
putexcel A7 = "W1ma"
putexcel B7 = "Heckman selection estimates using men that do not have an observed wage in the previous year"
putexcel A8 = "W1fb"
putexcel B8 = "Heckman selection estimates using women that have an observed wage in the previous year"
putexcel A9 = "W1mb"
putexcel B9 = "Heckman selection estimates using men that have an observed wage in the previous year"

putexcel A12 = "Notes:", bold
putexcel B12 = "Estimated on panel data unlike the labour supply estimates"
putexcel B13 = "Predicted wages used as input into union parameters and income process estimates"
putexcel B14 = "Two-step Heckman command is used which does not permit weights"
putexcel B15 = "Regions: PL4 = Polnocno-Zachodni, PL5 = Poludniowo-Zachodni, PL6 = Polnocy, PL10 = Central + East. Poludniowy is the omitted category."
putexcel B16 = "Estimate the models without the lagged wage observation on the full working age sample. Choice made because otherwise the reduction in the sample size makes the sigma used when correcting the bias when transforming the log wages to wage levels too large."


/********************************* PREPARE DATA *******************************/

* Convert real wage growth into .dta file

import excel "$dir_data/time_series_factor.xlsx", sheet("wage_growth") ///
	firstrow clear

rename Year swv 

gen stm = swv - 2000
drop swv 

rename Value real_wage_growth 

save "$dir_data/growth_rates", replace

* Load main dataset
use "$dir_input_data/${country}_pooled_ipop.dta", clear

* Set data
xtset idperson swv 
sort idperson swv

* Ensure missing is missing
recode deh_c3 deh_c4 obs_earning lhw drgn1 dhe les_c3 les_c4 (-9=.)

* Drop children 
drop if dag < ${age_seek_employment}

* Adjust variables 

* Time variables 
* Centre time variables 
replace stm = stm - 2000
replace swv = swv - 2010

* Year dummies
gen y2011 = (stm == 11)
gen y2012 = (stm == 12)
gen y2013 = (stm == 13)
gen y2014 = (stm == 14)
gen y2015 = (stm == 15)
gen y2016 = (stm == 16)
gen y2017 = (stm == 17)
gen y2018 = (stm == 18)
gen y2019 = (stm == 19)
gen y2020 = (stm == 20)
gen y2021 = (stm == 21)
gen y2022 = (stm == 22)
gen y2023 = (stm == 23)
gen y2024 = (stm == 24)

sort idperson swv 

gen L1les_c3 = L.les_c3

replace deh_c3 = . if deh_c4 == 0 

* Merge in wage growth index
merge m:1 stm using "$dir_data/growth_rates", keep(3) nogen ///
	keepusing(real_wage_growth)

* Check idperson and stm ensures uniqueness
duplicates tag idperson stm, gen(dup)

sort idperson stm
xtset idperson stm

* Total hours work per week (average)
gen hours = 0
replace hours = lhw if ((lhw > 0) & (lhw < .))
label var hours "Hours worked per week"

* Hour groups
gen hrs1 = (hours >   0) * (hours < 10)
gen hrs2 = (hours >= 10) * (hours < 15)
gen hrs3 = (hours >= 15) * (hours < 20)
gen hrs4 = (hours >= 20) * (hours < 25)
gen hrs5 = (hours >= 25) * (hours < 30)
gen hrs6 = (hours >= 30) * (hours < 35)
gen hrs7 = (hours >= 35) * (hours < 40)


lab var yplgrs_dv "Gross personal employment income, IHS"

* Hourly wage	
gen wage_hour = obs_earnings_hourly
	
* Winsorize
sum wage_hour, det
replace wage_hour = . if wage_hour <= 0
replace wage_hour = . if wage_hour >= r(p99)

gen lwage_hour = ln(wage_hour)
label var lwage_hour "Log gross hourly wage"

gen lwage_hour_2 = lwage_hour^2
label var lwage_hour_2 "Squared log gross hourly wage"

* Part-time dummy
gen pt = (hours >  0) * (hours <= 35)
label var pt "Works part-time"
rename pt Pt

* Create exclusion restrictions 
* Relationship status 
gen mar = (dcpst == 1)
label var mar "In a partnership"

* Children
gen any02 = dnc02 > 0 & dnc02 != . 
label var any02 "Has children between 0-2 years old"

cap gen child = (dnc > 0 & dnc != .)
label var child "Has children"

* Set data 
sort idperson stm
xtset idperson stm

* Flag to identify observations to be included in the estimation sample 
* Need to have been observed at least once in the past and activity information 
* is not missing in the previous observation 
bys idperson (swv): gen obs_count_ttl = _N
bys idperson(swv): gen obs_count = _n

gen in_sample = (obs_count_ttl > 1 & obs_count > 1) 
replace in_sample = 0 if swv != swv[_n-1] +1 & idperson == idperson[_n-1]
replace in_sample = 0 if les_c3 == . | obs_earning == . 

* Flag to distinguish the two samples (prev work and not)
xtset idperson swv 
sort idperson swv 

capture drop previouslyWorking

gen previouslyWorking = (L1.lwage_hour != .) 
replace previouslyWorking = . if in_sample == 0 

* Prep storage 
capture drop lwage_hour_hat wage_hour_hat esample

gen lwage_hour_hat = .
gen wage_hour_hat = .
gen esample = .
gen pred_hourly_wage = .


/********************************** ESTIMATION ********************************/
//********************************** ESTIMATION ********************************/

* Run Stata programs to produce Excel file 
do "${dir_do}/programs.do" 


/******************** WAGES: FEMALE, NO PREV WAGE OBSERVED ********************/
xtset idperson swv
gen Dgn = dgn 

gen Dag = dag  

gen Dag_sq = dagsq 

tab drgn1, gen(${country}) 
rename PL5 PL10 
rename PL4 PL6
rename PL3 PL5 
rename PL2 PL4
rename PL1 PL2

global regions "i.PL4 i.PL5 i.PL6 i.PL10"

tab deh_c3, gen(Deh_c3_)
rename Deh_c3_1 Deh_c3_High
rename Deh_c3_3 Deh_c3_Low

tab deh_c4, gen(Deh_c4_)
rename Deh_c4_1 Deh_c4_Na
rename Deh_c4_2 Deh_c4_High
rename Deh_c4_3 Deh_c4_Medium
rename Deh_c4_4 Deh_c4_Low

gen Deh_c4_Na_L1 = l.Deh_c4_Na
gen Deh_c4_High_L1 = l.Deh_c4_High
gen Deh_c4_Medium_L1 = l.Deh_c4_Medium
gen Deh_c4_Low_L1 = l.Deh_c4_Low

gen Ded_L1 = l.ded

tab dcpst, gen(Dcpst_)
rename Dcpst_1 Dcpst_Partnered
rename Dcpst_2 Dcpst_Single

tab les_c3, gen(Les_c3_)
rename Les_c3_1 Les_c3_Employed
rename Les_c3_2 Les_c3_Student
rename Les_c3_3 Les_c3_NotEmployed

tab ydses_c5, gen(Ydses_c5_Q) 

gen Ydses_c5_Q2_L1 = l.Ydses_c5_Q2
gen Ydses_c5_Q3_L1 = l.Ydses_c5_Q3
gen Ydses_c5_Q4_L1 = l.Ydses_c5_Q4
gen Ydses_c5_Q5_L1 = l.Ydses_c5_Q5

gen Dnc = dnc

gen Dnc02 = dnc02


gen Dnc1_plus=1 if dnc>=1
replace Dnc1_plus=0 if dnc==0


gen Dnc02_yes=1 if dnc02>0
replace Dnc02_yes=0 if dnc02==0


gen Year_transformed = stm  
gen Year_transformed_sq = stm * stm 

gen Y2011 = y2011
gen Y2012 = y2012  
gen Y2013 = y2013  
gen Y2014 = y2014 
gen Y2015 = y2015 
gen Y2016 = y2016
gen Y2017 = y2017
gen Y2018 = y2018
gen Y2019 = y2019  
gen Y2020 = y2020  
gen Y2021 = y2021 
gen Y2022 = y2022 
gen Y2023 = y2023
gen Y2024 = y2024
gen Y2223 = (stm == 22 | stm == 23)

gen Les_c3_Student_L1= 1 if L1les_c3==2
replace Les_c3_Student_L1=0 if L1les_c3!=2
replace Les_c3_Student_L1=. if L1les_c3==.

gen Les_c3_NotEmployed_L1=1 if L1les_c3==3
replace Les_c3_NotEmployed_L1=0 if L1les_c3!=3
replace Les_c3_NotEmployed_L1=. if L1les_c3==.

gen Deh_c4_Medium_Dag = Deh_c4_Medium*Dag
gen Deh_c4_Low_Dag = Deh_c4_Low*Dag

gen L1_log_hourly_wage=l.lwage_hour
tab dhe, gen(Dhe_)
rename Dhe_1 Dhe_Poor
rename Dhe_2 Dhe_Fair
rename Dhe_3 Dhe_Good
rename Dhe_4 Dhe_VeryGood
rename Dhe_5 Dhe_Excellent



xtset idperson swv
gen Dcpst_Partnered_L1 = l.Dcpst_Partnered


gen Dnc1_plus_L1 = l.Dnc1_plus

rename real_wage_growth RealWageGrowth


/******************** WAGES: FEMALE, NO PREV WAGE OBSERVED ********************/

local var_list Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag ///
	Deh_c4_Low_Dag Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
	PL4 PL5 PL6 PL10 Pt RealWageGrowth Y2020 Y2021 Constant InverseMillsRatio
	
local sel_var_list  Les_c3_Student_L1 Les_c3_NotEmployed_L1 Dag Dag_sq ///
	Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag  Deh_c4_Low_Dag ///
	Dcpst_Partnered_L1 D_Children_L1 Dhe_Fair Dhe_Good ///
	Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Y2020 Y2021 ///
	Constant	

global wage_eqn "lwage_hour Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Pt RealWageGrowth Y2020 Y2021"
global seln_eqn "Les_c3_Student_L1 Les_c3_NotEmployed_L1 Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag  Deh_c4_Low_Dag Dcpst_Partnered_L1 Dnc1_plus_L1 Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Y2020 Y2021" 
local filter = "${W1fa_if_condition} & previouslyWorking == 0"

capture drop lambda
heckman $wage_eqn if ${W1fa_if_condition}, select($seln_eqn) twostep mills(lambda)
process_heckman,  ///
    process("W1fa") ///
    ifcond("`filter'") ///
    savefile("Female_NPW_sample") ///
    graphsubtitle("Females, No previously observed wage") ///
    wordfile("$dir_raw_results/wages/Output_NWW.doc") ///
    wordtitle("Heckman-corrected wage equation: women not in employment last year") ///
    wordctitle("Not working women") ///
    sheet2("W1fa") sheet1("W1fa-sel") ///
    rmserow(2) varlist("`var_list'")




/********************* WAGES: MALE, NO PREV WAGE OBSERVED *********************/

local var_list Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag ///
	Deh_c4_Low_Dag Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent ///
	EPL4 PL5 PL6 PL10 Pt RealWageGrowth Y2020 Y2021 Constant InverseMillsRatio

local sel_var_list Les_c3_Student_L1 Les_c3_NotEmployed_L1 Dag Dag_sq ///
	Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag ///
	Dcpst_Partnered_L1 D_Children_L1 Dhe_Fair Dhe_Good ///
	Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Y2020 Y2021 ///
	Constant	

global wage_eqn "lwage_hour Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Pt RealWageGrowth Y2020 Y2021" 
global seln_eqn "Les_c3_Student_L1 Les_c3_NotEmployed_L1 Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag Dcpst_Partnered_L1 Dnc1_plus_L1 Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Y2020 Y2021" 
local filter = "${W1ma_if_condition} & previouslyWorking == 0"

capture drop lambda
heckman $wage_eqn if ${W1ma_if_condition}, select($seln_eqn) twostep mills(lambda)

process_heckman, ///
    process("W1ma") ///
    ifcond("`filter'") ///
    savefile("Male_NPW_sample") ///
    graphsubtitle("Males, No previously observed wage") ///
    wordfile("$dir_raw_results/wages/Output_NWM.doc") ///
    wordtitle("Heckman-corrected wage equation: men not in employment last year") ///
    wordctitle("Not working men") ///
    sheet2("W1ma") sheet1("W1ma-sel") ///
    rmserow(3) varlist("`var_list'")
*/


*/
/********************** WAGES: FEMALE, PREV WAGE OBSERVED *********************/
local var_list L1_log_hourly_wage Dag Dag_sq Deh_c4_Medium Deh_c4_Low ///
	Deh_c4_Medium_Dag Deh_c4_Low_Dag Dhe_Fair Dhe_Good Dhe_VeryGood ///
	Dhe_Excellent PL4 PL5 PL6 PL10 Pt RealWageGrowth Y2020 Y2021 Constant ///
	
local sel_var_list Dag Dag_sq ///
	Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag  Deh_c4_Low_Dag ///
	Dcpst_Partnered_L1 D_Children_L1 Dhe_Fair Dhe_Good ///
	Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Y2020 Y2021 ///
	Constant

global wage_eqn "lwage_hour L1_log_hourly_wage Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Pt RealWageGrowth Y2020 Y2021" 
global seln_eqn "Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag Dcpst_Partnered_L1 Dnc1_plus_L1 Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Y2020 Y2021" 

local filter = "${W1fb_if_condition} & previouslyWorking == 1"

capture drop lambda
heckman $wage_eqn if ${W1fb_if_condition}, select($seln_eqn) twostep mills(lambda)
	
process_heckman, ///
    process("W1fb") ///
    ifcond("`filter'") ///
    savefile("Female_PW_sample") ///
    graphsubtitle("Females, Previously observed wage") ///
    wordfile("$dir_raw_results/wages/Output_WW.doc") ///
    wordtitle("Heckman-corrected wage equation: women in employment last year") ///
    wordctitle("Working women") ///
    sheet2("W1fb") sheet1("W1fb-sel") ///
    rmserow(4) varlist("`var_list'")

*/

/*********************** WAGES: MEN, PREV WAGE OBSERVED ***********************/
/*
NOTE: Explored using log age due to signs of age and age squared, but in 
age validaition there is very little difference - main contrast among those 
age > 65. 
*/
/*********************** WAGES: MEN, PREV WAGE OBSERVED ***********************/
/*
NOTE: Explored using log age due to signs of age and age squared, but in 
age validaition there is very little difference - main contrast among those 
age > 65. 
*/
local var_list L1_log_hourly_wage Dag Dag_sq Deh_c4_Medium Deh_c4_Low ///
	Deh_c4_Medium_Dag Deh_c4_Low_Dag Dhe_Fair Dhe_Good Dhe_VeryGood ///
	Dhe_Excellent PL4 PL5 PL6 PL10 Pt RealWageGrowth Y2020 Y2021 Constant ///

local sel_var_list Dag Dag_sq ///
	Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag ///
	Dcpst_Partnered_L1 D_Children_L1 Dhe_Fair Dhe_Good ///
	Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Y2020 Y2021 ///
	Constant

global wage_eqn "lwage_hour L1_log_hourly_wage Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Pt RealWageGrowth Y2020 Y2021"
global seln_eqn "Dag Dag_sq Deh_c4_Medium Deh_c4_Low Deh_c4_Medium_Dag Deh_c4_Low_Dag Dcpst_Partnered_L1 Dnc1_plus_L1 Dhe_Fair Dhe_Good Dhe_VeryGood Dhe_Excellent PL4 PL5 PL6 PL10 Y2020 Y2021 " 

/*
gen ldag = ln(dag)

global wage_eqn "lwage_hour L1.lwage_hour ldag i.deh_c4 i.deh_c4#c.ldag i.dhe i.drgn1 i.pt real_wage_growth y2020 y2021"
global seln_eqn "ldag i.deh_c4 i.deh_c4#c.ldag i.mar i.child i.dhe i.drgn1 y2020 y2021" 
*/

local filter = "${W1mb_if_condition} & previouslyWorking == 1"

capture drop lambda
heckman $wage_eqn if ${W1mb_if_condition}, select($seln_eqn) twostep mills(lambda)
process_heckman, ///
    process("W1mb") ///
    ifcond("`filter'") ///
    savefile("Male_PW_sample") ///
    graphsubtitle("Male, Previously observed wage") ///
    wordfile("$dir_raw_results/wages/Output_WM.doc") ///
    wordtitle("Heckman-corrected wage equation: men in employment last year") ///
    wordctitle("Working men") ///
    sheet2("W1mb") sheet1("W1mb-sel") ///
    rmserow(5) varlist("`var_list'")
	
*process_heckman, ///
    process("W1mb") ///
    ifcond("`filter'") ///
    savefile("Male_PW_sample") ///
    graphsubtitle("Male, Previously observed wage") ///
    wordfile("$dir_raw_results/wages/Output_WM.doc") ///
    wordtitle("Heckman-corrected wage equation: men in employment last year") ///
    wordctitle("Working men") ///
    sheet2("W1mb") sheet1("W1mb-sel") ///
    rmserow(5) varlist("`var_list'")*

* Save predicted wages to dataset 
	
* Use predicted wage for all; fall back to observed wage for those with no
* prediction (first observation for an individual)
replace pred_hourly_wage = exp(lwage_hour) if missing(pred_hourly_wage)

gen labWageHrly = pred_hourly_wage


save "$dir_data/${country}-_pooled_ipop2.dta", replace
display "Wage analysis complete!"

capture log close
