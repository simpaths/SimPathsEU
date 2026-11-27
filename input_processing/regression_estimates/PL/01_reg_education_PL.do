/*******************************************************************************
* PROJECT:  		SimPaths EU 
* SECTION:			Education
* OBJECT: 			Final Probit Models 
* AUTHORS:			Daria Popova, Justin van de Ven, Ashley Burdett, 
*					Aleksandra Kolndrekaj 
* LAST UPDATE:		November 2026 AK
* COUNTRY: 			Poland 
********************************************************************************
* NOTES: 			
*******************************************************************************/

clear all
set more off
set mem 200m
set type double
set maxvar 30000

* Set off log 
cap log close 
log using "$dir_log/reg_education.log", replace


/********************************* SET EXCEL FILE *****************************/

* Info sheet
putexcel set "$dir_work/reg_education", sheet("Info") replace
putexcel A1 = "Description:", bold
putexcel B1 = "Model parameters governing projection of education status"

putexcel A2 = "Authors:", bold
putexcel B2 = "Ashley Burdett, Aleksandra Kolndrekaj" 	
putexcel A3 = "Last edit:", bold
putexcel B3 = "08 Oct 2026 AK"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "E1a"
putexcel B6 = "Probit regression estimates of exiting education"
putexcel A7 = "E1b"
putexcel B7 = "Probit regression estimates of returning to education"
putexcel A8 = "E2"
putexcel B8 = "Generalized ordered logit regression estimates of education attainment - individuals aged 16+ exiting education in t."
putexcel A9 = "E2a_raw"
putexcel B9 = "Raw generalized ordered logit regression estimates of education attainment - individuals aged 16+ exiting education. Useful for the 'Gologit predictor' file."

putexcel A11 = "Notes:", bold
putexcel B11 = "Regions: PL4 = Polnocno-Zachodni, PL5 = Poludniowo-Zachodni, PL6 = Polnocy, PL10 = Central + East. Poludniowy is the omitted category."


putexcel set "$dir_work/reg_education", sheet("Gof") modify
putexcel A1 = "Goodness of fit", bold		


/********************************* PREPARE DATA *******************************/

* Load data 
use "$dir_input_data/${country}_pooled_ipop.dta", clear

* Ensure missing is missing 
recode ded dgn dag der dagsq drgn1 stm deh_c3 deh_c4 les_c3 ydses_c5 (-9 = .) 

* Set data 
xtset idperson swv
sort idperson swv 

* Remove children 
drop if dag < 15


* Adjust variables 

* Create student flag 
cap gen Dst = .
replace Dst = 0 if les_c3 !=2 
replace Dst = 1 if les_c3 == 2 
replace Dst = . if les_c3 == . 

* Centering age 
gen Dag_c = dag - 23
gen Dag_c_sq = Dag_c * Dag_c

* Age transformtions

* Knots
gen Dag_knot17 = max(0, dag - 17)       
gen Dag_knot23 = max(0, dag - 23)       
gen Dag_knot26 = max(0, dag - 26)

* Age linear spline 
gen Dag_post25 = (dag > 25) * (dag - 25)

* Age quadratic spline 
gen Dag_post21 = (dag > 21) * (dag - 21)
gen Dag_post18_sq = (dag > 18) * (dag - 18) * (dag - 18) 
gen Dag_post21_sq = (dag > 21) * (dag - 21) * (dag - 21) 
gen Dag_post25_sq = (dag > 25) * (dag - 25) * (dag - 25)
gen Dag_post26_sq = (dag > 26) * (dag - 26) * (dag - 26) 

* Age cubic spline 
mkspline rcs = dag, cubic knots(18 21 23 26)

* Time transformations
* Year centered around 2000 (- helps to avoid invertability issue)
replace stm = stm - 2000
fre stm 

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

* Year linear spline
gen year_post2020 = (stm > 20) * (stm - 20)

* 2022-2023 
gen y2223 = (stm == 22 | stm == 23)

gen Post2020 = (stm >= 20)

gen Post2020_trend = max(0, stm - 20)

* Recode educational attianment ascending 
recode deh_c3 (1 = 3) (3 = 1), gen(deh_c3_recoded)	

* Labelling and formatting variables
label def jbf 1 "Employed" 2 "Student" 3 "Not Employed"			
label def gdr 1  "Male" 0 "Female"
label def yn	1 "Yes" 0 "No"
label def hht 1 "Couples with No Children" 2 "Couples with Children" ///
				3 "Single with No Children" 4 "Single with Children" 		
lab def deh_c3_recoded 1 "Low" 2 "Medium" 3 "High"

label val dgn gdr
label val les_c3 jbf 
label val ded yn
label val dhhtp_c4 hht
label val deh_c3_recoded deh_c3_recoded
				
label var dgn "Gender"
label var dag "Age"
label var dagsq "Age Squared"
label var drgn1 "Region"
label var stm "Year"
label var les_c3 "Employment Status: 3 Category" 
label var deh_c3 "Educational Attainment: 3 Category"
label var deh_c4 "Educational Attainment: 4 Category"
label var dhhtp_c4 "Household Type: 4 Category"
label var dnc "Number of Children in Household"
label var dnc02 "Number of Children aged 0-2 in Household"

* Alter names and create dummies for automatic labelling 
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

gen Ydses_c5_Q1_L1 = l.Ydses_c5_Q1
gen Ydses_c5_Q2_L1 = l.Ydses_c5_Q2
gen Ydses_c5_Q3_L1 = l.Ydses_c5_Q3
gen Ydses_c5_Q4_L1 = l.Ydses_c5_Q4
gen Ydses_c5_Q5_L1 = l.Ydses_c5_Q5

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

preserve
keep idhh swv idperson ypnbihs_dv
rename idperson parent_id
rename ypnbihs_dv parent_ypnb

* Check that each parent is unique
isid idhh swv parent_id

* Create temporary file
tempfile parent_income
save `parent_income'

restore

* 2. CHECK THE TEMPORARY PARENT INCOME FILE

preserve
use `parent_income', clear
describe
duplicates list idhh swv parent_id
restore

* 3. mother income

preserve

keep idhh swv idperson idmother

* idperson remains the CHILD's ID
rename idmother parent_id

* Match child to mother
merge m:1 idhh swv parent_id using `parent_income', ///
    keepusing(parent_ypnb)

* Check matching
tab _merge

* Keep all children, including those whose mother was not matched
keep if _merge == 1 | _merge == 3

drop _merge

* Rename mother's income
rename parent_ypnb mother_ypnb

* Keep only variables needed for final merge
keep idhh swv idperson mother_ypnb

* Check that each child is unique
isid idhh swv idperson

* Save temporary mother file
tempfile mother_income
save `mother_income'

restore

* 4. Father income

preserve
keep idhh swv idperson idfather

* idperson remains the CHILD's ID
rename idfather parent_id

* Match child to father
merge m:1 idhh swv parent_id using `parent_income', ///
    keepusing(parent_ypnb)

* Check matching
tab _merge

* Keep all children, including those whose father was not matched
keep if _merge == 1 | _merge == 3

drop _merge

* Rename father's income
rename parent_ypnb father_ypnb

* Keep only variables needed for final merge
keep idhh swv idperson father_ypnb
* Check that each child is unique
isid idhh swv idperson

* Save temporary father file
tempfile father_income
save `father_income'

restore

* 5. Merge mother'sincome back to OG data

merge 1:1 idhh swv idperson using `mother_income', ///
    keepusing(mother_ypnb)

tab _merge

drop _merge

* 6. MERGE FATHER'S INCOME BACK TO ORIGINAL DATA

merge 1:1 idhh swv idperson using `father_income', ///
    keepusing(father_ypnb)

tab _merge

drop _merge

gen mother_lvl = sinh(mother_ypnb)
gen father_lvl = sinh(father_ypnb)
egen parents_lvl = rowtotal(mother_lvl father_lvl), missing
gen parents_ypnb = asinh(parents_lvl)


replace parents_ypnb=. if mother_ypnb==. & father_ypnb==.

xtset idperson swv
gen Parents_ypnb_L1=l.parents_ypnb

bysort swv: egen Parents_ypnb_q_L1 = xtile(Parents_ypnb_L1), nq(5)


tabulate Parents_ypnb_q_L1, generate(Parents_ypnb_L1)

rename Parents_ypnb_L11 Parents_ypnb_Q1_L1  
rename Parents_ypnb_L12 Parents_ypnb_Q2_L1
rename Parents_ypnb_L13 Parents_ypnb_Q3_L1
rename Parents_ypnb_L14 Parents_ypnb_Q4_L1
rename Parents_ypnb_L15 Parents_ypnb_Q5_L1


*generate if parents are in hh
ssc install rangestat
gen parent_id = idfather
rangestat (count) father_match=idperson, by(swv idhh) interval(idperson parent_id parent_id)
gen father_in_hh = father_match > 0 & idfather != -9

replace parent_id = idmother
rangestat (count) mother_match=idperson, by(swv idhh) interval(idperson parent_id parent_id)

gen mother_in_hh = mother_match > 0 & idmother != -9
gen Parents_known = father_in_hh | mother_in_hh


xtset idperson swv
gen Parents_known_L1 = L.Parents_known



forvalues n=1(1)5{
gen Parents_known_Ydses_Q`n'_L1=Parents_known_L1*Ydses_c5_Q`n'_L1
}


/********************************** ESTIMATION ********************************/
* Run Stata programs to produce Excel file 
do "${dir_do}/programs.do" 

/****************** E1a: PROBABILITY OF REMAINING IN EDUCATION ****************/

xtset idperson swv

fre Dst if (dag >= 16 & dag <= 29) 

* Estimation
	

probit Dst i.Dgn Dag Dag_knot17 Dag_knot23 Dag_knot26 Ded_L1  ///
	    Parents_ypnb_Q2_L1 Parents_ypnb_Q3_L1 Parents_ypnb_Q4_L1 Parents_ypnb_Q5_L1  $regions ///
	Year_transformed Y2021 Y2022 Y2023 if ${e1a_if_condition} ///
	[pw=dwt], vce(robust)		
	
process_regression, domain("education") process("E1a") sheet("E1a") ///
	title("Process E1a: Prob. remain in education") ///
	gofrow(3) goflabel("E1a - Remain in education") ///
	ifcond("${e1a_if_condition}") probit	 	
	
/****************** E1b: PROBABILITY OF RETURNING TO EDUCATION ****************/
	
	
xtset idperson swv

fre der if (dag >= 16 & l.les_c4 != 4 & l.les_c4 != 2) 
replace der = . if der == -9

* Estimation 

probit der i.Dgn Dag Dag_sq li.Dcpst_Partnered li.Deh_c4_High ///
	 li.Deh_c4_Low li.Les_c3_NotEmployed li.Les_c3_Employed l.Dnc l.Dnc02 ///
	 $regions Year_transformed Year_transformed_sq Y2021 if ///
	 ${e1b_if_condition} [pw=dwt], vce(robust)
	 	 
process_regression, domain("education") process("E1b") sheet("E1b") ///
	title("Process E1b: Prob. return to education") ///
	gofrow(7) goflabel("E1b - Return to education") ///
	ifcond("${e1b_if_condition}") probit		
	 


/****************** E2: EDUCATION ATTAINMENT WHEN LEAVE SCHOOL ****************/

fre deh_c3 if Dag >= 16 & l.les_c4 == 2 & les_c4!=2 

sort idperson swv
xtset idperson swv

gologit2 deh_c3_recoded i.Dgn Dag Dag_sq $regions Year_transformed ///
	Year_transformed_sq Y2022 if ${e2_if_condition} [pw=dwt], autofit 

process_gologit, domain("education") process("E2") sheet("E2a") ///
    title("Process E2: Educational Attainment When Leave School") ///
    gofrow(11) goflabel("E2 - Education attainment") ///
    outcomes(3) ///
    ifcond("${e2_if_condition}")


display "Education analysis complete!"
		 
cap log close
