**************************************************************************
* 			Project: ESPON 
*           EU SILC (PL_2019_b3)
*           Master file using std model plus single adult chidren (split) hhs for Poland 
*           
*           Author: Zhechun He, Daria Popova 
*           Credit: Matteo Richiardi, Francesco Figari   
*           Latest revision: Daria Popova   
*           Date revised: 20 March 2026
************************************************************************
//note: "_indep" means singles are without partner, "_dep" means singles are not real singles, but live with non-flexible partner
//note: wage1:predicted wage for everyone. wage2:predicted wage for non-workers only. In the ls estimation, only wage1 is used.
************************************************************************


clear all
set more off
set type double
set maxvar 30000
set matsize 1000
//version 14 

/*Save add_partner_variables.ado add_mother_variables.ado and add_father_variables.ado in your ADO directory*/

*directories
global path "D:\Dasha\ESSEX\_SimPaths\_SimPaths_EU\PL\labour_supply"
global do_files "${path}\do-files" 
global do_files_std "${path}\do-files\std singles and couples data preparation" 
global do_files_adult_ch "${path}\do-files\adult children data preparation"
global do_files_specifications "${path}\do-files\model specifications"


global local_data "${path}\data" //folder to store data produced
global log "${path}\log"
 
global results_wi "${path}\results\wage imputation" //folder to store wage imputation results and graphs 
global results "${path}\results" //folder to store LS results  

global summary_table "${path}\results\summary_table" //folder to store general summary tables for all models 


**********************************************************************************************

global em_models "${path}/EUROMOD_RELEASES_I6.39+"  //folder with the input, output etc. EUROMOD folders
global em_exe "C:\Program Files\EUROMOD\Executable\EM_ExecutableCaller.exe"  //executable for EUROMOD

global em_original "${em_models}\Input\Original" //EUROMOD original data folder

global em_input "${em_models}\Input\" //EUROMOD input folder
global em_output "${em_models}\Output\"  //EUROMOD output folder

global file_input = "PL_2019_b3"
global file_output="pl_2018_std" //here output file is 2018 because 2018 system will be used with the 2019 data (2018 earnings)
global policy_year ="PL_2018"

global impmethod "1" //predicted wages for everyone 
*global impmethod "2" //predicted wages for non-working, observed wages for working  

*=======================================================================
* Globals used in Simpaths   

global age_seek_employment 16 
	
global age_force_retire 75     

global max_lhw 126  //ensure lhw is not above weekly maximum of 168 minus 6*7 hours of sleep

global age_max_dep_child 17     

/*-----------------------------------------------------------------------------------------------
* HOURS DISCRETISATION – POLAND 2018
-----------------------------------------------------------------------------------------------*/
global n_choices      4                                    // 1 non-work + 3 work brackets
global n_workchoices  = $n_choices - 1                     // work choices only


* Female
global min_hours_1_0  = 1         // [1,39]
global min_hours_2_0  = 40        // [40]
global min_hours_3_0  = 41        // [41,+∞)

* Male
global min_hours_1_1  = 1         // [1,39]
global min_hours_2_1  = 40        // [40]
global min_hours_3_1  = 41        // [41,+∞)

*=======================================================================

* Set Excel file 

* Info sheet

putexcel set "$results/reg_labourSupplyUtility_PL", sheet("Info") replace
putexcel A1 = ("Description:")
putexcel B1 = ("Regression estimates used by the labour supply process for the following subsamples:")
putexcel B2 = ("1- Single females")
putexcel B3 = ("2- Single males")
putexcel B4 = ("3- Couples with two labour flexible")
putexcel B5 = ("4- Singles with dependent, females")
putexcel B6 = ("5- Singles with dependent, males")
putexcel B7 = ("6- Single adult children, females")
putexcel B8 = ("7- Single adult children, males")

putexcel A10 = ("Notes:")
putexcel B10 = ("Added filter for single adult children to ensure consistency with sample used in simulation")
putexcel B11 = ("Subtracted 6 hours of sleep per day from lhw")

putexcel A15 =("Last update: 20 March 2026 by Daria Popova")

*****************************************************************************************************************************
* Set Excel file for wages 
* Info sheet - first stage 
putexcel set "$results_wi/reg_employment_selection", sheet("Info") replace
putexcel A1 = "Description:"
putexcel B1 = "This file contains regression estimates from the first stage of the Heckman selection model used to estimates wages."
putexcel A2 = "Authors:	Daria Popova" 
putexcel A3 = "Last edit: 9 April 2026"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "W1-sel"
putexcel B6 = "First stage Heckman selection estimates for women (low wages)"
putexcel A7 = "M1-sel"
putexcel B7 = "First stage Heckman selection estimates for men (low wages)"
putexcel A8 = "W2-sel"
putexcel B8 = "First stage Heckman selection estimates for women (normal wages)"
putexcel A9 = "M2-sel"
putexcel B9 = "First stage Heckman selection estimates for men (normal wages)"

putexcel A11 = "Notes:", bold
putexcel B11 = "Estimated on EUROMOD input data PL_2019_b3"
putexcel B12 = "Two-step Heckman command is used which does not permit weights"

* Info sheet - second stage 
putexcel set "$results_wi/reg_wages", sheet("Info") replace
putexcel A1 = "Description:"
putexcel B1 = "This file contains regression estimates used to calculate potential wages for males and females in the simulation."
putexcel A2 = "Authors:	Daria Popova" 
putexcel A3 = "Last edit: 9 April 2026"

putexcel A5 = "Process:", bold
putexcel B5 = "Description:", bold
putexcel A6 = "W1"
putexcel B6 = "Second stage Heckman selection estimates for women (low wages)"
putexcel A7 = "M1"
putexcel B7 = "Second stage Heckman selection estimates for men (low wages)"
putexcel A8 = "W2"
putexcel B8 = "Second stage Heckman selection estimates for women (normal wages)"
putexcel A9 = "M2"
putexcel B9 = "Second stage Heckman selection estimates for men (normal wages)"


putexcel A11 = "Notes:", bold
putexcel B11 = "Estimated on EUROMOD input data PL_2019_b3" 
putexcel B12 = "Two-step Heckman command is used which does not permit weights"



*=======================================================================
*           std singles and couples
*=======================================================================

//-input and output data in EM
do "$do_files_std\1-input and output data-std model.do"  //for std singles and couples, get wage estimates, impute wages in two ways, run EM

//-target samples
do "$do_files_std\2a-singles sample-std model.do"  //get sample for single and generate the vbls needed for ls (std singles)

do "$do_files_std\2b-couples sample-std model.do"  //get sample for couple and generate the vbls needed for ls (std couples)

//-run EM in preparation for computing elasticity
do "$do_files_std\3a-EM single wage elasticity-std model.do" //run EM to get the ils_dispy for sample of singles resulting from a 10% increase in gross wage (std singles)

do "$do_files_std\3b-EM couple wage elasticity-std model.do" //run EM to get the ils_dispy for sample of couples resulting from a 10% increase in gross wage (std couples)


*=======================================================================
*           single adult children (split hhs)
*=======================================================================

//-input and output data in EM
do "$do_files_adult_ch\1-input and output data-dropped sample.do"  //for adult children, split households, run EM

//-target samples
do "$do_files_adult_ch\2-singles sample-dropped sample.do"  //get sample for single and generate the vbls needed for ls (single adult children)

//-run EM in preparation for computing elasticity
do "$do_files_adult_ch\3-EM single wage elasticity-adult_ch.do" //run EM to get the ils_dispy for sample of singles resulting from a 10% increase in gross wage 


/*
*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v1" //folder to store LS results - baseline model with predicted wages for everyone 

global sheet "LS_v1"

do  "$do_files_specifications\4a-singles_indep_elast-std model.do" //predictors: hhcon_100 hhcon2_10000 leisure leisure2 lei_hhcon_100 fixed_cost

do  "$do_files_specifications\4b-singles_dep_elast-std model.do" //predictors: hhcon_100 hhcon2_10000 leisure leisure2 lei_hhcon_100 fixc_dgn 

do  "$do_files_specifications\4c-couples elast-std model.do" //predictors: hhcon_100 hhcon2_10000 leisure sp_leisure leisure2 sp_leisure2 lei_sp_lei lei_hhcon_100 sp_lei_hhcon_100 fixed_cost sp_fixed_cost

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch.do" //estimate ls for singles and compute MU, elasticity (adult children-indep)


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v2" //folder to store LS results - baseline model with number of months in employment  

global sheet "LS_v2"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v2.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v2.do"  

do  "$do_files_specifications\4c-couples elast-std model - v2.do"  

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v2.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v3" //folder to store LS results - baseline model with predicted wages for everyone and regional dummies

global sheet "LS_v3"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v3.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v3.do" 

do  "$do_files_specifications\4c-couples elast-std model - v3.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v3.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v4" //folder to store LS results - baseline model with predicted wages for everyone and higher education dummy

global sheet "LS_v4"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v4.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v4.do" 

do  "$do_files_specifications\4c-couples elast-std model - v4.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v4.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v5" //folder to store LS results - baseline model with interactions of age with leisure 

global sheet "LS_v5"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v5.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v5.do" 

do  "$do_files_specifications\4c-couples elast-std model - v5.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v5.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v6" //folder to store LS results - baseline model with interactions of age with income 

global sheet "LS_v6"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v6.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v6.do" 

do  "$do_files_specifications\4c-couples elast-std model - v6.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v6.do" 



*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v7" //folder to store LS results - baseline model with interactions of children with leisure 

global sheet "LS_v7"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v7.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v7.do" 

do  "$do_files_specifications\4c-couples elast-std model - v7.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v7.do" 



*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v8" //folder to store LS results - baseline model with interactions of children with income  

global sheet "LS_v8"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v8.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v8.do" 

do  "$do_files_specifications\4c-couples elast-std model - v8.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v8.do" 



*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v9" //folder to store LS results - baseline model with interactions of age and children with leisure 

global sheet "LS_v9"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v9.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v9.do" 

do  "$do_files_specifications\4c-couples elast-std model - v9.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v9.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v10" //folder to store LS results - baseline model with interactions of age and children with leisure + education dummies

global sheet "LS_v10"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v10.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v10.do" 

do  "$do_files_specifications\4c-couples elast-std model - v10.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v10.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v11" //folder to store LS results - baseline model with interactions of age and children with leisure + liwwh

global sheet "LS_v11"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v11.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v11.do" 

do  "$do_files_specifications\4c-couples elast-std model - v11.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v11.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v12" //folder to store LS results - baseline model with interactions of age, children and education dummies with leisure 

global sheet "LS_v12"


do  "$do_files_specifications\4a-singles_indep_elast-std model - v12.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v12.do" 

do  "$do_files_specifications\4c-couples elast-std model - v12.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v12.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v13" //folder to store LS results - baseline model with house ownership dummies 

global sheet "LS_v13"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v13.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v13.do" 

do  "$do_files_specifications\4c-couples elast-std model - v13.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v13.do" 


*=======================================================================
*           LS models -clogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v14" //folder to store LS results - baseline model with self-rated health dummies  

global sheet "LS_v14"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v14.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v14.do" 

do  "$do_files_specifications\4c-couples elast-std model - v14.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v14.do" 


*=======================================================================
*           LS models -clogit - baseline specification without fixed cost 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v15" //folder to store LS results - baseline model without fixed costs 
global sheet "LS_v15"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v15.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v15.do" 

do  "$do_files_specifications\4c-couples elast-std model - v15.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v15.do" 


*=======================================================================
*           LS models -clogit - baseline specification without fixed cost 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v16" //folder to store LS results - baseline model without fixed costs + liwwh
global sheet "LS_v16"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v16.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v16.do" 

do  "$do_files_specifications\4c-couples elast-std model - v16.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v16.do" 


*=======================================================================
*           LS models -clogit - baseline specification without fixed cost 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v17" //folder to store LS results - baseline model without fixed costs + 40 hours dummy 
global sheet "LS_v17"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v17.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v17.do" 

do  "$do_files_specifications\4c-couples elast-std model - v17.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v17.do" 


*=======================================================================
*           LS models -clogit - baseline specification without fixed cost 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v18" //folder to store LS results - baseline model without fixed costs + 40plus hours dummy 
global sheet "LS_v18"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v18.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v18.do" 

do  "$do_files_specifications\4c-couples elast-std model - v18.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v18.do" 


*=======================================================================
*           LS models -clogit - baseline specification without fixed cost 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v19" //folder to store LS results - baseline model without fixed costs + 40plus hours dummy + liwwh 
global sheet "LS_v19"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v19.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v19.do" 

do  "$do_files_specifications\4c-couples elast-std model - v19.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v19.do" 


*=======================================================================
*           LS models -clogit - baseline specification without fixed cost 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v20" //folder to store LS results - baseline model without fixed costs + 40plus hours dummy + liwwh & liwwh squared
global sheet "LS_v20"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v20.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v20.do" 

do  "$do_files_specifications\4c-couples elast-std model - v20.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v20.do" 


*=======================================================================
*           LS models -clogit - baseline specification without fixed cost 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v21" //folder to store LS results - baseline model without fixed costs + 40plus hours dummy + ln_liwwh 
global sheet "LS_v21"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v21.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v21.do" 

do  "$do_files_specifications\4c-couples elast-std model - v21.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v21.do" 


*=======================================================================
*           LS models -clogit - baseline specification without fixed cost 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v22" //folder to store LS results - baseline model without fixed costs + 40plus hours dummy + liwwh dummies  
global sheet "LS_v22"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v22.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v22.do" 

do  "$do_files_specifications\4c-couples elast-std model - v22.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v22.do" 
*/

*=======================================================================
*           LS models -clogit - baseline specification without fixed cost - final version to be used in the model
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_final" //folder to store LS results - v20: baseline model without fixed costs + 40plus hours dummy + liwwh & liwwh squared
global sheet "LS_final"

do  "$do_files_specifications\4a-singles_indep_elast-std model - final.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - final.do" 

do  "$do_files_specifications\4c-couples elast-std model - final.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - final.do" 



