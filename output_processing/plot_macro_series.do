/*******************************************************************************
 * plot_macro_series.do
 * 
 * Purpose: Plot quarterly DSGE macro paths from SimPaths simulation
 * 
 * Usage:
 *   1. Set working directory to the output/TIMESTAMP/csv folder
 *   2. Run this script: do "path/to/plot_macro_series.do"
 * 
 * Example:
 *   cd "C:/Users/PC/_IAB/Projekte/SimPathsEU/output/20260129162829/csv"
 *   do "../../../output_processing/plot_macro_series.do"
 * 
 * Output: 
 *   - Individual .gph files for each variable
 *   - Combined panel graph: MacroPaths{mode}.pdf/.png  (cycle deviations)
 *   - Log-level graph:      MacroPathsLog{mode}.pdf/.png (trend + total in logs)
 * 
 ******************************************************************************/

// set trace on 
// set tracedepth 1

clear all
set more off

// Maximum number of x-axis labels on quarterly graphs.
local max_x_labels = 10

local axis_helper_candidates "_quarterly_axis_helper.do output_processing/_quarterly_axis_helper.do ../output_processing/_quarterly_axis_helper.do ../../output_processing/_quarterly_axis_helper.do ../../../output_processing/_quarterly_axis_helper.do"
local axis_helper ""
foreach candidate of local axis_helper_candidates {
    cap confirm file "`candidate'"
    if _rc == 0 {
        local axis_helper "`candidate'"
        continue, break
    }
}
if "`axis_helper'" == "" {
    display as error "ERROR: Could not find output_processing/_quarterly_axis_helper.do"
    exit 601
}
quietly do "`axis_helper'"

local annual_axis_helper = subinstr("`axis_helper'", "_quarterly_axis_helper.do", "_annual_axis_helper.do", .)
cap confirm file "`annual_axis_helper'"
if _rc != 0 {
    display as error "ERROR: Could not find output_processing/_annual_axis_helper.do"
    exit 601
}
quietly do "`annual_axis_helper'"

// ============================================================================
// 1. LOAD DATA
// ============================================================================

// Select which simulation run to plot when MacroPaths.csv contains multiple runs.
local plot_run = 1

local macro_file "MacroPaths.csv"
local integration_label "Macro"

cap confirm file `"`macro_file'"'
if (_rc != 0) {
    cap confirm file MacroPathsDynamic.csv
    if (_rc == 0) {
        local macro_file "MacroPathsDynamic.csv"
        local integration_label "Dynamic (legacy)"
    }
}

import delimited "`macro_file'", clear varnames(1)

cap confirm variable run
if _rc == 0 {
    quietly count if run == `plot_run'
    if r(N) == 0 {
        display as error "ERROR: Requested run `plot_run' not found in `macro_file'"
        exit 111
    }
    keep if run == `plot_run'
    display as text "Using run `plot_run' from `macro_file'"
}
else {
    if `plot_run' != 1 {
        display as error "ERROR: `macro_file' has no run column; only plot_run = 1 is valid for legacy single-run files"
        exit 111
    }
    display as text "No run column found in `macro_file'; treating file as a legacy single-run export"
}

// Create time variable (quarters since start)
gen t = _n
label var t "Quarter"

// Create year-quarter label for x-axis
gen yq = yq(year, quarter)
format yq %tq
label var yq "Year-Quarter"

// Annual trend/total series are repeated within each year; plot one observation per year in annual panels.
bysort year (quarter): gen byte annual_plot = _n == 1
gen ya = yofd(dofq(yq))
format ya %ty
label var ya "Year"

quietly quarterly_xaxis_opts yq, maxlabels(`max_x_labels')
local xaxisopts `"`r(xaxisopts)'"'
quietly annual_xaxis_opts ya if annual_plot, maxlabels(`max_x_labels')
local annual_xaxisopts `"`r(xaxisopts)'"'

// ============================================================================
// 2. DEFINE VARIABLE LABELS AND SHOCK MAPPINGS
// ============================================================================

// State variables (11)
cap label var r "Interest rate R"
cap label var w "Wage w"
cap label var v "Vacancies v"
cap label var n "Employment n"
cap label var h "Hours h"
cap label var x "Technology x"
cap label var l "Labor force L"
cap label var k "Capital stock k"
cap label var inv "Investment inv"
cap label var sep_shock "Separation shock process"
cap label var match_shock "Matching shock process"

// Jump variables (11)
cap label var y "Output y"
cap label var d "Aggregate demand d"
cap label var c "Consumption c"
cap label var gap "Output gap"
cap label var pi "Inflation π"
cap label var w_star "Reset wage w*"
cap label var u "Unemployment u"
cap label var u_rate "Unemployment rate gap"
cap label var m "Matches m"
cap label var mc "Marginal cost mc"
cap label var theta "Labor market tightness θ"

// Shocks (9)
cap label var eps_a "Technology shock ε_a"
cap label var eps_r "Monetary shock ε_r"
cap label var eps_d "Demand shock ε_d"
cap label var eps_p "Cost-push shock ε_p"
cap label var eps_l "Labor force shock ε_L"
cap label var eps_sep "Separation shock ε_sep"
cap label var eps_match "Matching shock ε_match"
cap label var eps_h "Hours shock ε_h"
cap label var eps_inv "Investment shock ε_inv"

// Capital-deepening trend columns (may not exist in older CSVs)
cap label var w_trend "Wage trend"
cap label var w_total "Total wage (cycle + trend)"

// ============================================================================
// 3. GRAPH SETTINGS
// ============================================================================

// Common graph options
local gopts "ylabel(, angle(0) labsize(small)) `xaxisopts'"
local gopts "`gopts' ytitle("% dev. from SS", size(small))"
local gopts "`gopts' xtitle("", size(small))"
local gopts "`gopts' graphregion(color(white)) plotregion(margin(small))"

// Compact legend style for 2-series plots
local legstyle "size(*.5) ring(0) position(5) cols(1) region(lstyle(none)) symxsize(3pt) rowgap(0)"

// Line styles
local lstyle_var "lcolor(navy) lwidth(medium)"
local lstyle_shock "lcolor(cranberry) lwidth(thin) lpattern(dash)"

// ============================================================================
// 4. CREATE INDIVIDUAL GRAPHS
// ============================================================================

graph drop _all
set graph off

// --- Define variable groups using Mata ---

// Variables WITH corresponding shocks: (var, shock, title, legend_label)
mata: shock_vars   = ("x",          "r",              "d",                 "pi",              "l",            "h",       "inv",             "sep_shock",       "match_shock")
mata: shock_names  = ("eps_a",      "eps_r",          "eps_d",             "eps_p",           "eps_l",        "eps_h",   "eps_inv",         "eps_sep",         "eps_match")
mata: shock_titles = ("Technology x", "Interest rate R", "Aggregate demand d", "Inflation π",    "Labor force L", "Hours h", "Investment inv", "Separation shock", "Matching shock")
mata: shock_legs   = ("x",          "R",              "d",                 "pi",              "L",            "h",       "inv",             "sep_shock",       "match_shock")
mata: shock_gnames = ("x",          "r",              "d",                 "pi_shock",        "l",            "h",       "inv_shock",       "sepshock",        "matchshock")

// Variables WITHOUT shocks: (var, title, gname)
// Note: w is handled separately below as a custom two-line panel (w_cycle + w_total)
mata: noshock_vars   = ("v",          "n",          "y",        "c",            "gap",        "w_star",        "u",             "u_rate",               "m",        "mc",             "theta",        "k")
mata: noshock_titles = ("Vacancies v", "Employment n", "Output y", "Consumption c", "Output gap", "Reset wage w*", "Unemployment u", "Unemployment rate gap", "Matches m", "Marginal cost mc", "Tightness θ", "Capital stock k")
mata: noshock_gnames = ("v",          "n",          "y",        "c",            "gap",        "wstar",         "u",             "urate",                "m",        "mc",             "theta",        "k")

// --- Custom wage panels: separate cycle and total for different scales ---

local created_graphs ""

// Panel 1: w (DSGE cycle component only) — if available
cap confirm variable w
if (_rc == 0) {
    twoway (line w yq, `lstyle_var'), ///
        title("Wage cycle w", size(medium)) ///
        `gopts' legend(off) ///
        name(g_w, replace)
    local created_graphs "`created_graphs' g_w"
}

// Panel 2: w_total (cycle + capital-deepening trend) — only if both columns exist
cap confirm variable w_total
local has_wtotal = (_rc == 0)
cap confirm variable w_trend
local has_wtrend = (_rc == 0)
if (`has_wtotal' & `has_wtrend') {
    local lstyle_total "lcolor(dkorange) lwidth(medium)"
    local lstyle_trend "lcolor(forest_green) lwidth(thin) lpattern(dash)"
    twoway (line w_total yq, `lstyle_total') ///
           (line w_trend yq, `lstyle_trend'), ///
           title("Wage total w{sub:tot}", size(medium)) ///
           `gopts' legend(order(1 "total" 2 "trend") `legstyle') ///
           name(g_wtotal, replace)
    local created_graphs "`created_graphs' g_wtotal"
}

local have_wtotal = (`has_wtotal' & `has_wtrend')

// --- Generate graphs for variables with shocks ---
mata: st_local("n_shock", strofreal(cols(shock_vars)))
forvalues i = 1/`n_shock' {
    mata: st_local("var",   shock_vars[`i'])
    mata: st_local("shock", shock_names[`i'])
    mata: st_local("title", shock_titles[`i'])
    mata: st_local("leg",   shock_legs[`i'])
    mata: st_local("gname", shock_gnames[`i'])
    
    cap confirm variable `var'
    if (_rc != 0) continue
    cap confirm variable `shock'
    if (_rc != 0) continue

    twoway (line `var' yq, `lstyle_var') ///
           (line `shock' yq, `lstyle_shock'), ///
           title("`title'", size(medium)) ///
           `gopts' legend(order(1 "`leg'" 2 "`shock'") `legstyle') ///
           name(g_`gname', replace)
    local created_graphs "`created_graphs' g_`gname'"
}

// --- Generate graphs for variables without shocks ---
mata: st_local("n_noshock", strofreal(cols(noshock_vars)))
forvalues i = 1/`n_noshock' {
    mata: st_local("var",   noshock_vars[`i'])
    mata: st_local("title", noshock_titles[`i'])
    mata: st_local("gname", noshock_gnames[`i'])
    
    cap confirm variable `var'
    if (_rc != 0) continue

    twoway (line `var' yq, `lstyle_var'), ///
           title("`title'", size(medium)) ///
           `gopts' legend(off) ///
           name(g_`gname', replace)
    local created_graphs "`created_graphs' g_`gname'"
}

// ============================================================================
// 5. LOG-LEVEL TREND/TOTAL GRAPH (Second combined panel)
// ============================================================================

// Check which trend/total columns exist (new Ramsey columns: y, c, inv, k; w was already present)
local trend_vars ""
local trend_labels ""
local trend_gnames ""

// Define the 5 variables with Ramsey trends: short name, display title, graph name
// Each triple: (var_base, title, gname)
mata: tv_vars   = ("y",        "c",            "inv",          "k",             "w")
mata: tv_titles = ("Output Y", "Consumption C", "Investment I", "Capital stock K", "Wage w")
mata: tv_gnames = ("y",        "c",            "inv",          "k",             "w")

local log_graphs ""
local has_any_trend = 0

// Compute log-level variables and build individual panels
mata: st_local("n_tv", strofreal(cols(tv_vars)))
forvalues i = 1/`n_tv' {
    mata: st_local("vbase",  tv_vars[`i'])
    mata: st_local("vtitle", tv_titles[`i'])
    mata: st_local("vgname", tv_gnames[`i'])

    // Check if both trend and total columns exist
    cap confirm variable `vbase'_trend
    local has_trend = (_rc == 0)
    cap confirm variable `vbase'_total
    local has_total = (_rc == 0)
    
    if (`has_trend' & `has_total') {
        local has_any_trend = 1
        
        // Compute log indices: ln(1 + pct/100) — measures log-deviation from year 1 baseline
        gen ln_`vbase'_trend = ln(1 + `vbase'_trend / 100)
        gen ln_`vbase'_total = ln(1 + `vbase'_total / 100)
        label var ln_`vbase'_trend "`vtitle' trend (log)"
        label var ln_`vbase'_total "`vtitle' total (log)"

        local lstyle_total "lcolor(navy) lwidth(medium)"
        local lstyle_trend "lcolor(forest_green) lwidth(thin) lpattern(dash)"
        
         twoway (line ln_`vbase'_total ya if annual_plot, `lstyle_total') ///
             (line ln_`vbase'_trend ya if annual_plot, `lstyle_trend'), ///
               title("`vtitle'", size(medium)) ///
             ylabel(, angle(0) labsize(small)) `annual_xaxisopts' ///
               ytitle("log index", size(small)) ///
               xtitle("", size(small)) ///
               graphregion(color(white)) plotregion(margin(small)) ///
               legend(order(1 "total" 2 "trend") size(*.5) ring(0) position(5) cols(1) region(lstyle(none)) symxsize(3pt) rowgap(0)) ///
               name(lg_`vgname', replace)
        local log_graphs "`log_graphs' lg_`vgname'"
    }
}


// ============================================================================
// 6. COMBINE INTO PANELS
// ============================================================================

// Layout target: 5 rows x 5 columns (up to 25 panels)
// Includes expanded DSGE schema with c, k, inv and eps_p/eps_inv.
// Missing columns are skipped automatically for backward compatibility.

local panel_order "g_y g_d g_c g_gap g_w g_r g_pi_shock g_n g_h g_l g_inv_shock g_k g_v g_x g_m g_u g_urate g_mc g_theta g_wstar g_sepshock g_matchshock g_wtotal"
local combine_graphs ""
foreach g of local panel_order {
    cap graph describe `g'
    if (_rc == 0) local combine_graphs "`combine_graphs' `g'"
}

if "`combine_graphs'" == "" {
    noi di as error "No plottable DSGE columns found in `macro_file'."
    exit 498
}

set graph on
if (`have_wtotal') {
    graph combine ///
        `combine_graphs', ///
        cols(5) rows(5) ///
        title("DSGE Quarterly Paths (% deviation from steady state) - `integration_label' integration", size(medium)) ///
        subtitle("Dashed: shocks / trend.  w = DSGE cycle only; w{sub:tot} = trend + cycle.", size(small)) ///
        note("Source: SimPaths DSGE Module.", size(vsmall)) ///
        graphregion(color(white)) ///
        xsize(16) ysize(12) ///
        imargin(tiny) ///
        name(combined, replace)
}
else {
    graph combine ///
        `combine_graphs', ///
        cols(5) rows(5) ///
        title("DSGE Quarterly Paths (% deviation from steady state) - `integration_label' integration", size(medium)) ///
        subtitle("Dashed lines show exogenous shocks", size(small)) ///
        note("Source: SimPaths DSGE Module. Variables: navy solid; Shocks: cranberry dashed.", size(vsmall)) ///
        graphregion(color(white)) ///
        xsize(16) ysize(12) ///
        imargin(tiny) ///
        name(combined, replace)
}

// Save combined graph
graph export MacroPaths`integration_label'.pdf, replace
graph export MacroPaths`integration_label'.png, replace width(3840) height(2160)

if (`has_any_trend') {
    set graph on
    graph combine ///
        `log_graphs', ///
        cols(3) rows(2) ///
        title("Ramsey Trend + DSGE Cycle (log level, relative to baseline) - `integration_label' integration", size(medium)) ///
        subtitle("Solid: total (trend + cycle).  Dashed: Ramsey trend only.", size(small)) ///
        note("Source: SimPaths DSGE Module.  Log index = ln(1 + %deviation/100).", size(vsmall)) ///
        graphregion(color(white)) ///
        xsize(16) ysize(10) ///
        imargin(tiny) ///
        name(combined_log, replace)
    
    graph export MacroPathsLog`integration_label'.pdf, replace
    graph export MacroPathsLog`integration_label'.png, replace width(3840) height(2160)
}

// ============================================================================
// 7. SUMMARY STATISTICS
// ============================================================================

qui {
    noi di _n "=============================================="
    noi di "DSGE Macro Paths Summary Statistics"
    noi di "=============================================="
    noi di "Time span: " year[1] "Q" quarter[1] " to " year[_N] "Q" quarter[_N]
    noi di "Total quarters: " _N
    noi di ""

    // Key variables summary
    noi di "Key Variable Statistics (% deviation from SS):"
    noi di "----------------------------------------------"
    local stats_vars ""
    foreach v in y c inv k w pi n l h {
        cap confirm variable `v'
        if (_rc == 0) local stats_vars "`stats_vars' `v'"
    }
    if "`stats_vars'" != "" {
        noi tabstat `stats_vars', stats(mean sd min max) columns(statistics) format(%9.4f)
    }

    cap confirm variable w_total
    if (_rc == 0) {
        noi di _n "Trend/Cycle Decomposition (Ramsey trend + DSGE cycle):"
        noi di "------------------------------------------------------"
        local decomp_vars ""
        foreach v in w y c inv k {
            cap confirm variable `v'_trend
            if (_rc == 0) local decomp_vars "`decomp_vars' `v'_trend"
            cap confirm variable `v'_total
            if (_rc == 0) local decomp_vars "`decomp_vars' `v'_total"
        }
        if "`decomp_vars'" != "" {
            noi tabstat `decomp_vars', stats(mean sd min max) columns(statistics) format(%9.4f)
        }
    }

    noi di _n "Shock Statistics:"
    noi di "-----------------"
    local shock_stats ""
    foreach s in eps_l eps_h eps_a eps_r eps_d eps_p eps_inv {
        cap confirm variable `s'
        if (_rc == 0) local shock_stats "`shock_stats' `s'"
    }
    if "`shock_stats'" != "" {
        noi tabstat `shock_stats', stats(mean sd min max) columns(statistics) format(%9.4f)
    }

    noi di _n "=============================================="
    noi di "Graphs saved to current directory:"
    noi di "  - MacroPaths`integration_label'.pdf/.png (cycle deviations)"
    if (`has_any_trend') {
        noi di "  - MacroPathsLog`integration_label'.pdf/.png (log-level trends)"
    }
    noi di "  - Individual: g_*.gph, lg_*.gph"
    noi di "=============================================="
}
    