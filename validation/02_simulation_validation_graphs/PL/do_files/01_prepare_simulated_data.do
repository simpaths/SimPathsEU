********************************************************************************
* PROJECT:  		SimPaths EU 
* SECTION:			Validation - longitudinal SILC
* OBJECT: 			Simulation output pre-processing
* AUTHORS:			Patryk Bronka, Ashley Burdett 
* LAST UPDATE:		06/2025 (AB)
* COUNTRY: 			PL 

* NOTES: 			
********************************************************************************




* Import required variables from household file
import delimited "$dir_simulated_data/Household.csv", case(preserve) clear 

keep run time id_Household

rename id_Household idHh  

keep if time <= ${max_year}

save "$dir_data/household_validation", replace


* Import required variables from benefit unit file
import delimited "$dir_simulated_data/BenefitUnit.csv", case(preserve) clear

keep run time idHh id_BenefitUnit yDispMonth yDispEquivYear yGrossMonth 
	
rename id_BenefitUnit idBu

keep if time <= ${max_year}	

save "$dir_data/benefitunit_validation", replace


* Import required variables from person file
import delimited "$dir_simulated_data/Person.csv", case(preserve) clear

keep run time id_Person idPartner idBu idMother idFather demAge ///
	demMaleFlag demPartnerStatus labC4 eduHighestC4 ///
	healthDsblLongtermFlag healthSelfRated ///
	yNonBenPersGrossMonth yEmpPersGrossMonth yCapitalPersMonth ///
	yPensPersGrossMonth yMiscPersGrossMonth ///
	labHrsWorkWeek labHrsWorkEnumWeek labHrsWorkWeek ///
	labWageHrly
	
rename id_Person idPers

keep if time <= ${max_year}
										
save "$dir_data/person_validation", replace


* Merge data sets 
use "$dir_data/person_validation", clear

merge m:1 run time idBu using "$dir_data/benefitunit_validation", ///
	nogen keep(matched)

save "$dir_data/loaded_simulation_data.dta", replace 


* Tidy up 
erase "${dir_data}/household_validation.dta"
erase "${dir_data}/person_validation.dta"
erase "${dir_data}/benefitunit_validation.dta"
