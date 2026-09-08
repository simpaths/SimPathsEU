**************************************************************************
* 			Poland EM data (PL_2019_b3.txt data)
*run EM to get the ils_dispy for sample of couples resulting from a 10% increase in gross wage 
************************************************************************

global file_log="${log}/EM_couples_elast"

cd "$local_data"

capture log close
log using "$file_log", replace
pwd

global n_choices = 4           // 4 choices: no work, plus 3 hours brackets. 						   
global n_workchoices = $n_choices - 1     // 3 choices with positive supply of hours, 1 choice with 0 hours. 	

foreach i in 1 2{   //loop begin for wage imputation method 
//local i=1  //only for wage1
foreach gender in 0 1{
use individuals_wage`i',clear
merge 1:1 idperson using temp_file.dta												//add additional information
drop _merge
keep if temp_alt_nsq==1  //reduce EUROMOD burden
replace yivwg=1.1*yivwg  if dgn==`gender' & temp_couples==1  //to be safe (new)
*replace yem=1.1*yem if dgn==`gender' & temp_couples==1 //increase gross wage by 10%
*replace yse=1.1*yse if dgn==`gender' & temp_couples==1   //increase gross wage by 10%
replace yempj=1.1*yempj if dgn==`gender' & temp_couples==1
replace yemtj=1.1*yemtj if dgn==`gender' & temp_couples==1
replace yseag=1.1*yseag if dgn==`gender' & temp_couples==1
replace ysebs=1.1*ysebs if dgn==`gender' & temp_couples==1

/*//for self-employed income, change yse, yseev, ysenr to be on the safe side, and then EM decides which vbls use (either yseev+ysenr or yse) depending on the switch of the TCA
replace yse=1.1*yseev if dgn==`gender' & temp_couples==1   //increase gross wage by 10%
replace yse=1.1*ysenr if dgn==`gender' & temp_couples==1   //increase gross wage by 10%
*/

drop temp*
sort idhh

export delimited "$em_input\$file_input.txt", replace nolabel delim(tab) //create input data for EUROMOD
************************************************************
*						Run EUROMOD with Stata
************************************************************
version 13
* Call EUROMOD 

capture erase "${em_output}\$file_output.txt"        //erase previous output file, this is done in case EUROMOD call from Stata fails, to be sure we are not opening an early run of the model
                                                           
shell "${em_exe}" -emPath "${em_models}" -sys PL_2018 -data PL_2019_b3 -forceOutputInEuro //call EUROMOD 1:Program to call 2: path for folder 3: system name 4: dataset to use

*import EUROMOD RUN
import delimited "${em_output}\$file_output.txt", clear                                                            //import data from txt file in output folder 
gen sim_flag=1  //to indicate that these are simulated observations
rename ils_dispy sim_ils_dispy
rename yem sim_yem
rename yse sim_yse
bysort idhh: egen sim_hhcon=sum(sim_ils_dispy) //hh income, should be done before keeping only the target sample
keep if dgn==`gender'  //important for couples' data

keep idperson idpartner sim_ils_dispy sim_hhcon sim_yem sim_yse
if (`gender' == 0){
save "sim_110female_individuals_output_wage`i'",replace
}
else{
save "sim_110male_individuals_output_wage`i'",replace
}

} //loop end for gender
}  //loop end for wage imputation method

*=======================================================================
*           Extract the sample of couples and define variables (with simulated female wage) 
*=======================================================================
foreach i in 1 2{   //loop begin for wage imputation method 
//local i=1  //only for wage1
use "sim_110female_individuals_output_wage`i'",clear
drop idperson
rename idpartner idperson //for the puropose of merging with their partners
merge m:1 idperson using "couples_wage`i'.dta"
keep if _merge==3  //only keep the target sample of couples
drop _merge
su hhcon sim_hhcon
replace hhcon=sim_hhcon  //make hhcon=simulated hhcon
assert sim_hhcon==hhcon
drop sim_yem sim_yse  //there is no such vbls for female partners in IT_couples.dta
*replace sp_yem=sim_yem
*replace sp_yse=sim_yse
replace sp_ils_dispy=sim_ils_dispy //new

drop sim_*
gen sim_flag=10  //indicate that this is with simulated female partners wage
duplicates report idperson  //no duplicates
save "sim_couples_110female_output_wage`i'",replace
}  //loop end for wage imputation method

*=======================================================================
*           Extract the sample of couples and define variables (with simulated male wage) 
*=======================================================================
foreach i in 1 2{   //loop begin for wage imputation method 
//local i=1  //only for wage1
use "sim_110male_individuals_output_wage`i'",clear
merge 1:1 idperson using "couples_wage`i'.dta"
keep if _merge==3  //only keep the target sample of couples
drop _merge
su hhcon sim_hhcon
replace hhcon=sim_hhcon  //make hhcon=simulated hhcon
assert sim_hhcon==hhcon
replace yem=sim_yem
replace yse=sim_yse
replace ils_dispy=sim_ils_dispy //new

drop sim_*
gen sim_flag=11   //indicate that this is with simulated male partners wage
save "sim_couples_110male_output_wage`i'",replace
}  //loop end for wage imputation method

log close
