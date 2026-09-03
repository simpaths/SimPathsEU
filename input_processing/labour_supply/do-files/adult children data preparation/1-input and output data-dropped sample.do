**************************************************************************
* 			Poland EM data (PL_2019_b3.txt data)
*       for adult children, split households, run EM
************************************************************************
/*This code extracts adult children who were excluded from the standard labour supply sample 
and prepares them as a separate estimation group */

global file_log="input_output_data-adult children"

global n_choices = 4           // 4 choices: no work, plus 3 hours brackets. 						   
global n_workchoices = $n_choices - 1     // 3 choices with positive supply of hours, 1 choice with 0 hours. 	

*HU 2018 hours discretisation 
*female
global min_hours_1_0 = 1		// min hrs for [1,39] 
global min_hours_2_0 = 40		// min hrs for [40,49]
global min_hours_3_0 = 41       // min hrs for [41,+∞)

*male
global min_hours_1_1 = 1		// min hrs for [1,39]  
global min_hours_2_1 = 40		//  min hrs for [40,49]
global min_hours_3_1 = 41       // min hrs for [41,+∞)


cd "$local_data"
pwd

*version 13
capture log close
log using "$file_log", replace

clear all
set seed 1																//same seed gives same results	


use beforeReshape.dta, clear

keep temp_idorigperson2 
rename temp_idorigperson2 idperson
//try changing "double" to "long" for idperson
gen long idperson2=idperson
drop idperson
rename idperson2 idperson

/*afterheckman.dta contains everyone remaining after all the sample trimming for the standard model.
We merge adult children (beforeReshape) with afterheckman.
We keep only the individuals who appear in afterheckman but NOT in beforeReshape.
These are exactly the individuals:
… who were dropped from your standard LS model
… but still exist in the overall survey */
merge 1:1 idperson using afterheckman  
assert _merge!=1  //beforeReshape sample is a subsample of afterheckman
keep if _merge==2  //keep only those obs dropped from the std model
drop _merge

duplicates report idperson  //count how many unique individuals there are
//21041 obs 

//fre temp_adultchildflag


*add the hh split code here 
*=======================================================================
*           Household composition
*=======================================================================
gen long temp_before_idperson=idperson		 			//save id's before the artificial hh split. 
gen long temp_before_idpartner=idpartner
gen long temp_before_idhh=idhh
gen long temp_before_idmother=idmother
gen long temp_before_idfather=idfather
	format temp_before_id*  %20.0g
	format id*  %20.0g
	format temp_before_id*  %20.0g
	format id*  %20.0g
assert idperson==idorigperson  //this is not the same as UK
keep if idperson == idhh * 100 + mod(idorigperson,idhh*100)  //0 obs dropped
	*------------------------------------------------------------------------------------------------------
	* "Adjust" households: each household will only be comprised of one or two partners (male and female), and their children 
	* dgn: 0 (female); 1 (male)
	* Same-sex partners are temporarily assigned “virtual” genders so that EUROMOD can treat the pair as a male–female couple.
	*------------------------------------------------------------------------------------------------------
	// count same-sex partner
	add_partner_variables "dgn"
	tab dgn partner_dgn, m
	
	// assign "virtual" sex to same-sex partners (first record: male; second record: female)

	* female senior partner turned into "virtual" male
	gen dgn2 = 1 if dgn == 0 & partner_dgn == 0 & idperson < idpartner
	add_mother_variables "dgn2" 
	replace dgn = 1 if dgn2 == 1
	replace idfather = idmother if mother_dgn2 == 1   // these are the mothers who have been turned into "virtual" males
	replace idmother = 0 		if mother_dgn2 == 1
	drop mother_dgn2
	drop dgn2
	
	* male junior partner turned into "virtual" female
	gen dgn2 = 0 if dgn == 1 & partner_dgn == 1 & idperson > idpartner		
	add_father_variables "dgn2"
	replace dgn = dgn2 if dgn2 == 0
	replace idmother = idfather if father_dgn2 == 0   // these are the fathers who have been turned into "virtual" females
	replace idfather = 0 		if father_dgn2 == 0
	drop father_dgn2
	drop dgn2
	
	drop partner_dgn
	
	// check no more same-sex partners
	add_partner_variables "dgn"
	assert dgn != partner_dgn if dgn!=.  //added "if dgn!=."
	drop if dgn==.  //added
	drop partner_dgn
	
	// check fathers are males and mothers are females
    add_father_variables "dgn"
	add_mother_variables "dgn"
	assert father_dgn != 0
	assert mother_dgn != 1
	drop father_dgn mother_dgn
	
	// check that parents' id are within the household
	gen long idhh_father = floor(idfather/100)
	gen long idhh_mother = floor(idmother/100)
	assert idhh_father == idhh if idhh_father != 0
	assert idhh_mother == idhh if idhh_mother != 0
	drop idhh_father idhh_mother 
	
	// assert rule for creating idperson
	drop if idhh==.  //added
	//assert idperson == idhh * 100 + idorigperson  //this rule is for UK
	assert idperson == idhh * 100 + mod(idorigperson,idhh*100)
	
	scalar lambda = 10000000
	gen long new_idhh = idhh
	gen long new_idperson = idperson
	gen long new_idpartner = idpartner
	gen long new_idmother = idmother
	gen long new_idfather = idfather
	format id* new_* %12.0g
	
	// single individuals aged 16+ (anyone aged >= 16 whose idpartner=0 forms a new household on his/her own)
	gen byte d_single = (dag >= 16 & idpartner == 0 )
	replace new_idhh = lambda + idperson if d_single //new_idhh created for those with idpartner=0
	replace new_idperson = new_idhh * 100 + idorigperson if d_single  //corresponding idperson for those with idpartner=0
	replace new_idmother = 0 if d_single  //because they are 16+
	replace new_idfather = 0 if d_single  //because they are 16+
	*Note that new_idpartner does not need to be changed for singles because they are equal to the old idpartner which is 0.
	drop d_single 
	
	// males in couples aged 16+ ... (anyone aged >= 16 whose idpartner>0 forms a new household with his/her partner)
	gen byte d_malepartner = (dag >= 16 & idpartner > 0 & dgn == 1)
	replace new_idhh = lambda + idperson if d_malepartner     //new_idhh created for male partners
	replace new_idperson = new_idhh*100+idorigperson if d_malepartner    //corresponding new_idperson for male partners
	* new_idpartner will be imputed below (female id have not been reset yet)
	replace new_idmother = 0 if d_malepartner  //because they are 16+
	replace new_idfather = 0 if d_malepartner  //because they are 16+
	
	// ... and their female partners
	add_partner_variables "new_idhh new_idperson"   // first round: impute the new ids of the male partners to their female partners
	gen byte d_femalepartner = (dag >= 16 & idpartner > 0 & dgn == 0)
	replace new_idhh = partner_new_idhh if d_femalepartner  //new_idhh=new_idhh of their partners
	replace new_idperson = new_idhh * 100 + idorigperson if d_femalepartner //corresponding new_idperson for female partners
	replace new_idpartner = partner_new_idperson if d_femalepartner
	replace new_idmother = 0 if d_femalepartner  //because they are 16+
	replace new_idfather = 0 if d_femalepartner  //because they are 16+
	drop d_femalepartner
	drop partner_new*
	
	// now that female partners have their new id, this can be imputed to their male partners
    add_partner_variables "new_idperson"   // second round: impute the new ids of the female partners to their male partners
	replace new_idpartner = partner_new_idperson if d_malepartner
	drop d_malepartner
	drop partner_new*
	
	**Note: Up to this point, everyone aged >=16 (whether have a partner or not) has 
	**been assigned a new_idhh, new_idperson,new_idpartner, new_idmother, new_idfather.
	
	// add dependent children (<16) to their father's hh if no mother
	add_father_variables "new_idhh new_idperson"	
	gen byte d_childfather = (dag < 16 & idfather > 0 & idmother == 0)  //children who have a father but no mother
	replace new_idhh = father_new_idhh if d_childfather  //assgin new_idhh of their father to them
	replace new_idperson = new_idhh * 100 + idorigperson if d_childfather  //corresponding new_idperson for these children
	replace new_idfather = father_new_idperson if d_childfather	  //corresponding new_idfather
	drop d_childfather
	
	// add dependent children (<16) to their mother's hh, if any
	add_mother_variables "new_idhh new_idperson"	
	gen byte d_childmother = (dag < 16 & idmother > 0)  //children who have a mother (whehter have a father or not)
	replace new_idhh = mother_new_idhh if d_childmother   //assgin new_idhh of their mother to them (overwritten for those children have both parents)
	replace new_idperson = new_idhh * 100 + idorigperson if d_childmother
	replace new_idfather = father_new_idperson if d_childmother
	replace new_idfather = 0 if new_idfather == .		// children with no father have missing father_new_idperson
	replace new_idmother = mother_new_idperson if d_childmother  //corresponding new_idmother
	drop d_childmother
	
	**Note: Up to this point, everyone aged <16 has 
	**been assigned a new_idhh, new_idperson,new_idpartner, new_idmother, new_idfather.

	// repeat for children of under-age fathers (eg. idhh == 661)
	drop father_new*
	add_father_variables "new_idhh new_idperson"	
	gen byte d_childfather = (dag < 16 & idfather > 0 & idmother == 0)
	replace new_idhh = father_new_idhh if d_childfather
	replace new_idperson = new_idhh * 100 + idorigperson if d_childfather
	replace new_idfather = father_new_idperson if d_childfather	
	drop d_childfather
	
	// repeat for children of under-age mothers (eg. idhh == 661)
	drop mother_new*
	add_mother_variables "new_idhh new_idperson"	
	gen byte d_childmother = (dag < 16 & idmother > 0)
	replace new_idhh = mother_new_idhh if d_childmother
	replace new_idperson = new_idhh * 100 + idorigperson if d_childmother
	replace new_idfather = father_new_idperson if d_childmother
	replace new_idfather = 0 if new_idfather == .		// children with no father have missing father_new_idperson
	replace new_idmother = mother_new_idperson if d_childmother
	drop d_childmother
	
	drop father_new* mother_new*

	// drop dependent children (<16) with no mother nor father
	drop if dag < 16 & idmother == 0 & idfather == 0 //(15 observations deleted)

	
	replace idhh = new_idhh
	replace idperson = new_idperson
	replace idpartner = new_idpartner
	replace idpartner = 0 if idpartner == .
	replace idmother = new_idmother
	replace idfather = new_idfather
	drop new_*
	drop if idperson==.  //added
	duplicates report idperson  //no duplicate
	
	assert idfather>0 | idmother>0 if dag<16
	assert idfather==0 if dag>16


/*------------------------------------------------------------CHECK below
This code sorts households into:
Singles households
→ exactly one flexible adult (lone parent or single adult)
Couples households
→ exactly two flexible adults (couple)
Households that should be dropped
→ households with no flexible adults (students, children, non-participants)
It also performs consistency checks to ensure no impossible households exist (e.g. households with both singles and couples, or >2 flexible workers).
*/

bysort idhh: egen temp_with_singles=total(temp_singles), missing  //missing as 0
replace temp_with_singles=(temp_with_singles>0)   //dummy of at least one family member is "singles"

bysort idhh: egen temp_with_couples=total(temp_couples), missing
replace temp_with_couples=(temp_with_couples>0)   //dummy of at least one family member is "couples"
count if temp_singles==1 & temp_n_ch>0 //332 obs 

//check whether a not flexible individual can have temp_with_couples=1 and temp_with_singles=1 at the same time : no such cases 
su dag if temp_with_singles==1 &temp_with_couples==1 &temp_not_flexible==1  //they are <16 and either pre-school or student
tab les if temp_with_singles==1 &temp_with_couples==1 &temp_not_flexible==1  //they are <16 and either pre-school or student
***
su temp_singles temp_couples temp_not_flexible if temp_with_singles==1 &temp_with_couples==1  //this shows singles, couples, and not flexible individuals can all live together

count if temp_with_singles==1 &temp_with_couples==1  //0 obs

//count if there are more than one flexible workers (lone parent+child aged between 16 and 18 and not student) in a "singles"' household
gen worker_count=(temp_not_flexible==0)
bysort idhh: egen number_workers_singleshh=total(worker_count) if temp_singles==1, missing
su number_workers_singles
count if number_workers_singleshh>1 & temp_singles==1   //0 obs
//duplicates report idhh if number_workers_singleshh>1 & temp_singles==1  

//check there are no more than TWO flexible workers in a "COUPLES"' household
bysort idhh: egen number_workers_coupleshh=total(worker_count) if temp_couples==1, missing
su number_workers_couples
count if number_workers_coupleshh>2 & temp_couples==1   //0 obs
drop if number_workers_coupleshh>2 & temp_couples==1 //new in "using original hhs"
drop if number_workers_coupleshh<2 & temp_couples==1 //0 obs dropped 
assert number_workers_coupleshh==2 if temp_couples==1

duplicates report idperson  //count how many unique individuals there are

count if temp_p_student //16 obs 
//dropping
drop if temp_with_singles==1 &temp_with_couples==1  //0 obs dropped
duplicates report idperson  //count how many unique individuals there are

*Given the no. of hhs (lone parent+child aged between 16 and 18 and not student) is small, drop them
drop if number_workers_singleshh>1 & temp_singles==1   //0 obs dropped
duplicates report idperson  //count how many unique individuals there are

assert number_workers_singles==1 if temp_singles==1
drop worker_count number_* //22/1/2021
gen temp_alt_n=(temp_with_singles==1 & temp_with_couples==0) //dummy of individuals that should have n alternatives
gen temp_alt_nsq=(temp_with_couples==1)   //dummy of individuals that should have n^2 alternatives
gen temp_drop=(temp_with_singles==0 & temp_with_couples==0)  //dummy of individuals that can be dropped from EUROMOD input data because they are neither singles nor couples and do not live with singles or couples
assert temp_not_flexible==1 if temp_drop==1  //check that all individuals who will be dropped are not flexible
assert temp_alt_n+temp_alt_nsq+temp_drop==1

*=======================================================================
*           Labour supply alternatives
*=======================================================================
drop if temp_drop==1  //to reduce the burden of EUROMOD
duplicates report idperson  //count how many unique individuals there are

* create columns with imputed alternatives (same for everyone who is labour supply flexible)
foreach gender in 0 1{
local i = 0
levelsof temp_lhw_dobs_`gender', local(levels)
foreach l in `r(levels)' {
	gen byte temp_lhw_dobs_`gender'_`i' =  `l' if temp_not_flexible==0
	local i = `i' + 1
}  //loop end of ls alternatives `i'
}  //loop end of gender `gender'
sum temp_lhw_dobs_*

/*
forvalues i = 1 (1) $n_workchoices{
	assert lhw != .
	replace temp_bracket = `i' if lhw > $min_hours_`i'
}
*/

* choice set: generation of $n_choices^2 columns
// first index refers to male choice, second index refers to female choice
// note: couples (both partners flexible) have access to all $n_choices^2 options, 
// note: Although "singles" have access only to $n_choices options, I replicate these $n_choices across all choices of their partners.
// note: not flexible individuals' all options =0 hrs 
// Due to the way to construct fake id* to cheat EUROMOD, the treatment to "singles" and not flexible individuals is only for the purpose of linking with flexible people in the same hh 
// to provide info for EUROMOD.
forvalues m=0/$n_workchoices  {
	forvalues f=0/$n_workchoices  {
	
		capture drop lhw_`m'`f'
		gen byte lhw_`m'`f' = .
		replace lhw_`m'`f'=0 if temp_not_flexible==1  //both genders of not flexible individuals
		// males
		replace lhw_`m'`f' = temp_lhw_dobs_1_`m' if dgn == 1 & (temp_couples==1 |temp_singles==1) 		 //male partner in flexible couples	and male individuals in "singles"	 
		
		// females
		replace lhw_`m'`f' = temp_lhw_dobs_0_`f' if dgn == 0 & (temp_couples==1 |temp_singles==1)  		 //female partner in flexible couples and female individuals in "singles" 	 
	}
}


* choice conversion
// for flexible couples, flag for choice_`m'`f' is switched on only when the male partner chooses `m' and the female partner chooses `f'
// for second type of "singles", the inflexible partner always chooses 1st bracket (ie. 0 hours)
// for first type of "singles" (without a partner), we assume that their virtual partner chooses 1st bracket (ie. 0 hours).
// first index refers to male choice, second index refers to female choice

	    add_partner_variables  "temp_bracket_0 temp_bracket_1 dgn"
		replace partner_temp_bracket_0 = 0 if idpartner>0 &partner_dgn==0 &(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0) //second type of "singles"' partner must not work
		replace partner_temp_bracket_1 = 0 if idpartner>0 &partner_dgn==1 &(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0) //second type of "singles"' partner must not work


forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
		gen byte temp_choicehh_`m'`f' = .
		// males
		replace temp_choicehh_`m'`f' = (temp_bracket_1 == `m' & partner_temp_bracket_0 == `f') 	if dgn == 1 & temp_couples==1  	 //male partner in flexible couples
		replace temp_choicehh_`m'`f' = (temp_bracket_1 == `m') 							if dgn == 1 & temp_singles==1 & `f' == 0   	//male "singles"
		// females
		replace temp_choicehh_`m'`f' = (temp_bracket_0 == `f' & partner_temp_bracket_1 == `m') 	if dgn == 0 & temp_couples==1  	 //female partner in flexible couples
		replace temp_choicehh_`m'`f' = (temp_bracket_0 == `f') 							if dgn == 0 & temp_singles==1 & `m' == 0   	//female "singles"
	}
}


drop partner_temp_bracket* 

*------------------------------------------------------------
* Earnings
*------------------------------------------------------------	
cap drop yem yse 
gen yem = yempj + yemtj
gen yse = yseag + ysebs
gen temp_em=(yem>yse |(yem==yse & yem!=0))  //assign income to be employed income or self-employed income depending on whether yem>=yse for workers
gen temp_se=(yse>yem)   //assign income to be employed income or self-employed income depending on whether yem>yse for workers

assert temp_em==(1-temp_se) if yem!=0|yse!=0 //checking that non-zero hours working regimes either belong to temp_em or temp_se category
gen temp_nonworker=(yem==0 & yse==0)
assert (temp_em+temp_se+temp_nonworker==1) //checking that all regimes belong to one of the following: temp_em, temp_se, temp_nonworker
//for workers' all states, assume all income are employed income or self-employed income depending which is their major income source in their actual state

forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
gen yem_`m'`f' = .
gen yse_`m'`f' = .

replace yem_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_em==1		   
replace yse_`m'`f'=0 if temp_em==1 

replace yse_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_se==1                     
replace yem_`m'`f'=0 if temp_se==1 

// for non-workers' counterfacual states, assume all income are employed income
replace yem_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_nonworker==1	
replace yse_`m'`f'=0 if temp_nonworker==1	
  }
}
gen temp_yem=yem
gen temp_yse=yse
drop yem yse
*NOTE: for both the actual and counter-factural states, yem and yse are computed using wage*discretised hours of work. This now holds automatically because wage is generated as income/discritized hours


*-----------------------------------------------------------------------------------
* Generation of new identifiers for each LS alternative
*-----------------------------------------------------------------------------------
/*
foreach var in idhh idperson idpartner idfather idmother {
	capture drop `var'*
}
*/
forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
		foreach var in idhh idperson idpartner idfather idmother  {
			gen double `var'_`m'`f' = `var' * 100 + `m'*10 + `f'  //fake id to cheat EUROMOD
			replace `var'_`m'`f' = 0 if `var' == 0
		}
	}
}

*check idperson identifies persons uniquely
duplicates r idperson
gen double temp_idorigperson2=idperson		 			//save original id. idorigperson (within hh id) already existed and not the same as idperson
gen temp_idorigpartner=idpartner
gen temp_idorighh=idhh
gen temp_idorigmother=idmother
gen temp_idorigfather=idfather
drop idperson idpartner idhh idmother idfather

format temp_id* %15.0g 
duplicates r temp_idorigperson2
/*
foreach var of varlist idhh idperson idpartner idfather idmother lhw yem yse {
	quietly rename `var' obs_`var'
}

*/
preserve
drop idhh_* idperson_* idpartner_* idfather_* idmother_*  lhw_* yem_* yse_* temp_choicehh_*
save full_info-dropped_sample,replace
restore
save beforeReshape-dropped_sample.dta,replace


*=======================================================================
*            Reshaping data 
*=======================================================================

use beforeReshape-dropped_sample.dta, clear

keep  temp_idorigperson2 idhh_* idperson_* idpartner_* idfather_* idmother_*  lhw_* yem_* yse_* temp_choicehh_*

local reshapevbles = "idhh_ idperson_ idpartner_ idfather_ idmother_  lhw_ yem_ yse_ temp_choicehh_"
reshape long `reshapevbles', i(temp_idorigperson2) j(temp_option) string

duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

format id* %20.0g 
		foreach var in idhh idperson idpartner idfather idmother  lhw yem yse temp_choicehh  {
		rename `var'_ `var'
}
duplicates report idperson	// no duplicates
duplicates report idhh		

merge m:1 temp_idorigperson2 using full_info-dropped_sample
assert _merge==3
drop _merge
gen ind_option = substr(temp_option,1,1) if dgn==1  //alternative bracket for individual male
replace ind_option = substr(temp_option,2,1) if dgn==0 //alternative bracket for individual female
destring ind_option, replace

gen temp_choice=(ind_option==temp_bracket_0) if dgn==0  //dummy for female individual choice
replace temp_choice=(ind_option==temp_bracket_1) if dgn==1  //dummy for male individual choice
drop ind_option

destring temp_option, gen (temp_seq)
//check data structure 
gsort temp_idorigperson2 temp_seq //Place observations in ascending order of temp_seq within ascending order of original person id
bysort temp_idorigperson2:egen temp_seq2=seq() //give each working regime a label from 1 to $n_choice^2
assert lhw==0 if temp_not_flexible==1  //not flexible persons should have zero hours of work

bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices)^2 if temp_couples==1 //for an individual in a flexible couple, 1 option is chosen from ($n_choices)^2 options
assert mean_choicehh==1/($n_choices) if temp_singles==1  //for an individual in "singles", 1 option is chosen from $n_choices options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1|temp_couples==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation
drop mean_choicehh

assert temp_choicehh!=. if temp_couples==1
assert temp_choicehh==. if temp_not_flexible==1
//note: for each individual in "singles", $n_choices out of $n_choices^2 temp_choicehh are non-missing

gen count=1 
bysort temp_idorigperson2: egen sum_option=total(count)  //compute the sum of options
assert sum_option==$n_choices^2   //up to this point, every individual has $n_choices^2 alternatives
drop count sum_option


//update in v8
drop if temp_choicehh==. & temp_singles==1   //drop invalid rows for singles
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

bysort idhh: egen temp_with_singles2=total(temp_singles)  //the previously generated temp_with_singles may not be useful because up to this point some singles are dropped already 
drop if temp_with_singles2==0 & temp_with_couples==0 & temp_not_flexible==1  //delete not flexible people with no singles or couples to attach to
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

gen count=1
bysort temp_idorigperson2: egen sum_option=total(count)  //compute the sum of options

assert sum_option==$n_choices^2 if temp_alt_nsq==1  //yes
assert sum_option==$n_choices if temp_alt_n==1  
su temp_alt_nsq temp_with_singles temp_with_couples if temp_not_flexible==1
drop count sum_option
//check again
assert temp_choicehh!=. if temp_couples==1
assert temp_choicehh!=. if temp_singles==1  //this is new because now singles only have $n_choices kept, solved-contradiction: all aged 16,17,temp_alt_nsq==1, having 12 choices
assert temp_choicehh==. if temp_not_flexible==1

*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
* Correct values for benefits 1/2
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(A) @@@
/*SIMULATED BENEFITS:
Do not worry about them as EUROMOD calculates
the right amount in all choices, given other variables are set correctly.

*the code below is not relevant for PL 
*Notes about bunct_s (unemployment benefit (JSA)): PARTLY SIMULATED, i.e. IT IS SIMULATED BUT THE SIMULATION TAKES SOME VALUES FROM THE DATA. YOU CAN CONSIDER THAT AS "SIMULATED"
//check which variables are used to simulate and manipulate those variables rather than the bunct_s per se, to make bunct_s=0:
preserve
keep id* les bunct
rename les temp_les
rename bunct temp_bunct
save les_bunct,replace //store the original les and bunct for future use if needed
restore
replace les=5 if temp_singles==1|temp_couples==1
replace bunct=0 if temp_singles==1|temp_couples==1
*/

// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B1) @@@
/*BENEFITS NOT SIMULATED, COMPATIBLE WITH A WORKING CONDITION BUT DEPEND ON YEM\LHW:
Set them to zero (Otherwise they are positive only in the observed choice and not modelled in the other choices, 
and this creates a bias in the estimates of the utility function).*/
/*Italy 
drop if (bmals>0|bmase>0)& lhw==0 & (temp_singles==1|temp_couples==1) // bmals:Maternity payments (lump sum); bmase:Maternity payments (only self emp).
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

replace bsa00=0 if temp_singles==1|temp_couples==1   //Social assistance(Minimum Insertion Income )
replace bsa01=0 if temp_singles==1|temp_couples==1   //Social assistance (Basic Needs Debit Card )
*/
/*UK
replace bot=0 if temp_singles==1|temp_couples==1   //other benefits
drop if (bmaer>0|bmana>0)& lhw==0 & (temp_singles==1|temp_couples==1) // bmaer: Statutory maternity pay; bmana: Maternity Allowance (Only 40 obs are dropped from the original whole sample)
*Notes about maternity leave:
// Assume that one who receives at least one of the these benefits (Statutory maternity pay (bmaer) or Maternity Allowance (bmana)) 
//as being on maternity leave but think of them as “working”.
*/

/*DP: No such benefits in HU (materinity ones are simulated)*/

/*PL: 
fre bcc	//Supplement to the family allowance for parents who take unpaid childcare leave to care for a young child.
fre bchunlp //benefit for unemployed lone parents
fre bma	//Maternity allowance
fre ysv	//severance payment
*/
foreach var in bcc bchunlp bma ysv {
replace `var'=0 if temp_singles==1|temp_couples==1   
} 
/*(488 real changes made)
(0 real changes made)
(4,236 real changes made)
(20 real changes made)
*/

// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B2) @@@
/*BENEFITS NOT SIMULATED, NOT COMPATIBLE WITH A WORKING CONDITION AND DO NOT DEPEND ON YEM\LHW:
Set them equal to the amount in the observed choice.*/
/* HU: 
bed: education related income (oktatással kapcsolatos támogatás)
bho: housing benefit
botre: other regular benefits - N/A in the dataset 
bfaot: other family benefits (includes maternity allowance, child care fee and nursing fee) - N/A in the dataset 
*/

/*PL: 
fre bsaot //neither permanent nor temporary social assistance ==> granted once or occasionally for specific urgent needs
fre bed	//scholarships
*/
cap drop mean_*
foreach var in bed bsaot { 
bysort temp_idorigperson2: egen mean_`var'=mean(`var')
//assert `var'==mean_`var'  //make sure `var' is equal to the amount in the observed choice
assert abs(`var' - mean_`var') <= 0.1 
drop mean_`var'
}
 
// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B3) @@@
/*
BENEFITS NOT SIMULATED, NOT COMPATIBLE WITH A WORKING CONDITION AND AN INDIVIDUAL RECEIVES THEM IN THE OBSERVED CHOICE (E.G. A DISABILITY BENEFIT):
Exclude this individual from the sample used for labour supply estimates because it means that, in the observed choice, the individual
has some charateristics incompatible with a working condition
*/
/* Italy 
drop if bunct01>0 & (temp_singles==1|temp_couples==1)  //Unemployment benefit (Cassa Integrazione Guadagni)
drop if bunct02>0 & (temp_singles==1|temp_couples==1)  //Unemployment benefit (Indennita' di Disoccupazione - Mobilita')
drop if bunst>0 & (temp_singles==1|temp_couples==1)  //Unemployment benefit s.t. training
drop if yunsv>0 & (temp_singles==1|temp_couples==1)  //Severance pay (Liquidazioni da lavoro - TFR)
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)
*/
/*UK
drop if bedes>0 & (temp_singles==1|temp_couples==1) //Student payments
drop if bedsl>0 & (temp_singles==1|temp_couples==1) //Student Loan
drop if bdioa>0 & (temp_singles==1|temp_couples==1) //Attendance allowance
drop if bdisc>0 & (temp_singles==1|temp_couples==1) //Disability living allowance
drop if bdimb>0 & (temp_singles==1|temp_couples==1) //Disability living (mobility) allowance
drop if bdiscwa>0 & (temp_singles==1|temp_couples==1) //PIP living allowance
drop if bdimbwa>0 & (temp_singles==1|temp_couples==1) // PIP mobility

drop if bdict0117>0 & (temp_singles==1|temp_couples==1) //Incapacity Benefit 2017
drop if bdict0118>0 & (temp_singles==1|temp_couples==1) //Incapacity Benefit 2018
drop if bdict0217>0  & (temp_singles==1|temp_couples==1) //Contributory ESA 2017
drop if bdict0218>0  & (temp_singles==1|temp_couples==1) //Contributory ESA 2018

drop if bdiwi>0 & (temp_singles==1|temp_couples==1) //Industrial injuries pension
drop if bcrdi>0 & (temp_singles==1|temp_couples==1) //Invalid care allowance
drop if bdisv>0 & (temp_singles==1|temp_couples==1) //Severe disablement allowance
drop if bhlwk>0 & (temp_singles==1|temp_couples==1)  //Statutory sick pay
drop if buntr>0 & (temp_singles==1|temp_couples==1) //Training allowance
*/

/*HU: only pdi - disability pension -  could be classified as such  
drop if pdi>0 & (temp_singles==1|temp_couples==1) */

/*PL: all pensions are compatible with working condition but their earnings are (strictly) limited and may affect their pension. Not sure how to account for that because they are not simulated.  
==> opted for removing people on disability pensions completely 
fre pdi00 //Disability pension (agricultural and non-agricultural)
fre pdinw //Social pension
fre poa00 //Retirement pension (agricultural and non-agricultural)
fre poafr //Farmer's structural pension
fre poaot //pension : old age : other
fre psu00 //Survivors pension (agricultural and non-agricultural)
fre pyr	//Pre-retirement allowance and benefit
*/
drop if pdi00>0 | pdinw>0 & (temp_singles==1|temp_couples==1) //(5,896 observations deleted)
 
//////////////////////////////////////////////////////////////
//Now after benefit correction, check data structure again  //
//////////////////////////////////////////////////////////////
gen d=1
bysort temp_idorigperson2: egen count=total(d)
su count
drop if count!=($n_choices)^2 &temp_alt_nsq==1
drop if count!=($n_choices) &temp_alt_n==1

duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) //

drop d count
gsort temp_idorigperson2 temp_seq //Place observations in ascending order of temp_seq within ascending order of original person id
assert lhw==0 if temp_not_flexible==1  //not flexible persons should have zero hours of work

bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices)^2 if temp_couples==1 //for an individual in a flexible couple, 1 option is chosen from ($n_choices)^2 options
assert mean_choicehh==1/($n_choices) if temp_singles==1  //for an individual in "singles", 1 option is chosen from $n_choices options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1|temp_couples==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation

drop mean_choicehh

/*
//@@@ tax compliance assumption #1@@@
//assume full tax compliance, set yseev and ysenr to 0 and hence set TCA off in EUROMOD
//NOTE: an additional step to finish this assumption is to set TCA off which means adding -extSwitch "TCA=off" in the command to run EUROMOD later
//      Without this additional step, EUROMOD will still keep the defualt setting, i.e. TCA is on. 
//replace yseev=0 
//replace ysenr=0

//@@@ tax compliance assumption #2@@@
//assume no full tax compliance, fill in yseev, ysenr
//replace yseev=0.5*yse  //50% SE income reported to tax authority under no full tax compliance
//replace ysenr=0.5*yse  //50% SE income not reported to tax authority under no full tax compliance
gen ratio_yseev=yseev/(yseev+ysenr)   //this is how the ratio of total se income reported to tax authority (assume this to be the same in every alternative for the same individual)
gen ratio_ysenr=ysenr/(yseev+ysenr)   //this is how the ratio of total se income not reported to tax authority (assume this to be the same in every alternative for the same individual)
replace yseev=ratio_yseev*yse if yseev!=0|ysenr!=0
replace ysenr=ratio_ysenr*yse if yseev!=0|ysenr!=0
assert yseev!=.
assert ysenr!=.
*/

*------------------------------------------------------------
* Store information not for EUROMOD for later use
*------------------------------------------------------------	

preserve
keep id* temp*
save temp_file-dropped_sample.dta, replace
restore

/*VERY IMPORTANT: PL model does not use yem and yse as other models do. PL splits these income by type because different tax regimes are applied to different types of earnings  
This needs to be chnaged before data enters the model otherwise there will be no diferences in earnings by alternatives */
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
foreach var in yempj yemtj yseag ysebs {
gen temp_`var'= `var'
} //save original values 

cap drop yempj yemtj
gen yempj = 0
replace yempj = yem if temp_yempj>0 & temp_yemtj==0
gen yemtj = 0
replace yemtj = yem if temp_yempj==0 & temp_yemtj>0

cap drop yseag ysebs 
gen yseag = 0
replace yseag = yse if temp_yseag>0 & temp_ysebs==0
gen ysebs = 0
replace ysebs = yse if temp_yseag==0 & temp_ysebs>0 
*end of correction 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

save individuals-dropped_sample.dta,replace

*=======================================================================
*           create EUROMOD input data
*=======================================================================
*----------------------------------------------------------------------------------------------------
* singles_wage1.dta as input data(Predicted wage for everyone), but not in the EM input folder yet
*-----------------------------------------------------------------------------------------------------	
use individuals-dropped_sample,clear
drop temp*             //This is because as per EUROMOD conventions, some variables should not appear in the input database.
sort idhh idperson
//drop number* ratio* partner_dgn
drop  partner_dgn //ratio*
drop _est_heckman_*
save individuals_wage1-dropped_sample.dta, replace

*-------------------------------------------------------------------------------------------------------------
* singles_wage2.dta as input data(Predicted wage for non-workers only), but not in the EM input folder yet
*-------------------------------------------------------------------------------------------------------------	
use individuals-dropped_sample,clear

***************************************************
*// @@@ WAGE IMPUTATION METHOD #wage2@@@
* make predicted wage=yivwg only for non-workers 
*(before this yivwg=predicted wage for everyone)
****************************************************	
replace yivwg=temp_obs_wage if temp_em==1|temp_se==1 //for workers used for the Heckman estimation, wages=actual wages
/*
//for workers' all states, assume all income are employed income or self-employed income depending which is their major income source in their actual state

replace yem=yivwg*lhw*4.3 if temp_em==1		   
replace yse=0 if temp_em==1 

replace yse=yivwg*lhw*4.3 if temp_se==1                     
replace yem=0 if temp_se==1 

// for non-workers' counterfacual states, assume all income are employed income
replace yem=yivwg*lhw*4.3 if temp_nonworker==1	&temp_choice==0  
*/

/*VERY IMPORTANT: here's an additional correction of earnings specific for PL model */
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//for workers' all states, assume all income are employed income or self-employed income depending which is their major income source in their actual state
replace yempj=yivwg*lhw*4.3 if temp_em==1 &  yempj>0
replace yemtj=yivwg*lhw*4.3 if temp_em==1 &  yemtj>0
replace yseag=0 if temp_em==1 
replace ysebs=0 if temp_em==1 

replace yseag=yivwg*lhw*4.3 if temp_se==1 & yseag>0                 
replace ysebs=yivwg*lhw*4.3 if temp_se==1 & ysebs>0  
replace yempj=0 if temp_se==1 
replace yemtj=0 if temp_se==1 

// for non-workers' counterfacual states, assume all income are employed income
replace yempj=yivwg*lhw*4.3 if temp_nonworker==1	&temp_choice==0 
replace yemtj=yivwg*lhw*4.3 if temp_nonworker==1	&temp_choice==0  
*end of correction 
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////


drop temp*                                                 //This is because as per EUROMOD conventions, some variables should not appear in the input database.
sort idhh idperson

save individuals_wage2-dropped_sample.dta, replace

*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
* Correct values for benefits 2/2
*To be precise, no actual correction is done here, the point is to replicate benefits to 
*all alternatives to make a data set called special_partners.dta,
*and append this to the "singles" to make EUROMOD input data
// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #1 @@@
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

*loop through wage1, wage2:export as em input file, then run EM, then save output in the result folder for labour supply estimation, 
*named "IT_individuals_output_wage`i'"

foreach i in 1 2{ 
//local i=1
use individuals_wage`i'-dropped_sample,clear
export delimited "$em_input\$file_input.txt", replace nolabel delim(tab) //create input data for EUROMOD
sort idhh
format id*  %20.0g
drop ch*
************************************************************
*						Run EUROMOD with Stata
************************************************************
version 13
* Call EUROMOD 

capture erase "${em_output}\$file_output.txt"        //erase previous output file, this is done in case EUROMOD call from Stata fails, to be sure we are not opening an early run of the model
                                            
shell "${em_exe}" -emPath "${em_models}" -sys PL_2018 -data PL_2019_b3  -forceOutputInEuro //call EUROMOD 1:Program to call 2: path for folder 3: system name 4: dataset to use

*import EUROMOD RUN

import delimited "${em_output}\$file_output.txt", clear                                                            //import data from txt file in output folder 
save individuals_output_wage`i'-dropped_sample,replace

}


log close
