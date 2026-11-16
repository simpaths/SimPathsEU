/*******************************************************************************
 * _annual_axis_helper.do
 *
 * Shared helper for annual x-axis options in output_processing graphs.
 ******************************************************************************/

capture program drop annual_xaxis_opts
program define annual_xaxis_opts, rclass
    syntax varname(numeric) [if] [in] [, MAXLabels(integer 10) LABSize(string)]

    if "`labsize'" == "" {
        local labsize "vsmall"
    }

    local label_cap = max(`maxlabels', 2)

    quietly summarize `varlist' `if' `in', meanonly
    if r(N) == 0 {
        display as error "ERROR: annual_xaxis_opts requires at least one nonmissing observation."
        exit 2000
    }

    local first_ya = r(min)
    local last_ya = r(max)
    local x_label_span = `last_ya' - `first_ya'
    local x_label_step = 1
    local x_label_raw_step = max(1, ceil(`x_label_span' / (`label_cap' - 1)))

    foreach candidate in 1 2 3 4 5 10 15 20 25 30 40 50 {
        if `candidate' >= `x_label_raw_step' {
            local x_label_step = `candidate'
            continue, break
        }
    }

    if `x_label_step' < `x_label_raw_step' {
        local x_label_step = `x_label_raw_step'
    }

    local xlabels ""
    local xvalue = `first_ya'
    while `xvalue' <= `last_ya' {
        local xlabels "`xlabels' `xvalue'"
        local xvalue = `xvalue' + `x_label_step'
    }
    if `xvalue' - `x_label_step' != `last_ya' {
        local xlabels "`xlabels' `last_ya'"
    }
    local xlabels : list retokenize xlabels

    return scalar first_ya = `first_ya'
    return scalar last_ya = `last_ya'
    return scalar x_label_step = `x_label_step'
    return local xlabels "`xlabels'"
    return local xaxisopts "xlabel(`xlabels', angle(90) labsize(`labsize')) xscale(range(`first_ya' `last_ya') noextend)"
end