// Fetches the monthly HICP from Eurostat (ei_cphi_m, 2015=100, not seasonally adjusted),
// seasonally adjusts it with X-13ARIMA-SEATS and aggregates it to quarterly means.
// Writes HICP.dta (the unadjusted months) and hicp_q_sa.dta, which make_datasets.do
// merges as the DSGE price level of every country except the UK (see
// make_datasets_hicp_uk.do). make_datasets.do runs this file when
// do_HICP_seasonal_adjustment = 1; Stata's working directory must be
// input_processing/macromodel/stata/. The X-13 binary and spec are in x13_settings.do.
//
// SPAN. 1996m1-2025m12, the months the 2015=100 series cover (2026-10 vintage; a refetch
// then returned HICP.dta unchanged). Eurostat's UK series stops at 2020m11 (Brexit): it
// is adjusted over its own months and kept for reference only, as make_datasets.do reads
// the UK's price level from hicp_q_sa_uk.dta.
//
// FROM TRAMO/SEATS TO X-13 (2026-10). Until then hicp_q_sa.dta came from EViews'
// TRAMO/SEATS on the same HICP.dta. Over each country's estimation sample, Q-o-Q
// annualised inflation from X-13 and from TRAMO/SEATS differs by an RMSE of 0.131 pp
// (Germany, 2000q1-2025q1), 0.223 pp (Poland, 2005q1-2025q1), 0.261 pp (Spain,
// 2000q1-2025q1; one quarter 1.54 pp) and 0.001 pp (Sweden, 2001q1-2025q1), with mean
// differences of 0.002 pp or less. Neither leaves residual seasonality: regressing
// quarterly inflation on quarter dummies over those samples gives p = 0.83 to 0.996 for
// X-13 and 0.90 to 0.997 for TRAMO/SEATS. The old UK column ran to 2022q4, extended
// past the data (2020m11) by EViews' forecasts; it now stops at 2020q3, the last
// quarter with three observed months.

// First, so a missing X-13 binary stops the run before the tracked HICP.dta is rewritten.
include x13_settings.do

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

// =====================================================================
// Seasonal adjustment
// =====================================================================
keep if inrange(time, tm(1996m1), tm(2025m12))
sort time
tsset time, monthly

local sa_vars
foreach v of local outvars {
    local sa = strlower("`v'") + "_sa"
    if ("`v'" != "HICP_UK") {
        quietly count if missing(`v')
        if (r(N) > 0) | (_N != tm(2025m12) - tm(1996m1) + 1) {
            display as error "`v' does not cover 1996m1-2025m12 without gaps (N = `=_N', missing = `r(N)')."
            exit 498
        }
    }
    x13_seats `v', generate(`sa') exe("`x13_exe'") ///
        workdir("`x13_workdir'") spec("`x13_spec'")
    local sa_vars `sa_vars' `sa'
}

// Quarterly mean of the adjusted months. A quarter needs all three months: that
// leaves the UK's 2020q4, which has two, missing.
generate tq = qofd(dofm(time))
local counts
foreach sa of local sa_vars {
    local counts `counts' n_`sa' = `sa'
}
collapse (mean) `sa_vars' (count) `counts', by(tq)
foreach sa of local sa_vars {
    quietly replace `sa' = . if n_`sa' < 3
    drop n_`sa'
}
rename tq time
format time %tq
order time hicp_germany_sa hicp_poland_sa hicp_spain_sa hicp_sweden_sa hicp_uk_sa
foreach sa of local sa_vars {
    local c = proper(substr("`sa'", 6, strlen("`sa'") - 8))
    if ("`c'" == "Uk") local c "UK (Eurostat, to 2020m11; not read)"
    label variable `sa' "HICP `c', X-13ARIMA-SEATS SA, quarterly mean"
}

// make_datasets.do copies this into PROVENANCE_{country}.txt.
char _dta[sa_method] "X-13ARIMA-SEATS `x13_version' (SEATS) on Eurostat ei_cphi_m HICP 2015=100, 1996m1-2025m12, via make_datasets_hicp.do (fetched `c(current_date)')"
save hicp_q_sa, replace
