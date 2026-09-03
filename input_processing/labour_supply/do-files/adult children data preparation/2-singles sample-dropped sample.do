***************************************************************************************************
* 		Poland EM data (PL_2019_b3.txt data)
*       Labour supply estimation-get sample for adult children and generate the vbls needed for ls 
**************************************************************************************************

global file_log="singles_sample-dropped sample"

global n_choices = 4         // 4 choices: no work, plus 3 hours brackets. 						   
global n_workchoices = $n_choices - 1     // 3 choices with positive supply of hours, 1 choice with 0 hours. 	

cd "$local_data"

capture log close
log using "$file_log", replace
pwd
clear all
set seed 1																//same seed gives same results	

*version 15

//update 1/2/2021: at the end of the do file, divide this sample into two subsamples: singles_indep_wage`i'-dropped_sample and singles_dep_wage`i'-dropped_sample

*loop through wage1, wage2: hours of work estimation for each gender (triple loop)

//loop over wage1, wage2
foreach i in 1 2{   //loop begin for wage imputation method 
use "individuals_output_wage`i'-dropped_sample",clear
//assert bunct_s==0 //N/A for IT: making sure unemployment benefit (JSA): bunct_s=0 for every alternatives for everyone
gen sim_flag=0  //needed because this should contain the same variables as in dataset to be appended

merge m:1 idperson using "temp_file-dropped_sample.dta"												//add additional information
assert _merge==3
drop _merge

duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

gen d40=(dag>=40)

gen d45=(dag>=45)

//dummy of living with elderly (aged>=50), including themselves
gen d50=(dag>=50)
bysort temp_idorighh:egen d_with_elderly50=total(d50)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly50=(d_with_elderly50>0)
label variable d_with_elderly50 "1(living with people aged 50+)"

//dummy of living with elderly (aged>=55), including themselves
gen d55=(dag>=55)
bysort temp_idorighh:egen d_with_elderly55=total(d55)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly55=(d_with_elderly55>0)
label variable d_with_elderly55 "1(living with people aged 55+)"

//dummy of living with elderly (aged>=60), including themselves
gen d60=(dag>=60)
bysort temp_idorighh:egen d_with_elderly60=total(d60)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly60=(d_with_elderly60>0)
label variable d_with_elderly60 "1(living with people aged 60+)"

//dummy of living with elderly (aged>=65), including themselves
gen d65=(dag>=65)
bysort temp_idorighh:egen d_with_elderly65=total(d65)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly65=(d_with_elderly65>0)
label variable d_with_elderly65 "1(living with people aged 65+)"

//dummy of living with elderly (aged>=70), including themselves
gen d70=(dag>=70)
bysort temp_idorighh:egen d_with_elderly70=total(d70)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly70=(d_with_elderly70>0)
label variable d_with_elderly70 "1(living with people aged 70+)"

//dummy of living with elderly (aged>=75), including themselves
gen d75=(dag>=75)
bysort temp_idorighh:egen d_with_elderly75=total(d75)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly75=(d_with_elderly75>0)
label variable d_with_elderly75 "1(living with people aged 75+)"

label variable les "economic status"   //les=4: pensioner
gen d_se=(les==2)  //dummy of being self-employed
label variable d_se "1(self-employed)"   

********


bysort idhh: egen hhcon=sum(ils_dispy) //hh income, should be done before keeping only the target sample
//assert hhcon==. if sim_flag==1
label variable hhcon "income"
keep if temp_singles==1 &temp_choicehh!=. //target sample: "singles", and keep only $n_choices rows for each individual
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

//check data structure
bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices) if temp_singles==1  //for an individual in "singles", 1 option is chosen from $n_choices options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation

//generation of vbls
//house ownership
gen d_owner=(amrtn==1|amrtn==2)  
label variable d_owner "house owner (on mortgage or outright)"

gen d_owner_out=(amrtn==2)  //own outright
label variable d_owner_out "house owner (outright)"

gen d_owner_mort=(amrtn==1)  //own on mortgage
label variable d_owner_out "house owner (on mortgage)"

gen d_renter_social=(amrtn==5)  //own on mortgage
label variable d_renter_social "house renter (social rented)"

***********************
gen leisure=24*7-lhw																//define leisure for utility function		
label variable leisure "leisure"

//participation dummy	
gen fixed_cost=(lhw>0)																//define a fixed-cost of work (dummy)
label variable fixed_cost "fixed cost for labour"

//gen part-time fixed cost
gen part_fixed_cost=(lhw<40 &lhw>0)   //in HU full-time work is 40 hours per week
label variable part_fixed_cost "fixed cost for part-time work"

//gen full-time fixed cost
gen full_fixed_cost=(lhw>=40)
label variable full_fixed_cost "fixed cost for full-time work"

//gen interaction of fixed cost with gender 
gen fixc_dgn=fixed_cost*dgn
lab var fixc_dgn "fixed cost for labour$\times$1(male)"

//social norm?
gen hrs_40=(lhw==40)
label var hrs_40 "1(weekly working hours=40)"

gen hrs_40plus=(lhw>=40)
label var hrs_40plus "1(weekly working hours>=40)"

//gen interaction of 40 hours dummy with gender  
gen hrs_40_dgn=hrs_40*dgn
lab var hrs_40_dgn "1(weekly working hours=40)\times$1(male)"

gen hrs_40plus_dgn=hrs_40plus*dgn
lab var hrs_40plus_dgn "1(weekly working hours=40plus)\times$1(male)"

//experience variable 
//gen liwwh_0 = (liwwh==0) //zero experience 
gen liwwh_1 = (liwwh>=0 & liwwh<1) //less than a year experience  
gen liwwh_2 = (liwwh>=1 & liwwh<5) //1 to 5 years experience 
gen liwwh_3 = (liwwh>=5) //5+ years experience 
//lab var liwwh_0 "no experience"
lab var liwwh_1 "0-1 years (new entrants)"
lab var liwwh_2 "1-5 years (some experience)"
lab var liwwh_3 "5+ years (highly experienced)"

gen ln_liwwh = ln(liwwh + 1)

foreach var in liwwh  {
			gen `var'2=(`var'^2) 
			label variable `var'2 "`var'^2"
		}
		
* Generation of variables squared
		foreach var in leisure  hhcon {
			gen `var'2=(`var'^2) 
			label variable `var'2 "`var'^2"
		}

//rescale age and age^2
gen age_100=dag/100
label variable age_100 "age/100"

gen age2_10000= temp_age2/10000
label variable age2_10000 "age^2/10000"

//rescale hhcon and hhcon^2
gen hhcon_100=hhcon/100
label variable hhcon_100 "income/100"

gen hhcon2_10000= hhcon2/10000
label variable hhcon2_10000 "income^2/10000"

*generation of interactions with household income
global incomex "age_100 age2_10000 temp_n_ch temp_d_ch2 d_owner_out d_owner_mort d_renter_social temp_hhsize temp_dhe_1  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5"
foreach x of varlist $incomex{
gen hhcon_100_`x'=hhcon_100*`x'
local varlabel : var label `x'
label variable hhcon_100_`x' "income/100#`varlabel'"
}

/*combining regions
//North West + North East= North
gen temp_north=temp_region1+temp_region2
lab var temp_north "North"
//South + Islands= South
gen temp_south_islands=temp_region4+temp_region5
lab var temp_south_islands "South and Islands"
*/

*generation of interactions with fixed cost for labour
global fixedcostx "temp_n_ch temp_d_ch2 temp_p_sick_dis temp_p_student d_owner_out d_owner_mort d_renter_social temp_p_pensioner temp_d_deh_L temp_d_deh_M temp_d_deh_H d60 d65 d70 temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7 temp_dhe_1  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5"
foreach x of varlist $fixedcostx{
gen fixc_`x'=fixed_cost*`x'
local varlabel : var label `x'
label variable fixc_`x' "fixed cost for labour#`varlabel'"
}

*generation of interactions with leisure
global lx "hhcon_100 age_100 age2_10000 temp_n_ch temp_d_ch* temp_d_deh_L temp_d_deh_M temp_d_deh_H temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7 d_owner_out d_owner_mort d_renter_social temp_hhsize temp_dhe_1  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5"
foreach x of varlist $lx{
gen lei_`x'=leisure*`x'
local varlabel : var label `x'
label variable lei_`x' "leisure#`varlabel'"
}

*estimate labour supply model and compute predicted choices
// LS model of choices (0,20,40,50). By default assumes quadratic utility. verbose shows more detail

bysort temp_idorigperson2: egen min_hhcon=min(hhcon)
drop if min_hhcon<=0                        //consumption is not allowed to be 0 or negative for lslogit
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

//divide this sample into two subsamples:

/*DP: Added filter for adult children for consistency with simulations , 15 Nob 2025 */
//singles_indep_wage`i'-dropped_sample
preserve
keep if temp_singles_indep==1 & temp_adultchildflag==1 
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

save singles_indep_wage`i'-dropped_sample,replace
restore

//singles_dep_wage`i'-dropped_sample
preserve
keep if temp_singles_dep==1
save singles_dep_wage`i'-dropped_sample,replace
restore

save singles_wage`i'-dropped_sample,replace //still save this as will be used in EM sample (1.1wage)

}  //loop end for wage imputation method
log close


