**************************************************************************
* 			Poland EM data (PL_2019_b3.txt data)
*			Labour supply estimation-get sample for couples and generate the vbls needed for ls (std couples)
*************************************************************************


global file_log="${log}/couples_sample-std model"
global n_choices = 4          // 4 choices: no work, plus 3 hours brackets. 


cd "$local_data"

capture log close
log using "$file_log", replace
pwd
clear all
set seed 1																//same seed gives same results	

*version 15

*estimation of labour supply-loop through :wage1, wage2; hours of work estimation  (double loop)
foreach i in 1 2{   //loop begin for wage imputation method 
//local i=1 
use "individuals_output_wage`i'",clear

*use IT_individuals_output_wage2,clear //note that temp_idorigperson2 and other temp vbls are not in the EM output file
//assert bunct_s==0 //making sure unemployment benefit (JSA): bunct_s=0 for every alternatives for everyone

merge 1:1 idperson using "temp_file.dta"				//add additional information
assert _merge==3
drop _merge

duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)


bysort idhh: egen hhcon=sum(ils_dispy) //hh income, should be done before keeping only the target sample


gen d40=(dag>=40)

gen d45=(dag>=45)

//dummy of living with elderly (aged>=50), including themselves
gen d50=(dag>=50)
lab var d50 "1(male age>=50)"
bysort temp_idorighh:egen d_with_elderly50=total(d50)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly50=(d_with_elderly50>0)
label variable d_with_elderly50 "1(living with people aged 50+)"

//dummy of living with elderly (aged>=55), including themselves
gen d55=(dag>=55)
lab var d55 "1(male age>=55)"
bysort temp_idorighh:egen d_with_elderly55=total(d55)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly55=(d_with_elderly55>0)
label variable d_with_elderly55 "1(living with people aged 55+)"

//dummy of living with elderly (aged>=60), including themselves
gen d60=(dag>=60)
lab var d60 "1(male age>=60)"
bysort temp_idorighh:egen d_with_elderly60=total(d60)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly60=(d_with_elderly60>0)
label variable d_with_elderly60 "1(living with people aged 60+)"

//dummy of living with elderly (aged>=65), including themselves
gen d65=(dag>=65)
lab var d65 "1(male age>=65)"
bysort temp_idorighh:egen d_with_elderly65=total(d65)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly65=(d_with_elderly65>0)
label variable d_with_elderly65 "1(living with people aged 65+)"

//dummy of living with elderly (aged>=70), including themselves
gen d70=(dag>=70)
lab var d70 "1(male age>=70)"
bysort temp_idorighh:egen d_with_elderly70=total(d70)  //up to here d_with_elderly60=the no. of elderly in hh* $n_choices
replace d_with_elderly70=(d_with_elderly70>0)
label variable d_with_elderly70 "1(living with people aged 70+)"

/*
//get the original les (les was made to be 5 before running EM for bunct_s=0)
merge 1:1 idperson using les_bunct.dta
keep if _merge==3
drop _merge
*/
label variable les "economic status"   //temp_les=4: pensioner
gen d_se=(les==2)  //dummy of being self-employed
label variable d_se "1(self-employed)"   

********
keep if temp_couples==1 &temp_choicehh!=. //target sample: flexible couples
//check data structure
bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices^2) //for an individual in flexible couples, 1 option is chosen from ($n_choices)^2 options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation

	label variable temp_d_ch "1(children aged 0-17)"
	label variable temp_d_ch2 "1(children aged 0-2)"
	label variable temp_d_ch6 "1(children aged 3-6)"
	label variable temp_d_ch12 "1(children aged 7-12)"
	label variable temp_d_ch17 "1(children aged 13-17)"

	
	label variable temp_n_ch "number of children aged 0-17"
	label variable temp_n_ch2 "number of children aged 0-2"
	label variable temp_n_ch6 "number of children aged 3-6"
	label variable temp_n_ch12 "number of children aged 7-12"
	label variable temp_n_ch17 "number of children aged 13-17"
	

//generation of vbls
gen d_owner=(amrtn==1|amrtn==2)  
label variable d_owner "house owner (on mortgage or outright)"

gen d_owner_out=(amrtn==2)  //own outright
label variable d_owner_out "house owner (outright)"

gen d_owner_mort=(amrtn==1)  //own on mortgage
label variable d_owner_mort "house owner (on mortgage)"

gen d_renter_social=(amrtn==5)  //own on mortgage
label variable d_renter_social "house renter (social rented)"

****************
add_partner_variables "dag" 
rename partner_* sp_*  //just to make the names shorter      

gen temp_mean_age=(dag+sp_dag)/2   //partners' mean age
label variable temp_mean_age "partners' mean age"

gen temp_mean_age2=temp_mean_age^2  //partners' mean age squared
label variable temp_mean_age2 "partners' mean age^2"

gen leisure=24*7-lhw	
replace leisure=0 if leisure<0 																//define leisure for utility function		
label variable leisure "male leisure"

//generation of male leisure squared
gen leisure2=leisure^2
label variable leisure2 "male leisure^2"
gen fixed_cost=(lhw>0)																//define a fixed-cost of work (dummy)
label variable fixed_cost "male fixed cost for labour"

* Generation of hhcon squared
		foreach var in hhcon {
			gen `var'2=(`var'^2) 
			label variable `var'2 "`var'^2"
		}
		
//rescale partners' mean age and age^2
gen mean_age_100=temp_mean_age/100
label variable mean_age_100 "partners' mean age/100"

gen mean_age2_10000=temp_mean_age2/100
label variable mean_age2_10000 "partners' mean age^2/10000"
		
//rescale male age and age^2
gen age_100=dag/100
label variable age_100 "male age/100"

gen age2_10000= temp_age2/10000
label variable age2_10000 "male age^2/10000"

//rescale hhcon and hhcon^2
gen hhcon_100=hhcon/100
label variable hhcon_100 "income/100"

gen hhcon2_10000= hhcon2/10000
label variable hhcon2_10000 "income^2/10000"

*generation of interactions with household income
global incomex "mean_age_100 mean_age2_10000 temp_n_ch temp_d_ch2 d_owner_out d_owner_mort d_renter_social temp_hhsize temp_dhe_1  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5"
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

*generation of interactions with male fixed cost for labour
global fixedcostx "temp_n_ch temp_d_ch2 temp_d_ch6 temp_d_ch12 temp_d_ch17 d_owner_out d_owner_mort d_renter_social temp_d_deh_L temp_d_deh_M temp_d_deh_H d50 d55 d60 d65 d70 temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7 temp_dhe_1  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5"
foreach x of varlist $fixedcostx{
gen fixc_`x'=fixed_cost*`x'
local varlabel : var label `x'
label variable fixc_`x' "male fixed cost for labour#`varlabel'"
}
*generation of interactions with male leisure
global lx "hhcon_100 age_100 age2_10000 temp_n_ch temp_d_ch2 temp_d_deh_L temp_d_deh_M temp_d_deh_H temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7 d_owner_out d_owner_mort d_renter_social temp_hhsize d50 d55 d60 d65 d70 temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5"
foreach x of varlist $lx{
gen lei_`x'=leisure*`x'
local varlabel : var label `x'
label variable lei_`x' "male leisure#`varlabel'"
}

//social norm?
gen hrs_40=(lhw==40)
label var hrs_40 "1(male's weekly working hours=40)"

gen hrs_40plus=(lhw>=40)
label var hrs_40plus "1(male's weekly working hours>=40)"

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

add_partner_variables "liwwh_1 liwwh_2 liwwh_3 ln_liwwh hrs_40 hrs_40plus liwwh liwwh2 dgn dhe ils_dispy lhw leisure leisure2 lei_hhcon_100 lei_age_100 lei_age2_10000 lei_temp_n_ch lei_temp_d_ch2 lei_temp_d_deh_L lei_temp_d_deh_M lei_temp_d_deh_H lei_temp_region1 lei_temp_region2 lei_temp_region3 lei_temp_region4 lei_temp_region5 lei_temp_region6 lei_temp_region7 lei_d_owner_out lei_d_owner_mort lei_d_renter_social lei_temp_hhsize lei_d50 lei_d55 lei_d60 lei_d65 lei_d70 fixed_cost fixc_temp_n_ch fixc_temp_d_ch2 fixc_temp_d_ch6 fixc_temp_d_ch12 fixc_temp_d_ch17 fixc_d_owner_out fixc_d_owner_mort fixc_d_renter_social fixc_temp_d_deh_L fixc_temp_d_deh_M fixc_temp_d_deh_H fixc_d50 fixc_d55 fixc_d60 fixc_d65 fixc_d70 fixc_temp_region1 fixc_temp_region2 fixc_temp_region3 fixc_temp_region4 fixc_temp_region5 fixc_temp_region6 fixc_temp_region7 temp_d_deh_L temp_d_deh_M temp_d_deh_H  age_100 age2_10000 lowas les d_se d50 d55 d60 d65 d70 temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 lei_temp_dhe_1 lei_temp_dhe_2 lei_temp_dhe_3 lei_temp_dhe_4 lei_temp_dhe_5 fixc_temp_dhe_1  fixc_temp_dhe_2  fixc_temp_dhe_3 fixc_temp_dhe_4 fixc_temp_dhe_5"

rename partner_* sp_*  //just to make the names shorter      

label variable ils_dispy "male disposable income"

*change labels for the female partners ("male"-> "female")
foreach x of varlist liwwh_1 liwwh_2 liwwh_3 ln_liwwh hrs_40 hrs_40plus liwwh liwwh2 dgn dhe ils_dispy lhw leisure leisure2 lei_* fixed_cost fixc_* temp_d_deh_L temp_d_deh_M temp_d_deh_H age_100 age2_10000 temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 { 
local varlabel : var label `x'
label variable sp_`x' "fe`varlabel'"
}
lab var liwwh "male work history in months"
lab var sp_liwwh "female work history in months"

label variable sp_lei_age_100 "female leisure#female age/100"
label variable sp_lei_age2_10000 "female leisure#female age^2/10000"

label variable sp_hrs_40 "1(female's weekly working hours=40)"
label variable sp_hrs_40plus "1(female's weekly working hours>=40)"

//v2 update: generating interaction of leisure and sp_leisure
gen lei_sp_lei=leisure*sp_leisure
label variable lei_sp_lei "male leisure#female leisure"   
 
//to make some labels more clear
label variable lei_temp_d_deh_L "male leisure#male low education (up to lower secondary School; deh = 0-1)"
label variable lei_temp_d_deh_M "male leisure#male middle education (up to post secondary school; deh = 2-4)"
label variable lei_temp_d_deh_H "male leisure#male high education (higher education; deh = 5-6)"

label variable sp_lei_temp_d_deh_L "female leisure#female low education (up to lower secondary School; deh = 0-1)"
label variable sp_lei_temp_d_deh_M "female leisure#female middle education (up to post secondary school; deh = 2-4)"
label variable sp_lei_temp_d_deh_H "female leisure#female high education (higher education; deh = 5-6)"

lab var sp_lei_d50 "female leisure#1(female age>=50)"
lab var sp_lei_d55 "female leisure#1(female age>=55)"
lab var sp_lei_d60 "female leisure#1(female age>=60)"
lab var sp_lei_d65 "female leisure#1(female age>=65)"
lab var sp_lei_d70 "female leisure#1(female age>=70)"
                         
/*                                                          
preserve
keep if dgn==0
drop i_* //Stata refused to rename some of them probably because they are too long
drop tu_*
rename * sp_*
rename sp_temp_idorigpartner temp_idorigperson2 //for the purpose of merging with their male partners
gsort sp_temp_idorigperson2 sp_lhw //Place observations in ascending order of lhw within ascending order of person
bysort sp_temp_idorigperson2:egen sp_seq=seq() //give each working regime a label for the purpose
save IT_sp_output_wage`i',replace   //this file contains the female partners' information BUG:NO 0 working regime!!!(fixed)
restore

*=======================================================================
*           create combinations of hh labour supply regimes
*          (each line includes info of both partners in hh)
*=======================================================================
keep if dgn==1 //keep only male partners
expand 4														//4 choices	for each of the 4 regimes for male partners
sort _all														//sort to keep same order in seq()

bysort temp_idorigperson2 idperson lhw:egen sp_seq=seq()

merge m:1 temp_idorigperson2 sp_seq using IT_sp_output_wage1
keep if _merge==3 //keep only those whose partners' info is available in the data
*/
*-------------------------------------------------------------------------------------------------------------
*couples working regimes: lhw*sp_lhw (4*4=16 choices)
*-------------------------------------------------------------------------------------------------------------	
gsort temp_idorigperson2 lhw sp_lhw //Place observations in ascending order of lhw sp_lhw within ascending order of person
bysort temp_idorigperson2:egen temp_hh_alt=seq() //give each working regime a label for the purpose
//label var temp_hh_alt "household working regimes"
label var temp_hh_alt "weekly hours worked"

label define temp_lab_hh_alt 1 "(0,0)" 2 "(0,20)" 3 "(0,40)" 4 "(0,50)" ///
                             5 "(20,0)" 6 "(20,20)" 7 "(20,40)" 8 "(20,50)" ///
                             9 "(40,0)" 10 "(40,20)" 11 "(40,40)" 12 "(40,50)" ///
                            13 "(50,0)" 14 "(50,20)" 15 "(50,40)" 16 "(50,50)" 

/*
label define temp_lab_hh_alt 1 "(0,0)" 2 " (0,20)" 3 "(0,30)" 4 "(0,36)" 5 "(0,40)" ///
6 "(30,0)" 7 "(30,20)" 8 "(30,30)" 9 "(30,36)" 10 "(30,40)" ///
11 "(36,0)" 12 "(36,20)" 13 "(36,30)" 14 "(36,36)" 15 "(36,40)" ///
16 "(40,0)" 17 "(40,20)" 18 "(40,30)" 19 "(40,36)" 20 "(40,40)" ///
21 "(50,0)" 22 "(50,20)" 23 "(50,30)" 24 "(50,36)" 25 "(50,40)"
*/

label values temp_hh_alt temp_lab_hh_alt
keep if dgn==1
duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

drop if sp_dgn==.
duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

drop if sp_dgn==1  
duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

assert dgn==1 &sp_dgn==0 //assert partners are of different genders
bysort temp_idorigperson2: egen min_hhcon=min(hhcon)
drop if min_hhcon<=0                        //consumption is not allowed to be 0 or negative for lslogit

duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

gen sim_flag=0  //new in v8


save couples_wage`i',replace
}  //loop end for wage imputation method

log close
