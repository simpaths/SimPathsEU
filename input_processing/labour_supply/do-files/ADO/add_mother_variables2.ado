///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//PROGRAM TO ATTACH PARTNER VARIABLES TO THE RESPONDENT                                                              //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
program define add_mother_variables2
    args mother_vars //assign arguments to local macros
   
    preserve // Preserve the original dataset
	keep stm idperson `mother_vars'
    rename idperson idmother 
	  
    tokenize `mother_vars' // Split partner_vars into a list and store each resulting token in a numbered local macro.
    while "`1'" != "" { // Loop over each variable and rename
    capture confirm variable `1' // Check if the variable exists in the dataset
        if !_rc {
            rename `1' mother_`1'
        }
        macro shift //process each token in a loop
    }
	sort stm idmother
	
	save "${local_data}/temp_mother", replace // Save the modified dataset to a temporary file
    restore // Restore the original dataset
    
    sort stm idmother 
    merge m:1 stm idmother using "${local_data}/temp_mother" // Merge the temporary dataset to original , m:1 because idmother can be zero for many
    keep if _merge == 1 | _merge == 3  
    drop _merge
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
