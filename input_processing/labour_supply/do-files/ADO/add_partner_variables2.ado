///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//PROGRAM TO ATTACH PARTNER VARIABLES TO THE RESPONDENT                                                              //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
program define add_partner_variables2
    args partner_vars //assign arguments to local macros
   
    preserve // Preserve the original dataset
	keep stm idperson `partner_vars'
    rename idperson idpartner 
	  
    tokenize `partner_vars' // Split partner_vars into a list and store each resulting token in a numbered local macro.
    while "`1'" != "" { // Loop over each variable and rename
    capture confirm variable `1' // Check if the variable exists in the dataset
        if !_rc {
            rename `1' partner_`1'
        }
        macro shift //process each token in a loop
    }
	sort stm idpartner
	//sum partner_*
    save "${local_data}/temp_partner", replace // Save the modified dataset to a temporary file
    restore // Restore the original dataset
    
    sort stm idpartner
    merge m:1 stm idpartner using "${local_data}/temp_partner" // Merge the temporary dataset to original , m:1 because idpartner can be zero for many
    keep if _merge == 1 | _merge == 3  
    drop _merge
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
