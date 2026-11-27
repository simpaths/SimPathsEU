/*******************************************************************************
* PROJECT:  		SimPaths EU
* SECTION:			Leaving the Parental Home
* OBJECT: 			Probit Model 
* AUTHORS:			Daria Popova, Justin van de Ven, Ashley Burdett
*					Aleksandra Kolndrekaj 
* LAST UPDATE:		November 2026 AK
* COUNTRY: 			Poland  
********************************************************************************
* NOTES: 			
*				https://notesfrompoland.com/2024/07/03/one-third-of-poles-aged-25-34-live-with-parents/?utm_source=chatgpt.com
* 
*******************************************************************************/

clear all
set more off
set mem 200m
set type double
set maxvar 30000

* Set off log 
cap log close 
log using "$dir_log/reg_leaveParentalHome.log", replace

			
/********************************* SET EXCEL FILE *****************************/

* Info sheet
putexcel set "$dir_work/reg_leave_parental_home", sheet("Info") ///
	replace
putexcel A1 = "Description:", bold
putexcel B1 = "Model parameters governing leaving parental home process"

putexcel A2 = "Authors:", bold
putexcel B2 = "Ashley Burdett, Aleksandra Kolndrekaj" 	
putexcel A3 = "Last edit:", bold
putexcel B3 = "08 Oct 2026 AK"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "P1"
putexcel B6 = "Probit regression estimates for leaving the parental home, transitioning out of adult child status"

putexcel A11 = "Notes:", bold
putexcel B11 = "Regions: PL4 = Polnocno-Zachodni, PL5 = Poludniowo-Zachodni, PL6 = Polnocy, PL10 = Central + East. Poludniowy is the omitted category." 
putexcel B11 = "DV is synchronised with the adult child definition"

putexcel set "$dir_work/reg_leave_parental_home", sheet("Gof") modify
putexcel A1 = "Goodness of fit", bold		


/********************************* PREPARE DATA *******************************/

* Load data
use "$dir_input_data/${country}_pooled_ipop", clear

* Ensure missing is missing 
recode dlftphm ded dgn dag drgn1 stm deh_c3 deh_c4 les_c4 les_c3 ydses_c5 ///
	(-9=.) 

* Set data 
xtset idperson swv
sort idperson swv 

* Remove children 
drop if dag < 15

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


* Labeling and formating variables
label def jbg 1 "Employed" 2 "Student" 3 "Not employed" 4 "Retired"
label def edd 1 "Degree"	2 "High school" ///
				3 "Other/No Qualification"
label def hht 1 "Couples with No Children" 2 "Couples with Children" ///
				3 "Single with No Children" 4 "Single with Children"
label def gdr 1  "Male" 0 "Female"
label def yn	1 "Yes" 0 "No"

label val dgn gdr
label val drgn1 rgna
label val dhhtp_c4 hht 
label val les_c4 jbg 
label val deh_c3 edd 
label val ded yn

label var dgn "Gender"
label var dag "Age"
label var dagsq "Age Squared"
label var drgn1 "Region"
label var dhhtp_c4 "Household Type: 4 Category"
label var stm "Year"
label var les_c4 "Employment Status: 4 Category" 
label var dhe "Self-rated Health"
label var deh_c3 "Educational Attainment: 3 Category"
label var deh_c4 "Educational Attainment: 4 Category"
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

tab ydses_c5, gen(Ydses_c5_Q)

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



	
/********************************** ESTIMATION ********************************/
* Run Stata programs to produce Excel file 
do "${dir_do}/programs.do" 

/**************** P1: PROBABILITY OF LEAVING THE PARENTAL HOME ****************/

xtset idperson swv		
fre dlftphm if (ded == 0 & dag >= 18 & dag <= 45) 
	
* Estimation
probit dlftphm i.Dgn Dag Dag_sq li.Deh_c4_Medium li.Deh_c4_Low ///
	li.Les_c3_Student li.Les_c3_NotEmployed li.Ydses_c5_Q2 li.Ydses_c5_Q3 ///
	li.Ydses_c5_Q4 li.Ydses_c5_Q5 $regions Year_transformed ///
	Year_transformed_sq i.Y2016 i.Y2018 if ${p1_if_condition} [pw=dwt], ///
	vce(robust)
	
	
process_regression, domain("leave_parental_home") process("P1") sheet("P1") ///
	title("Process P1: Prob. leave parental home") ///
	gofrow(3) goflabel("P1 - Leave parental home") ///
	ifcond("${p1_if_condition}") probit	
	
	
display "Leaving parental home analysis complete!"
	
	
cap log close 	
