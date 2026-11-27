/*******************************************************************************
* PROJECT:  		SimPaths EU 
* SECTION:			Retirement  
* OBJECT: 			Probability of retiring by partnerhip status  
* AUTHORS:			Daria Popova, Justin van de Ven, Ashley Burdett, 
* 					Matteo Richiardi, Aleksandra Kolndrekaj
* LAST UPDATE:		November 2026 AK
* COUNTRY: 			Poland 
********************************************************************************
* NOTES: 			
* 
*******************************************************************************/

clear all
set more off
set mem 200m
set type double
set maxvar 30000

* Set off log 
cap log close 
log using "$dir_log/reg_retirement.log", replace


/********************************* SET EXCEL FILE *****************************/

* Info sheet
putexcel set "$dir_work/reg_retirement", sheet("Info") replace
putexcel A1 = "Description:", bold
putexcel B1 = "Model parameters governing projection of retirement"

putexcel A2 = "Authors:", bold
putexcel B2 = "Ashley Burdett, Aleksandra Kolndrekaj" 	
putexcel A3 = "Last edit:", bold
putexcel B3 = "08 Oct 2026"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "R1a"
putexcel B6 = "Probit regression estimates of the probability of retiring, single individuals aged 50+ not yet retired"
putexcel A7 = "R1b"
putexcel B7 = "Probit regression estimates of the probability of retiring, partnered individuals aged 50+ not yet retired"
putexcel A10 = "Notes:", bold
putexcel B10 = "Regions: PL4 = Polnocno-Zachodni, PL5 = Poludniowo-Zachodni, PL6 = Polnocy, PL10 = Central + East. Poludniowy is the omitted category."

putexcel set "$dir_work/reg_retirement", sheet("Gof") modify
putexcel A1 = "Goodness of fit", bold	


/********************************* PREPARE DATA *******************************/

* Load data 
use "$dir_input_data/${country}_pooled_ipop.dta", clear

* Ensure missing is missing 
recode dgn dag dagsq deh_c3 deh_c4 dagpns ydses_c5 dlltsd drgn1 stm ///
	dcpst drtren dagpns_sp lessp_c3 dlltsd_sp dcpst dagpns_y dagpns_y1 ///
	dagpns_y_sp dagpns_y1_sp (-9=.)

* Set data
xtset idperson swv 
sort idperson swv
	
* Sample selection 
drop if dag < 16

* Adjust variables

* Time variables
* Centre year around 2000 
replace stm = stm - 2000

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


gen lesnr_c2 = . 
replace lesnr_c2 = 0 if les_c4 == 1
replace lesnr_c2 = 1 if inrange(les_c4,2,3)
	
* Labeling and formating variables
label def jbf 1 "Employed" 2 "Student" 3 "Not Employed"
label def edd 1 "Degree"	2 "High school" ///
				3 "Other/No Qualification"
label def gdr 1  "Male" 0 "Female"				
label def yn	1 "Yes" 0 "No"
label def hht 1 "Couples with No Children" 2 "Couples with Children" ///
				3 "Single with No Children" 4 "Single with Children"

label val dgn gdr
label val drgn1 rgna
label val les_c3 lessp_c3 jbf 
label val deh_c3 dehsp_c3 edd 
label val dcpen dcpex dlrtrd dagpns dagpns_sp yn
label val dhhtp_c4 hht				
				
label var dgn "Gender"
label var dag "Age"
label var dagsq "Age Squared"
label var drgn1 "Region"
label var stm "Year"
label var les_c3 "Employment Status: 3 Category" 
label var dhe "Self-rated Health"
label var deh_c3 "Educational Attainment: 3 Category"
label var dhhtp_c4 "Household Type: 4 Category"

* Alter names and create dummies for automatic labelling 
gen Dgn = dgn 

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

tab dehsp_c4, gen(Dehsp_c4_)
rename Dehsp_c4_1 Dehsp_c4_Na
rename Dehsp_c4_2 Dehsp_c4_High
rename Dehsp_c4_3 Dehsp_c4_Medium
rename Dehsp_c4_4 Dehsp_c4_Low

tab lesdf_c4, gen(Lesdf_c4_)
rename Lesdf_c4_1 Lesdf_c4_BothEmployed
rename Lesdf_c4_2 Lesdf_c4_EmpSpouseNotEmp
rename Lesdf_c4_3 Lesdf_c4_NotEmpSpouseEmp
rename Lesdf_c4_4 Lesdf_c4_BothNotEmployed

tab dcpst, gen(Dcpst_)
rename Dcpst_1 Dcpst_Partnered
rename Dcpst_2 Dcpst_Single

tab lessp_c3, gen(Lessp_c3_)
rename Lessp_c3_1 Lessp_c3_Employed
rename Lessp_c3_2 Lessp_c3_Student
rename Lessp_c3_3 Lessp_c3_NotEmployed 

gen Dnc = dnc

gen Dnc02 = dnc02

gen Year_transformed = stm  

gen Post2015 = (stm >= 16) 

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

gen Dhe = dhe 

gen Ydses_c5 = ydses_c5 

gen New_rel = new_rel

gen Dcpyy = dcpyy_st 

gen Dcpagdf = dcpagdf

gen Ypnbihs_dv = ypnbihs_dv

gen Ynbcpdf_dv = ynbcpdf_dv

gen Elig_pen = dagpns_y

gen Elig_pen_L1 = dagpns_y1

gen Reached_Retirement_Age = dagpns

gen Les_c2_NotEmployed = lesnr_c2

gen Dlltsd = dlltsd

gen Reached_Retirement_Age_Sp = dagpns_sp

gen Elig_pen_Sp = dagpns_y_sp

gen Elig_pen_L1_Sp = dagpns_y1_sp

gen Dlltsdsp = dlltsd_sp

* Create interactions 
cap gen Reached_Retirement_Age_Les_L1 = Reached_Retirement_Age * ///
	l.Les_c2_NotEmployed	


	
/***************************** PRELIMINARY ANALYSIS ***************************/
	
/*
* Age at retirement 


* Pooled
twoway (histogram dag if dgn == 1 & drtren == 1, fraction color(blue%50)) ///
	(histogram dag if dgn == 0 & drtren == 1, fraction color(red%50)), ///
	legend(label(1 "men") label(2 "women")) ///
	title("Age at retirement") ytitle("Frequency") ///
	name("retAll", replace)
	graph export "$dir_work/graphs/retirement_age_pooled.png", as(png) name(retAll) replace

		
* By year
forvalues y = 2010/2023 {
	twoway (histogram dag if dgn == 1 & drtren == 1 & swv == `y', fraction color(blue%50)) ///
		(histogram dag if dgn == 0 & drtren == 1 & swv == `y', fraction color(red%50)), ///
		legend(label(1 "men") label(2 "women")) ///
		title("Age at retirement, `y'") ytitle("Frequency") ///
		name("ret`y'", replace)	
}

graph combine ret2010 ret2011 ret2012 ret2013 ret2014 ret2015 ret2016 ret2017 ret2018 ret2019 ret2020 ret2021 ret2022 ret2023
*/


/********************************** ESTIMATION ********************************/

* Run Stata programs to produce Excel file 
do "${dir_do}/programs.do" 
/****************** R1a: PROBABILITY OF RETIREMENT, SINGLE ********************/


display "${r1a_if_condition}"

xtset idperson swv		

probit drtren i.Dgn Dag Dag_sq i.Elig_pen i.Elig_pen_L1 li.Deh_c4_Medium ///
	li.Deh_c4_Low i.Reached_Retirement_Age li.Les_c3_NotEmployed ///
	li.Ydses_c5_Q2 li.Ydses_c5_Q3 li.Ydses_c5_Q4 li.Ydses_c5_Q5 li.Dlltsd ///
	$regions Year_transformed Post2015 ///
	if ${r1a_if_condition} [pw=dwt], vce(robust)
	
process_regression, domain("retirement") process("R1a") sheet("R1a") ///
	title("Process R1a: Prob. retire, singles") ///
	gofrow(3) goflabel("R1a - Retire, singles") ///
	ifcond("${r1a_if_condition}") probit	
	
	
	
/***************** R1b: PROBABILITY OF RETIREMENT, PARTNERED ******************/

xtset idperson swv 

display "${r1b_if_condition}"

xtset idperson swv 

* Estimation    Dag_sq
probit drtren i.Dgn Dag  i.Elig_pen i.Elig_pen_L1 ///
	 i.Reached_Retirement_Age ///
	li.Les_c3_NotEmployed i.Reached_Retirement_Age_Les_L1 ///
	li.Deh_c4_Medium li.Deh_c4_Low  li.Ydses_c5_Q2 li.Ydses_c5_Q3 li.Ydses_c5_Q4 li.Ydses_c5_Q5  li.Dlltsd li.Reached_Retirement_Age_Sp li.Elig_pen_Sp  li.Elig_pen_L1_Sp ///
	li.Lessp_c3_Student li.Lessp_c3_NotEmployed li.Dlltsdsp ///
	$regions Year_transformed Y2022 Y2023 if ///
	${r1b_if_condition} [pweight = dwt], vce(robust)	

process_regression, domain("retirement") process("R1b") sheet("R1b") ///
	title("Process R1b: Prob. retire, partnered") ///
	gofrow(7) goflabel("R1a - Retire, partnered") ///
	ifcond("${r1b_if_condition}") probit		
	
	
display "Retirement analysis complete!"
	
		
capture log close 	 
	 
