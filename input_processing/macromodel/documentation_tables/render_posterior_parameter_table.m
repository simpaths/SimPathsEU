function result = render_posterior_parameter_table(summary_input, output_file, options)
% RENDER_POSTERIOR_PARAMETER_TABLE  Render one country posterior table to LaTeX.

    arguments
        summary_input
        output_file (1,:) char = ''
        options.write_file (1,1) logical = true
    end

    summary = load_summary(summary_input);
    validate_documentation_summary(summary, 'dsge');

    country = summary.metadata.country;
    lower_country = lower(country);

    row_order = {'sigma_a', 'sigma_d', 'sigma_r', 'sigma_p', 'sigma_h', 'sigma_L', 'sigma_inv', 'omega_h', 'phi_inv_r'};
    label_map = get_posterior_label_map();
    rows = summary.posterior_parameters;
    bs = char(92);
    row_break = [char(92) char(92)];

    lines = {
        [bs 'begin{table}[H]']
        [bs 'centering']
        [bs 'begin{threeparttable}']
        [bs 'caption{Posterior parameter estimates (' country ')}']
        [bs 'label{tab:post_means_' lower_country '}']
        [bs 'begin{tabular}{lcccc}']
        [bs 'toprule']
        sprintf('Parameter & Prior mean & Posterior mean & 90\\%% HPD low & 90\\%% HPD high %s', row_break)
        [bs 'midrule']
    };

    for idx = 1:numel(row_order)
        row = find_posterior_row(rows, row_order{idx});
        if isempty(row)
            error('Posterior row %s not found in summary for %s.', row_order{idx}, country);
        end

        if isfield(label_map, row_order{idx})
            label = label_map.(row_order{idx});
        elseif isfield(row, 'label_latex') && ~isempty(row.label_latex)
            label = row.label_latex;
        else
            label = row.name;
        end

        lines{end + 1} = sprintf('%s & %.2f & %.2f & %.2f & %.2f %s', ...
            label, row.prior_mean, row.posterior_mean, row.hpd_low, row.hpd_high, row_break); %#ok<AGROW>
    end

    lines = [lines; {
        [bs 'bottomrule']
        [bs 'end{tabular}']
        [bs 'begin{tablenotes}[flushleft]']
        [bs 'footnotesize']
        [bs 'item Notes: HPD = highest posterior density. The HPD columns report the lower and upper bounds of the 90\% Bayesian credible interval, matching Dynare''s default interval level because no ' bs 'texttt{conf\_sig} override is set in the estimation block.']
        [bs 'end{tablenotes}']
        [bs 'end{threeparttable}']
        [bs 'end{table}']
    }];

    latex_text = strjoin(lines, newline);

    if options.write_file && ~isempty(output_file)
        render_latex_table(output_file, latex_text, ...
            'generated_by', 'render_posterior_parameter_table');
    end

    result = struct();
    result.country = country;
    result.output_file = output_file;
    result.latex_text = latex_text;
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

function row = find_posterior_row(rows, row_name)
    row = [];
    for idx = 1:numel(rows)
        if strcmp(rows(idx).name, row_name)
            row = rows(idx);
            return;
        end
    end
end

function label_map = get_posterior_label_map()
    bs = char(92);
    label_map = struct();
    label_map.sigma_a = ['$' bs 'sigma_a$ (technology)'];
    label_map.sigma_d = ['$' bs 'sigma_d$ (demand)'];
    label_map.sigma_r = ['$' bs 'sigma_r$ (monetary)'];
    label_map.sigma_p = ['$' bs 'sigma_p$ (cost-push)'];
    label_map.sigma_h = ['$' bs 'sigma_h$ (hours)'];
    label_map.sigma_L = ['$' bs 'sigma_L$ (labour force)'];
    label_map.sigma_inv = ['$' bs 'sigma_{' bs 'mathrm{inv}}$ (investment)'];
    label_map.omega_h = ['$' bs 'omega_h$ (hours weight)'];
    label_map.phi_inv_r = ['$' bs 'phi_{' bs 'mathrm{inv},r}$ (inv. interest sensitivity)'];
end