********************************************************************************
* PROJECT:  		SimPaths EU 
* SECTION:			Validation
* OBJECT: 			Validation targets
* AUTHORS:			Ashley Burdett 
* LAST UPDATE:		11/2025 (AB)
* COUNTRY: 			PL 
* DESCRIPTION:      This file creates variables from the simulated data
* 					that are used to generate in the comparison plots. 
********************************************************************************
* NOTES: 			Income amounts are converted from IHS to levels and from 
* 					monthly to annual. 
* 					Two datasets are saved, one containing all observations 
* 					(..._full) and one containing only the adult population 
* 					(18-65 inc).
*******************************************************************************/

* Generate/Tidy required variables

* Load simulated panel 
use "$dir_data/loaded_simulation_data.dta", clear


** TIME

rename time year 


** DEMOGRAPHICS

* Gender 
gen demMaleFlag_coded = .
replace demMaleFlag_coded = 1 if demMaleFlag == "Male"
replace demMaleFlag_coded = 0 if demMaleFlag == "Female"

drop demMaleFlag
rename demMaleFlag_coded demMaleFlag	


* Age 
* Define age groups
gen ageGroup = .
replace ageGroup = 0 if demAge >= 0 & demAge < 15
replace ageGroup = 1 if demAge >= 15 & demAge < 20
replace ageGroup = 2 if demAge >= 20 & demAge < 25
replace ageGroup = 3 if demAge >= 25 & demAge < 30
replace ageGroup = 4 if demAge >= 30 & demAge < 35
replace ageGroup = 5 if demAge >= 35 & demAge < 40
replace ageGroup = 6 if demAge >= 40 & demAge < 60
replace ageGroup = 7 if demAge >= 60 & demAge < 80
replace ageGroup = 8 if demAge >= 80 & demAge <= 100

label def ageGroup /// 
	0 "ageGroup_0_14" ///
	1 "ageGroup_15_19" ///
	2 "ageGroup_20_24" ///
	3 "ageGroup_25_29" ///
	4 "ageGroup_30_34" ///
	5 "ageGroup_35_39" ///
	6 "ageGroup_40_59" ///
	7 "ageGroup_60_79" ///
	8 "ageGroup_80_100" ///
	
label val ageGroup ageGroup

gen ageGroup2 = .
replace ageGroup2 = 0 if demAge >= 16 & demAge < 25
replace ageGroup2 = 1 if demAge >= 25 & demAge < 30
replace ageGroup2 = 2 if demAge >= 30 & demAge < 35
replace ageGroup2 = 3 if demAge >= 35 & demAge < 40
replace ageGroup2 = 4 if demAge >= 40 & demAge < 45
replace ageGroup2 = 5 if demAge >= 45 & demAge < 50
replace ageGroup2 = 6 if demAge >= 50 & demAge < 55
replace ageGroup2 = 7 if demAge >= 55 & demAge < 60
replace ageGroup2 = 8 if demAge >= 60 & demAge <= 65

label def ageGrouplb2 /// 
	0 "ageGroup_16_24" ///
	1 "ageGroup_25_29" ///
	2 "ageGroup_30_34" ///
	3 "ageGroup_35_39" ///
	4 "ageGroup_40_44" ///
	5 "ageGroup_45_49" ///
	6 "ageGroup_50_54" ///
	7 "ageGroup_55_59" ///
	8 "ageGroup_60_65" ///
	
label val ageGroup2 ageGrouplb2


* Max benefit unit age
bys run year idBu: egen demAgeBuMax = max(demAge)

* Partnership status 
gen demPartnerStatus_coded = .
replace demPartnerStatus_coded = 1 if demPartnerStatus == "Partnered"
replace demPartnerStatus_coded = 2 if demPartnerStatus == "Single"

drop demPartnerStatus
rename demPartnerStatus_coded demPartnerStatus	
	
gen sim_partnered = (demPartnerStatus == 1) 
gen sim_single = (demPartnerStatus == 2) 

replace idPartner = "" if idPartner == "null"
destring idPartner , replace
gen sim_has_partner = (idPartner != .)


* Number of children
gen child = (demAge < ${age_become_responsible})
bys run year idBu: egen sim_demNChild = total(child)

gen child02 = (demAge < 3)
bys run year idBu: egen sim_demNChild0to2 = total(child02)

gen child00 = (demAge < 1)
bys run year idBu: egen sim_demNChild0 = total(child00)

gen sim_new_born = (demMaleFlag == 0 & sim_demNChild0 > 0 & ///
	sim_demNChild0 != . & demAge >= 18)

gen children_0 = (sim_demNChild == 0)
gen children_1 = (sim_demNChild == 1)
gen children_2 = (sim_demNChild == 2)
gen children_3plus = (sim_demNChild >= 3)


* Interact partnership status and number of children
foreach var1 in sim_partnered sim_single {
	
	foreach var2 in children_0 children_1 children_2 children_3plus {
	
		gen `var1'_`var2' = (`var1' & `var2')
	
	}
}


** EDUCATION 
* Education dummies 
gen sim_edu_na = (eduHighestC4 == "NotAssigned") 
gen sim_edu_high = (eduHighestC4 == "High")
gen sim_edu_med = (eduHighestC4 == "Medium")
gen sim_edu_low = (eduHighestC4 == "Low")


** HEALTH 
* Disabled / LT sick 
gen sim_healthDsblLongtermFlag = (healthDsblLongtermFlag == "True")

* Self rated heath 
gen sim_healthSelfRated = . 
replace sim_healthSelfRated = 1 if healthSelfRated == "Poor"
replace sim_healthSelfRated = 2 if healthSelfRated == "Fair"
replace sim_healthSelfRated = 3 if healthSelfRated == "Good"
replace sim_healthSelfRated = 4 if healthSelfRated == "VeryGood"
replace sim_healthSelfRated = 5 if healthSelfRated == "Excellent"

lab def sim_healthSelfRated 1 "Poor" 2 "Fair" 3 "Good" 4 "VeryGood" ///
	5 "Excellent"
	
lab val sim_healthSelfRated sim_healthSelfRated


** LABOUR MARKET

* Economic activity dummies
gen sim_employed = (labC4 == "EmployedOrSelfEmployed")
gen sim_student = (labC4 == "Student")
gen sim_inactive = (labC4 == "NotEmployed")
gen sim_retired = (labC4 == "Retired")


* Hours worked weekly (continuous)
gen sim_labHrsWorkWeek = labHrsWorkWeek


* Hours worked weekly (categories) 
/*
For Poland these categries are symmetric cross genders. 
*/
* Address generic lables 
replace labHrsWorkEnumWeek = "ZERO" if labHrsWorkEnumWeek == "null"
replace labHrsWorkEnumWeek = "TWENTY" if labHrsWorkEnumWeek == "CATEGORY_PL_1"
replace labHrsWorkEnumWeek = "FORTY" if labHrsWorkEnumWeek == "CATEGORY_PL_2"
replace labHrsWorkEnumWeek = "FIFTY" if labHrsWorkEnumWeek == "CATEGORY_PL_3"

gen sim_labHrsWorkEnumWeek = labHrsWorkEnumWeek

gen sim_labHrsWorkEnum_no = .
replace sim_labHrsWorkEnum_no = 0 if labHrsWorkEnumWeek == "ZERO" 
replace sim_labHrsWorkEnum_no = 20 if labHrsWorkEnumWeek == "TWENTY" 
replace sim_labHrsWorkEnum_no = 40 if labHrsWorkEnumWeek == "FORTY" 
replace sim_labHrsWorkEnum_no = 50 if labHrsWorkEnumWeek == "FIFTY" 

* Categorical variable 
gen sim_cat_hours = .
replace sim_cat_hours = 1 if labHrsWorkEnumWeek == "ZERO" 
replace sim_cat_hours = 2 if labHrsWorkEnumWeek == "TWENTY" 
replace sim_cat_hours = 3 if labHrsWorkEnumWeek == "FORTY" 
replace sim_cat_hours = 4 if labHrsWorkEnumWeek == "FIFTY" 

tab labHrsWorkEnumWeek year


* Hourly wage 
gen sim_pred_wage = labWageHrly


** INCOME (ANNUAL)
/*
Amounts of personal income stored with the IHS trasnformation. 
Benefit Unit level measure (gross and dispoable income) are stored without the 
transformation. 
*/

* Destring individual amounts 
destring yNonBenPersGrossMonth yEmpPersGrossMonth yCapitalPersMonth ///
	yPensPersGrossMonth, replace ignore("null" "NaN") 	


* Annual individual gross employment income 
* Convert to levels
gen yEmpPersGrossLevelMonth = sinh(yEmpPersGrossMonth)
* Convert to annual 
gen sim_yEmpPersGrossLevelYear = yEmpPersGrossLevelMonth * 12

* Annual benefit unit gross employment income
bys run year idBu: egen sim_yEmpBuGrossLevelYear = ///
	total(sim_yEmpPersGrossLevelYear)	
	
	
* Annual individual capital income 
* Convert to levels
gen yCapitalPersLevelMonth = sinh(yCapitalPersMonth)
* Convert to annual 
gen sim_yCapitalPersLevelYear = yCapitalPersLevelMonth * 12

* Annual benefit unit capital income
bys run year idBu: egen sim_yCapitalBuLevelYear = ///
	total(sim_yCapitalPersLevelYear)
	
	
* Annual individual gross private pension income 
* Convert to levels
gen yPensPersGrossLevelMonth = 0
* Convert to annual 
gen sim_yPensPersGrossLevelYear = yPensPersGrossLevelMonth * 12

* Annual benefit unit gross private pension income
bys run year idBu: egen sim_yPensBuGrossLevelYear = ///
	total(sim_yPensPersGrossLevelYear)
	

* Annual individual gross non-benefit income
* Converts to levels 
gen yNonBenPersGrossLevelMonth = sinh(yNonBenPersGrossMonth)
* Convert to annual 
gen sim_yNonBenPersGrossLevelYear = sim_yPensPersGrossLevelYear + ///
	sim_yCapitalPersLevelYear + sim_yEmpPersGrossLevelYear

// gen 	sim_yNonBenPersGrossLevelYear = yNonBenPersGrossLevelMonth * 12
	
* Annual benefit unit gross non-benefit income	
gen sim_yNonBenBuGrossLevelYear = sim_yPensBuGrossLevelYear + ///
	sim_yCapitalBuLevelYear + sim_yEmpBuGrossLevelYear	
	
	
* Annual benefit unit gross income (level, non-benefit)
/*
Note this should be the same as sim_yNonBenBuGrossLevelYear
*/
gen sim_yGrossBuLevelMonth = yGrossMonth
gen sim_yGrossBuLevelYear = sim_yGrossBuLevelMonth * 12		

* Check 
gen diff = sim_yGrossBuLevelYear - sim_yNonBenBuGrossLevelYear

hist diff 	// very close
	
replace sim_yGrossBuLevelYear = sim_yNonBenBuGrossLevelYear

gen sim_yGrossPersLevelYear = sim_yNonBenPersGrossLevelYear	
	
	
* Annual benefit unit disposable (level)
gen yDispBuLevelMonth = yDispMonth 
gen sim_yDispBuLevelYear = yDispBuLevelMonth * 12		
	

* Annual benefit unit equivlaized disposable income (BU, level)
gen sim_yDispEquivYear = yDispEquivYear	
	

* Benefit unit - Net transfers 	
gen sim_net_transfers = sim_yDispBuLevelYear - sim_yNonBenBuGrossLevelYear


* Restrict sample to relevant valdiation years 
keep if year >= ${min_sim_year}
keep if year <= ${max_sim_year}

drop diff 

save "$dir_data/simulation_sample.dta", replace


graph drop _all
