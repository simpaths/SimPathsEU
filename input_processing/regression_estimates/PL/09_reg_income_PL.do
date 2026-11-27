********************************************************************************
* PROJECT:  		SimPaths EU
* SECTION:			Non-employment/non-benefit income
* OBJECT: 			Final Regresion Models 
* AUTHORS:			Daria Popova, Justin van de Ven, Ashley Burdett, 
*					Aleksandra Kolndrekaj
* LAST UPDATE:		November 2026 AK
* COUNTRY: 			Poland  
********************************************************************************
* NOTES: 			 
* 					I1a - Capital income (in cont edu, selection & amount)
* 					I1b - Capital income (not in cont edu, selection & amount)
* 
* 					Estimate both 
* 					Explored using les_c4 instead of les_c3, but didn't make a 
* 						material difference. 
* 
********************************************************************************

clear all
set more off
set mem 200m
set type double
set maxvar 30000

* Set off log
cap log close 
log using "$dir_log/reg_income.log", replace


/********************************* SET EXCEL FILE *****************************/

* Info sheet
putexcel set "$dir_work/reg_income", sheet("Info") replace
putexcel A1 = "Description:", bold
putexcel B1 = "This file contains regression estimates used by process I3, capital income. The data suggests there is no private pension income "

putexcel A2 = "Authors:", bold
putexcel B2 = "Ashley Burdett, Aleksandra Kolndrekaj" 	
putexcel A3 = "Last edit:", bold
putexcel B3 = "11 Oct. 26 AK"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold

putexcel A6 = "Process I1a"
putexcel B6 = "Logit regression estimates of the probability of receiving capital income "

putexcel A8 = "Process I1b"
putexcel B8 = "OLS regression estimates (ihs) capital income amount -  who receive capital income"

putexcel A12 = "Notes:", bold
putexcel B12 = "Categorical health variable modelled as continuous"
putexcel B12 = "Regions: PL4 = Polnocno-Zachodni, PL5 = Poludniowo-Zachodni, PL6 = Polnocy, PL10 = Central + East. Poludniowy is the omitted category."

* Goodness of fit
putexcel set "$dir_work/reg_income", sheet("Gof") modify

putexcel A1 = "Goodness of fit", bold


/********************************* PREPARE DATA *******************************/

* Load data 
use "$dir_input_data/${country}_pooled_ipop", clear 

* Ensure missing is missing 
recode dgn dag dagsq dhe drgn1 stm scedsmpl deh_c3 deh_c4 les_c4 les_c3 ///
	dhhtp_c4 dhe (-9=.)

* Remove children 
drop if dag < 16

* Adjust variables	

sum yplgrs_dv ypncp ypnoab /*pred_hourly_wage*/
replace stm = stm - 2000
fre stm 
* Time variables 
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
bys swv idhh: gen nwa = _N

gen ypncp_lvl = sinh(ypncp) 


* Trim the top captial income percentile
sum ypncp, det
scalar p99 = r(p99)

replace ypncp = . if ypncp >= p99


gen receives_ypncp = (ypncp > 0 & !missing(ypncp))

gen  ypnbihs_dv_sq = ypnbihs_dv^2 


* Labeling and formating variables
label def jbf 1 "Employed" 2 "Student" 3 "Not Employed"
label def edd 1 "Degree"	2 "High school" ///
				3 "Other/No Qualification"		
label def gdr 1  "Male" 0 "Female"
		
label def yn	1 "Yes" 0 "No"
label def hht 1 "Couples with No Children" 2 "Couples with Children" ///
				3 "Single with No Children" 4 "Single with Children" 

label val dgn gdr
label val les_c3 jbf 
label val deh_c3 edd 
label val dcpen dcpex yn
label val lesdf_c4 dces
label val ded dlltsd yn
label val dhhtp_c4 hht
				
				
label var dgn "Gender"
label var dag "Age"
label var dagsq "Age Squared"
label var drgn1 "Region"
label var stm "Year"
label var les_c3 "Employment Status: 3 Category" 
label var deh_c3 "Educational Attainment: 3 Category"
label var dhhtp_c4 "Household Type: 4 Category"
label var dnc "Number of Children in Household"
label var dnc02 "Number of Children aged 0-2 in Household"
label var dhe "Self-rated Health"
label var ydses_c5 "Annual Household Income Quintile" 
label var dlltsd "Long-term Sick or Disabled"
label var dcpen "Entered a new Partnership"
label var dcpex "Partnership dissolution"
label var lesdf_c4 "Differential Employment Status"
label var ypnbihs_dv "Personal Non-benefit Gross Income"
label var ypnoab_lvl "Real pension income, level"
label var ypnoab "Real pension income, IHS"
label var ypnbihs_dv_sq "Personal Non-benefit Gross Income Squared"
label var ynbcpdf_dv "Differential Personal Non-Benefit Gross Income"
label var ypncp "Gross real monthly personal non-emp capital income, asinh"

* Alter names and create dummies for automatic labelling 
gen Dgn = dgn 

gen Ded= ded

gen Dag = dag  

gen  Dag_sq = dagsq 

tab drgn1, gen(${country}) 
rename PL5 PL10 
rename PL4 PL6
rename PL3 PL5 
rename PL2 PL4
rename PL1 PL2

global regions "i.PL4 i.PL5 i.PL6 i.PL10"

tab deh_c3, gen(Deh_c3_)
rename Deh_c3_1 Deh_c3_High
rename Deh_c3_2 Deh_c3_Medium
rename Deh_c3_3 Deh_c3_Low

tab deh_c4, gen(Deh_c4_)
rename Deh_c4_1 Deh_c4_Na
rename Deh_c4_2 Deh_c4_High
rename Deh_c4_3 Deh_c4_Medium
rename Deh_c4_4 Deh_c4_Low

tab les_c3, gen(Les_c3_)
rename Les_c3_1 Les_c3_Employed
rename Les_c3_2 Les_c3_Student
rename Les_c3_3 Les_c3_NotEmployed

tab les_c4, gen(Les_c4_)
rename Les_c4_1 Les_c4_Employed
rename Les_c4_2 Les_c4_Student
rename Les_c4_3 Les_c4_NotEmployed
rename Les_c4_4 Les_c4_Retired

tab ydses_c5, gen(Ydses_c5_Q)

tab dhe, gen(Dhe_)
rename Dhe_1 Dhe_Poor
rename Dhe_2 Dhe_Fair
rename Dhe_3 Dhe_Good
rename Dhe_4 Dhe_VeryGood
rename Dhe_5 Dhe_Excellent

tab dhesp, gen(Dhesp_)
rename Dhesp_1 Dhesp_Poor
rename Dhesp_2 Dhesp_Fair
rename Dhesp_3 Dhesp_Good
rename Dhesp_4 Dhesp_VeryGood
rename Dhesp_5 Dhesp_Excellent

tab dehsp_c3, gen(Dehsp_c3_)
rename Dehsp_c3_1 Dehsp_c3_High
rename Dehsp_c3_2 Dehsp_c3_Medium
rename Dehsp_c3_3 Dehsp_c3_Low

tab lesdf_c4, gen(Lesdf_c4_)
rename Lesdf_c4_1 Lesdf_c4_BothEmployed
rename Lesdf_c4_2 Lesdf_c4_EmpSpouseNotEmp
rename Lesdf_c4_3 Lesdf_c4_NotEmpSpouseEmp
rename Lesdf_c4_4 Lesdf_c4_BothNotEmployed

tab dhhtp_c4, gen(Dhhtp_c4_)
rename Dhhtp_c4_1 Dhhtp_c4_CoupleNoChildren
rename Dhhtp_c4_2 Dhhtp_c4_CoupleChildren
rename Dhhtp_c4_3 Dhhtp_c4_SingleNoChildren
rename Dhhtp_c4_4 Dhhtp_c4_SingleChildren

gen Dnc = dnc

gen Dnc02 = dnc02

gen Year_transformed = stm 

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

gen Dhe = dhe 

gen Ydses_c5 = ydses_c5 

gen New_rel = new_rel

gen Dcpyy = dcpyy_st 

gen Dcpagdf = dcpagdf

gen Ypnbihs_dv = ypnbihs_dv

gen Ynbcpdf_dv = ynbcpdf_dv

gen Yplgrs_dv = yplgrs_dv

gen Ypncp = ypncp

gen Ln_Ypncp=ln_ypncp

* Age centred
gen Dag_c20 = dag - 20
gen Dag_c20_sq = Dag_c20^2

gen Dag_c42 = dag - 42
gen Dag_c42_sq = Dag_c42^2

* Generate interactions 

gen Ded_Dgn = Ded * Dgn
gen Ded_Dag =  Ded * Dag 
gen Ded_Dag_sq = Ded *Dag_sq 
gen Ded_Dag_c20 = Ded * Dag_c20
gen Ded_Dag_c20_sq = Ded * Dag_c20_sq

xtset idperson swv

gen Ded_Dhe_Fair_L1 = l.Dhe_Fair * Ded 
gen Ded_Dhe_Good_L1 = l.Dhe_Good * Ded
gen Ded_Dhe_VeryGood_L1 = l.Dhe_VeryGood * Ded 
gen Ded_Dhe_Excellent_L1 = l.Dhe_Excellent * Ded 
	
gen Ded_Ypncp_L1 = l.Ypncp * Ded
gen Ded_Yplgrs_dv_L1 = l.Yplgrs_dv * Ded
gen Ded_Yplgrs_dv_L2 = l2.Yplgrs_dv * Ded
gen Ded_Ypncp_L2 = l2.Ypncp * Ded

gen Ded_Ln_Ypncp_L1 = l.Ln_Ypncp * Ded
gen Ded_Ln_Ypncp_L2 = l2.Ln_Ypncp * Ded


		
	
/********************************** ESTIMATION ********************************/
* Set data 
xtset idperson swv
/*************** I1a: PROBABILITY OF RECEIVEING CAPITAL INCOME ****************/
	
/*
logit receives_ypncp i.dgn dag dagsq ib1.deh_c3 li.les_c4 lib1.dhhtp_c4 ///
	l.dhe l.yplgrs_dv l.ypncp l2.yplgrs_dv l2.ypncp i.drgn1 stm Y2020 ///
	Y2021 if ded == 0 [pweight = dimxwt], vce(cluster idperson) base
removed for multicollinearity issues Ded_Dag  Ded_Dhe_Fair_L1 Ded_Dhe_Good_L1 Ded_Dhe_VeryGood_L1 Ded_Dhe_Excellent_L1 */

do "${dir_do}/programs.do" 
/*************** I1a: PROBABILITY OF RECEIVEING CAPITAL INCOME ****************/
	
/*
logit receives_ypncp i.dgn dag dagsq ib1.deh_c3 li.les_c4 lib1.dhhtp_c4 ///
	l.dhe l.yplgrs_dv l.ypncp l2.yplgrs_dv l2.ypncp i.drgn1 stm Y2020 ///
	Y2021 if ded == 0 [pweight = dimxwt], vce(cluster idperson) base
removed for multicollinearity issues*/

logit receives_ypncp i.Dgn c.Dag c.Dag c.Dag_sq l.Dhe_Poor l.Dhe_Fair ///
	l.Dhe_Good l.Dhe_VeryGood l.Dhe_Excellent lc.Ypncp lc.Yplgrs_dv ///
	l2c.Yplgrs_dv l2c.Ypncp Ded_Dgn Ded_Dag_sq ///
	Ded_Dhe_Fair_L1 Ded_Dhe_Good_L1 Ded_Dhe_VeryGood_L1 Ded_Dhe_Excellent_L1 ///
	Ded_Ypncp_L1 Ded_Yplgrs_dv_L1 Ded_Yplgrs_dv_L2 Ded_Ypncp_L2 ///
	i.Deh_c4_Low i.Deh_c4_Medium i.Deh_c4_High ///
	li.Les_c4_Student li.Les_c4_NotEmployed li.Les_c4_Retired ///
	li.Dhhtp_c4_CoupleChildren li.Dhhtp_c4_SingleNoChildren ///
	li.Dhhtp_c4_SingleChildren $regions Year_transformed Y2020 Y2021 if ///
	 ${i1a_if_condition} [pweight = dwt], ///
	 vce(cluster idperson) base


process_regression, domain("income") process("I1a") sheet("I1a") ///
	title("Process I1a: Prob. recieve capital income") ///
	gofrow(3) goflabel("I1a - Receive capital income ") ///
	ifcond("${i1a_if_condition}") probit	 
	
	
/********************** I1b: AMOUNT OF CAPITAL INCOME *************************/

xtset idperson swv 

reg ln_ypncp i.Dgn c.Dag c.Dag c.Dag_sq l.Dhe_Fair l.Dhe_Good l.Dhe_VeryGood ///
	l.Dhe_Excellent lc.Ln_Ypncp lc.Yplgrs_dv l2c.Yplgrs_dv l2c.Ln_Ypncp ///
	Ded_Dgn /*Ded_Dag Ded_Dag_sq*//*Ded_Dhe_Fair_L1 Ded_Dhe_Good_L1 ///
	Ded_Dhe_VeryGood_L1 Ded_Dhe_Excellent_L1 */ Ded_Ln_Ypncp_L1 ///
	Ded_Yplgrs_dv_L1 Ded_Yplgrs_dv_L2 Ded_Ln_Ypncp_L2 i.Deh_c4_Low ///
	i.Deh_c4_Medium i.Deh_c4_High li.Les_c4_Student li.Les_c4_NotEmployed ///
	li.Les_c4_Retired li.Dhhtp_c4_CoupleChildren ///
	li.Dhhtp_c4_SingleNoChildren li.Dhhtp_c4_SingleChildren $regions ///
	Year_transformed Y2020 Y2021 if ${i1b_if_condition} [pw=dwt], ///
	vce(cluster idperson)
	
process_regression, domain("income") process("I1b") sheet("I1b") ///
	title("Process I1b: Amount of capital income") ///
	gofrow(7) goflabel("I1b - Amount of capital income") ///
	ifcond("${i1b_if_condition}")		  
		    

* Calculate RMSE
cap drop residuals squared_residuals  
predict  residuals , residuals
gen squared_residuals = residuals^2

preserve 
keep if receives_ypncp == 1
sum squared_residuals [w = dwt]
di "RMSE for Amount of capital income" sqrt(r(mean))
putexcel set "$dir_work/reg_RMSE.xlsx", sheet("RMSE") modify
putexcel A6 = ("I3") B6 = (sqrt(r(mean))) 
restore 
			