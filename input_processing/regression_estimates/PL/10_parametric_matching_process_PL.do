********************************************************************************
* PROJECT:  		SimPaths EU
* SECTION:			Partnership formation 
* OBJECT: 			Estimates for the parametric couple matching process
* AUTHORS:			Daria Popova, Justin van de Ven, Ashley Burdett
* LAST UPDATE:		21/04/2024 (JV)
* COUNTRY: 			PL 
********************************************************************************

clear all
set more off
set mem 200m
set type double
//set maxvar 120000
set maxvar 30000


* Call dataset with Heckman estimates 
use "$dir_data/${country}-_pooled_ipop2.dta", clear 

sort idperson stm  
xtset idperson stm 
gen newMarriage = (idpartner > 0 & idpartner<.) & ///
	(l.idpartner <= 0 | l.idpartner >= .)

save "$dir_data/parametricUnionDataset", replace 


* 2. Use wages predicted using wage equation:

sum pred_hourly_wage if dgn == 0
sum pred_hourly_wage if dgn == 1

gen predictedWage = pred_hourly_wage

*3. Keep only those above 18 as that's the minimum age to get married in the 
* simulation

keep if dag >= ${age_form_partnership}

*4. Look at newly matched couples in the initial population 
* (this requires the longitudinal component). 
*This has been added to the input data file as newMarriage variable

tempfile partners

preserve

keep if dgn == 0 //All partners female
keep stm idperson idhh dgn dag predictedWage
rename idperson idpartner
rename dag dagPartner
rename predictedWage predictedWagePartner
rename dgn dgnPartner
save `partners', replace

restore 

//Keep only newly matched people
drop if idpartner < 0 | missing(idpartner) 
keep if newMarriage
keep if dgn == 1

merge 1:1 stm idpartner using `partners', keep(matched)


* 4. Look at the difference in wage and age of the newly matched couples
*The first partner should probably always have the same gender, so calculate 
* the difference between male - female

gen dagDifference = dag - dagPartner
gen predictedWageDifference = predictedWage - predictedWagePartner 
drop if missing(dagDifference) | missing(predictedWageDifference)

* 5. Plot the distribution of wage and age differentials against a normal 
* distribution

//hist dagDifference, frequency normal
//hist predictedWageDifference, frequency normal

*6. Obtain the parameters for the bivariate normal distribution 
*Sample moments are a good enough approximation to the true parameters?

sum dagDifference predictedWageDifference //Get sample mean and std dev

putexcel set "$dir_work/scenario_parametricMatching", sheet("Parameters") replace
putexcel A1 = ("Parameter") 
putexcel A2 = ("mean_dag_diff")
putexcel A3 = ("mean_wage_diff")
putexcel A4 = ("var_dag_diff")
putexcel A5 = ("var_wage_diff")
putexcel A6 = ("cov_dag_wage_diff")
putexcel B1 = ("Value")

qui sum dagDifference 
putexcel B2 = matrix(r(mean)')
putexcel B4 = matrix(r(Var)')

qui sum predictedWageDifference
putexcel B3 = matrix(r(mean)')
putexcel B5 = matrix(r(Var)')

corr dagDifference predictedWageDifference, cov 
return list
matrix list r(C) //Get variance-covariance matrix

putexcel B6 = matrix(r(cov_12)') 


*rho x,y = cov x,y / (sigma x * sigma y), which is equivalent to corr 
* dagDifference predictedWageDifference

corr dagDifference predictedWageDifference


scalar BesselCorrection = _N / (_N - 1)
di BesselCorrection

*Corrected rho:
qui corr dagDifference predictedWageDifference
di "Small sample corrected rho:"
di r(rho) * BesselCorrection
