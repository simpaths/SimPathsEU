/*******************************************************************************
 * _quarterly_axis_helper.do
 *
 * Shared helper for quarterly x-axis options in output_processing graphs.
 ******************************************************************************/

capture program drop quarterly_xaxis_opts
program define quarterly_xaxis_opts, rclass
    syntax varname(numeric) [if] [in] [, MAXLabels(integer 10) LABSize(string)]

    if "`labsize'" == "" {
        local labsize "vsmall"
    }

    local label_cap = max(`maxlabels', 2)

    quietly summarize `varlist' `if' `in', meanonly
    if r(N) == 0 {
        display as error "ERROR: quarterly_xaxis_opts requires at least one nonmissing observation."
        exit 2000
    }

    local first_yq = r(min)
    local last_yq = r(max)
    local x_label_span = `last_yq' - `first_yq'
    local x_label_step = 1
    local x_label_raw_step = max(1, ceil(`x_label_span' / (`label_cap' - 1)))

    foreach candidate in 1 2 4 8 12 16 20 24 32 40 {
        if `candidate' >= `x_label_raw_step' {
            local x_label_step = `candidate'
            continue, break
        }
    }

    if `x_label_step' < `x_label_raw_step' {
        local x_label_step = `x_label_raw_step'
    }

    local xlabels ""
    local xvalue = `first_yq'
    while `xvalue' <= `last_yq' {
        local xlabels "`xlabels' `xvalue'"
        local xvalue = `xvalue' + `x_label_step'
    }
    if `xvalue' - `x_label_step' != `last_yq' {
        local xlabels "`xlabels' `last_yq'"
    }
    local xlabels : list retokenize xlabels

    return scalar first_yq = `first_yq'
    return scalar last_yq = `last_yq'
    return scalar x_label_step = `x_label_step'
    return local xlabels "`xlabels'"
    return local xaxisopts "xlabel(`xlabels', angle(90) labsize(`labsize')) xscale(range(`first_yq' `last_yq') noextend)"
end