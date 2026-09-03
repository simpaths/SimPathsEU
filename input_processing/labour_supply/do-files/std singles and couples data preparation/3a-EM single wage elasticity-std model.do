**************************************************************************
* 			Poland EM data (PL_2019_b3.txt data)
*run EM to get the ils_dispy for sample of singles resulting from a 10% increase in gross wage 
************************************************************************

global file_log="${log}/EM_singles_elast"

cd "$local_data"

capture log close
log using "$file_log", replace
pwd


global n_choices = 4           // 4 choices: no work, plus 3 hours brackets. 						   
global n_workchoices = $n_choices - 1     // 3 choices with positive supply of hours, 1 choice with 0 hours. 	
//update 1/2/2021: when Extract the sample of "singles" and define variables, save separately as sim_singles_indep_110_IT_individuals_output_wage`i' 
//& sim_singles_dep_110_IT_individuals_output_wage`i'

foreach i in 1 2{   //loop begin for wage imputation method 
//local i=1  //only do for wage1
use individuals_wage`i',clear
merge 1:1 idperson using temp_file.dta								//add additional information
drop _merge
keep if temp_alt_n==1  //reduce EUROMOD burden

replace yivwg=1.1*yivwg  //to be safe (new)
*replace yem=1.1*yem    //increase gross wage by 10%
*replace yse=1.1*yse    //increase gross wage by 10%
replace yempj=1.1*yempj
replace yemtj=1.1*yemtj
replace yseag=1.1*yseag
replace ysebs=1.1*ysebs

//for self-employed income, change yse, yseev, ysenr to be on the safe side, and then EM decides which vbls use (either yseev+ysenr or yse) depending on the switch of the TCA
/*replace yseev=1.1*yseev //increase gross wage by 10%
replace ysenr=1.1*ysenr //increase gross wage by 10%*/

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
keep idperson sim_ils_dispy sim_hhcon sim_yem sim_yse
save sim_110_individuals_output_wage`i',replace
}  //loop end for wage imputation method

*=======================================================================
*           Extract the sample of "singles" and define variables
*=======================================================================
foreach i in 1 2{   //loop begin for wage imputation method 
//local i=1
use "sim_110_individuals_output_wage`i'",clear
merge 1:1 idperson using "singles_wage`i'.dta"
keep if _merge==3
drop _merge
su hhcon sim_hhcon
replace hhcon=sim_hhcon  //make hhcon=simulated hhcon
assert sim_hhcon==hhcon
replace yem=sim_yem
replace yse=sim_yse
replace ils_dispy=sim_ils_dispy //new

drop sim_*
gen sim_flag=1
//singles_indep
preserve
keep if temp_singles_indep==1
save "sim_singles_indep_110_individuals_output_wage`i'",replace
restore
//singles_dep
preserve
keep if temp_singles_dep==1
save "sim_singles_dep_110_individuals_output_wage`i'",replace
restore

}  //loop end for wage imputation method

log close
