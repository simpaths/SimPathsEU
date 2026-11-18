function result = render_dsge_fit_tables(summary_input, moments_output_file, vd_output_file, options)
% RENDER_DSGE_FIT_TABLES  Render moments and variance decomposition tables from one DSGE summary.

    arguments
        summary_input
        moments_output_file (1,:) char = ''
        vd_output_file (1,:) char = ''
        options.write_files (1,1) logical = true
    end

    summary = load_summary(summary_input);
    validate_documentation_summary(summary, 'dsge');

    country = summary.metadata.country;
    moments_text = build_moments_table(summary, country);
    vd_text = build_vd_table(summary, country);

    if options.write_files && ~isempty(moments_output_file)
        render_latex_table(moments_output_file, moments_text, ...
            'generated_by', 'render_dsge_fit_tables');
    end

    if options.write_files && ~isempty(vd_output_file)
        render_latex_table(vd_output_file, vd_text, ...
            'generated_by', 'render_dsge_fit_tables');
    end

    result = struct();
    result.country = country;
    result.moments_output_file = moments_output_file;
    result.vd_output_file = vd_output_file;
    result.moments_latex = moments_text;
    result.vd_latex = vd_text;
end

function summary = load_summary(summary_input)
    if isstruct(summary_input)
        summary = summary_input;
        return;
    end

    if isstring(summary_input)
        summary_input = char(summary_input);
    end

    if ischar(summary_input)
        if ~exist(summary_input, 'file')
            error('Summary file not found: %s', summary_input);
        end
        summary = jsondecode(fileread(summary_input));
        return;
    end

    error('summary_input must be a struct or a JSON file path.');
end

function latex_text = build_moments_table(summary, country)
    bs = char(92);
    row_break = [bs bs];
    observables = {'y', 'inv', 'c', 'pi', 'R', 'n', 'L', 'h'};
    lower_country = lower(country);

    lines = {
        [bs 'begin{table}[H]']
        [bs 'centering']
        [bs 'caption{Standard deviations and autocorrelations (' country ')}']
        [bs 'label{tab:moments_' lower_country '}']
        [bs 'begin{tabular}{lcccc}']
        [bs 'toprule']
        [' & ' bs 'multicolumn{2}{c}{Std.' bs ' dev.' bs ' (' bs '%)} & ' bs 'multicolumn{2}{c}{AC1} ' row_break]
        ['Variable & Data & Model & Data & Model ' row_break]
        [bs 'midrule']
    };

    for idx = 1:numel(observables)
        row = find_moment_row(summary.moments, observables{idx});
        if isempty(row)
            error('Moment row %s not found in summary for %s.', observables{idx}, country);
        end
        lines{end + 1} = sprintf('%s & %.2f & %.2f & %.2f & %.2f %s', ...
            observable_label(observables{idx}), ...
            row.data_std, row.model_std, row.data_ac1, row.model_ac1, row_break); %#ok<AGROW>
    end

    lines = [lines; {
        [bs 'bottomrule']
        [bs 'end{tabular}']
        [bs 'end{table}']
    }];

    latex_text = strjoin(lines, newline);
end

function latex_text = build_vd_table(summary, country)
    bs = char(92);
    row_break = [bs bs];
    observables = {'y', 'inv', 'c', 'pi', 'R', 'n', 'L', 'h'};
    shocks = {'eps_a', 'eps_d', 'eps_r', 'eps_p', 'eps_L', 'eps_sep', 'eps_h', 'eps_inv'};
    lower_country = lower(country);

    lines = {
        [bs 'begin{table}[H]']
        [bs 'centering']
        [bs 'caption{Posterior mean variance decomposition (' country ', percent shares)}']
        [bs 'label{tab:vd_' lower_country '}']
        [bs 'begin{tabular}{lcccccccc}']
        [bs 'toprule']
        ['Variable & Tech & Demand & Monet. & Cost-p. & Lab.' bs ' force & Sep. & Hours & Inv. ' row_break]
        [bs 'midrule']
    };

    for idx = 1:numel(observables)
        row = find_vd_row(summary.variance_decomposition.rows, observables{idx});
        if isempty(row)
            error('Variance decomposition row %s not found in summary for %s.', observables{idx}, country);
        end

        share_values = cell(1, numel(shocks));
        for jdx = 1:numel(shocks)
            if ~isfield(row.shares_percent, shocks{jdx})
                error('Variance decomposition row %s is missing shock %s.', observables{idx}, shocks{jdx});
            end
            share_values{jdx} = format_share(row.shares_percent.(shocks{jdx}));
        end

        lines{end + 1} = sprintf('%s & %s & %s & %s & %s & %s & %s & %s & %s %s', ...
            observable_label(observables{idx}), ...
            share_values{1}, share_values{2}, share_values{3}, share_values{4}, ...
            share_values{5}, share_values{6}, share_values{7}, share_values{8}, row_break); %#ok<AGROW>
    end

    lines = [lines; {
        [bs 'bottomrule']
        [bs 'end{tabular}']
        [bs 'end{table}']
    }];

    latex_text = strjoin(lines, newline);
end

function row = find_moment_row(rows, observable)
    row = [];
    for idx = 1:numel(rows)
        if strcmp(rows(idx).observable, observable)
            row = rows(idx);
            return;
        end
    end
end

function row = find_vd_row(rows, observable)
    row = [];
    for idx = 1:numel(rows)
        if strcmp(rows(idx).observable, observable)
            row = rows(idx);
            return;
        end
    end
end

function label = observable_label(observable)
    bs = char(92);
    switch observable
        case 'y'
            label = '$y$';
        case 'inv'
            label = ['$' bs 'mathrm{inv}$'];
        case 'c'
            label = '$c$';
        case 'pi'
            label = ['$' bs 'pi$'];
        case 'R'
            label = '$R$';
        case 'n'
            label = '$n$';
        case 'L'
            label = '$L$';
        case 'h'
            label = '$h$';
        otherwise
            label = observable;
    end
end

function text = format_share(value)
    if abs(value) < 0.05
        value = 0;
    end
    text = sprintf('%.1f', value);
    if strcmp(text, '-0.0')
        text = '0.0';
    end
end

