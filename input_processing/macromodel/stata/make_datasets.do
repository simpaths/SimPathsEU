// Switches:
global country Poland // Roadmap options: "Germany", "Poland", "Sweden", "Spain", "UK"

// The country can also be passed as the first argument, which overrides the line above
// without editing this file, so script_checksum in PROVENANCE_{country}.txt is the
// checksum of the file as committed:  StataSE-64.exe /e do make_datasets.do UK
args country_arg
if `"`country_arg'"' != "" global country `country_arg'

local do_HICP_seasonal_adjustment = 0 // Set to 1 to create datasaet with HICP variables that are seasonally adjusted with X-13ARIMA-SEATS
local fetch_vars = 1     // Set to 1 to fetch data from dbnomics; set to 0 to skip fetching and use existing dataset
local do_dsge_graphs = 1 // Set to 1 to enable DSGE model variable graphs

// Validate country choice early so unsupported cases fail before any data work starts.
if !inlist("$country", "Germany", "Poland", "Sweden", "Spain", "UK") {
    display as error "Country $country not recognized. Valid project countries: Germany, Poland, Sweden, Spain, UK."
    exit 1
}

// Estimation sample
if "$country" == "Germany" { // set to start of Euro adoption for Germany
    local startdate  2000q1
    local enddate  2025q1
}
else if "$country" == "Poland" {
    local startdate  2005q1
    local enddate  2025q1
}
else if "$country" == "Spain" { // euro founder member; 2000q1 matches Germany
    // The binding constraint is the OECD LFS stock series (pop_active,
    // unemp_pers_ilo), which start 1999q1; the Eurostat national accounts run
    // from 1995q1. 2000q1 is chosen over 1999q1 to match the German sample and
    // to leave a year of LFS burn-in rather than starting on the first print.
    local startdate  2000q1
    local enddate  2025q1
}
else if "$country" == "Sweden" { // bounded by OECD LFS availability, not policy
    // The Eurostat national accounts run from 1993q1 and the 3-month rate from
    // 1987, but the OECD LFS stocks (pop_active, unemp_pers_ilo) only begin
    // 2001q1, and those are the labour-market levels the model is built on.
    // So 2001q1 is a DATA constraint, not a regime choice: it happens to sit
    // well after Sweden's 1993 move to inflation targeting, so the whole sample
    // is one monetary regime.
    local startdate  2001q1
    local enddate  2025q1
}
else if "$country" == "UK" { // bounded by OECD LFS availability, as for Spain and Sweden
    // The OECD LFS stocks (pop_active, unemp_pers_ilo) begin 1999q2; the ONS national
    // accounts run from 1955q1, the OECD employment tables from 1995q1 and the 3-month
    // rate from 1986. 2000q1 leaves three quarters of LFS burn-in and matches the German
    // and Spanish samples. The whole sample is one monetary regime: the Bank of England
    // has set rates independently since May 1997. Its target moved from RPIX 2.5% to
    // CPI 2% in December 2003, a change of index rather than of stance.
    local startdate  2000q1
    local enddate  2025q1
}
else {
    display as error "Country $country not recognized. Please check the country name and series codes in the script."
    exit 1
}

// Countries with their own currency. Their series block takes the wage
// aggregates in national currency and also fetches gdpr_nac; the currency section
// below converts them to euro at the fixed 2015 rate read off gdpr / gdpr_nac.
local non_euro = inlist("$country", "Poland", "Sweden", "UK")

// The UK's price level comes from its own file. Eurostat's UK HICP stops at 2020m11
// (Brexit), so the UK takes the ONS CPI, which is the UK's HICP, seasonally adjusted
// by make_datasets_hicp_uk.do with X-13ARIMA-SEATS. The UK column of hicp_q_sa.dta is
// the truncated Eurostat series and is not read.
local hicp_file = cond("$country" == "UK", "hicp_q_sa_uk.dta", "hicp_q_sa.dta")

// Use dbnomics to fetch data
// To get the package, run in Stata:
// ssc install dbnomics

// NOTE: "vanilla" dbnomics causes a (harmless) error message because mata function urlencode()
// became a built-in.

// FAIL EARLY: When seasonal adjustment is skipped, the later merge step still
// requires the pre-generated HICP file to be present in Stata's current
// working directory. This also catches the common case where pwd is not the
// folder containing this script and its companion files.
if !(`do_HICP_seasonal_adjustment') {
    if !fileexists("`hicp_file'") {
        display as error "Required file `hicp_file' not found in the current working directory: `c(pwd)'"
        display as error "make_datasets.do expects Stata's pwd to point to the folder containing this script and `hicp_file'."
        display as error "Either set do_HICP_seasonal_adjustment = 1 to regenerate the file (via X-13), or start Stata in the make_datasets.do folder with an existing `hicp_file'."
        exit 1
    }
}

// The CSVs for the MATLAB stage go to ../data/, so Stata's pwd must be
// input_processing/macromodel/stata/. Fail here rather than writing a stray data/ folder elsewhere.
mata: st_local("datadir_ok", strofreal(direxists("../data")))
if ("`datadir_ok'" != "1") {
    display as error "../data/ not found from `c(pwd)'."
    display as error "Run make_datasets.do with Stata's working directory set to input_processing/macromodel/stata/."
    exit 1
}

// Seasonal adjustment of the HICP with X-13ARIMA-SEATS, run from Stata through
// x13_seats.ado with the binary and spec in x13_settings.do (the binary is not tracked:
// ../tools/x13as/README.md). make_datasets_hicp.do adjusts the Eurostat HICP of every
// country into hicp_q_sa.dta; the UK's own price level goes through
// make_datasets_hicp_uk.do into hicp_q_sa_uk.dta. x13_seats exits with an error when
// X-13 fails, and each file is saved only after every series is adjusted, so a failed
// regeneration stops here instead of falling through to a stale file.
if (`do_HICP_seasonal_adjustment') & ("$country" == "UK") {
    do make_datasets_hicp_uk.do
}
else if (`do_HICP_seasonal_adjustment') {
    do make_datasets_hicp.do
}

if "$country" == "Germany" {
    mata:
    series_codes_q = (
    //  Provider    , Dataset       , Series ID                                 , Internal var name         , Variable label
        // unused, but keep for reference when adding more variables later
        // "DESTATIS"  , "81000BV007"  , "DG.VGRJPM.X13JDKSB.VGR014"               , "gdpn"                    , "Gross domestic product (GDP) (in bn euro)"                               \
        // "DESTATIS"  , "81000BV019"  , "DG.VGR-VWB-BIB.X13JDKSB.VGR200"          , "pgdp"                    , "GDP Deflator (2020=100)"                                                 \
        // "DESTATIS"  , "81000BV014"  , "DG.X13JDSB.PRO015"                       , "pr_pp"                   , "Lab.prod. per person in empl. (domestic concept) (2020=100)"             \
        // "DESTATIS"  , "81000BV014"  , "DG.X13JDSB.PRO016"                       , "pr_hour"                 , "Lab.prod. per h.worked by pers.in empl.(dom.conc.) (2020=100)"           \
        // "DESTATIS"  , "81000BV014"  , "DG.X13JDSB.VST038"                       , "w_pp"                    , "Gross wages and salaries per employee (dom. conc.) (in euro)"            \
        // "DESTATIS"  , "81000BV014"  , "DG.X13JDSB.VST039"                       , "w_hour"                  , "Gross wages and sal. per empl. hour (dom. concept) (in euro)"            \
        // "DESTATIS"  , "81000BV001"  , "DG.X13JDSB.BEV020"                       , "pop"                     , "Population (in 1,000 persons)"                                           \
        // "DESTATIS"  , "81000BV001"  , "DG.X13JDSB.ERW030"                       , "pop_selfempl"            , "Self-employed persons (in 1,000 persons)"                                \
        // "DESTATIS"  , "81000BV001"  , "DG.X13JDSB.ERW060"                       , "employment_nat"          , "Persons in employment (national concept)"                                \
        // "DESTATIS"  , "81000BV001"  , "DG.WERTORG.ERW089"                       , "ur_ilo_unadj"            , "Unemployment rate, not seasonally adjusted (ILO)"                        \
        // "DESTATIS"  , "81000BV012"  , "DG.X13JDSB.ERW063"                       , "employment"              , "Persons in employment (domestic concept) (in 1,000 persons)"             \
        // "DESTATIS"  , "81000BV012"  , "DG.X13JDSB.STD002"                       , "hours_employment"        , "Hours worked by persons in empl.(domestic concept) (in mn hours)"        \
        // "DESTATIS"  , "81000BV012"  , "DG.X13JDSB.STD003"                       , "hours_employees"         , "Hours worked by employees (domestic concept) (in mn hours)"              \
        // "DESTATIS"  , "81000BV012"  , "DG.X13JDSB.STD007"                       , "hours_employment_pp"     , "Hours worked per person in empl. (dom. concept) (in hours)"              \
        // "BUBA"      , "BBDL1"       , "Q.DE.Y.UNE.UBA000.A0000.A01.D00.0.ABA.A" , "unemp_pers"              , "Unemployed persons (registered unemployment (in 1,000 persons))"         \
        // "BUBA"      , "BBDL1"       , "Q.DE.Y.UNE.UBA000.A0000.A01.D00.0.R00.A" , "ur"                      , "Unemployment rate (in percent)"                                          \

        // =====================================================================
        // LABOUR MARKET: LFS-based stocks (labour force, unemployed)
        // =====================================================================
        "DESTATIS"  , "81000BV001"  , "DG.X13JDSB.ERW001"                       , "pop_active"              , "Economically active population (in 1,000 persons)"                       \
        "DESTATIS"  , "81000BV001"  , "DG.X13JDSB.ERW003"                       , "unemp_pers_ilo"          , "Unemployed persons (ILO)"                                                \

        // =====================================================================
        // LABOUR MARKET: National accounts employment & hours
        // =====================================================================
        "DESTATIS"  , "81000BV012"  , "DG.X13JDSB.ERW061"                       , "employees"               , "Employees (domestic concept) (in 1,000 persons)"                         \
        "DESTATIS"  , "81000BV001"  , "DG.X13JDSB.ERW036"                       , "employees_nat"           , "Employees (national concept)"                                            \
        "DESTATIS"  , "81000BV012"  , "DG.X13JDSB.ETG005"                       , "labour_cost"             , "Compensation of employees (<Arbeitnehmerentgelt>) (in bn euro)"          \
        "DESTATIS"  , "81000BV012"  , "DG.X13JDSB.VST020"                       , "gross_wages"             , "Gross wages and salaries (domestic concept) (in bn euro)"                \
        "DESTATIS"  , "81000BV012"  , "DG.X13JDSB.STD008"                       , "hours_employees_pp"      , "Hours worked per employee (domestic concept) (in hours)"                 \

        // =====================================================================
        // GDP AND EXPENDITURE COMPONENTS (chain-linked volumes)
        // =====================================================================
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.B1GQ.DE"                , "gdpr"                    , "GDP at market prices, chain linked, (in million euro)"                   \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.P31_S14.DE"             , "cons_mn"                 , "Household final consumption, chain linked (million euro)"                \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.P51G.DE"                , "gfcf_mn"                 , "Gross fixed capital formation, chain linked (million euro)"              \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.P3_S13.DE"              , "gov_cons_mn"             , "Government final consumption, chain linked (million euro)"               \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.P6.DE"                  , "exports_mn"              , "Exports of goods and services, chain linked (million euro)"              \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.P7.DE"                  , "imports_mn"              , "Imports of goods and services, chain linked (million euro)"              \

        "", "", "", "", ""  // End marker (last row cannot end with "\", which is inconvenient; adding empty row eases maintenance)
    )

    // Monthly variables, aggregated to quarterly, end of quarter values
    series_codes_me = (
        "ECB"       , "FM"             , "M.U2.EUR.RT.MM.EURIBOR3MD_.HSTA"      , "R_eur3"                  , "Euribor 3-month"                                                         \

        "", "", "", "", ""  // End marker
    )

    end
}

else if "$country" == "Poland" {
    mata:
    series_codes_q = (
    //  Provider    , Dataset       , Series ID                                 , Internal var name         , Variable label

        // =====================================================================
        // LABOUR MARKET: LFS-based stocks (labour force, unemployed)
        // =====================================================================
        "OECD"      , "DSD_LFS@DF_IALFS_LF_Q" , "POL.LF.PS._Z.Y._T.Y15T74._Z.Q" , "pop_active"              , "Labour force (ILO, SA, 15-74, 1000 persons)"                             \
        "OECD"      , "DSD_LFS@DF_IALFS_UNE_Q", "POL.UNE.PS._Z.Y._T.Y15T74._Z.Q", "unemp_pers_ilo"          , "Unemployed persons (ILO, SA, 15-74, 1000 persons)"                       \

        // =====================================================================
        // LABOUR MARKET: National accounts employment & hours
        // =====================================================================
        "Eurostat"  , "namq_10_pe"  , "Q.THS_PER.SA.SAL_DC.PL"                  , "employees"                , "Employees, domestic concept (1000 persons, SCA)"                        \
        "Eurostat"  , "namq_10_pe"  , "Q.THS_PER.SA.SAL_NC.PL"                  , "employees_nat"            , "Employees, national concept (1000 persons, SCA)"                        \
        // CURRENCY: wage aggregates in million PLN (CP_MNAC), the currency of the
        // HICP that deflates them, as for Sweden. Until 2026-10 these were CP_MEUR,
        // converted at the CURRENT exchange rate, so every PLN/EUR swing landed in
        // the "real" wage (-28% in w_level between 2008q3 and 2009q1; issue #29).
        // The wage section converts them to euro at the fixed 2015 rate.
        "Eurostat"  , "namq_10_gdp" , "Q.CP_MNAC.SCA.D1.PL"                     , "labour_cost"              , "Compensation of employees D1 (million PLN, current prices, SCA)"        \
        "Eurostat"  , "namq_10_gdp" , "Q.CP_MNAC.SCA.D11.PL"                    , "gross_wages"              , "Wages and salaries - Poland D11 (million PLN, current prices, SCA)"     \
        "Eurostat"  , "namq_10_a10_e", "Q.THS_HW.TOTAL.SCA.SAL_DC.PL"           , "hours_employees_total"    , "Hours worked by employees, domestic concept (1000 hours, SCA)"          \

        // =====================================================================
        // GDP AND EXPENDITURE COMPONENTS (chain-linked volumes)
        // =====================================================================
        // Euro volumes, as for Sweden: CLV15_MEUR is CLV15_MNAC at the FIXED 2015
        // rate. gdpr_nac is the PLN twin of gdpr; it only supplies that rate.
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.B1GQ.PL"                , "gdpr"                    , "GDP at market prices, chain linked (million EURO)"                       \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.B1GQ.PL"                , "gdpr_nac"                , "GDP at market prices, chain linked (million PLN)"                        \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P31_S14.PL"             , "cons_mn"                 , "Household final consumption, chain linked (million EURO)"                \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P51G.PL"                , "gfcf_mn"                 , "Gross fixed capital formation, chain linked (million EURO)"              \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P3_S13.PL"              , "gov_cons_mn"             , "Government final consumption, chain linked (million EURO)"               \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P6.PL"                  , "exports_mn"              , "Exports of goods and services, chain linked (million EURO)"              \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P7.PL"                  , "imports_mn"              , "Imports of goods and services, chain linked (million EURO)"              \

        "", "", "", "", ""  // End marker
    )

    // Monthly variables, aggregated to quarterly, end of quarter values
    series_codes_me = (
        // WIBOR 3M is the Polish analogue of the 3-month Euribor used for Germany.
        // Source: Eurostat irt_st_m (3-month interbank rate, monthly AVERAGE,
        // % p.a.), the same dataset Sweden uses.
        //
        // Until 2026-10 this was OECD MEI POL.IR3TIB01.ST.M. That dataset stopped
        // at 2024-01, so R was missing for 2024q1-2025q1 and the Kalman filter
        // ran without the rate observable for the last five quarters. The two
        // sources are not interchangeable in history either: the OECD series is
        // an END-OF-MONTH value, so the quarterly R differs from the Eurostat one
        // by up to 0.5 pp in quarters where the rate was moving (2008q4, 2022q1;
        // median 0.01 pp). Do not splice them. The monthly average is also what
        // Germany and Spain (ECB Euribor) and Sweden already use.
        // TODO: I'm using the name R_eur3 for the Polish interest rate variable for now.
        "Eurostat"  , "irt_st_m"       , "M.IRT_M3.PL"                          , "R_eur3"                  , "WIBOR 3-month, monthly average (% p.a.)"                                 \

        "", "", "", "", ""  // End marker
    )

    end
}

else if "$country" == "Spain" {
    mata:
    series_codes_q = (
    //  Provider    , Dataset       , Series ID                                 , Internal var name         , Variable label

        // =====================================================================
        // LABOUR MARKET: LFS-based stocks (labour force, unemployed)
        // =====================================================================
        "OECD"      , "DSD_LFS@DF_IALFS_LF_Q" , "ESP.LF.PS._Z.Y._T.Y15T74._Z.Q" , "pop_active"              , "Labour force (ILO, SA, 15-74, 1000 persons)"                             \
        "OECD"      , "DSD_LFS@DF_IALFS_UNE_Q", "ESP.UNE.PS._Z.Y._T.Y15T74._Z.Q", "unemp_pers_ilo"          , "Unemployed persons (ILO, SA, 15-74, 1000 persons)"                       \

        // =====================================================================
        // LABOUR MARKET: National accounts employment & hours
        // =====================================================================
        // Spain publishes namq_10_pe under s_adj = SCA (seasonally AND calendar
        // adjusted); the SA variant used for Poland does not exist for ES.
        "Eurostat"  , "namq_10_pe"  , "Q.THS_PER.SCA.SAL_DC.ES"                 , "employees"                , "Employees, domestic concept (1000 persons, SCA)"                        \
        "Eurostat"  , "namq_10_pe"  , "Q.THS_PER.SCA.SAL_NC.ES"                 , "employees_nat"            , "Employees, national concept (1000 persons, SCA)"                        \
        "Eurostat"  , "namq_10_gdp" , "Q.CP_MEUR.SCA.D1.ES"                     , "labour_cost"              , "Compensation of employees D1 (million euro, current prices, SCA)"       \
        "Eurostat"  , "namq_10_gdp" , "Q.CP_MEUR.SCA.D11.ES"                    , "gross_wages"              , "Wages and salaries - Spain D11 (million euro, current prices, SCA)"     \
        "Eurostat"  , "namq_10_a10_e", "Q.THS_HW.TOTAL.SCA.SAL_DC.ES"           , "hours_employees_total"    , "Hours worked by employees, domestic concept (1000 hours, SCA)"          \

        // =====================================================================
        // GDP AND EXPENDITURE COMPONENTS (chain-linked volumes)
        // =====================================================================
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.B1GQ.ES"                , "gdpr"                    , "GDP at market prices, chain linked (million EURO)"                       \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P31_S14.ES"             , "cons_mn"                 , "Household final consumption, chain linked (million EURO)"                \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P51G.ES"                , "gfcf_mn"                 , "Gross fixed capital formation, chain linked (million EURO)"              \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P3_S13.ES"              , "gov_cons_mn"             , "Government final consumption, chain linked (million EURO)"               \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P6.ES"                  , "exports_mn"              , "Exports of goods and services, chain linked (million EURO)"              \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P7.ES"                  , "imports_mn"              , "Imports of goods and services, chain linked (million EURO)"              \

        "", "", "", "", ""  // End marker
    )

    // Monthly variables, aggregated to quarterly, end of quarter values
    series_codes_me = (
        // Spain is a euro founder member, so the policy-relevant short rate is
        // the same 3-month Euribor used for Germany - NOT a national rate as
        // for Poland (WIBOR).
        "ECB"       , "FM"             , "M.U2.EUR.RT.MM.EURIBOR3MD_.HSTA"      , "R_eur3"                  , "Euribor 3-month"                                                         \

        "", "", "", "", ""  // End marker
    )

    end
}

else if "$country" == "Sweden" {
    mata:
    series_codes_q = (
    //  Provider    , Dataset       , Series ID                                 , Internal var name         , Variable label

        // =====================================================================
        // LABOUR MARKET: LFS-based stocks (labour force, unemployed)
        // =====================================================================
        // These two are what bind the sample start to 2001q1.
        "OECD"      , "DSD_LFS@DF_IALFS_LF_Q" , "SWE.LF.PS._Z.Y._T.Y15T74._Z.Q" , "pop_active"              , "Labour force (ILO, SA, 15-74, 1000 persons)"                             \
        "OECD"      , "DSD_LFS@DF_IALFS_UNE_Q", "SWE.UNE.PS._Z.Y._T.Y15T74._Z.Q", "unemp_pers_ilo"          , "Unemployed persons (ILO, SA, 15-74, 1000 persons)"                       \

        // =====================================================================
        // LABOUR MARKET: National accounts employment & hours
        // =====================================================================
        // Sweden publishes namq_10_pe under s_adj = SCA, as Spain does; the SA
        // variant used for Poland does not exist for SE.
        "Eurostat"  , "namq_10_pe"  , "Q.THS_PER.SCA.SAL_DC.SE"                 , "employees"                , "Employees, domestic concept (1000 persons, SCA)"                        \
        "Eurostat"  , "namq_10_pe"  , "Q.THS_PER.SCA.SAL_NC.SE"                 , "employees_nat"            , "Employees, national concept (1000 persons, SCA)"                        \
        // CURRENCY: the current-price wage aggregates are taken in NATIONAL
        // CURRENCY (CP_MNAC = million SEK), not CP_MEUR. real_wage_per_employee
        // deflates them by the Swedish HICP, which is a SEK-denominated index, and
        // Eurostat converts CP_MEUR at the CURRENT exchange rate: a euro numerator
        // pushes every SEK/EUR swing straight into the "real" wage. Measured on
        // this sample the implied conversion factor runs from 0.085 (2023q3) to
        // 0.119 (2012q3), and falls 15% within three quarters in 2008-09.
        // The wage section converts them to euro at the FIXED 2015 rate instead;
        // see the note on the volumes below for why a fixed rate is harmless.
        "Eurostat"  , "namq_10_gdp" , "Q.CP_MNAC.SCA.D1.SE"                     , "labour_cost"              , "Compensation of employees D1 (million SEK, current prices, SCA)"        \
        "Eurostat"  , "namq_10_gdp" , "Q.CP_MNAC.SCA.D11.SE"                    , "gross_wages"              , "Wages and salaries - Sweden D11 (million SEK, current prices, SCA)"     \
        "Eurostat"  , "namq_10_a10_e", "Q.THS_HW.TOTAL.SCA.SAL_DC.SE"           , "hours_employees_total"    , "Hours worked by employees, domestic concept (1000 hours, SCA)"          \

        // =====================================================================
        // GDP AND EXPENDITURE COMPONENTS (chain-linked volumes)
        // =====================================================================
        // Chain-linked volumes in euro are safe for a floating currency:
        // CLV15_MEUR is CLV15_MNAC converted at the FIXED 2015 rate, i.e. a
        // constant rescaling (0.10691 for SEK) that drops out of every ratio and
        // log deviation the Ramsey and DSGE layers use. gdpr_nac is the SEK twin
        // of gdpr; it only supplies that rate to the wage section.
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.B1GQ.SE"                , "gdpr"                    , "GDP at market prices, chain linked (million EURO)"                       \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.B1GQ.SE"                , "gdpr_nac"                , "GDP at market prices, chain linked (million SEK)"                        \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P31_S14.SE"             , "cons_mn"                 , "Household final consumption, chain linked (million EURO)"                \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P51G.SE"                , "gfcf_mn"                 , "Gross fixed capital formation, chain linked (million EURO)"              \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P3_S13.SE"              , "gov_cons_mn"             , "Government final consumption, chain linked (million EURO)"               \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P6.SE"                  , "exports_mn"              , "Exports of goods and services, chain linked (million EURO)"              \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.P7.SE"                  , "imports_mn"              , "Imports of goods and services, chain linked (million EURO)"              \

        "", "", "", "", ""  // End marker
    )

    // Monthly variables, aggregated to quarterly, end of quarter values
    series_codes_me = (
        // Sweden has its own currency and central bank (Riksbank), so the short
        // rate is the Swedish 3-month rate, not Euribor.
        //
        // NOTE: this deliberately does NOT use the OECD MEI interbank series
        // (SWE.IR3TIB01.ST.M). That dataset stops at 2024-01, which would leave
        // the last five quarters of R missing against a 2025q1 enddate.
        // Eurostat irt_st_m runs to 2025-12 and is maintained; Poland uses it
        // too, for the same reason.
        "Eurostat"  , "irt_st_m"       , "M.IRT_M3.SE"                          , "R_eur3"                  , "Sweden 3-month rate (% p.a.)"                                            \

        "", "", "", "", ""  // End marker
    )

    end
}

else if "$country" == "UK" {
    // NO EUROSTAT SERIES FOR THE DATA. Eurostat stopped publishing UK data after Brexit:
    // namq_10_gdp and namq_10_pe end at 2020q3, the HICP at 2020m11 and irt_st_m at
    // 2024m3. Each Eurostat series the other countries use is replaced by the same
    // concept from the ONS or the OECD, for the whole sample, with no splicing. The one
    // Eurostat pair fetched below supplies the fixed 2015 euro rate and nothing else.
    mata:
    series_codes_q = (
    //  Provider    , Dataset       , Series ID                                 , Internal var name         , Variable label

        // =====================================================================
        // LABOUR MARKET: LFS-based stocks (labour force, unemployed)
        // =====================================================================
        // Same OECD source and concept as the other countries. These bind the sample
        // start: they begin 1999q2.
        "OECD"      , "DSD_LFS@DF_IALFS_LF_Q" , "GBR.LF.PS._Z.Y._T.Y15T74._Z.Q" , "pop_active"              , "Labour force (ILO, SA, 15-74, 1000 persons)"                             \
        "OECD"      , "DSD_LFS@DF_IALFS_UNE_Q", "GBR.UNE.PS._Z.Y._T.Y15T74._Z.Q", "unemp_pers_ilo"          , "Unemployed persons (ILO, SA, 15-74, 1000 persons)"                       \

        // =====================================================================
        // LABOUR MARKET: National accounts employment & hours
        // =====================================================================
        // OECD QNA tables 0110 (national concept) and 0111 (domestic concept) are the
        // same SNA transmission tables Eurostat publishes as namq_10_pe and
        // namq_10_a10_e. UNITS: employees in thousands, as Eurostat, but hours in
        // MILLIONS, not thousands; hours_employees_pp below rescales.
        "OECD"      , "DSD_NAMAIN1@DF_QNA_BY_ACTIVITY_EMPDC", "Q.Y.GBR.S1.S1.SAL._Z._T._Z.PS._Z.N.T0111", "employees"             , "Employees, domestic concept (1000 persons, SCA)"                  \
        "OECD"      , "DSD_NAMAIN1@DF_QNA_POP_EMPNC"        , "Q.Y.GBR.S1.S1.SAL._Z._T._Z.PS._Z.N.T0110", "employees_nat"         , "Employees, national concept (1000 persons, SCA)"                  \
        "OECD"      , "DSD_NAMAIN1@DF_QNA_BY_ACTIVITY_EMPDC", "Q.Y.GBR.S1.S1.SAL._Z._T._Z.H._Z.N.T0111" , "hours_employees_total" , "Hours worked by employees, domestic concept (million hours, SCA)" \
        // CURRENCY: the wage aggregates are GBP, the currency of the CPI that deflates
        // them, as for Poland and Sweden; the currency section converts them to euro at
        // the fixed 2015 rate. DTWM and DTWL are the S.1 USES side, i.e. paid by
        // resident employers: the domestic concept of Eurostat's D1 and D11, and the
        // same concept as the employees denominator above. (ROYJ, the D11 series ONS
        // headlines, is RECEIVED by households, a national concept.)
        "ONS"       , "QNA"         , "DTWM.Q"                                  , "labour_cost"              , "Compensation of employees D1, S.1 uses (million GBP, current prices, SA)" \
        "ONS"       , "QNA"         , "DTWL.Q"                                  , "gross_wages"              , "Wages and salaries D11, S.1 uses (million GBP, current prices, SA)"     \

        // =====================================================================
        // GDP AND EXPENDITURE COMPONENTS (chained volume measures)
        // =====================================================================
        // ONS chained volume measures (_cvm), SA, million GBP at the reference year of
        // the ONS vintage, each with its current-price twin (_cp). The currency section
        // re-references each volume to 2015 with its own 2015 current-price total and
        // converts it to euro at the fixed 2015 rate, which is how Eurostat builds the
        // CLV15_MEUR volumes of every other country. The re-referencing matters:
        // chain-linked components are valued at the reference year's relative prices,
        // so the base-year shares calibrate_growth_model reads (C/Y, I/Y, NX/Y) depend
        // on the reference year, not only on a currency factor. ONS rather than OECD
        // QNA: ONS is the primary source and the more recent vintage. ABJR/ABJQ are
        // households only (S.14, national concept), Eurostat's P31_S14; NPQT/NPQS are
        // total GFCF (P51G); NMRY/NMRP general government (P3_S13); IKBK/IKBH and
        // IKBL/IKBI total exports (P6) and imports (P7).
        "ONS"       , "QNA"         , "ABMI.Q"                                  , "gdpr_cvm"                , "GDP at market prices, chained volume (million GBP)"                      \
        "ONS"       , "QNA"         , "YBHA.Q"                                  , "gdpr_cp"                 , "GDP at market prices, current prices (million GBP)"                      \
        "ONS"       , "QNA"         , "ABJR.Q"                                  , "cons_mn_cvm"             , "Household final consumption, chained volume (million GBP)"               \
        "ONS"       , "QNA"         , "ABJQ.Q"                                  , "cons_mn_cp"              , "Household final consumption, current prices (million GBP)"               \
        "ONS"       , "QNA"         , "NPQT.Q"                                  , "gfcf_mn_cvm"             , "Gross fixed capital formation, chained volume (million GBP)"             \
        "ONS"       , "QNA"         , "NPQS.Q"                                  , "gfcf_mn_cp"              , "Gross fixed capital formation, current prices (million GBP)"             \
        "ONS"       , "QNA"         , "NMRY.Q"                                  , "gov_cons_mn_cvm"         , "Government final consumption, chained volume (million GBP)"              \
        "ONS"       , "QNA"         , "NMRP.Q"                                  , "gov_cons_mn_cp"          , "Government final consumption, current prices (million GBP)"              \
        "ONS"       , "QNA"         , "IKBK.Q"                                  , "exports_mn_cvm"          , "Exports of goods and services, chained volume (million GBP)"             \
        "ONS"       , "QNA"         , "IKBH.Q"                                  , "exports_mn_cp"           , "Exports of goods and services, current prices (million GBP)"             \
        "ONS"       , "QNA"         , "IKBL.Q"                                  , "imports_mn_cvm"          , "Imports of goods and services, chained volume (million GBP)"             \
        "ONS"       , "QNA"         , "IKBI.Q"                                  , "imports_mn_cp"           , "Imports of goods and services, current prices (million GBP)"             \
        // Eurostat's UK GDP pair, CLV15_MEUR and its GBP twin. It ends at 2020q3 and is
        // NOT the volume: it supplies the fixed 2015 rate, read off it exactly as for
        // Poland and Sweden, and a cross-check of the ONS-based GDP. The currency section
        // then replaces gdpr with the ONS-based volume.
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MEUR.SCA.B1GQ.UK"                , "gdpr"                    , "GDP, chain linked (million EURO), Eurostat to 2020q3: rate source only"  \
        "Eurostat"  , "namq_10_gdp" , "Q.CLV15_MNAC.SCA.B1GQ.UK"                , "gdpr_nac"                , "GDP, chain linked (million GBP), Eurostat to 2020q3: rate source only"   \

        "", "", "", "", ""  // End marker
    )

    // Monthly variables, aggregated to quarterly, end of quarter values
    series_codes_me = (
        // The UK has its own currency and central bank (Bank of England), so the short
        // rate is the UK 3-month rate, not Euribor. Eurostat irt_st_m stops at 2024m3;
        // the OECD STES series is the same monthly-average concept (on 1999m1-2024m3
        // the two differ by -0.002 pp on average, at most 0.12 pp) and runs past the
        // sample end, so it is used for the WHOLE sample rather than spliced on.
        // Not the OECD MEI series the Poland note warns about: that one was an
        // end-of-month value from a dataset that stopped at 2024m1.
        "OECD"      , "DSD_STES@DF_FINMARK" , "GBR.M.IR3TIB.PA._Z._Z._Z._Z.N"       , "R_eur3"                  , "UK 3-month rate, monthly average (% p.a.)"                               \

        "", "", "", "", ""  // End marker
    )

    end
}

else {
    display as error "Country $country not recognized. Please check the country name and series codes in the script."
}

// Remove end markers
mata: series_codes_q = series_codes_q[1..rows(series_codes_q)-1, .]
mata: series_codes_me = series_codes_me[1..rows(series_codes_me)-1, .]


if (`fetch_vars') {
    // ########################################################################################
    // Seasonally adjusted quarterly data
    cwf default // Reset to default frame
    get_data, series_codes(series_codes_q) tframe(data) startdate(`startdate') enddate(`enddate') replace

    // Monthly data, aggregated to quarterly, mean values
    // get_data, series_codes(series_codes_mm) tframe(data_mm) replace freq(monthly) agg(quarter_mean)

    // Monthly data, aggregated to quarterly, mean values
    get_data, series_codes(series_codes_me) tframe(data_me) startdate(`startdate') enddate(`enddate') replace freq(monthly) agg(quarter_end)

    // Merge aggreated monthly data (means) into quarterly data
    // TODO: Only keep for comparison purposes; this gets replaced by the seasonally adjusted HICP from `hicp_file' (below)
    // frame data: merge_frame, linkvar(time) use(data_mm)
    // frame drop data_mm

    // Merge aggreated monthly data (end of quarter values) into quarterly data
    frame data: merge_frame, linkvar(time) use(data_me)
    frame drop data_me

    frame data: save data_${country}_raw, replace
}

else {
    cwf default
    cap frame drop data
    frame create data
    frame data: use data_${country}_raw, clear
}

// Merge the seasonally adjusted HICP from `hicp_file' into the main dataset; this is the
// series we use for the DSGE model estimation. It is merged after the branch above, so a
// regenerated `hicp_file' reaches the data whether the series were fetched or reused. A
// data_${country}_raw.dta saved before 2026-10 still carries the HICP it was fetched
// with; that copy is dropped.
cwf default
use `hicp_file', clear
sort time
tempfile hicp_q_sa
save `hicp_q_sa', replace
local lower_counter = strlower("$country")
frame data: cap drop HICP
frame data: merge 1:1 time using `hicp_q_sa', nogen keepusing(hicp_`lower_counter'_sa)
frame data: rename hicp_`lower_counter'_sa HICP

cwf data
tsset time, quarterly

// =====================================================================
// Currency: euro at the fixed 2015 rate
// =====================================================================

// CURRENCY OF THE WAGE AGGREGATES (labour_cost, gross_wages). They are fetched
// in the currency of the HICP that deflates them: euro for Germany and Spain,
// national currency for the non_euro countries (see the Poland, Sweden and UK
// series blocks). To keep w_level in euro like every other level column, the
// national-currency wages are converted at the FIXED 2015 rate, the constant
// Eurostat uses to turn CLV15_MNAC into CLV15_MEUR, read off the GDP pair rather
// than typed in. A fixed rate is a constant rescaling, so the real wage carries
// no exchange-rate movement, and every country's w_level is euro at 2015 rates.
// The rate is set here, before any series is filtered, because the UK's volumes
// need it too (below).
local eur_per_nac = 1
if (`non_euro') {
    gen double eur_per_nac = gdpr / gdpr_nac
    quietly summarize eur_per_nac
    // Rounding in the published millions moves the ratio by about 1e-6; anything
    // larger means the two series are not a fixed-rate pair.
    if (r(N) == 0) | (r(max) - r(min) > 1e-4 * r(mean)) {
        display as error "gdpr / gdpr_nac is not constant for $country (N = `r(N)', min `r(min)', max `r(max)')."
        display as error "gdpr must be CLV15_MEUR and gdpr_nac CLV15_MNAC of the same series; check the series block."
        exit 9
    }
    local eur_per_nac = r(mean)
    display as text "Wage aggregates converted to euro at the fixed 2015 rate: " %9.6f `eur_per_nac' " EUR per unit of national currency (`r(N)' quarters)"
    drop eur_per_nac gdpr_nac
}

// THE UK'S VOLUMES. The ONS publishes chained volumes in GBP at the reference year
// of its vintage, not Eurostat's CLV15_MEUR. Each is rebuilt here in that concept:
// re-referenced to 2015 by the ratio of its own 2015 current-price total to its 2015
// chained-volume total (re-referencing a chain-linked series is that one constant
// factor), then converted at the fixed 2015 rate. gdpr arrives as Eurostat's UK
// CLV15_MEUR, which ends at 2020q3; it has supplied the rate above and now serves
// as a cross-check of the rebuilt GDP before the ONS-based series replaces it.
if "$country" == "UK" {
    rename gdpr gdpr_eurostat
    foreach v in gdpr cons_mn gfcf_mn gov_cons_mn exports_mn imports_mn {
        quietly summarize `v'_cvm if year(dofq(time)) == 2015
        local n_cvm_2015 = r(N)
        local cvm_2015 = r(sum)
        quietly summarize `v'_cp if year(dofq(time)) == 2015
        if (`n_cvm_2015' != 4) | (r(N) != 4) {
            display as error "`v': re-referencing to 2015 needs all four quarters of 2015 in `v'_cvm and `v'_cp."
            exit 9
        }
        local reref = r(sum) / `cvm_2015'
        gen double `v' = `v'_cvm * `reref' * `eur_per_nac'
        display as text "`v': ONS volume re-referenced to 2015 by " %8.6f `reref' ", then x " %8.6f `eur_per_nac' " EUR/GBP"
        drop `v'_cvm `v'_cp
    }
    label variable gdpr        "GDP at market prices, chain linked 2015 (million EURO; ONS, fixed 2015 rate)"
    label variable cons_mn     "Household final consumption, chain linked 2015 (million EURO; ONS, fixed 2015 rate)"
    label variable gfcf_mn     "Gross fixed capital formation, chain linked 2015 (million EURO; ONS, fixed 2015 rate)"
    label variable gov_cons_mn "Government final consumption, chain linked 2015 (million EURO; ONS, fixed 2015 rate)"
    label variable exports_mn  "Exports of goods and services, chain linked 2015 (million EURO; ONS, fixed 2015 rate)"
    label variable imports_mn  "Imports of goods and services, chain linked 2015 (million EURO; ONS, fixed 2015 rate)"

    // The rebuilt GDP and Eurostat's own series differ only by ONS revisions since
    // Eurostat's last UK vintage: on the 2026-10 vintage the gap runs from -0.3% to
    // +3.3% (mean +0.9%, largest in 2017-2020 after the Blue Book revisions). A wrong
    // unit or rate is off by tens of percent, and GVA at basic prices in place of GDP
    // at market prices by about 11%, so 5% separates the cases.
    gen double gdpr_gap_pct = 100 * (gdpr / gdpr_eurostat - 1)
    quietly summarize gdpr_gap_pct
    display as text "UK GDP rebuilt from ONS vs Eurostat CLV15_MEUR, `r(N)' quarters: gap mean " %6.2f r(mean) "%, min " %6.2f r(min) "%, max " %6.2f r(max) "%"
    if (r(N) == 0) | (max(abs(r(min)), abs(r(max))) > 5) {
        display as error "The ONS-based UK GDP is more than 5% away from Eurostat's CLV15_MEUR series; check the series codes, units and rate."
        exit 9
    }
    drop gdpr_gap_pct gdpr_eurostat
}

// =====================================================================
// Modify variables
// =====================================================================

// Generate Y-o-Y annualized inflation of HICP
sort time
* Rebase HICP to 2020=100 (if not already)
rebase HICP, timevar(time) baseyear(2020) generate(hicp_2020) replace

// Year-on-Year inflation (diagnostics/plots only — NOT the DSGE observable)
sort time
gen hicp_yoy = 1 * 100 * ((hicp_2020 / L4.hicp_2020) - 1)
label variable hicp_yoy "hicp_2020 Y-o-Y inflation (in percent)"

// Q-o-Q annualized — THIS is the DSGE observable pi (renamed below).
// The NKPC describes quarterly pricing decisions, not 4-quarter averages.
gen hicp_qoq_ann = 4 * 100 * ((hicp_2020 / L1.hicp_2020) - 1)
label variable hicp_qoq_ann "hicp_2020 Q-o-Q annualized inflation (in percent)"

// Detrended real GDP using HP filter
gen ln_gdp = log(gdpr)
tsfilter hp gdpr_cycle = ln_gdp, smooth(1600)
replace gdpr_cycle = 100 * gdpr_cycle  // Convert to percentage deviations

// Real investment (Eurostat GFCF, chain-linked million EUR)
// Using same Eurostat series (gfcf_mn) that feeds the Ramsey growth model
// via data_for_dynare_levels.csv, ensuring HP and Ramsey cycles are
// based on the identical underlying investment concept.
gen ln_inv = log(gfcf_mn)
tsfilter hp inv_cycle = ln_inv, smooth(1600)
replace inv_cycle = 100 * inv_cycle  // % deviation from trend
label variable inv_cycle "Investment (GFCF, mn EUR) - HP-filtered (% deviation)"

// Real consumption (Eurostat household final consumption, chain-linked million EUR)
// Same Eurostat series (cons_mn) used by the Ramsey growth model.
gen ln_cons = log(cons_mn)
tsfilter hp cons_cycle = ln_cons, smooth(1600)
replace cons_cycle = 100 * cons_cycle  // % deviation from trend
label variable cons_cycle "Consumption (mn EUR) - HP-filtered (% deviation)"


// We use **3-month Euribor** as the interest rate observable, following Smets & 
// Wouters (2003), Christoffel et al. (2008), and other canonical Euro Area DSGE 
// studies. The 3-month Euribor represents the effective short-term interest rate 
// faced by economic agents and provides continuous daily variation (aggregated to 
// quarterly) for identifying Taylor rule parameters.



*===============================================================================
* CALCULATE COMPENSATION PER EMPLOYEE (FOR DSGE WAGE OBSERVABLE)
*===============================================================================


local factor = cond("$country" == "Germany", 1000, 1) // Convert bn EUR to million EUR for Germany (DESTATIS labour_cost is bn EUR); the other countries take D1/D11 already in millions (Eurostat; ONS for the UK)

// eur_per_nac, the fixed 2015 rate, is set in the currency section above (1 for
// the euro countries).
*---------------------------------------------------------------------------
* Method 1: Total Compensation per Employee (RECOMMENDED)
*---------------------------------------------------------------------------
* ETG005 = Total compensation of employees (Arbeitnehmerentgelt)
* ERW061 = Number of employees (domestic concept)

gen comp_per_employee_q = (labour_cost * `factor' * `eur_per_nac') / employees
label variable comp_per_employee_q "Compensation per employee (thousands EUR/quarter)"
* Annualize (multiply by 4) for easier interpretation
gen comp_per_employee_annual = comp_per_employee_q * 4
label variable comp_per_employee_annual "Compensation per employee (thousands EUR/year)"

*---------------------------------------------------------------------------
* Method 2: Gross Wages per Employee (Alternative)
*---------------------------------------------------------------------------
* VST020 = Gross wages and salaries only (excludes social contributions)

gen wage_per_employee_q = (gross_wages * `factor' * `eur_per_nac') / employees
label variable wage_per_employee_q "Gross wages per employee (thousands EUR/quarter)"

gen wage_per_employee_annual = wage_per_employee_q * 4
label variable wage_per_employee_annual "Gross wages per employee (thousands EUR/year)"

*---------------------------------------------------------------------------
* Convert to Real Terms (Deflate by HICP)
*---------------------------------------------------------------------------
* Real compensation per employee (2020=100)
gen real_comp_per_employee = (comp_per_employee_q / hicp_2020) * 100
label variable real_comp_per_employee "Real compensation per employee (2020=100)"

* Real wages per employee (2020=100)
gen real_wage_per_employee = (wage_per_employee_q / hicp_2020) * 100
label variable real_wage_per_employee "Real wage per employee (in thousand EUR/quarter, 2020=100)"

*---------------------------------------------------------------------------
* HP-Filter Real Compensation (For DSGE Observable "w")
*---------------------------------------------------------------------------
gen ln_real_comp = log(real_comp_per_employee)
tsfilter hp comp_cycle = ln_real_comp, smooth(1600)

gen ln_real_wage = log(real_wage_per_employee)
tsfilter hp wage_cycle = ln_real_wage, smooth(1600)

* Convert to percentage deviations (for Dynare)
gen w_comp = 100 * comp_cycle
label variable w_comp "Real compensation per employee - HP-filtered (% deviation)"

gen w = 100 * wage_cycle
label variable w "Real wage per employee - HP-filtered (% deviation)"

// GERMANY SPECIFIC NOTE!
*===============================================================================
* EMPLOYMENT-UNEMPLOYMENT-LABOR FORCE CYCLES
*===============================================================================
* 
* CONCEPT CHOICE: National (residence-based) for all labor market stocks
* - L: pop_active (Erwerbspersonen, national)
* - n: employees_nat (Arbeitnehmer Inländer, national, excl. self-employed)
* - u: unemp_pers_ilo / pop_active (ILO unemployment rate)
*
* WHY NATIONAL CONCEPT?
* 1. SimPaths models resident households' labor supply decisions
* 2. Search-matching operates on resident labor force
* 3. Identity u = L - n holds exactly (up to self-employed adjustment)
*
* WHY EXCLUDE SELF-EMPLOYED?
* 1. Wage variable (w) is compensation per employee (excludes self-employed)
* 2. Hours variable (h) is hours per employee (excludes self-employed)
* 3. Search-matching framework models employee-vacancy matching
*
* SimPaths' labour-supply model does NOT exclude the self-employed: its working
* state is Les_c4.EmployedOrSelfEmployed, and its wage equation pools employee
* and self-employment income. The Ramsey feedback bridges the two concepts with
* a level factor that holds the employee share of workers fixed (contract 16 in
* docs/Integration_Contracts.md; docs/SimPaths_Coupling.md, section 8.1).
*
* The identity becomes: L - self_empl - n = u (approximately)
* This is documented as a known measurement limitation.
*===============================================================================

// 1. EMPLOYMENT (National concept, excluding self-employed)
// employees_nat = Arbeitnehmer (Inländer) from 81000BV001
gen ln_employees_nat = log(employees_nat)
tsfilter hp emp_cycle = ln_employees_nat, smooth(1600)
gen n = 100 * emp_cycle  // % deviation from trend
label variable n "Employment (national, excl. self-empl.) - HP-filtered (% deviation)"

// 2. UNEMPLOYMENT RATE: HP-filter (not just demean!)
// Demeaning would treat post-Hartz low unemployment as a "boom"
// HP-filter removes the slow-moving NAIRU shift from structural reforms
//
// IMPORTANT: Use ILO unemployment rate for consistency with Destatis
// employment and labor force data. The Bundesbank registered unemployment
// rate (ur) uses a different definition that breaks the identity U = L - N.
// See _CHATS_23_Perplexity_ILO_unemployment.md for details.
gen ur_ilo = (unemp_pers_ilo / pop_active) * 100
label variable ur_ilo "ILO unemployment rate (in percent)"

tsfilter hp unemp_cycle = ur_ilo, smooth(1600)

// NOTE: Keep u in percentage points (pp) as the HP-filtered rate deviation
// The DSGE model has a separate observation equation: u_rate = L - n
// which maps model variables to the observed unemployment rate gap
gen u = unemp_cycle  // HP-filtered unemployment rate in pp
label variable u "Unemployment rate (ILO) - HP-filtered (pp deviation)"

// 3. LABOR FORCE: log-level HP filter
gen ln_lab_force = log(pop_active)
tsfilter hp lf_cycle = ln_lab_force, smooth(1600)
gen L = 100 * lf_cycle  // % deviation from trend
label variable L "Labor force - HP-filtered (% deviation)"

// 4. HOURS PER EMPLOYEE (INTENSIVE MARGIN)
// HP-filter hours per employee to capture cyclical hours adjustment
// Germany adjusts 70-90% via hours (not employment) in recessions
// hours_employees_pp is already seasonally adjusted from Destatis
//
// MEASUREMENT LIMITATION: hours_employees_pp uses DOMESTIC concept
// Destatis publishes hours data only by domestic (Inlands-) concept.
// No national (Inländer-) concept hours series exists.
// This inconsistency is small because:
//   - Pendlersaldo is ~300k (< 1% of 45mn workforce)
//   - Hours adjustment is a workplace phenomenon (intensive margin)
//   - Cyclical correlation between concepts is near-perfect
// For Poland, Spain, Sweden and the UK: hours_employees_pp is not fetched directly
// but computed from total hours / number of employees (both domestic concept).
// UNITS: Eurostat publishes total hours in thousands, the OECD (UK) in millions;
// employees are thousands in both. The UK factor of 1000 puts hours_employees_pp in
// hours per employee per quarter for every country.
if inlist("$country", "Poland", "Spain", "Sweden", "UK") {
    local hours_factor = cond("$country" == "UK", 1000, 1)
    gen hours_employees_pp = hours_employees_total * `hours_factor' / employees
    label variable hours_employees_pp "Hours per employee, domestic concept (computed)"
    drop hours_employees_total
}

// UNITS CHECK. Hours per employee per quarter sit between 310 and 520 for every
// country so far; a thousands/millions slip in the source is a factor of 1000 and
// lands far outside [200, 700].
quietly summarize hours_employees_pp
if (r(N) == 0) | (r(min) < 200) | (r(max) > 700) {
    display as error "hours_employees_pp for $country spans `r(min)' to `r(max)' (N = `r(N)'), outside [200, 700] hours per employee per quarter; check the units of the hours series."
    exit 9
}

gen ln_hours = log(hours_employees_pp)
tsfilter hp hours_cycle = ln_hours, smooth(1600)
gen h = 100 * hours_cycle  // % deviation from trend
label variable h "Hours per employee (domestic) - HP-filtered (% deviation)"

// 5. VALIDATION CHECKS
// 5a. ILO unemployment rate identity (should hold exactly)
gen unemployment_from_identity = (unemp_pers_ilo / pop_active) * 100
gen residual_u = ur_ilo - unemployment_from_identity
summarize residual_u  // Should be ~0 (identity holds by construction)

// 5b. Labor force identity check (L = n + self_empl + u)
// Note: We use employees_nat (excl. self-employed), so identity is approximate
// The gap equals self-employed as share of labor force (~9-10%)
gen employed_total_nat = pop_active - unemp_pers_ilo  // Erwerbstätige (Inländer)
gen self_empl_share = (employed_total_nat - employees_nat) / pop_active * 100
label variable self_empl_share "Self-employed as % of labor force (national)"
summarize self_empl_share  // Expected: ~9-10%

// 5c. Check cyclical correlation between concepts
gen ln_empl_total = log(employed_total_nat)
tsfilter hp empl_total_cycle = ln_empl_total, smooth(1600)
correlate emp_cycle empl_total_cycle  // Should be very high (>0.95)


// Save complete dataset before trimming for Dynare
cwf data
save data_${country}, replace

// Keep only needed vars for Dynare
keep time ///
    gdpr gdpr_cycle ///
    cons_mn cons_cycle ///
    gfcf_mn inv_cycle ///
    gov_cons_mn exports_mn imports_mn ///
    HICP hicp_qoq_ann ///
    R_eur3 ///
    real_wage_per_employee w ///
    employees_nat n ///
    ur_ilo u ///
    pop_active L ///
    hours_employees_pp h 

// Government consumption and net exports (chain-linked million EUR, same units as GDP)
rename gov_cons_mn g_level
gen nx_level = exports_mn - imports_mn
label variable g_level "Government final consumption (mn EUR, chain-linked 2015)"
label variable nx_level "Net exports (mn EUR, chain-linked 2015)"
drop exports_mn imports_mn

rename gdpr y_level
rename gdpr_cycle y
rename cons_mn c_level           // Eurostat, million EUR (same units as y_level)
rename cons_cycle c
rename gfcf_mn inv_level         // Eurostat, million EUR (same units as y_level)
rename inv_cycle inv

rename HICP P
// CRITICAL FIX: Use QoQ annualized inflation for DSGE estimation
// The NK Phillips Curve describes quarterly pricing decisions, not 4-quarter averages.
// YoY inflation is artificially smooth (4-quarter moving average of price changes).
// QoQ annualized: pi_t = 400 * (P_t / P_{t-1} - 1)
rename hicp_qoq_ann pi

rename R_eur3 R
rename real_wage_per_employee w_level
rename employees_nat n_level  // National concept, excl. self-employed
rename ur_ilo u_level  // ILO unemployment rate (consistent with national concept)
rename pop_active L_level  // Labor force (national concept)

// NOTE: h is domestic concept (Destatis provides no national concept hours data)
// This is a documented measurement limitation. Justification:
// 1. Hours are tied to workplace location, not residence
// 2. Pendlersaldo (net commuters) is small (~300k, <1% of workforce)
// 3. Cyclical hours patterns are nearly identical across concepts
// 4. SimPaths models hours decisions, which map to workplace adjustments
rename hours_employees_pp h_level  // Hours per employee (domestic concept)
// h is already named correctly from HP-filter step

// Rename u to u_rate for diagnostics/plots (u_rate is no longer in varobs)
rename u u_rate

//=========================================================================
// SAMPLE RESTRICTIONS FOR DYNARE ESTIMATION
//=========================================================================
// 1. Restrict to EMU era (Euribor starts 1999, use 2000Q1 for clean start)
//    if possible; if not possible (e.g. Poland) then use longest available sample
drop if time < tq(`startdate') | time > tq(`enddate')

// 2. Censor COVID period (2020Q1-2021Q2) - treat as missing data
// Dynare's Kalman filter handles NaN automatically
// This prevents the -10% output drop from inflating shock variances
foreach var of varlist y c inv pi w n u_rate L h {
    replace `var' = . if time >= tq(2020q1) & time <= tq(2021q2)
}
// Note: R (interest rate) kept as-is during COVID (ZLB is informative)
// Note: h (hours) especially important to censor - Kurzarbeit distortion in 2020


// local do_dsge_graphs = 1 // for debugging
if `do_dsge_graphs' {
    // Define variable groups and titles
    if ("$country" == "Germany") local interest_rate_string "3m Euribor (%)"
    else if ("$country" == "Poland") local interest_rate_string "3-month WIBOR (%)"
    else if ("$country" == "Spain") local interest_rate_string "3m Euribor (%)"
    else if ("$country" == "Sweden") local interest_rate_string "3-month rate, Sweden (%)"
    else if ("$country" == "UK") local interest_rate_string "3-month rate, UK (%)"
    else local interest_rate_string "Short-term interest rate (%)"

    local level_vars "y_level c_level inv_level g_level nx_level P R w_level n_level u_level L_level h_level"
    local level_titles `" "Real GDP (mn EUR)" "Consumption (mn EUR)" "Investment (mn EUR)" "Gov. Cons. (mn EUR)" "Net Exports (mn EUR)" "HICP (2020=100)" "`interest_rate_string'" "Real wage per employee (in thousand EUR/quarter)" "Employees nat. (1000s)" "Unemp. Rate (%)" "Labor Force (1000s)" "Hours/Employee" "'
    
    local cycle_vars "y c inv pi R w n u_rate L h"
    local cycle_titles `" "Output Gap (%)" "Consumption Gap (%)" "Investment Gap (%)" "Inflation (% Q-o-Q)" "Interest Rate (%)" "Wage Gap (%)" "Empl. Gap (%)" "Unemp. Gap (pp)" "LF Gap (%)" "Hours Gap (%)" "'
    
    // Generate level plots
    local i = 1
    foreach var of local level_vars {
        local title : word `i' of `level_titles'
        twoway line `var' time, ///
            title("`title'", size(small)) ///
            ytitle("") xtitle("") ///
            name(g_`var', replace) nodraw
        local ++i
    }
    graph combine g_y_level g_c_level g_inv_level g_g_level g_nx_level g_P g_R g_w_level g_n_level g_u_level g_L_level g_h_level, ///
        cols(3) title("DSGE Observables - ${country} - Levels") ///
        name(levels_combined, replace)
    graph export "dsge_levels_${country}.png", replace width(1200)
    
    // Generate cycle plots
    local i = 1
    foreach var of local cycle_vars {
        local title : word `i' of `cycle_titles'
        twoway line `var' time, ///
            title("`title'", size(small)) ///
            ytitle("") xtitle("") ///
            yline(0, lcolor(red) lpattern(dash)) ///
            name(g_`var'_c, replace) nodraw
        local ++i
    }
    graph combine g_y_c g_c_c g_inv_c g_pi_c g_R_c g_w_c g_n_c g_u_rate_c g_L_c g_h_c, ///
        cols(2) title("DSGE Observables - ${country} - Cyclical Components") ///
        name(cycles_combined, replace)
    graph export "dsge_cycles_${country}.png", replace width(1200)
    
    // Clean up individual graphs
    graph drop g_y_level g_c_level g_inv_level g_g_level g_nx_level g_P g_R g_w_level g_n_level g_u_level g_L_level g_h_level
    graph drop g_y_c g_c_c g_inv_c g_pi_c g_R_c g_w_c g_n_c g_u_rate_c g_L_c g_h_c
}

save data_for_dynare_${country}, replace

//=========================================================================
// EXPORT LEVEL DATA FOR RAMSEY GROWTH MODEL (NEW)
//=========================================================================
// The Ramsey growth model (ramsey_trend.m) does structural detrending.
// It needs level data as input. This export provides:
//   y_level   = real GDP (mn EUR, chain-linked 2015, Eurostat namq_10_gdp)
//   c_level   = household final consumption (mn EUR, chain-linked 2015, Eurostat)
//   inv_level = gross fixed capital formation (mn EUR, chain-linked 2015, Eurostat)
//   g_level   = government final consumption (mn EUR, chain-linked 2015, Eurostat)
//   nx_level  = net exports (exports - imports) (mn EUR, chain-linked 2015, Eurostat)
//               The UK's five volumes are ONS chained volumes rebuilt in the same
//               concept: re-referenced to 2015 and converted at the fixed 2015 rate.
//   pi       = inflation (QoQ annualized, %): 400 * (P_t / P_{t-1} - 1); the UK's
//              price level is the ONS CPI (its HICP), from hicp_q_sa_uk.dta
//   R        = 3-month money-market rate (% p.a.), monthly average of the last
//              month of the quarter: Euribor for Germany and Spain, WIBOR for
//              Poland, the Swedish 3-month rate for Sweden, the UK 3-month rate
//              (OECD) for the UK (see series_codes_me)
//   w_level  = real gross wages (D11) per employee, thousand EUR per quarter at
//              2020 prices. Poland, Sweden and the UK deflate their national-
//              currency D11 by their own HICP and convert at the FIXED 2015 rate,
//              so the column carries no exchange-rate movement. Diagnostic only:
//              nothing in the MATLAB pipeline reads it.
//   n_level  = employees, national concept excl. self-employed (thousands)
//   u_level  = ILO unemployment rate (%)
//   L_level  = labor force, national concept (thousands)
//   h_level  = hours per employee, domestic concept (hours/quarter)
//
// COVID censoring does not touch the *_level variables — they are separate
// variables from the censored DSGE observables, so the Ramsey model gets the
// continuous level data its trend computation needs.
//
// EXCEPTION: pi and R are exported under their DSGE names because no _level
// twin exists. pi IS censored above (2020q1-2021q2 are missing in this file);
// R is not. ramsey_trend.m tolerates the gap (omitnan/interp when building the
// inflation trend). Do not "restore" pi here without re-checking the inflation
// trend — uncensoring it changes the trend the DSGE is detrended against.
preserve
    keep time y_level c_level inv_level g_level nx_level pi R w_level n_level u_level L_level h_level
    order time y_level c_level inv_level g_level nx_level pi R w_level n_level u_level L_level h_level
    export delimited using "../data/data_for_dynare_levels_${country}.csv", replace
restore

//=========================================================================
// EXPORT HP-FILTERED DATA (FOR COMPARISON / VALIDATION)
//=========================================================================
// The HP-filtered cyclical components are kept as a benchmark to compare
// against Ramsey-detrended cycles. This file is not used by Dynare
// estimation when the Ramsey pipeline is active.
preserve
    local observables_hp y inv c pi R n L h
    keep time `observables_hp'
    order time `observables_hp'
    // Demean for comparability
    foreach o of local observables_hp {
        qui sum `o'
        replace `o' = `o' - r(mean)
    }
    export delimited using "../data/data_for_dynare_hp_${country}.csv", replace
restore

//=========================================================================
// STAMP THE DATA VINTAGE
//=========================================================================
// input_processing/macromodel/data/ is tracked in git, so these CSVs are a snapshot of moving
// external sources: statistical agencies revise national accounts, and the
// dbnomics series IDs themselves drift (the Poland WIBOR series rode a
// deprecated OECD dataset that silently stopped updating in 2024-01, which
// left R missing for five quarters until the source was switched to Eurostat).
// Without a stamp a tracked CSV is
// "some vintage"; with one it is identifiable, and an upstream revision that
// rewrites history shows up as a diff here rather than silently.
//
// The series definitions live in this script's mata blocks, so rather than
// duplicating them, the stamp records this script's own checksum: change the
// series list and the checksum moves with it.
//
// One file per country, so re-running Germany does not overwrite Poland's.
//
// The seasonal adjustment is stamped inside the HICP file (char sa_method, written by
// make_datasets_hicp.do or make_datasets_hicp_uk.do); it is copied into the stamp.
preserve
use "`hicp_file'", clear
local hicp_sa_method : char _dta[sa_method]
restore
quietly {
    local prov "../data/PROVENANCE_${country}.txt"
    capture file close provfh
    file open provfh using "`prov'", write replace

    file write provfh "Data vintage for ${country}" _n
    file write provfh "=========================================" _n
    file write provfh "generated_by     make_datasets.do" _n
    file write provfh "generated_at     `c(current_date)' `c(current_time)'" _n
    file write provfh "stata_version    `c(stata_version)'" _n
    file write provfh "country          ${country}" _n
    file write provfh "sample_requested `startdate' to `enddate'" _n

    summarize time, meanonly
    local first : display %tq r(min)
    local last  : display %tq r(max)
    file write provfh "observed_span    `=trim("`first'")' to `=trim("`last'")'" _n
    file write provfh "observations     `=_N'" _n

    // Properties of the vintage rather than of the code that reads it.
    file write provfh "covid_censored   2020q1-2021q2 (y c inv pi w n u_rate L h)" _n
    if (`do_HICP_seasonal_adjustment') {
        file write provfh "hicp_seasonal    regenerated: `hicp_sa_method'" _n
    }
    else {
        file write provfh "hicp_seasonal    reused existing `hicp_file': `hicp_sa_method'" _n
    }
    if (`fetch_vars') {
        file write provfh "series_fetched   yes (dbnomics)" _n
    }
    else {
        file write provfh "series_fetched   no (reused existing data_${country}_raw.dta)" _n
    }

    capture checksum "make_datasets.do"
    if (_rc == 0) {
        file write provfh "script_checksum  `r(checksum)' (length `r(filelen)')" _n
    }

    capture confirm file "../../../.git/HEAD"
    if (_rc == 0) {
        tempname githead
        file open `githead' using "../../../.git/HEAD", read
        file read `githead' gitline
        file close `githead'
        file write provfh "git_head         `gitline'" _n
    }

    file write provfh _n "Files written by this run" _n
    file write provfh "-----------------------------------------" _n
    file write provfh "  input_processing/macromodel/data/data_for_dynare_levels_${country}.csv  Ramsey calibration input" _n
    file write provfh "  input_processing/macromodel/data/data_for_dynare_hp_${country}.csv      HP benchmark only" _n
    file write provfh "  data_${country}.dta                                    Stata working frame" _n
    file write provfh "  data_for_dynare_${country}.dta                         Stata frame WITH HP cycles" _n
    file write provfh _n
    file write provfh "NAMING TRAP: data_for_dynare_${country}.dta is NOT the Stata form of" _n
    file write provfh "input_processing/macromodel/data/data_for_dynare_${country}.csv. The CSV is RAMSEY-detrended" _n
    file write provfh "and written by ramsey_trend.m; the .dta is this script's HP frame. Same stem," _n
    file write provfh "different producer, different content -- a leftover from when Stata owned that" _n
    file write provfh "filename (integration contract #12)." _n
    file write provfh _n
    file write provfh "Series definitions: see the mata series_codes_* blocks in make_datasets.do" _n
    file write provfh "at the checksum above." _n

    file close provfh
}
display as text "Wrote ../data/PROVENANCE_${country}.txt"

//=========================================================================
// data_for_dynare_${country}.csv IS DELIBERATELY *NOT* WRITTEN HERE
//=========================================================================
// That file is the DSGE estimation input and is owned solely by
// ramsey_trend.m, which writes the Ramsey-detrended observables to it.
//
// This script used to also export an HP-filtered version to the same path as a
// "legacy fallback until the Ramsey pipeline overwrites it". Both writers
// produced identical column names in identical order, so the two versions were
// indistinguishable except by content, and the last writer silently won.
// Re-running this script after a data refresh therefore replaced the
// Ramsey-detrended estimation input with HP-filtered data with no warning --
// which is exactly what happened between 2026-05 and 2026-08: the DSGE was
// estimated, frozen and exported on HP-filtered data while the pipeline was
// believed to be running on Ramsey trends.
//
// The HP-filtered observables are still exported above, under their own name
// (data_for_dynare_hp_${country}.csv), which is what run_detrending_benchmark.m
// consumes. Do not reintroduce a second writer to the shared path.

frames dir
// NOTE: no interactive commands (browse, edit, ...) in this script — it runs
// unattended as the first stage of the DSGE pipeline.


// Some checks
// Volatility ratios
quietly sum y
local sd_y = r(sd)
quietly sum h  
local sd_h = r(sd)
quietly sum n
local sd_n = r(sd)

display "σ(h) = " `sd_h'
display "σ(n) = " `sd_n'  
display "σ(h)/σ(n) = " `sd_h'/`sd_n'   // Target: 1.5-2.0
display "σ(h)/σ(y) = " `sd_h'/`sd_y'   // Target: 0.4-0.6

correlate y inv h n
// Expected: corr(y,h) ≈ 0.6-0.8, corr(h,n) ≈ 0.5-0.7

