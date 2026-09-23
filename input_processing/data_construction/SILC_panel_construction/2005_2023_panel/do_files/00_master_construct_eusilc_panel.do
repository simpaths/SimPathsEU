********************************************************************************
* PROJECT:             	SimPaths EU  
* DO-FILE NAME:         00_master_construct_eusilc_panel
* DESCRIPTION:          Imports the EU-SILC csv files. 
********************************************************************************
* COUNTRY:              -
* DATA:         	    EU-SILC longitudinal data
* AUTHORS: 				Ashley Burdett
* LAST UPDATE:          Jan 2025
********************************************************************************
* NOTE:					This is a formatted, extended (to include 2023 data) 
* 						and organised version of the procedure constructed by 
* 						GESIS to combine the SILC longitudinal data panels in a 
* 						systematic way to identify individuals across 
* 						observations. 
* 
* 						In addition to the included do-files, you will need to 
* 						obtain the set-up files that transform csv files 
* 						containing the SILC data from GESIS. They can be found 
* 						here:  https://www.gesis.org/en/missy/materials/EU-SILC/setups#:~:text=Routines%20to%20transform%20*.csv%20to,document%20of%20every%20data%20release.
* 
* 						The version of the set-up files used should coincide 
* 						with the data release being used. 
* 
* 						Population files merged and added in "05_weights" need to be
* 						uploaded into the input_data subfolder. The 2005-2020 
* 						information was obtained from GESIS, whilst the 
* 						2021-2023 information was obtained from EUROSTAT. 
* 		
* 						Make sure the necessary subfolders are created for the 
* 						set-up file outputs. 
*						Currently called in do-file 01-04 using the following 
* 						pattern
* 						${do_dir}/EU-SILC/19 L-2023/ 
* 						${do_dir}/EU-SILC/18 L-2022/
* 						${do_dir}/EU-SILC/17 L-2021/ ...
*
********************************************************************************

* Initalization 
clear all
capture log close
set more off


/*******************************************************************************
* DEFINE DIRECTORIES
*******************************************************************************/

global main_dir "/Users/aburdett/Library/CloudStorage/Box-Box/ESPON - OVERLAP/_countries/Cumulative Longitudional Dataset (all countries)/2005_2023_panel" // master folder for processing

global log_dir "$main_dir/logs" // folder in main_dir that contains logs

global do_files_dir "$main_dir/do_files" // folder in main_dir that contains do files 

global data_dir "$main_dir/data" // folder in main_dir that contains output data

global input_data_dir "$main_dir/input_data"

//for set-up files 
global do_dir "$main_dir/data" // folder in main_dir that contains output data for merging do file 

global datapath "$main_dir/data" // folder in main_dir that contains output data for merging do file 

global csv_path "$main_dir/input_data"


/*******************************************************************************
* EXECUTE FILES
*******************************************************************************/
* Call set-up files to import the EU-SILC data 
forvalues i = 2005/2023 {
		
	do "$do_files_dir/Long_allcountries_Dfiles_`i'.do" 
}	

forvalues i = 2005/2023 {
		
	do "$do_files_dir/Long_allcountries_Hfiles_`i'.do" 
}	


forvalues i = 2005/2023 {
		
	do "$do_files_dir/Long_allcountries_Pfiles_`i'.do" 
}	


forvalues i = 2005/2023 {
		
	do "$do_files_dir/Long_allcountries_Rfiles_`i'.do" 
}	
*/

* Create panel using D files
do "$do_files_dir/01_create_masterD.do" 


* Create panel using H files
do "$do_files_dir/02_create_masterH.do" 


* Create panel using R files
do "$do_files_dir/03_create_masterR.do" 


* Create panel using P files
do "$do_files_dir/04_create_masterP.do"
 

* Adjust weight variables 
do "$do_files_dir/05_weights.do" 
