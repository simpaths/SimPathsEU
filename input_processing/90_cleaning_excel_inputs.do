****************************************************
* Clean regression Excel workbooks (no overwrite)
* Output: OUTPUT_DIR/<original filename>.xlsx
*
* For each workbook:
*   - Copies sheets: Info, Gof (if present)
*   - Cleans model sheets (drops empty rows / empty columns)
*   - Writes via putexcel with explicit nformat so decimals show in Excel
****************************************************
clear all
set more off

/****************************************************
* Helper: write current dataset to a sheet via putexcel
****************************************************/
capture program drop _write_sheet
program define _write_sheet
    syntax, file(string) sheet(string) mode(string)

    putexcel set "`file'", sheet("`sheet'") `mode'

    local col = 0
    foreach v of varlist _all {
        local ++col
        mata: st_local("L", numtobase26(`col'))
        putexcel `L'1 = ("`v'")
        if `=_N' == 0 continue

        capture confirm numeric variable `v'
        if !_rc {
            tempname M
            mata: st_matrix("`M'", st_data(., "`v'"))
            putexcel `L'2 = matrix(`M')
        }
        else {
            forvalues i = 1/`=_N' {
                if `v'[`i'] != "" putexcel `L'`=`i'+1' = ("`=`v'[`i']'")
            }
        }
    }
    putexcel close
end

/****************************************************
* USER SETTINGS
****************************************************/
local country    "ES"
local INPUT_DIR  "~/IdeaProjects/SimPathsEU_AUG/input_processing/reg_estimates_`country'_toClean"
local OUTPUT_DIR "~/IdeaProjects/SimPathsEU_AUG/input_processing/reg_estimates_`country'_Cleaned"
local EXT        "xlsx"

capture mkdir "`OUTPUT_DIR'"

local passthrough "Info Gof"

local workbooks ///
"reg_education reg_health reg_partnership reg_fertility reg_home_ownership reg_leave_parental_home reg_retirement reg_income reg_wages reg_labourSupplyUtility reg_RMSE reg_employmentSelection"

foreach wb of local workbooks {
    di as txt "--------------------------------------------"
    di as txt "Processing workbook: `wb'"
    di as txt "--------------------------------------------"

    * Try without suffix first, then with _`country' suffix
    local infile ""
    capture confirm file "`INPUT_DIR'/`wb'.`EXT'"
    if !_rc local infile "`INPUT_DIR'/`wb'.`EXT'"
    else {
        capture confirm file "`INPUT_DIR'/`wb'_`country'.`EXT'"
        if !_rc {
            local infile "`INPUT_DIR'/`wb'_`country'.`EXT'"
            di as txt "  Found with country suffix: `wb'_`country'.`EXT'"
        }
    }

    if "`infile'" == "" {
        di as err "WARNING: Input file not found (`wb'.`EXT' or `wb'_`country'.`EXT') -> skipping"
        continue
    }

    local outfile "`OUTPUT_DIR'/`wb'.`EXT'"

    * Define model sheets for each workbook
    local models ""
    if "`wb'" == "reg_education"           local models "E1a E1b E2a"
    if "`wb'" == "reg_health"              local models "H1 H2"
    if "`wb'" == "reg_partnership"         local models "U1 U2"
    if "`wb'" == "reg_fertility"           local models "F1"
    if "`wb'" == "reg_home_ownership"      local models "HO1"
    if "`wb'" == "reg_leave_parental_home" local models "P1"
    if "`wb'" == "reg_retirement"          local models "R1a R1b"
    if "`wb'" == "reg_income"              local models "I1a I1b"
    if "`wb'" == "reg_wages"               local models "W1fa W1ma W1fb W1mb"
    if "`wb'" == "reg_labourSupplyUtility" local models "Single_female Single_male SingleDep_Females SingleDep_Males Couples SingleAC_Females SingleAC_Males"
    if "`wb'" == "reg_RMSE"                local models "RMSE"
    if "`wb'" == "reg_employmentSelection" local models "W1fa-sel W1ma-sel W1fb-sel W1mb-sel"

    local started = 0

    /**********************
    * A) Copy Info + Gof unchanged
    **********************/
    foreach s of local passthrough {
        capture noisily import excel "`infile'", sheet("`s'") firstrow clear
        if _rc {
            di as txt "  Passthrough sheet `s' not found -> skipping"
            continue
        }
        local mode = cond(`started', "modify", "replace")
        capture noisily _write_sheet, file("`outfile'") sheet("`s'") mode("`mode'")
        if _rc {
            di as err "ERROR: Could not save `outfile' (close Excel / check permissions)."
            exit 603
        }
        local started = 1
    }

    /**********************
    * B) Clean model sheets
    **********************/
    foreach s of local models {
        di as txt "  Cleaning sheet: `s'"

        capture noisily import excel "`infile'", sheet("`s'") firstrow clear
        if _rc {
            di as err "    -> Could not import sheet `s' from `infile' (skipping)"
            continue
        }

        * Drop empty rows (missing() handles both numeric and string)
        gen byte __keep = 0
        foreach v of varlist _all {
            replace __keep = 1 if !missing(`v')
        }
        drop if __keep == 0
        drop __keep

        * Drop empty columns
        foreach v of varlist _all {
            quietly count if !missing(`v')
            if r(N) == 0 drop `v'
        }

        local mode = cond(`started', "modify", "replace")
        capture noisily _write_sheet, file("`outfile'") sheet("`s'") mode("`mode'")
        if _rc {
            di as err "ERROR: Could not save `outfile' (close Excel / check permissions)."
            exit 603
        }
        local started = 1
    }

    if `started' == 0 di as err "No sheets exported for `wb'."
    else di as res "Done: `outfile'"
}

di as res "All done."
