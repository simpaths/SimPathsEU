************************************************************************
* 			EU SILC (PL_2019_b3) 
*			Labour supply estimation for dependent singles 
************************************************************************
/*
// @@@ SPECIFICATION @@@
Consumption-leisure preferences using a quadratic utility function with fixed costs. 
Combined model for men and women with fixed cost interacted with gender, using predicted wages for everyone 
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
set seed 1																//same seed gives same results	

*version 15

*=======================================================================
*           estimate hours of work for female and male, respectively
*=======================================================================
//use wage 1 only because MU is better                       
use singles_dep_wage$impmethod, clear
//foreach gender in 0 1{ //loop begin for gender
capture drop temp_pred_lhw1
capture drop pred_prob
capture drop pred_utility
capture drop pred_utility2
capture drop max_utility2
capture drop pred_choice2
capture drop pred_lhw2
capture drop temp_pred_lhw2
capture drop epsilon2

capture drop pred_choice1
capture drop pred_utility1
capture drop max_utility1
capture drop pred_choice1
capture drop pred_lhw1
capture drop temp_pred_lhw1


drop if sim_flag==1  //make sure the data is actual at this point


global vars "hhcon_100 hhcon2_10000 leisure leisure2 lei_hhcon_100 hrs_40plus_dgn" //fixc_dgn adding fixed_cost#gender dummy
****************************************************************************************************************
//clogit temp_choicehh `vars_simple', group (temp_idorigperson2) //estimate only on actual data (sim_flag==0)
asclogit temp_choicehh  ${vars}, case(temp_idorigperson2) alt(temp_seq) casevars(liwwh liwwh2)  nocons 
****************************************************************************************************************

gen ll = (e(ll)) //gen log likelyhood 

eststo singles_wage$impmethod
gen sample=(e(sample))

//version 13

foreach gender in 0 1{ //loop begin for gender
//////////////////////////////////////
//output estimated results to Excel //
//////////////////////////////////////
* output labels 
if (`gender' == 0){
putexcel set "$results/reg_labourSupplyUtility_PL", sheet("SingleDep_Females") modify

putexcel A1 = "REGRESSOR"
putexcel A2 = "IncomeDiv100"
putexcel A3 = "IncomeSqDiv10000"
putexcel A4 = "FemaleLeisure"
putexcel A5 = "FemaleLeisureSq"
putexcel A6 = "FemaleLeisure_IncomeDiv100"
putexcel A7 = "Hrs_40plus_Female"
putexcel A8 = "Liwwh_Female_1"
putexcel A9 = "LiwwhSq_Female_1"
putexcel A10 = "Liwwh_Female_2"
putexcel A11 = "LiwwhSq_Female_2"
putexcel A12 = "Liwwh_Female_3"
putexcel A13 = "LiwwhSq_Female_3"
putexcel A14 = "Liwwh_Female_10"
putexcel A15 = "LiwwhSq_Female_10"
putexcel A16 = "Liwwh_Female_20"
putexcel A17 = "LiwwhSq_Female_20"
putexcel A18 = "Liwwh_Female_30"
putexcel A19 = "LiwwhSq_Female_30"

putexcel B1 = "COEFFICIENT"
putexcel C1 = "IncomeDiv100"
putexcel D1 = "IncomeSqDiv10000"
putexcel E1 = "FemaleLeisure"
putexcel F1 = "FemaleLeisureSq"
putexcel G1 = "FemaleLeisure_IncomeDiv100"
putexcel H1 = "Hrs_40plus_Female"
putexcel I1 = "Liwwh_Female_1"
putexcel J1 = "LiwwhSq_Female_1"
putexcel K1 = "Liwwh_Female_2"
putexcel L1 = "LiwwhSq_Female_2"
putexcel M1 = "Liwwh_Female_3"
putexcel N1 = "LiwwhSq_Female_3"
putexcel O1 = "Liwwh_Female_10"
putexcel P1 = "LiwwhSq_Female_10"
putexcel Q1 = "Liwwh_Female_20"
putexcel R1 = "LiwwhSq_Female_20"
putexcel S1 = "Liwwh_Female_30"
putexcel T1 = "LiwwhSq_Female_30"
}

else{
putexcel set "$results/reg_labourSupplyUtility_PL", sheet("SingleDep_Males") modify

putexcel A1 = "REGRESSOR"
putexcel A2 = "IncomeDiv100"
putexcel A3 = "IncomeSqDiv10000"
putexcel A4 = "MaleLeisure"
putexcel A5 = "MaleLeisureSq"
putexcel A6 = "MaleLeisure_IncomeDiv100"
putexcel A7 = "Hrs_40plus_Male"
putexcel A8 = "Liwwh_Male_1"
putexcel A9 = "LiwwhSq_Male_1"
putexcel A10 = "Liwwh_Male_2"
putexcel A11 = "LiwwhSq_Male_2"
putexcel A12 = "Liwwh_Male_3"
putexcel A13 = "LiwwhSq_Male_3"
putexcel A14 = "Liwwh_Male_10"
putexcel A15 = "LiwwhSq_Male_10"
putexcel A16 = "Liwwh_Male_20"
putexcel A17 = "LiwwhSq_Male_20"
putexcel A18 = "Liwwh_Male_30"
putexcel A19 = "LiwwhSq_Male_30"

putexcel B1 = "COEFFICIENT"
putexcel C1 = "IncomeDiv100"
putexcel D1 = "IncomeSqDiv10000"
putexcel E1 = "MaleLeisure"
putexcel F1 = "MaleLeisureSq"
putexcel G1 = "MaleLeisure_IncomeDiv100"
putexcel H1 = "Hrs_40plus_Male"
putexcel I1 = "Liwwh_Male_1"
putexcel J1 = "LiwwhSq_Male_1"
putexcel K1 = "Liwwh_Male_2"
putexcel L1 = "LiwwhSq_Male_2"
putexcel M1 = "Liwwh_Male_3"
putexcel N1 = "LiwwhSq_Male_3"
putexcel O1 = "Liwwh_Male_10"
putexcel P1 = "LiwwhSq_Male_10"
putexcel Q1 = "Liwwh_Male_20"
putexcel R1 = "LiwwhSq_Male_20"
putexcel S1 = "Liwwh_Male_30"
putexcel T1 = "LiwwhSq_Male_30"
}

* output coefficients 
matrix results = r(table)
matrix results = results[1..6,1...]'   //extract the first six rows of results, and then transpose results
putexcel B2= matrix(results /*, names*/ ) //names nformat(number_d2)  //write estimates in Excel from cell B2

* output variance-covariance matrix 
matrix results=e(V)
putexcel C2 = matrix(results /*, names*/ ) //names nformat(number_d2)  //write e(V) in Excel from cell C2 

} //end of loop for gender 


*********************
*Marginal utilities *
*********************
*this is inside the gender loop (ignore,estimates are combined for  both genders)
capture drop dU_c
capture drop dU_lei
capture drop dU2_c
capture drop dU2_lei

			*-----------------------------------------------------------------
			* First differential of utility w.r.t. disposable income
			*-----------------------------------------------------------------
			gen dU_c=_b[hhcon_100]+2*hhcon_100*_b[hhcon2_10000]+leisure*_b[lei_hhcon_100] 
            su dU_c if temp_choicehh==1  //& sim_flag==0
			
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. disposable income
			*-----------------------------------------------------------------
            gen dU2_c=2*_b[hhcon2_10000]
			su dU2_c if temp_choicehh==1  //& sim_flag==0

			*-----------------------------------------------------------------
			* First differential of utility w.r.t. leisure
			*-----------------------------------------------------------------
			gen double dU_lei=_b[leisure]+2*leisure*_b[leisure2]+hhcon_100*_b[lei_hhcon_100] 
            su dU_lei if temp_choicehh==1  //& sim_flag==0
			
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. leisure
			*-----------------------------------------------------------------
		    gen dU2_lei=2*_b[leisure2]
			su dU2_lei if temp_choicehh==1  //& sim_flag==0
			
			
			
*-----------------------------------------------------------------
* Predict prob for both actual and simulated data
*-----------------------------------------------------------------
capture drop choice_prob
capture drop hrs_hat
capture drop E_hrs_hat
capture drop prob_work

predict choice_prob    //probability of a positive outcome
count 
*the highest utility=deterministic+stochastic is chosen

append using "sim_singles_dep_110_individuals_output_wage$impmethod"   //for "singles" sample, get simulated ils_dispy resulting from 10% increase of gross wage
fre sim_flag 
//we need to generate  fixc_dgn also for the simulated income sample
replace fixc_dgn=fixed_cost*dgn if sim_flag==1
lab var fixc_dgn "fixed cost for labour$\times$1(male)"

predict double pred_prob if sim_flag==0										//predicted probabilities (deterministic)
predict double de_pred_utility if  sim_flag==0, xb										//deterministic component of utility
sum de_pred_utility if  sim_flag==0
//v15 update
predict double sim_pred_prob if  sim_flag==1										//predicted probabilities (deterministic)
predict double sim_de_pred_utility if  sim_flag==1, xb										//for simulated hhcon, deterministic component of utility
su sim_de_pred_utility if  sim_flag==1



capture drop hrs_elas_*
set seed 339487731
//v15 update: loop for random draw
//add loop beginning
forvalues i = 1/$n_draws {
capture drop epsilon 
capture drop pred_utility
capture drop max_utility
capture drop pred_lhw
capture drop temp_pred_lhw

capture drop sim_pred_utility
capture drop sim_max_utility
capture drop sim_pred_lhw
capture drop sim_temp_pred_lhw


gen double epsilon= -log(-log(runiform()))	 						//random draw from an extreme value distribution (required for counterfactual)
gen double pred_utility= de_pred_utility+epsilon if  sim_flag==0				//utility=deterministic utility+stochastic utility

bys temp_idorigperson2: egen double max_utility=max(pred_utility) if  sim_flag==0	//for each agent highest utility 
gen pred_lhw=lhw if max_utility==pred_utility & sim_flag==0						//predicted hours of work (only present in the chosen row)
replace pred_lhw=0 if pred_lhw==.
bys temp_idorigperson2: egen temp_pred_lhw=total(pred_lhw) , missing				//expand pred_lhw2 to all alternatives (missing as 0)



//v15 update: predict optimal hours for sim_hhcon
gen double sim_pred_utility= sim_de_pred_utility+epsilon if  sim_flag==1				//utility=deterministic utility+stochastic utility
bys temp_idorigperson2: egen double sim_max_utility=max(sim_pred_utility) if sim_flag==1	//for each agent highest utility 
gen sim_pred_lhw=lhw if sim_max_utility==sim_pred_utility  & sim_flag==1							//predicted hours of work (only present in the chosen row)
bys temp_idorigperson2: egen sim_temp_pred_lhw=total(sim_pred_lhw) , missing				//expand pred_lhw2 to all alternatives (missing as 0)


****************
*Elasticities  *
****************
gen hrs_elas_`i'=10*(sim_temp_pred_lhw-temp_pred_lhw)/temp_pred_lhw if  temp_choicehh==1
}
order hrs_elas_*, last 
egen mean_hrs_elas=rmean(hrs_elas_1-hrs_elas_$n_draws) if  temp_choicehh==1 & sample==1  // single female's/male's hours elasticity (for each obs)
su mean_hrs_elas if  temp_choicehh==1 & sample==1,d  //summary of single females's hours elasticity across observations


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//hours fit graph (histograms for two genders)(with the last random draw as previous draws are all overwritten)  //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
twoway (histogram lhw           if temp_choice==1  & sample==1, discrete percent color(green) ) ///
	   (histogram temp_pred_lhw if temp_choice==1  & sample==1, discrete percent fcolor(none) lcolor(black)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Couples, only one partner LS flexible") xtitle("weekly hours worked") xlabel(0 20 40 50, valuelabel )
 
//graph combine  "his_hoursfit_0" "his_hoursfit_1" 
graph export "$results_ls/singles-dep/his_hoursfit_bothgenders_dep.png", as(png) replace


/////////////////////////
//graph of elasticity  //
/////////////////////////
twoway (histogram mean_hrs_elas if temp_choicehh==1 & sample==1 ,  fcolor(none) lcolor(black)), ///
		      subtitle("Hours elasticity")
graph export "$results_ls/singles-dep/hrs_elas_single_dep.png", as(png) replace


sum ils_dispy
//save singles_wage$impmethod.dta, replace  //try not to save too many data files to save disc space

///////////////////////////////
//histogram of du/dc, du/dlei//
///////////////////////////////
twoway (histogram dU_c if sample==1 &temp_choicehh==1 ,  fcolor(none) lcolor(black)), ///
		   subtitle("MU wrt income")
		   graph export "$results_ls/singles-dep/dUdc_single_dep.png", as(png) replace
		   
twoway (histogram dU_lei if sample==1& temp_choicehh==1,  fcolor(none) lcolor(black)), ///
		   subtitle("MU wrt leisure")
		   graph export "$results_ls/singles-dep/dUdlei_single_dep.png", as(png) replace

		   
su dU_c dU_lei  dU2_c dU2_lei  if sample==1& temp_choicehh==1  

  

/////////////////////////////////////
//export estimation results to tex //
/////////////////////////////////////
esttab  singles_wage$impmethod using "$results_ls/singles-dep/ls_single_dep_10.tex", replace label cells(b(star fmt(3))) stats(ll r2_p N ) nonumbers ///
collabels(none) ///
title(Labour supply (utility function) estimation: Couples, only one partner LS flexible. ///
		Notes: Income in hundreds of British Pounds. ///
\label{tab:hours-singles}) ///
varlabels(r2_p pseudo-R^2) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing tex including female and male(including at least three non-zero digits)

esttab  singles_wage$impmethod using "$results_ls/singles-dep/ls_single_dep_10.csv", replace label cells(b(star fmt(3))) stats(ll r2_p N ) nonumbers  ///
collabels(none) ///
title(Labour supply (utility function) estimation: Couples, only one partner LS flexible. ///
		Notes: Income in hundreds of British Pounds. ///
\label{tab:hours-singles}) ///
varlabels(r2_p pseudo-R^2) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing csv including female and male(including at least three non-zero digits)

/////////////////////
//Income deciles ////
/////////////////////
xtile dec_hhcon = hhcon if sample==1 &temp_choicehh==1, nq(10)  //create decile variable for single female and male

bysort dec_hhcon:su mean_hrs_elas if sample==1 &temp_choicehh==1

//box plot
label var dec_hhcon "income decile"
graph box mean_hrs_elas if temp_choicehh==1, ytitle(wage elasticity) over(dec_hhcon)  subtitle("Couples, only one partner LS flexible") note("Income decile" ///
"Lines indicate upper adjacent value, 75th percentile, median, 25th percentile, lower adjacent value.") 

graph export "$results_ls/singles-dep/wage_elas_dep.png", as(png) replace
		
		
///////////////////
///summary stats //
///////////////////

*percent of obs with positive marginal utilities 
foreach i in dU_c dU_lei{
//foreach gender in 0 1{
gen `i'positive=(`i'>0)
su `i'positive if sample==1 & temp_choicehh==1
//}
}
*percent of obs with negative marginal utilities  
foreach i in dU_c dU_lei{
cap drop `i'_negative
gen `i'_negative=(`i'<0)
sum `i'_negative if sample==1 & temp_choicehh==1 
} 

		
///////////////////////////////////////////////		
//output to Excel file with summary stats   ///
///////////////////////////////////////////////
putexcel set "${summary_table}", sheet(${sheet}, replace) modify	


putexcel A2=("Wage elasticities of hours of work")
putexcel A8=("Couples, only one LS flexible")
qui mean mean_hrs_elas if sample==1 &temp_choicehh==1
putexcel B8=matrix(e(b)')

putexcel A9=("% obs with negative marginal utility wrt income")
putexcel A14=("Couples, only one LS flexible")
qui mean dU_c_negative if sample==1 &temp_choicehh==1
putexcel B14=matrix(e(b)')


putexcel A15=("% obs with negative marginal utility wrt leisure")
putexcel A21=("Couples, only one LS flexible")
qui mean dU_lei_negative if sample==1 &temp_choicehh==1
putexcel B21=matrix(e(b)')

//add log likelihood 
putexcel A22=("Log likelihood")
putexcel A27=("Couples, only one LS flexible")
qui mean ll if sample==1 
putexcel B27=matrix(e(b)')


//obs vs predicted wages fit 
putexcel A44=("Couples, only one LS flexible")
putexcel A45=("observed")
putexcel A46=("predicted")
qui mean lhw if temp_choice==1 & sample==1 
putexcel B45=matrix(e(b)')
qui mean temp_pred_lhw if temp_choice==1  & sample==1
putexcel B46=matrix(e(b)')
	
		
		
log close

		

