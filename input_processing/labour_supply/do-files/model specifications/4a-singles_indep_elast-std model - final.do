**************************************************************************
* 			EU SILC (PL_2019_b3)
*			Labour supply estimation for independent singles 
************************************************************************
/*
// @@@ SPECIFICATION @@@
Consumption-leisure preferences using a quadratic utility function with fixed costs. 
Separate models for men and women, using predicted wages for everyone 
*/

global file_log="${log}/singles_indep_elast-std-simple"
global n_choices = 4           // 4 choices: no work, plus 3 hours brackets. 
global n_draws=100 //modify when computing elasticity 100 

cd "$local_data"

*Housekeeping
capture log close
*office PC

log using "$file_log", replace
pwd
clear all
set seed 1		

*version 15


*=======================================================================
*           estimate hours of work for female and male, respectively
*=======================================================================
//drop monthly hhcon<10
*capture drop min_hhcon
*bysort temp_idorigperson2: egen min_hhcon=min(hhcon)
*drop if min_hhcon<=10 


                 
*use singles_indep_wage1,clear //use predicted wages for everyone 
use singles_indep_wage$impmethod, clear //use observed wage for workers      

foreach gender in 0 1{ //loop begin for gender
capture drop temp_pred_lhw1_`gender'
capture drop pred_prob_`gender'
capture drop pred_utility_`gender'
capture drop pred_utility2_`gender'
capture drop max_utility2_`gender'
capture drop pred_choice2_`gender'
capture drop pred_lhw2_`gender'
capture drop temp_pred_lhw2_`gender'
capture drop epsilon2

capture drop pred_choice1_`gender'
capture drop pred_utility1_`gender'
capture drop max_utility1_`gender'
capture drop pred_choice1_`gender'
capture drop pred_lhw1_`gender'
capture drop temp_pred_lhw1_`gender'


//female variables 
global vars_0 "hhcon_100 hhcon2_10000 leisure leisure2 lei_hhcon_100 hrs_40plus" //fixed_cost
//male variables
global vars_1 "hhcon_100 hhcon2_10000 leisure leisure2 lei_hhcon_100 hrs_40plus" //fixed_cost

**************************************************************************************************************************************
drop if sim_flag==1  //make sure the data is actual at this point
//clogit temp_choicehh ${vars_`gender'}  if dgn==`gender'  , group (temp_idorigperson2) //estimate only on actual data (sim_flag==0)
asclogit temp_choicehh  ${vars_`gender'}  if dgn==`gender', case(temp_idorigperson2) alt(temp_seq) casevar(liwwh liwwh2) nocons 
**************************************************************************************************************************************

gen ll_`gender' = (e(ll))


eststo singles_`gender'_wage$impmethod
gen sample_`gender'=(e(sample))

//version 13

//////////////////////////////////////
//output estimated results to Excel //
//////////////////////////////////////
* output labels 
if (`gender' == 0){
putexcel set "$results/reg_labourSupplyUtility_PL", sheet("Single_female") modify

putexcel A1 = "REGRESSOR"
putexcel A2 = "IncomeDiv100"
putexcel A3 = "IncomeSqDiv10000"
putexcel A4 = "FemaleLeisure"
putexcel A5 = "FemaleLeisureSq"
putexcel A6 = "FemaleLeisure_IncomeDiv100"
putexcel A7 = "Hrs_40plus_Female"
putexcel A8 = "Liwwh_1"
putexcel A9 = "LiwwhSq_1"
putexcel A10 = "Liwwh_2"
putexcel A11 = "LiwwhSq_2"
putexcel A12 = "Liwwh_3"
putexcel A13 = "LiwwhSq_3"

putexcel B1 = "COEFFICIENT"
putexcel C1 = "IncomeDiv100"
putexcel D1 = "IncomeSqDiv10000"
putexcel E1 = "FemaleLeisure"
putexcel F1 = "FemaleLeisureSq"
putexcel G1 = "FemaleLeisure_IncomeDiv100"
putexcel H1 = "Hrs_40plus_Female"
putexcel I1 = "Liwwh_1"
putexcel J1 = "LiwwhSq_1"
putexcel K1 = "Liwwh_2"
putexcel L1 = "LiwwhSq_2"
putexcel M1 = "Liwwh_3"
putexcel N1 = "LiwwhSq_3"
}

else{
putexcel set "$results/reg_labourSupplyUtility_PL", sheet("Single_male") modify

putexcel A1 = "REGRESSOR"
putexcel A2 = "IncomeDiv100"
putexcel A3 = "IncomeSqDiv10000"
putexcel A4 = "MaleLeisure"
putexcel A5 = "MaleLeisureSq"
putexcel A6 = "MaleLeisure_IncomeDiv100"
putexcel A7 = "Hrs_40plus_Male"
putexcel A8 = "Liwwh_10"
putexcel A9 = "LiwwhSq_10"
putexcel A10 = "Liwwh_20"
putexcel A11 = "LiwwhSq_20"
putexcel A12 = "Liwwh_30"
putexcel A13 = "LiwwhSq_30"

putexcel B1 = "COEFFICIENT"
putexcel C1 = "IncomeDiv100"
putexcel D1 = "IncomeSqDiv10000"
putexcel E1 = "MaleLeisure"
putexcel F1 = "MaleLeisureSq"
putexcel G1 = "MaleLeisure_IncomeDiv100"
putexcel H1 = "Hrs_40plus_Male"
putexcel I1 = "Liwwh_10"
putexcel J1 = "LiwwhSq_10"
putexcel K1 = "Liwwh_20"
putexcel L1 = "LiwwhSq_20"
putexcel M1 = "Liwwh_30"
putexcel N1 = "LiwwhSq_30"

}

* output coefficients 
matrix results = r(table)
matrix results = results[1..6,1...]'   //extract the first six rows of results, and then transpose results
putexcel B2 = matrix(results /*, names*/) //names nformat(number_d2)  //write estimates in Excel from cell B2


* output variance-covariance matrix 
matrix results=e(V)
putexcel C2 = matrix(results /*, names*/ ) //names nformat(number_d2)  //write e(V) in Excel from cell C2 


******************
*Predict choices *
******************
predict double de_pred_utility_`gender' if dgn==`gender' , xb		//deterministic component of utility

set seed 1																//same seed gives same results	
gen double epsilon_`gender'= -log(-log(runiform()))	 						//random draw from an extreme value distribution (required for counterfactual)
gen double pred_utility_`gender'= de_pred_utility_`gender'+epsilon_`gender' if dgn==`gender'					//utility=deterministic utility+stochastic utility

bys temp_idorigperson2: egen double max_utility_`gender'=max(pred_utility_`gender') if dgn==`gender'	//for each agent highest utility 
//gen pred_choice2_`gender'=(max_utility2_`gender'==pred_utility2_`gender') if dgn==`gender'						//dummy for predicted choices
//gen pred_lhw2_`gender'=lhw if pred_choice2_`gender'==1& dgn==`gender'							//predicted hours of work
gen pred_lhw_`gender'=lhw if max_utility_`gender'==pred_utility_`gender' & dgn==`gender'							//predicted hours of work (only present in the chosen row)
replace pred_lhw_`gender'=0 if pred_lhw_`gender'==.
bys temp_idorigperson2: egen temp_pred_lhw_`gender'=total(pred_lhw_`gender') if dgn==`gender', missing				//expand pred_lhw2 to all alternatives (missing as 0)

   
*********************
*Marginal utilities *
*********************

*this is inside the gender loop
capture drop dU_c_`gender'
capture drop dU_lei_`gender'
capture drop dU2_c_`gender'
capture drop dU2_lei_`gender'

			*-----------------------------------------------------------------
			* First differential of utility w.r.t. disposable income
			*-----------------------------------------------------------------
			gen dU_c_`gender'=_b[hhcon_100]+2*hhcon_100*_b[hhcon2_10000] +leisure*_b[lei_hhcon_100]
            su dU_c_`gender' if temp_choicehh==1 &dgn==`gender' //& sim_flag==0
			
			
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. disposable income
			*-----------------------------------------------------------------
            gen dU2_c_`gender'=2*_b[hhcon2_10000]
			su dU2_c_`gender' if temp_choicehh==1 &dgn==`gender' //& sim_flag==0

			
			*-----------------------------------------------------------------
			* First differential of utility w.r.t. leisure
			*-----------------------------------------------------------------
			gen double dU_lei_`gender'=_b[leisure]+2*leisure*_b[leisure2]+hhcon_100*_b[lei_hhcon_100] 
            su dU_lei_`gender' if temp_choicehh==1 &dgn==`gender' //& sim_flag==0
			
			
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. leisure
			*-----------------------------------------------------------------
		    gen dU2_lei_`gender'=2*_b[leisure2]
			su dU2_lei_`gender' if temp_choicehh==1 &dgn==`gender' //& sim_flag==0
			
			
***************************************************
* Predict prob for both actual and simulated data *
***************************************************
capture drop choice_prob_`gender'
capture drop hrs_hat_`gender'
capture drop E_hrs_hat_`gender'
capture drop prob_work_`gender'

predict choice_prob_`gender' if dgn==`gender'   //probability of a positive outcome


*the highest utility=deterministic+stochastic is chosen

append using "sim_singles_indep_110_individuals_output_wage$impmethod"   //for "singles" sample, get simulated ils_dispy resulting from 10% increase of gross wage
//predict double pred_prob_`gender' if dgn==`gender'& sim_flag==0										//predicted probabilities (deterministic)
//predict double de_pred_utility_`gender' if dgn==`gender' & sim_flag==0, xb										//deterministic component of utility
sum de_pred_utility_`gender' if dgn==`gender' & sim_flag==0
//v15 update
predict double sim_pred_prob_`gender' if dgn==`gender'& sim_flag==1										//predicted probabilities (deterministic)

predict double sim_de_pred_utility_`gender' if dgn==`gender' & sim_flag==1, xb										//for simulated hhcon, deterministic component of utility
su sim_de_pred_utility_`gender' if dgn==`gender' & sim_flag==1


capture drop hrs_elas_`gender'_*
set seed 339487731
//v15 update: loop for random draw
//add loop beginning
forvalues i = 1/$n_draws {
capture drop epsilon 
capture drop pred_utility_`gender'
capture drop max_utility_`gender'
capture drop pred_lhw_`gender'
capture drop temp_pred_lhw_`gender'

capture drop sim_pred_utility_`gender'
capture drop sim_max_utility_`gender'
capture drop sim_pred_lhw_`gender'
capture drop sim_temp_pred_lhw_`gender'


gen double epsilon= -log(-log(runiform()))	 						//random draw from an extreme value distribution (required for counterfactual)
gen double pred_utility_`gender'= de_pred_utility_`gender'+epsilon if dgn==`gender'	& sim_flag==0				//utility=deterministic utility+stochastic utility

bys temp_idorigperson2: egen double max_utility_`gender'=max(pred_utility_`gender') if dgn==`gender'	& sim_flag==0	//for each agent highest utility 
//gen pred_choice2_`gender'=(max_utility2_`gender'==pred_utility2_`gender') if dgn==`gender'						//dummy for predicted choices
//gen pred_lhw2_`gender'=lhw if pred_choice2_`gender'==1& dgn==`gender'							//predicted hours of work
gen pred_lhw_`gender'=lhw if max_utility_`gender'==pred_utility_`gender' & dgn==`gender'	& sim_flag==0						//predicted hours of work (only present in the chosen row)
replace pred_lhw_`gender'=0 if pred_lhw_`gender'==.
bys temp_idorigperson2: egen temp_pred_lhw_`gender'=total(pred_lhw_`gender') if dgn==`gender', missing				//expand pred_lhw2 to all alternatives (missing as 0)

*replace pred_lhw_0=temp_pred_lhw_0 if dgn==`gender'	& pred_lhw_0==.								//expand pred_lhw2 to all alternatives


//v15 update: predict optimal hours for sim_hhcon
gen double sim_pred_utility_`gender'= sim_de_pred_utility_`gender'+epsilon if dgn==`gender'	& sim_flag==1				//utility=deterministic utility+stochastic utility
bys temp_idorigperson2: egen double sim_max_utility_`gender'=max(sim_pred_utility_`gender') if dgn==`gender'	& sim_flag==1	//for each agent highest utility 
//gen pred_choice2_`gender'=(max_utility2_`gender'==pred_utility2_`gender') if dgn==`gender'						//dummy for predicted choices
//gen pred_lhw2_`gender'=lhw if pred_choice2_`gender'==1& dgn==`gender'							//predicted hours of work
gen sim_pred_lhw_`gender'=lhw if sim_max_utility_`gender'==sim_pred_utility_`gender' & dgn==`gender' & sim_flag==1							//predicted hours of work (only present in the chosen row)
bys temp_idorigperson2: egen sim_temp_pred_lhw_`gender'=total(sim_pred_lhw_`gender') if dgn==`gender', missing				//expand pred_lhw2 to all alternatives (missing as 0)

*replace sim_pred_lhw_`gender'=sim_temp_pred_lhw_`gender' if dgn==`gender'	& sim_pred_lhw_`gender'==.								//expand pred_lhw2 to all alternatives


****************
*Elasticities  *
****************
gen hrs_elas_`gender'_`i'=10*(sim_temp_pred_lhw_`gender'-temp_pred_lhw_`gender')/temp_pred_lhw_`gender' if dgn==`gender' & temp_choicehh==1

} //end of draws loop??? 

order hrs_elas_`gender'_*, last
egen mean_hrs_elas_`gender'=rmean(hrs_elas_`gender'_1-hrs_elas_`gender'_$n_draws) if  temp_choicehh==1 & sample_`gender'==1  // single female's/male's hours elasticity (for each obs)
su mean_hrs_elas_`gender' if  temp_choicehh==1 & sample_`gender'==1,d  //summary of single females's hours elasticity across observations


*version 14 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//hours fit graph (histograms for two genders)(with the last random draw as previous draws are all overwritten)//////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
if (`gender'==0) {
twoway     (histogram lhw                    if temp_choice==1 & sample_`gender'==1,  discrete percent color(green)) ///
		   (histogram temp_pred_lhw_`gender' if temp_choice==1  & sample_`gender'==1,  discrete percent color(none) lcolor(black)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Independent singles, Women") xtitle("weekly hours worked") ///
		   xlabel(0 20 40 50, valuelabel ) 
}	   
else {
twoway     (histogram lhw                    if temp_choice==1 & sample_`gender'==1,   discrete percent color(green)) ///
		   (histogram temp_pred_lhw_`gender' if temp_choice==1  & sample_`gender'==1,  discrete percent fcolor(none) lcolor(black)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Independent singles, Men") xtitle("weekly hours worked") ///
		   xlabel(0 20 40 50, valuelabel )
}	
graph save "$results_ls/singles-ind/his_hoursfit_`gender'.gph", replace	
   
}  //end of loop end for gender


graph combine  "$results_ls/singles-ind/his_hoursfit_0" "$results_ls/singles-ind/his_hoursfit_1" 
graph export "$results_ls/singles-ind/his_hoursfit_bothgenders_indep.png", as(png) replace


/////////////////////////////////////////
//graph of elasticity for both genders //
/////////////////////////////////////////
twoway (histogram mean_hrs_elas_0 if temp_choicehh==1 & sample_0==1 ,  color(green) ) ///
		   (histogram mean_hrs_elas_1 if temp_choicehh==1 & sample_1==1, ///
		    fcolor(none) lcolor(black)), legend(order(1 "female single" 2 "male single" )) ///
		   subtitle("Hours elasticity")
graph export "$results_ls/singles-ind/hrs_elas_single_indep.png", as(png) replace


sum ils_dispy
//save singles_wage$impmethod.dta, replace  //try not to save too many data files to save disc space



///////////////////////////////
//histogram of du/dc, du/dlei//
///////////////////////////////
twoway (histogram dU_c_0 if sample_0==1 &temp_choicehh==1 ,  color(green) ) ///
		   (histogram dU_c_1 if sample_1==1 &temp_choicehh==1, ///
		    fcolor(none) lcolor(black)), legend(order(1 "female single" 2 "male single" )) ///
		   subtitle("MU wrt income")

		   graph export "$results_ls/singles-ind/dUdc_single_indep.png", as(png) replace

		   
twoway (histogram dU_lei_0 if sample_0==1& temp_choicehh==1,  color(green) ) ///
		   (histogram dU_lei_1 if sample_1==1 &temp_choicehh==1, ///
		    fcolor(none) lcolor(black)), legend(order(1 "female single" 2 "male single" )) ///
		   subtitle("MU wrt leisure")

		   graph export "$results_ls/singles-ind/dUdlei_single_indep.png", as(png) replace

su dU_c_0 dU_lei_0  dU2_c_0 dU2_lei_0  if sample_0==1& temp_choicehh==1  //female single
su dU_c_1 dU_lei_1 dU2_c_1 dU2_lei_1 if sample_1==1 & temp_choicehh==1  //male single


/////////////////////////////////////
//export estimation results to tex //
/////////////////////////////////////
esttab  singles_0_wage$impmethod  singles_1_wage$impmethod using "$results_ls/singles-ind/ls_single_indep_10.tex", replace label cells(b(star fmt(3))) stats(ll r2_p N ) nonumbers mtitles("Men" "Women") ///
collabels(none) ///
title(Labour supply (utility function) estimation: Independent singles. ///
		Notes: Income in hundreds of HUF. ///
\label{tab:hours-singles}) ///
varlabels(r2_p pseudo-R^2) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing tex including female and male(including at least three non-zero digits)

esttab  singles_0_wage$impmethod  singles_1_wage$impmethod using "$results_ls/singles-ind/ls_single_indep_10.csv", replace label cells(b(star fmt(3))) stats(ll r2_p N ) nonumbers mtitles("Men" "Women") ///
collabels(none) ///
title(Labour supply (utility function) estimation: Independent singles. ///
		Notes: Income in hundreds of HUF. ///
\label{tab:hours-singles}) ///
varlabels(r2_p pseudo-R^2) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing csv including female and male(including at least three non-zero digits)



/////////////////////////
////Income deciles  /////
/////////////////////////
xtile dec_hhcon0 = hhcon if sample_0==1 &temp_choicehh==1, nq(10)  //create decile variable for single female
xtile dec_hhcon1 = hhcon if sample_1==1 &temp_choicehh==1, nq(10)  //create decile variable for single male
bysort dec_hhcon0:su mean_hrs_elas_0 if sample_0==1 &temp_choicehh==1

bysort dec_hhcon1:su mean_hrs_elas_1 if sample_1==1 &temp_choicehh==1
//box plot
label var dec_hhcon0 "income decile"
graph box mean_hrs_elas_0 if temp_choicehh==1, ytitle(wage elasticity) over(dec_hhcon0)  subtitle("Independent singles, Women") note("Income decile" ///
"Lines indicate upper adjacent value, 75th percentile, median, 25th percentile, lower adjacent value.") 

		   graph export "$results_ls/singles-ind/wage_elas0_indep.png", as(png) replace
		   
graph box mean_hrs_elas_1 if temp_choicehh==1, ytitle(wage elasticity) over(dec_hhcon1) subtitle("Independent singles, Men") note("Income decile" ///
"Lines indicate upper adjacent value, 75th percentile, median, 25th percentile, lower adjacent value.") 

		   graph export "$results_ls/singles-ind/wage_elas1_indep.png", as(png) replace

		   
///////////////////
///summary stats //
///////////////////
*percent of obs with positive marginal utilities 
foreach i in dU_c dU_lei{
foreach gender in 0 1{
gen `i'_`gender'positive=(`i'_`gender'>0)
su `i'_`gender'positive if sample_`gender'==1 & temp_choicehh==1
}
}

*percent of obs with negative marginal utilities
foreach i in dU_c dU_lei{
foreach gender in 0 1{
cap drop `i'_`gender'negative
gen `i'_`gender'negative=(`i'_`gender'<0)
sum `i'_`gender'negative if sample_`gender'==1 & temp_choicehh==1
}
} 

/////////////////////////////////////////////
//output to Excel file with summary stats ///
/////////////////////////////////////////////
putexcel set "${summary_table}", sheet(${sheet}, replace) modify	   

putexcel A2=("Wage elasticities of hours of work")
putexcel A3=("Independent singles, women")
putexcel A4=("Independent singles, men")
mean mean_hrs_elas_0 if sample_0==1 &temp_choicehh==1
putexcel B3=matrix(e(b)')
mean mean_hrs_elas_1 if sample_1==1 &temp_choicehh==1
putexcel B4=matrix(e(b)')

putexcel A9=("% obs with negative marginal utility wrt income")
putexcel A10=("Independent singles, women")
putexcel A11=("Independent singles, men")
mean dU_c_0negative if sample_0==1 &temp_choicehh==1
putexcel B10=matrix(e(b)')
mean dU_c_1negative if sample_1==1 &temp_choicehh==1
putexcel B11=matrix(e(b)')

putexcel A15=("% obs with negative marginal utility wrt leisure")
putexcel A16=("Independent singles, women")
putexcel A17=("Independent singles, men")
mean dU_lei_0negative if sample_0==1 &temp_choicehh==1
putexcel B16=matrix(e(b)')
mean dU_lei_1negative if sample_1==1 &temp_choicehh==1
putexcel B17=matrix(e(b)')


//log likelihood 	
putexcel A22=("Log likelihood")
putexcel A23=("Independent singles, women")
putexcel A24=("Independent singles, men")

qui mean ll_0 if sample_0==1 
putexcel B23=matrix(e(b)')
qui mean ll_1 if sample_1==1 
putexcel B24=matrix(e(b)')


//obs vs predicted wages fit 
putexcel A28=("Mean hours")
putexcel A29=("Independent singles, women")
putexcel A30=("observed")
putexcel A31=("predicted")
putexcel A32=("Independent singles, men")
putexcel A33=("observed")
putexcel A34=("predicted")

	
qui mean lhw if temp_choice==1 & sample_0==1 
putexcel B30=matrix(e(b)')
qui mean temp_pred_lhw_0 if temp_choice==1 & sample_0==1 
putexcel B31=matrix(e(b)')

qui mean lhw if temp_choice==1 & sample_1==1 
putexcel B33=matrix(e(b)')
qui mean temp_pred_lhw_1 if temp_choice==1 & sample_1==1 
putexcel B34=matrix(e(b)')


log close
