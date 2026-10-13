// Small helper script to get the HICP data from Eurostat; those are seasonally unadjusted
// Workflow: Export them, read them into EViews, do the season adjustement there, aggregate to quarterly
// export them to Stata format, import them in `make_datasets.do`
cap program drop get_hicp
program get_hicp
    syntax , invar(string) outvar(string)
    dbnomics import, provider(Eurostat) dataset(ei_cphi_m) ///
        series(`invar') clear
    keep period value
    gen time = monthly(period, "YM")
    format %tm time
    drop period
    order time value
    rename value `outvar'
end

local series_codes ///
    M.HICP2015.NSA.CP-HI00.DE ///
    M.HICP2015.NSA.CP-HI00.PL ///
    M.HICP2015.NSA.CP-HI00.SE ///
    M.HICP2015.NSA.CP-HI00.ES ///
    M.HICP2015.NSA.CP-HI00.UK

local outvars ///
    HICP_Germany ///
    HICP_Poland ///
    HICP_Sweden ///
    HICP_Spain ///
    HICP_UK

local N: word count `series_codes'

forvalues i = 1/`N' {
    local invar `: word `i' of `series_codes''
    local outvar `: word `i' of `outvars''
    get_hicp, invar(`invar') outvar(`outvar')
        tempfile `outvar'
        save ``outvar'', replace
}

forvalues i = 1/`N' {
    local outvar `: word `i' of `outvars''
    if (`i' == 1) use ``outvar'', clear
    else merge 1:1 time using ``outvar'', nogen
}

save HICP, replace
