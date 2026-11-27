/*******************************************************************************
* PROJECT:  		SimPaths EU  
* SECTION:			Health
* OBJECT: 			Health status and Disability
* AUTHORS:			Daria Popova, Justin van de Ven, Ashley Burdett
*					Aleksandra Kolndrekaj 
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
log using "$dir_log/reg_health.log", replace


/********************************* SET EXCEL FILE *****************************/

* Info sheet
putexcel set "$dir_work/reg_health", sheet("Info") replace
putexcel A1 = "Description:", bold
putexcel B1 = "Model parameters governing projection self-reported health status"

putexcel A2 = "Authors:", bold
putexcel B2 = "Ashley Burdett, Aleksandra Kolndrekaj" 	
putexcel A3 = "Last edit:", bold
putexcel B3 = "08 Oct 2026"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "H1"
putexcel B6 = "Generalized ordered logit regression estimates of self reported health status - individuals age 16+"
putexcel B7 = "Covariates that satisfy the parallel lines assumption have one estimate for all categories of the dependent variable and are present once in the table"
putexcel B8 = "Covariates that do not satisfy the parallel lines assumption have an estimate for each estimated category of the dependent variable. These covariates have the dependent variable category appended to their name."
putexcel A11 = "H2"
putexcel B11 = "Probit regression estimates of the probability of being long-term sick or disabled - people aged 16+, non-students and non-retirees."
putexcel A12 = "H1_raw"
putexcel B12 = "Raw generalized ordered logit regression estimates of self reported health status. Useful for the 'Gologit predictor' file."

putexcel A15 = "Notes:", bold
putexcel B15 = "Regions: PL4 = Polnocno-Zachodni, PL5 = Poludniowo-Zachodni, PL6 = Polnocy, PL10 = Central + East. Poludniowy is the omitted category."

putexcel set "$dir_work/reg_health", sheet("Gof") modify
putexcel A1 = "Goodness of fit", bold		


/********************************* PREPARE DATA *******************************/

* Load data 
use "$dir_input_data/${country}_pooled_ipop", clear

* Ensure missing is missing 
recode dhe deh_c3 les_c3 les_c4 ydses_c5 dhhtp_c4 drgn1 stm  (0= .) (-9=.) 
recode dgn dag dagsq deh_c4 (-9=.)
replace dlltsd=. if dlltsd==-9
* Set data 
xtset idperson swv
sort idperson swv 

* Drop children 
drop if dag < 16

* Adjust variables 
* Time variables
* Centre age aroudn 2000
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


* Generate lags
gen l_ydses_c5 = ydses_c5[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 

gen l_dhe = dhe[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 
		
gen l_les_c3 = les_c3[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 
		
gen l_dhhtp_c4 = dhhtp_c4[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 	


* Labeling and formating variables
label def jbf 1 "Employed" 2 "Student" 3 "Not Employed"
label def edd 1 "Degree"	2 "High school" ///
					3 "Other/No Qualification"
label def hht 1 "Couples with No Children" 2 "Couples with Children" ///
				3 "Single with No Children" 4 "Single with Children"
label def gdr 1  "Male" 0 "Female"				
label def yn	1 "Yes" 0 "No"
label def dhe 1 "Poor" 2"Fair" 3"Good" 4"VeryGood" 5"Excellent", modify 

label val dgn gdr
label val drgn1 rgna
label val dhhtp_c4 hht 
label val les_c3 jbf 
label val deh_c3 edd 
label val ded yn
label var dhe dhe

label var dgn "Gender"
label var dag "Age"
label var dagsq "Age Squared"
label var drgn1 "Region"
label var dhhtp_c4 "Household Type: 4 Category"
label var stm "Year"
label var les_c3 "Employment Status: 3 Category" 
label var dhe "Self-rated Health"
label var deh_c3 "Educational Attainment: 3 Category"
label var ydses_c5 "Annual Household Income Quintile" 
label var dlltsd "Long-term Sick or Disabled"

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

tab l_les_c3, gen(L_Les_c3_)
rename L_Les_c3_1 Les_c3_Employed_L1
rename L_Les_c3_2 Les_c3_Student_L1
rename L_Les_c3_3 Les_c3_NotEmployed_L1

tab les_c4, gen(Les_c4_)
rename Les_c4_1 Les_c4_Employed
rename Les_c4_2 Les_c4_Student
rename Les_c4_3 Les_c4_NotEmployed
rename Les_c4_4 Les_c4_Retired

tab ydses_c5, gen(Ydses_c5_Q)

tab l_ydses_c5, gen(L_Ydses_c5_Q)

tab dhe, gen(Dhe_)
rename Dhe_1 Dhe_Poor
rename Dhe_2 Dhe_Fair
rename Dhe_3 Dhe_Good
rename Dhe_4 Dhe_VeryGood
rename Dhe_5 Dhe_Excellent

tab l_dhe, gen(L_Dhe_c5_)
rename L_Dhe_c5_1 Dhe_Poor_L1
rename L_Dhe_c5_2 Dhe_Fair_L1
rename L_Dhe_c5_3 Dhe_Good_L1
rename L_Dhe_c5_4 Dhe_VeryGood_L1
rename L_Dhe_c5_5 Dhe_Excellent_L1


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

tab l_dhhtp_c4, gen(L_Dhhtp_c4_)
rename L_Dhhtp_c4_1 Dhhtp_c4_CoupleNoChildren_L1
rename L_Dhhtp_c4_2 Dhhtp_c4_CoupleChildren_L1
rename L_Dhhtp_c4_3 Dhhtp_c4_SingleNoChildren_L1
rename L_Dhhtp_c4_4 Dhhtp_c4_SingleChildren_L1

gen Dnc = dnc

gen Dnc02 = dnc02

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

gen Dhe = dhe 
gen Ded = ded

gen Ydses_c5 = ydses_c5 

gen New_rel = new_rel

gen Dcpyy = dcpyy_st 

gen Dcpagdf = dcpagdf

gen Ypnbihs_dv = ypnbihs_dv

gen Ynbcpdf_dv = ynbcpdf_dv

gen Ydses_c5_L1 = l_ydses_c5
gen Ydses_c5_Q2_L1 = L_Ydses_c5_Q2

gen Dhe_L1 = l_dhe

gen Dlltsd = dlltsd

* Generate interactions 
gen Ded_Dag =  Ded * c.Dag 
gen Ded_Dag_sq = Ded * Dag_sq 
gen Ded_Dgn = Ded * Dgn

/********************************** ESTIMATION ********************************/
* Run Stata programs to produce Excel file 
do "${dir_do}/programs.do" 

/********************** H1: SELF-REPORTED HEALTH STATUS ***********************/
display "${h1_if_condition}"
* Generalized ordered logit			
sort idperson swv

	* Estimation
// NOTE:  Removed for not convergence Ded_Dag Deh_c4_Na
gologit2 dhe i.Dgn c.Dag c.Dag_sq  Ded_Dag_sq Ded_Dgn Dhe_Fair_L1 ///
	Dhe_Good_L1 Dhe_VeryGood_L1 Dhe_Excellent_L1 Deh_c4_High ///
	Deh_c4_Low i.Les_c3_Student_L1 i.Les_c3_NotEmployed_L1 i.Ydses_c5_Q2_L1 ///
	i.Dhhtp_c4_CoupleChildren_L1 i.Dhhtp_c4_SingleNoChildren_L1 ///
    i.Dhhtp_c4_SingleChildren_L1 $regions Year_transformed ///
	Year_transformed_sq if ${h1_if_condition} [pw=dwt], autofit force
	
process_gologit, domain("health") process("H1") sheet("H1") ///
    title("Process H1: Self Rated Health") ///
    gofrow(3) goflabel("H1 - Self-rated health") ///
    outcomes(5) ///
    ifcond("${h1_if_condition}")


/**************** H2: PROBABILITY LONG-TERM SICK OR DISABLED ******************/
	
display "${h2_if_condition}"
	
xtset idperson stm


* Estimation 	
probit dlltsd i.Dgn c.Dag c.Dag_sq li.Ydses_c5_Q2 li.Ydses_c5_Q3 ///
	li.Ydses_c5_Q4 li.Ydses_c5_Q5 i.Deh_c4_High i.Deh_c4_Medium ///
	i.Dhe_Poor i.Dhe_Fair i.Dhe_Good i.Dhe_VeryGood li.Dhe_Poor li.Dhe_Fair ///
	li.Dhe_Good li.Dhe_VeryGood l.Dlltsd li.Dhhtp_c4_CoupleChildren ///
	li.Dhhtp_c4_SingleNoChildren li.Dhhtp_c4_SingleChildren $regions ///
	Year_transformed Y2020 Y2021 if ${h2_if_condition} [pw=dwt], vce(robust)
	
process_regression, domain("health") process("H2") sheet("H2") ///
	title("Process H2: Prob.disabled or long term sick") ///
	gofrow(7) goflabel("H2 - Disabled or long term sick") ///
	ifcond("${h2_if_condition}") probit	 	
		
	
display "Self-rated health analysis complete!"
		 

capture log close