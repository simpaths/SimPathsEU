/*******************************************************************************
* PROJECT:  		SimPaths EU 
* SECTION:			Fertility
* OBJECT: 			Having a child
* AUTHORS:			Daria Popova, Justin van de Ven, Ashley Burdett
*					Aleksandra Kolndrekaj 
* LAST UPDATE:		November 2026 AK
* COUNTRY: 			Poland 
********************************************************************************
* NOTES:			Simplified the fertility process for those in this initial 
* 						education spell. Exclude l.dnc, l.dnc02, li.ydses_c5 
* 						and model health as a continuous variable. 	
* 
* 					Make sure the raw fertility rate file is in the data folder. 
* 					Ensure the same numbers as used in SimPaths 		
*******************************************************************************/

clear all
set more off
set mem 200m
set type double
set maxvar 30000

* Set off log 
cap log close 
log using "$dir_log/reg_fertility.log", replace


/********************************* SET EXCEL FILE *****************************/

* Info sheet
putexcel set "$dir_work/reg_fertility", sheet("Info") replace
putexcel A1 = "Description:", bold
putexcel B1 = "Model parameters governing projection of fertility"

putexcel A2 = "Authors:", bold
putexcel B2 = "Ashley Burdett, Aleksandra Kolndrekaj" 	
putexcel A3 = "Last edit:", bold
putexcel B3 = "08 Oct 2026 AK"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "F1"
putexcel B6 = "Probit regression estimates of the probability of having a child for women"


putexcel A8 = "Notes:", bold
putexcel B8 = "Regions: PL4 = Polnocno-Zachodni, PL5 = Poludniowo-Zachodni, PL6 = Polnocy, PL10 = Central + East. Poludniowy is the omitted category."

putexcel set "$dir_work/reg_fertility", sheet("Gof") modify
putexcel A1 = "Goodness of fit", bold		


/********************************* PREPARE DATA *******************************/

* Convert the fertility rate into a .dta file 
import excel "$dir_data/projections_fertility.xlsx", sheet("FertilityByYear") ///
	firstrow clear
	
drop Fertility 

xpose, clear varname 

gen swv = 2011 if _varname == "B"
replace swv = swv[_n-1] + 1 if swv[_n-1] != . 

rename v1 dplfr
drop _varname 

save "$dir_data/fertility_rate", replace 


* Load main data 
use "$dir_input_data/${country}_pooled_ipop", clear

* Ensure missing is missing 
recode dhe dnc dnc02 deh_c3 les_c3 ydses_c5 dcpst drgn1 sprfm scedsmpl ///
	 dchpd (-9=. )


* Sample selection 
drop if dag < 16

* Adjust variables 

* Time transformations 
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
* Have any number of children dummy
tab dchpd
replace dchpd = 1 if dchpd == 2 | dchpd == 3 | dchpd == 4 | dchpd == 5 



* Labeling and formating variables
label def jbf 1 "Employed" 2 "Student" 3 "Not Employed"
label def edd 1 "Degree"	2 "High school" ///
				3 "Other/No Qualification"
label def hht 1 "Couples with No Children" 2 "Couples with Children" ///
				3 "Single with No Children" 4 "Single with Children" 
label def gdr 1  "Male" 0 "Female"
label def yn	1 "Yes" 0 "No"

label val dgn gdr
label val drgn1 rgna
label val dhhtp_c4 hht 
label val les_c3 jbf 
label val deh_c3 edd 
label val ded yn

label var dgn "Gender"
label var dag "Age"
label var dagsq "Age Squared"
label var drgn1 "Region"
label var dhhtp_c4 "Household Type: 4 Category"
label var stm "Year"
label var les_c3 "Employment Status: 3 Category" 
label var dhe "Self-rated Health"
label var deh_c3 "Educational Attainment: 3 Category"
label var dnc "Number of Children in Household"
label var dnc02 "Number of Children aged 0-2 in Household"
label var ydses_c5 "Annual Household Income Quintile" 


* Alter names and create dummies for automatic labelling 
gen Dgn = dgn 

gen Dag = dag  

gen Dag_sq = dagsq 
xtset idperson swv

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

tab dcpst, gen(Dcpst_)
rename Dcpst_1 Dcpst_Partnered
rename Dcpst_2 Dcpst_Single

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
gen Deh_c4=deh_c4

gen Ydses_c5 = ydses_c5 

gen New_rel = new_rel

gen Dcpyy = dcpyy_st 

gen Dcpagdf = dcpagdf

gen Ypnbihs_dv = ypnbihs_dv

gen Ynbcpdf_dv = ynbcpdf_dv

gen Ded_2 = 1 - ded

* Generate interactions
gen Les_c4_Student_Dgn = Dgn * Les_c4_Student
gen Les_c4_NotEmployed_Dgn = Dgn * Les_c4_NotEmployed
gen Les_c4_Retired_Dgn = Dgn * Les_c4_Retired

gen Ded_Dag =  Ded * c.Dag 
gen Ded_Dag_sq = Ded * Dag_sq 
gen Ded_Dgn = Ded * Dgn

gen Ded_Dhe_Poor=Ded * Dhe_Poor
gen Ded_Dhe_Fair=Ded * Dhe_Fair
gen Ded_Dhe_Good=Ded * Dhe_Good
gen Ded_Dhe_VeryGood=Ded * Dhe_VeryGood
gen Ded_Dhe_Excellent=Ded * Dhe_Excellent

gen Ded_Dcpst_Single = Dcpst_Single * Ded

* Lagged interactions 
xtset idperson swv
gen Ded_Dcpst_Single_L1 = l.Dcpst_Single * Ded

* Set data
xtset idperson swv

* Merge in fertility rate
merge m:1 swv using "$dir_data/fertility_rate"

drop if _m == 2 
drop _m

gen FertilityRate = dplfr

sort idperson swv 


/********************************** ESTIMATION ********************************/
* Run Stata programs to produce Excel file 
do "${dir_do}/programs.do" 
/*********************** F1: PROBABILITY OF HAVING A CHILD ********************/

display "${f1_if_condition}" 

xtset idperson swv
tab dchpd if (sprfm == 1  & dgn == 0) 

* Estimation 
probit dchpd i.Ded Dag Dag_sq i.Dhe_Fair i.Dhe_Good i.Dhe_VeryGood ///
	i.Dhe_Excellent i.Dcpst_Single li.Dcpst_Single Ded_Dag /*Ded_Dag_sq*/ ///
	Ded_Dcpst_Single Ded_Dcpst_Single_L1 Ded_Dhe_Poor Ded_Dhe_Fair  ///
	Ded_Dhe_Good Ded_Dhe_VeryGood Ded_Dhe_Excellent li.Ydses_c5_Q2 ///
	li.Ydses_c5_Q3 li.Ydses_c5_Q4 li.Ydses_c5_Q5 l.Dnc l.Dnc02 i.Deh_c4_Low ///
	i.Deh_c4_High FertilityRate li.Les_c3_Student li.Les_c3_NotEmployed ///
	Year_transformed Year_transformed_sq $regions if ${f1_if_condition} ///
	[pw=dwt], vce(robust)
	

process_regression, domain("fertility") process("F1") sheet("F1") ///
	title("Process F1: Prob. have a child") ///
	gofrow(3) goflabel("F1 - Have child") ///
	ifcond("${f1_if_condition}") probit	 
	 

display "Fertility analysis complete!"
	 

capture log close 