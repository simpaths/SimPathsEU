/*******************************************************************************
 * compare_scenarios.do
 * 
 * Purpose: Compare baseline and counterfactual SimPaths macro outputs in one
 *          unified script:
 *          1) DSGE cycle variables (y, c, pi, r, ...)
 *          2) Ramsey structural trends (w_trend, y_trend, ...)
 *          3) Totals (cycle + trend: w_total, y_total, ...)
 *          4) Population & labour levels (l_level, h_level, n_ramsey)
 *          5) Labour-category shares and mean hours (cat_*_share, cat_*_meanHours)
 *
 * Workflow:
 *   1. Run SimPaths baseline (no shock scenario)
 *   2. Run SimPaths scenario (shock and/or Ramsey scenario)
 *   3. Set the two output directories below
 *   4. Run this script
 *
 * Example:
 *   global baseline_dir "C:/Users/PC/_IAB/Projekte/SimPathsEU/output/20260210_baseline/csv"
 *   global scenario_dir "C:/Users/PC/_IAB/Projekte/SimPathsEU/output/20260210_energy/csv"
 *   global scenario_label "Energy shock (eps_p) + higher gA"
 *   do "output_processing/compare_scenarios.do"
 *
 * Output:
 *   - cycle_levels.png         : Cycle levels (baseline vs scenario)
 *   - cycle_diffs.png          : Cycle differences (scenario − baseline)
 *   - trend_levels.png         : Trend levels (baseline vs scenario)
 *   - trend_diffs.png          : Trend differences (scenario − baseline)
 *   - total_levels.png         : Total levels (baseline vs scenario)
 *   - total_diffs.png          : Total differences (scenario − baseline)
 *   - pop_levels.png           : Population & labour level comparison
 *   - category_diagnostics.png: Labour-category shares and mean-hours plots
 *   - scenario_comparison.txt  : Summary statistics
 *   - scenario_merged.dta      : Merged dataset
 *
 ******************************************************************************/

clear all
set more off

// Maximum number of x-axis labels on quarterly graphs.
local max_x_labels = 10

// Show titles? (0 for presentation, 1 for paper) — if 0, titles are still set on individual graphs but not shown; the combined panel can then be titled manually in PowerPoint or similar.
local show_titles = 1

// Choose which graphs to display (if graph names are not empty, the corresponding graph will be created and combined into a panel at the end; set to 0 to skip)
local do_cycle_level_graphs = 1 // DSGE levels (baseline vs scenario)
local do_cycle_diff_graphs = 1 // DSGE differences (scenario - baseline)
local do_trend_level_graphs = 1 // Ramsey trend levels (baseline vs scenario)
local do_trend_diff_graphs = 1 // Ramsey trend differences (scenario - baseline)
local do_total_level_graphs = 1 // Total levels (cycle + trend) (baseline vs scenario)
local do_total_diff_graphs = 1 // Total differences (cycle + trend) (scenario - baseline)
local do_pop_level_graphs = 1 // Population & labour levels (baseline vs scenario)
local do_pop_level_LN_graph = 1 // L and N levels only (baseline + scenario) — the Demographics panel restricted to the two coupling variables
local do_category_share_graphs = 0 // labour category shares: baseline stack, scenario stack, scenario-baseline differences
local do_category_meanhours_graph = 0 // labour category mean hours: baseline + scenario in one plot

// ============================================================================
// 0. CONFIGURATION — set these before running
// ============================================================================

// Select which simulation run to compare when MacroPaths.csv contains multiple runs.
local plot_run = 1

// Set these before calling the script:
global baseline_dir "c:\Users\PC\_IAB\Projekte\SimPathsEU\output\20260820155653_baseline-2023-2060_1seeds\csv"
global scenario_dir "c:\Users\PC\_IAB\Projekte\SimPathsEU\output\20260820155653_alternative-2023-2060_1seeds\csv"
// global baseline_label "Baseline (no macro)"
global baseline_label "Baseline (Ramsey)"
// global baseline_label "Higher TFP growth (+0.5 pp gA)"

// global scenario_label "Baseline (no macro)"
// global scenario_label "Baseline (Ramsey)"
// global scenario_label "Higher TFP growth (+0.5 pp gA)"
// global scenario_label "Higher TFP growth (+0.5 pp gA) starting in 2040"
global scenario_label "Energy shock (eps_p) 1 sd + higher gA (+0.5 pp)"


if "$baseline_dir" == "" {
    display as error "ERROR: Set global baseline_dir to the baseline output/TIMESTAMP/csv folder"
    exit 198
}
if "$scenario_dir" == "" {
    display as error "ERROR: Set global scenario_dir to the scenario output/TIMESTAMP/csv folder"
    exit 198
}
if "$scenario_label" == "" {
    global scenario_label "Scenario"
}

// Use current CSV (fall back to legacy dynamic/static names)
local csv_file = "MacroPaths.csv"
cap confirm file "$baseline_dir/`csv_file'"
if _rc != 0 {
    local csv_file = "MacroPathsDynamic.csv"
    cap confirm file "$baseline_dir/`csv_file'"
    if _rc != 0 {
        local csv_file = "MacroPathsStatic.csv"
        cap confirm file "$baseline_dir/`csv_file'"
        if _rc != 0 {
            display as error "ERROR: No MacroPaths.csv (or legacy MacroPathsDynamic/Static.csv) found in $baseline_dir"
            exit 601
        }
    }
}

cap confirm file "$scenario_dir/`csv_file'"
if _rc != 0 {
    display as error "ERROR: `csv_file' not found in $scenario_dir"
    exit 601
}

display as text "Using: `csv_file'"

// Output goes into the scenario directory
cd "$scenario_dir"


local axis_helper_candidates "../output_processing/_quarterly_axis_helper.do ../../output_processing/_quarterly_axis_helper.do ../../../output_processing/_quarterly_axis_helper.do"
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
// 1. LOAD BASELINE
// ============================================================================

import delimited "$baseline_dir/`csv_file'", clear varnames(1)

cap confirm variable run
if _rc == 0 {
    quietly count if run == `plot_run'
    if r(N) == 0 {
        display as error "ERROR: Requested run `plot_run' not found in $baseline_dir/`csv_file'"
        exit 111
    }
    keep if run == `plot_run'
    display as text "Using run `plot_run' from baseline file"
}
else {
    if `plot_run' != 1 {
        display as error "ERROR: Baseline file has no run column; only plot_run = 1 is valid for legacy single-run files"
        exit 111
    }
    display as text "Baseline file has no run column; treating it as a legacy single-run export"
}

// Create time variable
gen t = _n
gen yq = yq(year, quarter)
format yq %tq

// Rename all variables with _base suffix (except identifiers)
foreach var of varlist _all {
    if !inlist("`var'", "year", "quarter", "t", "yq") {
        rename `var' `var'_base
    }
}

tempfile baseline
save `baseline'

// ============================================================================
// 2. LOAD SCENARIO
// ============================================================================

import delimited "$scenario_dir/`csv_file'", clear varnames(1)

cap confirm variable run
if _rc == 0 {
    quietly count if run == `plot_run'
    if r(N) == 0 {
        display as error "ERROR: Requested run `plot_run' not found in $scenario_dir/`csv_file'"
        exit 111
    }
    keep if run == `plot_run'
    display as text "Using run `plot_run' from scenario file"
}
else {
    if `plot_run' != 1 {
        display as error "ERROR: Scenario file has no run column; only plot_run = 1 is valid for legacy single-run files"
        exit 111
    }
    display as text "Scenario file has no run column; treating it as a legacy single-run export"
}

gen t = _n
gen yq = yq(year, quarter)
format yq %tq

// ============================================================================
// 3. MERGE
// ============================================================================

merge 1:1 year quarter using `baseline', nogen

// Sort by time
sort year quarter

// Annual series are repeated within each year; plot one observation per year to avoid staircase artefacts.
bysort year (quarter): gen byte annual_plot = _n == 1
gen ya = yofd(dofq(yq))
format ya %ty

quietly quarterly_xaxis_opts yq, maxlabels(`max_x_labels')
local xaxisopts `"`r(xaxisopts)'"'
quietly annual_xaxis_opts ya if annual_plot, maxlabels(`max_x_labels')
local annual_xaxisopts `"`r(xaxisopts)'"'

// ============================================================================
// 4. COMPUTE DIFFERENCES (scenario - baseline)
// ============================================================================

// ----- 4a. Cycle variables -----
local cycle_vars "y c inv pi r w n l h u_rate"
local cycle_labels `" "Output y" "Consumption c" "Investment inv" "Inflation π" "Interest rate R" "Real wage w" "Employment n" "Participation L" "Hours h" "Unemployment rate gap u_rate" "'

// ----- 4b. Trend variables (Ramsey structural trends) -----
local trend_vars   "w_trend y_trend c_trend inv_trend k_trend"
local trend_labels `" "Wage trend" "Output trend" "Consumption trend" "Investment trend" "Capital trend" "'

// ----- 4c. Total variables (cycle + trend) -----
local total_vars   "w_total y_total c_total inv_total k_total"
local total_labels `" "Total wage" "Total output" "Total consumption" "Total investment" "Total capital" "'

// ----- 4d. Population / labour level variables (new: cumulative indices) -----
local pop_vars   "l_level h_level n_ramsey l_ramsey participation_rate workers_over_atriskpool total_population wap_level atrisk_level wage_realized"
local pop_labels `" "Labour force L (SimPaths)" "Hours per worker h (SimPaths)" "Employees N (Ramsey)" "Participation rate l (Ramsey, %)" "Participation rate (SimPaths, % of WAP)" "Workers / at-risk pool (SimPaths, %)" "Total population (SimPaths)" "WAP 15-64 (SimPaths)" "At-risk pool (SimPaths)" "Realised wage (at-risk pool, % from first year)" "'

// Labour category ranges from SimPaths Labour.java for PL/HU/EL:
// Cat. 0 = 0 hours, Cat. 1 = 1-39 hours, Cat. 2 = 40 hours, Cat. 3 = 41-60 hours.
// Parameters.MAX_LABOUR_HOURS_IN_WEEK = 60.
local cat_label_0 "0 hours"
local cat_label_1 "1-39 hours"
local cat_label_2 "40 hours"
local cat_label_3 "41-60 hours"

local cat_share_vars   "cat_0_share cat_1_share cat_2_share cat_3_share"
local cat_share_labels `" "Share: `cat_label_0'" "Share: `cat_label_1'" "Share: `cat_label_2'" "Share: `cat_label_3'" "'

local cat_mean_vars   "cat_0_meanhours cat_1_meanhours cat_2_meanhours cat_3_meanhours"
local cat_mean_labels `" "Mean hours: `cat_label_0'" "Mean hours: `cat_label_1'" "Mean hours: `cat_label_2'" "Mean hours: `cat_label_3'" "'

// Additional variables for table
local addvars "gap d x k w_star u m v mc eps_a eps_r eps_d eps_p eps_sep eps_inv eps_l eps_h "
#d ;
local addvar_labels `" 
    "Demand-supply gap" "Aggregate demand (d)" "Technology level (x)" "Capital stock (k)" "Reset wage (w_star)" 
    "Unemployment level (u)" "Matches (m)" "Vacancies (v)" "Marginal costs (mc)" 
    "Techology shock (ε_a)" "Monetary policy shock (ε_r)" "Demand shock (ε_d)" "Cost-push/Price markup shock (ε_p)" 
    "Separation shock (ε_sep)" "Investment-specific shock (ε_inv)" "Labour supply shock (ε_L)" "Hours shock (ε_h)" " 
    "'  
; #d cr

local allvars `cycle_vars' `trend_vars' `total_vars' `pop_vars' `cat_share_vars' `cat_mean_vars' `addvars'
local allvar_labels `" `cycle_labels' `trend_labels' `total_labels' `pop_labels' `cat_share_labels' `cat_mean_labels' `addvar_labels' "'

local i = 1
local n_diff_created = 0
foreach var of local allvars {
    cap confirm variable `var' `var'_base
    if _rc == 0 {
        cap confirm numeric variable `var'
        if _rc != 0 {
            quietly destring `var', replace force
        }

        cap confirm numeric variable `var'_base
        if _rc != 0 {
            quietly destring `var'_base, replace force
        }

        cap drop diff_`var'
        gen double diff_`var' = `var' - `var'_base

        cap confirm variable diff_`var'
        if _rc == 0 {
            local ++n_diff_created
        }

        local lab : word `i' of `allvar_labels'
        label var diff_`var' "Δ`lab' (scenario - baseline)"
        label var `var' "`lab' (scenario)"
        label var `var'_base "`lab' (baseline)"
    }
    local ++i
}

display as text "Created `n_diff_created' diff_ variables."

// ----- 4e. Demographic level indices: use Java-provided values directly -----
// LaborSupplyAggregator/MacroModelManager now emit wap_level and atrisk_level
// as labour-market-invariant head-count indices (% from first year), correct
// from the first simulated year. Use them directly instead of reconstructing
// WAP/atRisk from the l_level / participation_rate identity. That reconstruction
// anchored pr0/ar0 on the first row with participation_rate > 0; once the
// eager year-1 demographic pass was added on the Java side, a pre-labour-market
// year-1 participation_rate became that anchor and produced a spurious +13%
// WAP/atRisk spike. Java's wap_level/atrisk_level have no such dependency.
//
// Downstream (the Demographics panel) expects wap_level / wap_level_base and
// atRiskPool_level / atRiskPool_level_base. wap_level(_base) already carry the
// Java column names; alias atrisk_level(_base) -> atRiskPool_level(_base).

cap confirm variable atrisk_level
if _rc == 0 {
    cap drop atRiskPool_level
    gen double atRiskPool_level = atrisk_level
}

cap confirm variable atrisk_level_base
if _rc == 0 {
    cap drop atRiskPool_level_base
    gen double atRiskPool_level_base = atrisk_level_base
}

cap confirm variable wap_level wap_level_base
if _rc == 0 {
    cap drop diff_wap_level
    gen double diff_wap_level = wap_level - wap_level_base
}

cap confirm variable atRiskPool_level atRiskPool_level_base
if _rc == 0 {
    cap drop diff_atRiskPool_level
    gen double diff_atRiskPool_level = atRiskPool_level - atRiskPool_level_base
}

// ----- 4f. Labour-category helper series for annual plots -----
cap confirm variable cat_0_share cat_1_share cat_2_share cat_3_share cat_0_share_base cat_1_share_base cat_2_share_base cat_3_share_base
if _rc == 0 {
    cap drop cat_share_cum1 cat_share_cum2 cat_share_cum3 cat_share_cum4
    cap drop cat_share_cum1_base cat_share_cum2_base cat_share_cum3_base cat_share_cum4_base
    cap drop cat_share_zero

    gen double cat_share_zero = 0

    gen double cat_share_cum1 = cat_0_share
    gen double cat_share_cum2 = cat_0_share + cat_1_share
    gen double cat_share_cum3 = cat_0_share + cat_1_share + cat_2_share
    gen double cat_share_cum4 = cat_0_share + cat_1_share + cat_2_share + cat_3_share

    gen double cat_share_cum1_base = cat_0_share_base
    gen double cat_share_cum2_base = cat_0_share_base + cat_1_share_base
    gen double cat_share_cum3_base = cat_0_share_base + cat_1_share_base + cat_2_share_base
    gen double cat_share_cum4_base = cat_0_share_base + cat_1_share_base + cat_2_share_base + cat_3_share_base
}

// ----- 4g. Capital-output ratio index (K/Y) -----
// The break-even / capital-widening diagnostic needs absolute I/Y and K/Y,
// which MacroPaths.csv does not carry. But the capital-output RATIO relative
// to the first year is exactly recoverable from the existing trend indices:
// k_trend and y_trend are both % from first year, so
//   (K/Y)_t / (K/Y)_0 = (1 + k_trend/100) / (1 + y_trend/100).
// Plotted as % deviation, this shows the capital-output transition that
// resolves the "investment up, capital down" paradox (K/Y dips when capital
// lags output). No level anchor, no delta, no Java-recorder change required.
cap confirm variable k_trend y_trend k_trend_base y_trend_base
if _rc == 0 {
    cap drop ky_ratio_idx ky_ratio_idx_base diff_ky_ratio_idx
    gen double ky_ratio_idx      = 100 * ((1 + k_trend/100)      / (1 + y_trend/100)      - 1)
    gen double ky_ratio_idx_base = 100 * ((1 + k_trend_base/100) / (1 + y_trend_base/100) - 1)
    gen double diff_ky_ratio_idx = ky_ratio_idx - ky_ratio_idx_base
    label var ky_ratio_idx      "Capital-output ratio K/Y (scenario)"
    label var ky_ratio_idx_base "Capital-output ratio K/Y (baseline)"
    label var diff_ky_ratio_idx "ΔCapital-output ratio K/Y (scenario - baseline)"
}

// Same K/Y ratio at the TOTAL (cycle + trend) level, from k_total / y_total.
// Identical to the trend version in shock-free runs (cycle ~ 0) but carries the
// cyclical capital-output dynamics in shock scenarios.
cap confirm variable k_total y_total k_total_base y_total_base
if _rc == 0 {
    cap drop ky_ratio_tot_idx ky_ratio_tot_idx_base diff_ky_ratio_tot_idx
    gen double ky_ratio_tot_idx      = 100 * ((1 + k_total/100)      / (1 + y_total/100)      - 1)
    gen double ky_ratio_tot_idx_base = 100 * ((1 + k_total_base/100) / (1 + y_total_base/100) - 1)
    gen double diff_ky_ratio_tot_idx = ky_ratio_tot_idx - ky_ratio_tot_idx_base
    label var ky_ratio_tot_idx      "Capital-output ratio K/Y, total (scenario)"
    label var ky_ratio_tot_idx_base "Capital-output ratio K/Y, total (baseline)"
    label var diff_ky_ratio_tot_idx "ΔCapital-output ratio K/Y, total (scenario - baseline)"
}

// ============================================================================
// 5. PANEL 1: CYCLE LEVEL COMPARISON (baseline vs scenario)
// ============================================================================

graph drop _all
set graph off

// Common graph options
local gopts "ylabel(, angle(0) labsize(vsmall)) `xaxisopts'"
local gopts "`gopts' ytitle("% dev. from SS", size(vsmall))"
local gopts "`gopts' xtitle("", size(small))"
local gopts "`gopts' graphregion(color(white)) plotregion(margin(small))"
local legstyle "size(*.5) position(6) rows(1) region(lstyle(none)) symxsize(3pt) rowgap(0)" // ring(0) position(2) 


local cycle_level_graphs ""
local i = 1
foreach var of local cycle_vars {
    cap confirm variable diff_`var'
    if _rc == 0 {
        local lab : word `i' of `cycle_labels'
        local title = cond(1, `"title("`lab'", size(small))"', "") // always show!

        // Overlay plot: baseline (dashed) vs scenario (solid)
        twoway ///
            (line `var'_base yq, lpattern(dash) lcolor(gs8) lwidth(medium)) ///
            (line `var' yq, lpattern(solid) lcolor(navy) lwidth(medium)), ///
            `title' ///
            `gopts' ///
            legend(`legstyle') ///
            name(level_`var', replace)
        
        // graph save level_`var'.gph, replace
        local cycle_level_graphs "`cycle_level_graphs' level_`var'"
    }
    local ++i
}


// ============================================================================
// 6. PANEL 2: CYCLE DIFFERENCE (scenario - baseline)
// ============================================================================

// Common graph options
local gopts "ylabel(, angle(0) labsize(vsmall)) `xaxisopts'"
local gopts "`gopts' ytitle("pp difference", size(vsmall))"
local gopts "`gopts' xtitle("", size(small))"
local gopts "`gopts' graphregion(color(white)) plotregion(margin(small))"

local cycle_diff_graphs ""
local i = 1
foreach var of local cycle_vars {
    cap confirm variable diff_`var'
    if _rc == 0 {
        local lab : word `i' of `cycle_labels'
        local title = cond(1, `"title("Δ`lab'", size(small))"', "") // always show!
        twoway ///
            (line diff_`var' yq, lcolor(cranberry) lwidth(medium)) ///
            (function y=0, range(yq) lcolor(gs10) lpattern(dash)), ///
            `title' ///
            `gopts' ///
            legend(off) ///
            name(diff_`var', replace)
        
        // graph save scenario_diff_`var'.gph, replace
        local cycle_diff_graphs "`cycle_diff_graphs' diff_`var'"
    }
    local ++i
}


// ============================================================================
// 7. PANEL 3: TREND LEVEL COMPARISON (baseline vs scenario)
// ============================================================================

local trend_gopts "ylabel(, angle(0) labsize(vsmall))"
local trend_gopts "`trend_gopts' xtitle("", size(small))"
local trend_gopts "`trend_gopts' graphregion(color(white)) plotregion(margin(small))"
local trend_legstyle "size(*.6) position(6) rows(1) region(lstyle(none)) symxsize(4pt) rowgap(0)"

local trend_level_graphs ""
local i = 1
foreach var of local trend_vars {
    cap confirm variable diff_`var'
    if _rc == 0 {
        local lab : word `i' of `trend_labels'
        local title = cond(1, `"title("`lab'", size(small))"', "") // always show!
        twoway ///
            (line `var'_base ya if annual_plot, lpattern(dash) lcolor(gs8) lwidth(medium)) ///
            (line `var' ya if annual_plot, lpattern(solid) lcolor(navy) lwidth(medium)), ///
            `title' ///
            ytitle("% from first year", size(vsmall)) ///
            `trend_gopts' `annual_xaxisopts' ///
            legend(order(1 "Baseline" 2 "Scenario") `trend_legstyle') ///
            name(trend_`var', replace)
        
        local trend_level_graphs "`trend_level_graphs' trend_`var'"
    }
    local ++i
}

// 6th trend panel: capital-output ratio K/Y (fills the empty 2x3 slot)
cap confirm variable ky_ratio_idx ky_ratio_idx_base
if _rc == 0 {
    local title = cond(1, `"title("Capital-output ratio K/Y", size(small))"', "")
    twoway ///
        (line ky_ratio_idx_base ya if annual_plot, lpattern(dash) lcolor(gs8) lwidth(medium)) ///
        (line ky_ratio_idx ya if annual_plot, lpattern(solid) lcolor(navy) lwidth(medium)), ///
        `title' ///
        ytitle("% from first year", size(vsmall)) ///
        `trend_gopts' `annual_xaxisopts' ///
        legend(order(1 "Baseline" 2 "Scenario") `trend_legstyle') ///
        name(trend_ky_ratio, replace)

    local trend_level_graphs "`trend_level_graphs' trend_ky_ratio"
}


// ============================================================================
// 8. PANEL 4: TOTAL LEVEL COMPARISON (cycle + trend)
// ============================================================================

local total_level_graphs ""
local i = 1
foreach var of local total_vars {
    cap confirm variable diff_`var'
    if _rc == 0 {
        local lab : word `i' of `total_labels'
        local title = cond(1, `"title("`lab'", size(small))"', "") // always show!
        twoway ///
            (line `var'_base ya if annual_plot, lpattern(dash) lcolor(gs8) lwidth(medium)) ///
            (line `var' ya if annual_plot, lpattern(solid) lcolor(dkgreen) lwidth(medium)), ///
            `title' ///
            ytitle("% from SS first year", size(vsmall)) ///
            `trend_gopts' `annual_xaxisopts' ///
            legend(order(1 "Baseline" 2 "Scenario") `trend_legstyle') ///
            name(total_`var', replace)
        
        local total_level_graphs "`total_level_graphs' total_`var'"
    }
    local ++i
}

// 6th total panel: capital-output ratio K/Y (total = cycle + trend)
cap confirm variable ky_ratio_tot_idx ky_ratio_tot_idx_base
if _rc == 0 {
    local title = cond(1, `"title("Capital-output ratio K/Y", size(small))"', "")
    twoway ///
        (line ky_ratio_tot_idx_base ya if annual_plot, lpattern(dash) lcolor(gs8) lwidth(medium)) ///
        (line ky_ratio_tot_idx ya if annual_plot, lpattern(solid) lcolor(dkgreen) lwidth(medium)), ///
        `title' ///
        ytitle("% from SS first year", size(vsmall)) ///
        `trend_gopts' `annual_xaxisopts' ///
        legend(order(1 "Baseline" 2 "Scenario") `trend_legstyle') ///
        name(total_ky_ratio, replace)

    local total_level_graphs "`total_level_graphs' total_ky_ratio"
}


// ============================================================================
// 9. PANEL 5: TREND DIFFERENCE (scenario - baseline)
// ============================================================================

local diff_trend_gopts "ylabel(, angle(0) labsize(vsmall))"
local diff_trend_gopts "`diff_trend_gopts' ytitle("pp difference", size(vsmall))"
local diff_trend_gopts "`diff_trend_gopts' xtitle("", size(small))"
local diff_trend_gopts "`diff_trend_gopts' graphregion(color(white)) plotregion(margin(small))"

local trend_diff_graphs ""
local i = 1
foreach var of local trend_vars {
    cap confirm variable diff_`var'
    if _rc == 0 {
        local lab : word `i' of `trend_labels'
        local title = cond(1, `"title("`lab'", size(small))"', "") // always show!
        twoway ///
            (line diff_`var' ya if annual_plot, lcolor(cranberry) lwidth(medium)) ///
            (function y=0, range(ya) lcolor(gs10) lpattern(dash)), ///
            `title' ///
            `diff_trend_gopts' `annual_xaxisopts' ///
            legend(off) ///
            name(rdiff_`var', replace)
        
        local trend_diff_graphs "`trend_diff_graphs' rdiff_`var'"
    }
    local ++i
}

// 6th trend-diff panel: capital-output ratio K/Y (scenario - baseline)
cap confirm variable diff_ky_ratio_idx
if _rc == 0 {
    local title = cond(1, `"title("ΔCapital-output ratio K/Y", size(small))"', "")
    twoway ///
        (line diff_ky_ratio_idx ya if annual_plot, lcolor(cranberry) lwidth(medium)) ///
        (function y=0, range(ya) lcolor(gs10) lpattern(dash)), ///
        `title' ///
        `diff_trend_gopts' `annual_xaxisopts' ///
        legend(off) ///
        name(rdiff_ky_ratio, replace)

    local trend_diff_graphs "`trend_diff_graphs' rdiff_ky_ratio"
}


// ============================================================================
// 10. PANEL 6: TOTAL DIFFERENCE (scenario - baseline)
// ============================================================================

local total_diff_graphs ""
local i = 1
foreach var of local total_vars {
    cap confirm variable diff_`var'
    if _rc == 0 {
        local lab : word `i' of `total_labels'
        local title = cond(1, `"title("Δ`lab'", size(small))"', "") // always show!
        twoway ///
            (line diff_`var' ya if annual_plot, lcolor(cranberry) lwidth(medium)) ///
            (function y=0, range(ya) lcolor(gs10) lpattern(dash)), ///
            `title' ///
            `diff_trend_gopts' `annual_xaxisopts' ///
            legend(off) ///
            name(tdiff_`var', replace)

        local total_diff_graphs "`total_diff_graphs' tdiff_`var'"
    }
    local ++i
}

// 6th total-diff panel: capital-output ratio K/Y (total, scenario - baseline)
cap confirm variable diff_ky_ratio_tot_idx
if _rc == 0 {
    local title = cond(1, `"title("ΔCapital-output ratio K/Y", size(small))"', "")
    twoway ///
        (line diff_ky_ratio_tot_idx ya if annual_plot, lcolor(cranberry) lwidth(medium)) ///
        (function y=0, range(ya) lcolor(gs10) lpattern(dash)), ///
        `title' ///
        `diff_trend_gopts' `annual_xaxisopts' ///
        legend(off) ///
        name(tdiff_ky_ratio, replace)

    local total_diff_graphs "`total_diff_graphs' tdiff_ky_ratio"
}

// Panel 7: Row-2 diagnostics requested by user
// (1) L vs Ramsey N with baseline+scenario overlaid in one plot (4 lines)
// (2) h level index (baseline vs scenario)
// (3) SimPaths participation rate = workersCount / WAP (baseline vs scenario)

local pop_gopts "ylabel(, angle(0) labsize(vsmall))"
local pop_gopts "`pop_gopts' xtitle("", size(small))"
local pop_gopts "`pop_gopts' graphregion(color(white)) plotregion(margin(small))"
local pop_legstyle "size(*.55) position(6) rows(1) region(lstyle(none)) symxsize(3.5pt) rowgap(0)"
local pop_legstyle_8 "size(*.5) position(6) rows(2) region(lstyle(none)) symxsize(3pt) rowgap(0)"
local pop_legstyle_10 "size(*.45) position(6) rows(2) region(lstyle(none)) symxsize(2.5pt) rowgap(0)"

local pop_graphs ""

// 7.1 L vs Ramsey N (baseline + scenario overlaid)
cap confirm variable l_level l_level_base n_ramsey n_ramsey_base
if _rc == 0 {
    cap confirm variable total_population total_population_base wap_level wap_level_base atRiskPool_level atRiskPool_level_base
    if _rc == 0 {
        local title = cond(`show_titles', `"title("Population, WAP, at-risk Pool, Participation (SimPaths), Ramsey N", size(small))"', "")
        twoway ///
            (line l_level_base ya if annual_plot,              lpattern(dash)  lcolor(gs8)          lwidth(medium)) ///
            (line l_level ya if annual_plot,                   lpattern(solid) lcolor(navy)         lwidth(medium)) ///
            (line n_ramsey_base ya if annual_plot,             lpattern(dash)  lcolor(cranberry)    lwidth(medium)) ///
            (line n_ramsey ya if annual_plot,                  lpattern(solid) lcolor(cranberry)    lwidth(medium)) ///
            (line total_population_base ya if annual_plot,     lpattern(dash)  lcolor(purple)       lwidth(medium)) ///
            (line total_population ya if annual_plot,          lpattern(solid) lcolor(purple)       lwidth(medium)) ///
            (line wap_level_base ya if annual_plot,            lpattern(dash)  lcolor(forest_green) lwidth(medium)) ///
            (line wap_level ya if annual_plot,                 lpattern(solid) lcolor(forest_green) lwidth(medium)) ///
            (line atRiskPool_level_base ya if annual_plot,     lpattern(dash)  lcolor(dkorange)     lwidth(medium)) ///
            (line atRiskPool_level ya if annual_plot,          lpattern(solid) lcolor(dkorange)     lwidth(medium)), ///
            `title' ///
            ytitle("% from first year", size(vsmall)) ///
            `pop_gopts' `annual_xaxisopts' ///
            legend(order(1 "L baseline" 2 "L scenario" 3 "N baseline" 4 "N scenario" 5 "Pop baseline" 6 "Pop scenario" 7 "WAP baseline" 8 "WAP scenario" 9 "atRisk baseline" 10 "atRisk scenario") `pop_legstyle_10') ///
            name(pop_l_vs_n, replace)
    }
    else {
        local title = cond(`show_titles', `"title("Participation (SimPaths), Ramsey N", size(small))"', "")
        twoway ///
            (line l_level_base ya if annual_plot, lpattern(dash)  lcolor(gs8)       lwidth(medium)) ///
            (line l_level ya if annual_plot,      lpattern(solid) lcolor(navy)      lwidth(medium)) ///
            (line n_ramsey_base ya if annual_plot,lpattern(dash)  lcolor(cranberry) lwidth(medium)) ///
            (line n_ramsey ya if annual_plot,     lpattern(solid) lcolor(cranberry) lwidth(medium)), ///
            `title' ///
            ytitle("% from first year", size(vsmall)) ///
            `pop_gopts' `annual_xaxisopts' ///
            legend(order(1 "L baseline" 2 "L scenario" 3 "N baseline" 4 "N scenario") `pop_legstyle') ///
            name(pop_l_vs_n, replace)
    }

    local pop_graphs "`pop_graphs' pop_l_vs_n"
}

// 7.2 h level index (baseline vs scenario)
cap confirm variable h_level h_level_base
local title = cond(`show_titles', `"title("Hours per worker h (SimPaths)", size(small))"', "")

if _rc == 0 {
    twoway ///
        (line h_level_base ya if annual_plot, lpattern(dash)  lcolor(gs8)  lwidth(medium)) ///
        (line h_level ya if annual_plot,      lpattern(solid) lcolor(navy) lwidth(medium)), ///
        `title' ///
        ytitle("% from first year", size(vsmall)) ///
        `pop_gopts' `annual_xaxisopts' ///
        legend(order(1 "Baseline" 2 "Scenario") `pop_legstyle') ///
        name(pop_h_level, replace)

    local pop_graphs "`pop_graphs' pop_h_level"
}

// 7.3 Participation rates (SimPaths vs Ramsey) — indexed to first year
// The two series are different objects with different anchors: l_ramsey is the
// FOC-solved Ramsey participation N/WAP (SNA-anchored, model-solved, drifts
// under sigma>1), while participation_rate is the SimPaths micro employment
// rate (LFS-anchored, measured). Comparing them in levels exaggerates a purely
// definitional ~20pp offset and hides the dynamics. Index each series to its
// own first valid (>0) annual value and plot % change from first year, so the
// comparison isolates the dynamics (incl. the sigma>1 Ramsey drift). Leading
// pre-labour-market zeros are left missing (line starts at first valid year, no
// spurious -100 jump); a series that is zero throughout (e.g. l_ramsey in
// exogenous mode) stays flat at 0, as before.
cap confirm variable participation_rate participation_rate_base
if _rc == 0 {
    cap drop _ord
    gen long _ord = _n
    foreach vv in participation_rate participation_rate_base l_ramsey l_ramsey_base {
        cap confirm variable `vv'
        if _rc == 0 {
            cap drop i_`vv'
            quietly gen double i_`vv' = .
            quietly summarize _ord if annual_plot & `vv' > 0 & !missing(`vv')
            if r(N) > 0 {
                local _anch = `vv'[r(min)]
                quietly replace i_`vv' = (`vv' / `_anch' - 1) * 100 if `vv' > 0 & !missing(`vv')
            }
            else {
                quietly replace i_`vv' = 0
            }
            label var i_`vv' "`vv' (% from first year)"
        }
    }
    cap drop _ord

    cap confirm variable i_l_ramsey i_l_ramsey_base
    if _rc == 0 {
        local title = cond(1, `"title("Participation rates (SimPaths vs Ramsey)", size(small))"', "")
        twoway ///
            (line i_participation_rate_base ya if annual_plot, lpattern(dash)  lcolor(gs8)       lwidth(medium)) ///
            (line i_participation_rate ya if annual_plot,      lpattern(solid) lcolor(navy)      lwidth(medium)) ///
            (line i_l_ramsey_base ya if annual_plot,           lpattern(dash)  lcolor(cranberry) lwidth(medium)) ///
            (line i_l_ramsey ya if annual_plot,                lpattern(solid) lcolor(cranberry) lwidth(medium)), ///
            `title' ///
            ytitle("% from first year", size(vsmall)) ///
            `pop_gopts' `annual_xaxisopts' ///
            legend(order(1 "SimPaths (baseline)" 2 "SimPaths (scenario)" 3 "Ramsey (baseline)" 4 "Ramsey (scenario)") `pop_legstyle_8') ///
            name(pop_participation, replace)
    }
    else {
        local title = cond(1, `"title("Participation rates (SimPaths)", size(small))"', "")
        twoway ///
            (line i_participation_rate_base ya if annual_plot, lpattern(dash)  lcolor(gs8)  lwidth(medium)) ///
            (line i_participation_rate ya if annual_plot,      lpattern(solid) lcolor(navy) lwidth(medium)), ///
            `title' ///
            ytitle("% from first year", size(vsmall)) ///
            `pop_gopts' `annual_xaxisopts' ///
            legend(order(1 "Baseline" 2 "Scenario") `pop_legstyle') ///
            name(pop_participation, replace)
    }

    local pop_graphs "`pop_graphs' pop_participation"
}

// 7.4 Realised and exogenous wage paths (baseline vs scenario)
// At-risk pool (Person.atRiskOfWork() within ages 15-64) mean labWageHrly,
// emitted by MacroPathRecorder as % change from the simulation start year
// (= 0 in the start year), so the realised wage shares units with w_total and
// the two wage concepts can sit on a common axis. Always present,
// including when the macro model is off. Averaging over the at-risk pool —
// the exact population that enters the SimPaths discrete-choice labour-supply
// model — keeps the wage diagnostic internally consistent with
// participation_rate, workers_over_atriskpool and the labour-category panels
// (cf. SP_CHATS_107 / SP_CHATS_108).
cap confirm variable wage_realized wage_realized_base w_total w_total_base
if _rc == 0 {
    local rw_growth_base_fmt "n.a."
    local rw_growth_scen_fmt "n.a."
    local wt_growth_base_fmt "n.a."
    local wt_growth_scen_fmt "n.a."
    local rw_growth_box ""

    cap drop _ord
    gen long _ord = _n

    // wage_realized = (mean_t/mean_0 - 1) * 100, so the cumulative ratio is
    // (1 + wage_realized/100) and the annualised growth rate is
    // ((1 + wage_realized_last/100)^(1/years) - 1) * 100.
    quietly summarize _ord if annual_plot & !missing(wage_realized_base)
    if r(N) >= 2 {
        local rw_first_base = r(min)
        local rw_last_base = r(max)
        local rw_years_base = ya[`rw_last_base'] - ya[`rw_first_base']
        if `rw_years_base' > 0 & !missing(wage_realized_base[`rw_last_base']) {
            local rw_growth_base = ((1 + wage_realized_base[`rw_last_base']/100)^(1 / `rw_years_base') - 1) * 100
            local rw_growth_base_fmt : display %4.2f `rw_growth_base'
        }
    }

    quietly summarize _ord if annual_plot & !missing(wage_realized)
    if r(N) >= 2 {
        local rw_first_scen = r(min)
        local rw_last_scen = r(max)
        local rw_years_scen = ya[`rw_last_scen'] - ya[`rw_first_scen']
        if `rw_years_scen' > 0 & !missing(wage_realized[`rw_last_scen']) {
            local rw_growth_scen = ((1 + wage_realized[`rw_last_scen']/100)^(1 / `rw_years_scen') - 1) * 100
            local rw_growth_scen_fmt : display %4.2f `rw_growth_scen'
        }
    }

    quietly summarize _ord if annual_plot & !missing(w_total_base)
    if r(N) >= 2 {
        local wt_first_base = r(min)
        local wt_last_base = r(max)
        local wt_years_base = ya[`wt_last_base'] - ya[`wt_first_base']
        if `wt_years_base' > 0 & !missing(w_total_base[`wt_last_base']) {
            local wt_growth_base = ((1 + w_total_base[`wt_last_base']/100)^(1 / `wt_years_base') - 1) * 100
            local wt_growth_base_fmt : display %4.2f `wt_growth_base'
        }
    }

    quietly summarize _ord if annual_plot & !missing(w_total)
    if r(N) >= 2 {
        local wt_first_scen = r(min)
        local wt_last_scen = r(max)
        local wt_years_scen = ya[`wt_last_scen'] - ya[`wt_first_scen']
        if `wt_years_scen' > 0 & !missing(w_total[`wt_last_scen']) {
            local wt_growth_scen = ((1 + w_total[`wt_last_scen']/100)^(1 / `wt_years_scen') - 1) * 100
            local wt_growth_scen_fmt : display %4.2f `wt_growth_scen'
        }
    }

    quietly summarize ya if annual_plot, meanonly
    local rw_x_min = r(min)
    local rw_x_max = r(max)

    cap drop _rw_ymin _rw_ymax
    egen double _rw_ymin = rowmin(wage_realized wage_realized_base w_total w_total_base)
    egen double _rw_ymax = rowmax(wage_realized wage_realized_base w_total w_total_base)
    quietly summarize _rw_ymin if annual_plot, meanonly
    local rw_y_min = r(min)
    quietly summarize _rw_ymax if annual_plot, meanonly
    local rw_y_max = r(max)

    local rw_x_span = `rw_x_max' - `rw_x_min'
    local rw_y_span = `rw_y_max' - `rw_y_min'
    if `rw_x_span' <= 0 {
        local rw_x_span = 1
    }
    if `rw_y_span' <= 0 {
        local rw_y_span = 1
    }

    local rw_x_box = `rw_x_min' + 0.03 * `rw_x_span'
    local rw_y_box = `rw_y_max' - 0.03 * `rw_y_span'
    local rw_growth_box `"text(`rw_y_box' `rw_x_box' "Avg. yearly growth" "Baseline: `rw_growth_base_fmt'% (realised), `wt_growth_base_fmt'% (exogenous)" "Scenario: `rw_growth_scen_fmt'% (realised), `wt_growth_scen_fmt'% (exogenous)", place(se) box justification(left) margin(small) fcolor(white%85) lcolor(gs10) size(vsmall))"'

    cap drop _rw_ymin _rw_ymax _ord

    local title = cond(`show_titles', `"title("Realised wage (at-risk pool) vs. exogenous wage", size(small))"', "")
    twoway ///
        (line wage_realized_base ya if annual_plot, lpattern(dash)  lcolor(blue) lwidth(medium)) ///
        (line wage_realized ya if annual_plot,      lpattern(solid) lcolor(blue) lwidth(medium)) ///
        (line w_total_base ya if annual_plot,       lpattern(dash)  lcolor(red)  lwidth(medium)) ///
        (line w_total ya if annual_plot,            lpattern(solid) lcolor(red)  lwidth(medium)), ///
        `title' ///
        ytitle("% from first year", size(vsmall)) ///
        `rw_growth_box' ///
        `pop_gopts' `annual_xaxisopts' ///
        legend(order(1 "Baseline realised" 2 "Scenario realised" 3 "Baseline exogenous" 4 "Scenario exogenous") `pop_legstyle_8') ///
        name(pop_realized_wage, replace)

    local pop_graphs "`pop_graphs' pop_realized_wage"
}


// ============================================================================
// 11. PANEL 8: LABOUR CATEGORY SHARES AND MEAN HOURS
// ============================================================================

local cat_gopts "ylabel(0(20)100, angle(0) labsize(vsmall))"
local cat_gopts "`cat_gopts' xtitle("", size(small))"
local cat_gopts "`cat_gopts' graphregion(color(white)) plotregion(margin(small))"
local cat_legstyle "size(*.5) position(6) rows(2) region(lstyle(none)) symxsize(3pt) rowgap(0)"
local cat_line_legstyle "size(*.45) position(6) rows(2) region(lstyle(none)) symxsize(2.5pt) rowgap(0)"

local category_graphs ""

if `do_category_share_graphs' {
    cap confirm variable cat_share_cum1_base cat_share_cum2_base cat_share_cum3_base cat_share_cum4_base
    if _rc == 0 {
        local title = cond(`show_titles', `"title("Category shares: $baseline_label", size(small))"', "")
        twoway ///
            (rarea cat_share_zero      cat_share_cum1_base ya if annual_plot, sort vertical color(navy)         fintensity(45)) ///
            (rarea cat_share_cum1_base cat_share_cum2_base ya if annual_plot, sort vertical color(forest_green) fintensity(45)) ///
            (rarea cat_share_cum2_base cat_share_cum3_base ya if annual_plot, sort vertical color(dkorange)     fintensity(45)) ///
            (rarea cat_share_cum3_base cat_share_cum4_base ya if annual_plot, sort vertical color(cranberry)    fintensity(45)), ///
            `title' ///
            ytitle("Share of at-risk pool (%)", size(vsmall)) ///
            `cat_gopts' `annual_xaxisopts' ///
            yscale(range(0 100)) ///
            legend(order(1 "`cat_label_0'" 2 "`cat_label_1'" 3 "`cat_label_2'" 4 "`cat_label_3'") `cat_legstyle') ///
            name(catshare_base, replace)

        local category_graphs "`category_graphs' catshare_base"
    }

    cap confirm variable cat_share_cum1 cat_share_cum2 cat_share_cum3 cat_share_cum4
    if _rc == 0 {
        local title = cond(`show_titles', `"title("Category shares: $scenario_label", size(small))"', "")
        twoway ///
            (rarea cat_share_zero cat_share_cum1 ya if annual_plot, sort vertical color(navy)         fintensity(45)) ///
            (rarea cat_share_cum1 cat_share_cum2 ya if annual_plot, sort vertical color(forest_green) fintensity(45)) ///
            (rarea cat_share_cum2 cat_share_cum3 ya if annual_plot, sort vertical color(dkorange)     fintensity(45)) ///
            (rarea cat_share_cum3 cat_share_cum4 ya if annual_plot, sort vertical color(cranberry)    fintensity(45)), ///
            `title' ///
            ytitle("Share of at-risk pool (%)", size(vsmall)) ///
            `cat_gopts' `annual_xaxisopts' ///
            yscale(range(0 100)) ///
            legend(order(1 "`cat_label_0'" 2 "`cat_label_1'" 3 "`cat_label_2'" 4 "`cat_label_3'") `cat_legstyle') ///
            name(catshare_scen, replace)

        local category_graphs "`category_graphs' catshare_scen"
    }

    cap confirm variable diff_cat_0_share diff_cat_1_share diff_cat_2_share diff_cat_3_share
    if _rc == 0 {
        local title = cond(`show_titles', `"title("Category-share change: scenario - baseline", size(small))"', "")
        twoway ///
            (line diff_cat_0_share ya if annual_plot, lcolor(navy)         lwidth(medium)) ///
            (line diff_cat_1_share ya if annual_plot, lcolor(forest_green) lwidth(medium)) ///
            (line diff_cat_2_share ya if annual_plot, lcolor(dkorange)     lwidth(medium)) ///
            (line diff_cat_3_share ya if annual_plot, lcolor(cranberry)    lwidth(medium)) ///
            (function y=0, range(ya) lcolor(gs10) lpattern(dash)), ///
            `title' ///
            ytitle("pp vs baseline", size(vsmall)) ///
            `diff_trend_gopts' `annual_xaxisopts' ///
            legend(order(1 "`cat_label_0'" 2 "`cat_label_1'" 3 "`cat_label_2'" 4 "`cat_label_3'") `cat_legstyle') ///
            name(catshare_diff, replace)

        local category_graphs "`category_graphs' catshare_diff"
    }
}

if `do_category_meanhours_graph' {
    cap confirm variable cat_0_meanhours cat_1_meanhours cat_2_meanhours cat_3_meanhours cat_0_meanhours_base cat_1_meanhours_base cat_2_meanhours_base cat_3_meanhours_base
    if _rc == 0 {
        local title = cond(`show_titles', `"title("Mean hours within each labour category", size(small))"', "")
        twoway ///
            (line cat_0_meanhours_base ya if annual_plot, lpattern(dash)  lcolor(navy)         lwidth(medium)) ///
            (line cat_0_meanhours ya if annual_plot,      lpattern(solid) lcolor(navy)         lwidth(medium)) ///
            (line cat_1_meanhours_base ya if annual_plot, lpattern(dash)  lcolor(forest_green) lwidth(medium)) ///
            (line cat_1_meanhours ya if annual_plot,      lpattern(solid) lcolor(forest_green) lwidth(medium)) ///
            (line cat_2_meanhours_base ya if annual_plot, lpattern(dash)  lcolor(dkorange)     lwidth(medium)) ///
            (line cat_2_meanhours ya if annual_plot,      lpattern(solid) lcolor(dkorange)     lwidth(medium)) ///
            (line cat_3_meanhours_base ya if annual_plot, lpattern(dash)  lcolor(cranberry)    lwidth(medium)) ///
            (line cat_3_meanhours ya if annual_plot,      lpattern(solid) lcolor(cranberry)    lwidth(medium)), ///
            `title' ///
            ytitle("Mean weekly hours in category", size(vsmall)) ///
            `pop_gopts' `annual_xaxisopts' ///
            legend(order(1 "`cat_label_0' baseline" 2 "`cat_label_0' scenario" 3 "`cat_label_1' baseline" 4 "`cat_label_1' scenario" 5 "`cat_label_2' baseline" 6 "`cat_label_2' scenario" 7 "`cat_label_3' baseline" 8 "`cat_label_3' scenario") `cat_line_legstyle') ///
            name(catmeanhours, replace)

        local category_graphs "`category_graphs' catmeanhours"
    }
}



// ============================================================================
// COMBINE PANELS INTO FINAL FIGURE(S)
// ============================================================================

set graph on

// Panel 1: Cycle levels
if `do_cycle_level_graphs' & "`cycle_level_graphs'" != "" {
    local title = cond(`show_titles', `"title("$baseline_label vs $scenario_label", size(small))"', "")
    graph combine `cycle_level_graphs', ///
        `title' ///
        subtitle("DSGE integration — level indices", size(small)) ///
        rows(2) cols(3) ///
        /// xsize(16) ysize(8) ///
        name(cycle_levels, replace)
    
    graph export cycle_levels.png, replace
    graph export cycle_levels.pdf, replace
}

// Panel 2: Cycle differences
if `do_cycle_diff_graphs' & "`cycle_diff_graphs'" != "" {
    local title = cond(`show_titles', `"title("Scenario Effect: $baseline_label vs $scenario_label", size(small))"', "")
    graph combine `cycle_diff_graphs', ///
        `title' ///
        subtitle("Difference from baseline (pp)", size(small)) ///
        rows(2) cols(3) ///
        /// xsize(16) ysize(8) ///
        name(cycle_diffs, replace)
    
    // graph save cycle_diffs.gph, replace
    graph export cycle_diffs.png, replace
    graph export cycle_diffs.pdf, replace
}

// Panel 3: Trend levels
if `do_trend_level_graphs' & "`trend_level_graphs'" != "" {
    local title = cond(`show_titles', `"title("Ramsey Trend: $baseline_label vs $scenario_label", size(small))"', "")
    graph combine `trend_level_graphs', ///
        `title' ///
        subtitle("Annual structural trend index (% from first year)", size(small)) ///
        rows(2) cols(3) ///
        /// xsize(18) ysize(5) ///
        name(trends_levels, replace)
    
    graph export trends_levels.png, replace
    graph export trends_levels.pdf, replace
}

// Panel 4: Trend differences
if `do_trend_diff_graphs' & "`trend_diff_graphs'" != "" {
    local title = cond(`show_titles', `"title("Scenario Effect on Ramsey Trend: $baseline_label vs $scenario_label", size(small))"', "")
    graph combine `trend_diff_graphs', ///
        `title' ///
        subtitle("Annual scenario run minus baseline run (pp)", size(small)) ///
        rows(2) cols(3) ///
        /// xsize(18) ysize(5) ///
        name(trend_diffs, replace)
    
    // graph save trend_diffs.gph, replace
    graph export trend_diffs.png, replace
    graph export trend_diffs.pdf, replace
}

// Panel 5: Total levels
if `do_total_level_graphs' & "`total_level_graphs'" != "" {
    local title = cond(`show_titles', `"title("Total (Cycle + Trend): $baseline_label vs $scenario_label", size(small))"', "")
    graph combine `total_level_graphs', ///
        `title' ///
        subtitle("Annual total index (% from first year)", size(small)) ///
        rows(2) cols(3) ///
        /// xsize(18) ysize(5) ///
        name(total_levels, replace)
    
    graph export total_levels.png, replace
    graph export total_levels.pdf, replace
}

// Panel 6: Total differences
if `do_total_diff_graphs' & "`total_diff_graphs'" != "" {
    local title = cond(`show_titles', `"title("Scenario Effect on Total Variables: $baseline_label vs $scenario_label", size(small))"', "")
    graph combine `total_diff_graphs', ///
        `title' ///
        subtitle("Annual scenario run minus baseline run (pp)", size(small)) ///
        rows(2) cols(3) ///
        /// xsize(18) ysize(5) ///
        name(total_diffs, replace)

    graph export total_diffs.png, replace
    graph export total_diffs.pdf, replace
}

// Panel 7: Population & labour levels
if `do_pop_level_graphs' & "`pop_graphs'" != "" {
    local ngraphs : word count `pop_graphs'
    local ncols = min(`ngraphs', 2)
    local nrows = ceil(`ngraphs' / `ncols')
    local title = cond(`show_titles', `"title("Demographics & Labour Levels: $baseline_label vs $scenario_label", size(small))"', "")
    graph combine `pop_graphs', ///
        `title' ///
        rows(`nrows') cols(`ncols') ///
        /// xsize(18) ysize(5) ///
        name(pop_levels, replace)

    graph export pop_levels.png, replace
    graph export pop_levels.pdf, replace

    #d ;
    local names `"
    "Demographics"
    "Hours_per_worker"
    "Participation_rates"
    "Realized_wage_index"
    "'
    ; #d cr
    local i = 0
    foreach g of local pop_graphs {
        local gname : word `++i' of `names'
        graph display `g'
        graph export `gname'.pdf, replace
        graph export `gname'.png, replace
    }
}

// Panel 8a: Labour-category shares and mean hours
if ( `do_category_share_graphs' | `do_category_meanhours_graph' ) & "`category_graphs'" != "" {
    local ngraphs : word count `category_graphs'
    local ncols = min(`ngraphs', 2)
    local nrows = ceil(`ngraphs' / `ncols')
    local title = cond(`show_titles', `"title("Labour-category diagnostics: $baseline_label vs $scenario_label", size(small))"', "")
    graph combine `category_graphs', ///
        `title' ///
        rows(`nrows') cols(`ncols') ///
        name(category_diagnostics, replace)

    graph export category_diagnostics.png, replace
    graph export category_diagnostics.pdf, replace

    capture graph display catshare_base
    if _rc == 0 {
        graph export category_share_baseline.png, replace
        graph export category_share_baseline.pdf, replace
    }

    capture graph display catshare_scen
    if _rc == 0 {
        graph export category_share_scenario.png, replace
        graph export category_share_scenario.pdf, replace
    }

    capture graph display catshare_diff
    if _rc == 0 {
        graph export category_share_diff.png, replace
        graph export category_share_diff.pdf, replace
    }

    capture graph display catmeanhours
    if _rc == 0 {
        graph export category_meanhours.png, replace
        graph export category_meanhours.pdf, replace
    }
}

// ============================================================================
// PANEL 8b (opt-in): L AND N LEVELS — baseline + scenario
// ============================================================================
// The Demographics panel restricted to the two macro-coupling variables: the
// SimPaths extensive margin L and the Ramsey labour input N. Same series,
// styling and units (% from first year) as in the Demographics panel — just
// without Pop/WAP/atRisk. Note N baseline is zero by construction: n_ramsey
// only exists when the macro model is on, so the no-macro baseline run has
// n_ramsey_base = 0.
if `do_pop_level_LN_graph' {
    cap confirm variable l_level l_level_base n_ramsey n_ramsey_base
    if _rc == 0 {
        local title = cond(`show_titles', `"title("Demographics: L (SimPaths) and N (Ramsey", size(small))"', "")
        twoway ///
            (line l_level_base ya  if annual_plot, lpattern(dash)  lcolor(gs8)       lwidth(medium)) ///
            (line l_level ya       if annual_plot, lpattern(solid) lcolor(navy)      lwidth(medium)) ///
            (line n_ramsey_base ya if annual_plot, lpattern(dash)  lcolor(cranberry) lwidth(medium)) ///
            (line n_ramsey ya      if annual_plot, lpattern(solid) lcolor(cranberry) lwidth(medium)), ///
            `title' ///
            ytitle("% from first year", size(vsmall)) ///
            `pop_gopts' `annual_xaxisopts' ///
            legend(order(1 "L baseline" 2 "L scenario" 3 "N baseline" 4 "N scenario") `pop_legstyle') ///
            name(Demographics_LN, replace)

        graph display Demographics_LN
        graph export Demographics_LN.png, replace
        graph export Demographics_LN.pdf, replace
    }
    else {
        display as text "Demographics_LN graph skipped: l_level / n_ramsey not available."
    }
}


// ============================================================================
// 10. SUMMARY TABLE
// ============================================================================

quietly {
    cap log close
    log using scenario_comparison.txt, text replace

    noi display _newline
    noi display as text "{hline 80}"
    noi display as text "Scenario comparison: $scenario_label"
    noi display as text "{hline 80}"

    // --- Cycle variables ---
    noi display _newline
    noi display as text "DSGE CYCLE VARIABLES"
    noi display as text "{hline 80}"
    noi display as text %20s "Variable" %15s "Max |diff|" %15s "Mean diff" %15s "Last diff"
    noi display as text "{hline 80}"

    foreach var of local cycle_vars {
        cap confirm variable diff_`var'
        if _rc == 0 {
            quietly summarize diff_`var'
            local maxabs = max(abs(r(min)), abs(r(max)))
            local meandiff = r(mean)
            
            // Get last observation
            quietly summarize t
            local T = r(max)
            local lastdiff = diff_`var'[`T']

            noi display as result %20s "`var'" %15.4f `maxabs' %15.4f `meandiff' %15.4f `lastdiff'
        }
    }

    // --- Trend variables ---
    noi display _newline
    noi display as text "RAMSEY TREND VARIABLES"
    noi display as text "{hline 80}"
    noi display as text %20s "Variable" %15s "Max |diff|" %15s "Mean diff" %15s "Last diff" %15s "Last level"
    noi display as text "{hline 80}"

    foreach var of local trend_vars {
        cap confirm variable diff_`var'
        if _rc == 0 {
            quietly summarize diff_`var'
            local maxabs = max(abs(r(min)), abs(r(max)))
            local meandiff = r(mean)

            quietly summarize t
            local T = r(max)
            local lastdiff = diff_`var'[`T']
            local lastlevel = `var'[`T']

            noi display as result %20s "`var'" %15.4f `maxabs' %15.4f `meandiff' %15.4f `lastdiff' %15.2f `lastlevel'
        }
    }

    // --- Total variables ---
    noi display _newline
    noi display as text "TOTAL VARIABLES (cycle + trend)"
    noi display as text "{hline 80}"
    noi display as text %20s "Variable" %15s "Max |diff|" %15s "Mean diff" %15s "Last diff" %15s "Last level"
    noi display as text "{hline 80}"

    foreach var of local total_vars {
        cap confirm variable diff_`var'
        if _rc == 0 {
            quietly summarize diff_`var'
            local maxabs = max(abs(r(min)), abs(r(max)))
            local meandiff = r(mean)

            quietly summarize t
            local T = r(max)
            local lastdiff = diff_`var'[`T']
            local lastlevel = `var'[`T']

            noi display as result %20s "`var'" %15.4f `maxabs' %15.4f `meandiff' %15.4f `lastdiff' %15.2f `lastlevel'
        }
    }

    // --- Population / labour level variables ---
    noi display _newline
    noi display as text "POPULATION & LABOUR LEVELS (cumulative indices, % from first year)"
    noi display as text "{hline 80}"
    noi display as text %20s "Variable" %15s "Max |diff|" %15s "Mean diff" %15s "Last diff" %15s "Last level"
    noi display as text "{hline 80}"

    foreach var of local pop_vars {
        cap confirm variable diff_`var'
        if _rc == 0 {
            quietly summarize diff_`var'
            local maxabs = max(abs(r(min)), abs(r(max)))
            local meandiff = r(mean)

            quietly summarize t
            local T = r(max)
            local lastdiff = diff_`var'[`T']
            local lastlevel = `var'[`T']

            noi display as result %20s "`var'" %15.4f `maxabs' %15.4f `meandiff' %15.4f `lastdiff' %15.2f `lastlevel'
        }
    }

    // --- Additional variables ---
    noi display _newline
    noi display as text "ADDITIONAL VARIABLES (diagnostics + shocks)"
    noi display as text "{hline 80}"
    noi display as text %20s "Variable" %15s "Max |diff|" %15s "Mean diff" %15s "Last diff"
    noi display as text "{hline 80}"

    foreach var of local addvars {
        cap confirm variable diff_`var'
        if _rc == 0 {
            quietly summarize diff_`var'
            local maxabs = max(abs(r(min)), abs(r(max)))
            local meandiff = r(mean)

            quietly summarize t
            local T = r(max)
            local lastdiff = diff_`var'[`T']

            noi display as result %20s "`var'" %15.4f `maxabs' %15.4f `meandiff' %15.4f `lastdiff'
        }
    }

    noi display as text "{hline 80}"

    // Save merged dataset
    save scenario_merged.dta, replace
    noi display _newline
    noi display as text "Merged data saved to: $scenario_dir/scenario_merged.dta"
    noi display as text "Graphs saved to: $scenario_dir/"
    log close
}