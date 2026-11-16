function result = render_dsge_parameter_classification_table(dsge_summary_dir, calibration_dir, output_file, options)
% RENDER_DSGE_PARAMETER_CLASSIFICATION_TABLE  Render a cross-country DSGE parameter reference table.

    arguments
        dsge_summary_dir (1,:) char
        calibration_dir (1,:) char
        output_file (1,:) char = ''
        options.write_file (1,1) logical = true
    end

    summary_files = dir(fullfile(dsge_summary_dir, 'dsge_postestimation_*.json'));
    if isempty(summary_files)
        error('No DSGE summary files found in %s.', dsge_summary_dir);
    end

    country_refs = load_country_references(summary_files, calibration_dir);
    row_specs = get_row_specs();

    bs = char(92);
    row_break = [bs bs];
    country_headers = cell(1, numel(country_refs));
    country_columns = repmat('p{1.5cm}', 1, numel(country_refs));
    for idx = 1:numel(country_refs)
        country_headers{idx} = country_refs(idx).country;
    end

    column_spec = ['p{3.4cm}p{1.7cm}' country_columns 'p{8.7cm}'];
    header_row = strjoin([{'Parameter', 'Symbol'}, country_headers, {'Classification / note'}], ' & ');
    column_count = 3 + numel(country_refs);

    lines = {
        [bs 'begin{landscape}']
        [bs 'begingroup']
        [bs 'footnotesize']
        [bs 'setlength{' bs 'LTleft}{0pt}']
        [bs 'setlength{' bs 'LTright}{0pt}']
        [bs 'renewcommand{' bs 'arraystretch}{0.95}']
        [bs 'begin{longtable}{' column_spec '}']
        [bs 'caption{DSGE parameter classification by country. Estimated rows report posterior means from post-estimation summaries; calibrated rows are read directly from the country calibration files.}']
        [bs 'label{tab:dsge_parameter_classification}' row_break]
        [bs 'toprule']
        [header_row ' ' row_break]
        [bs 'midrule']
        [bs 'endfirsthead']
        [bs 'multicolumn{' num2str(column_count) '}{l}{' bs 'textit{Table ' bs 'ref{tab:dsge_parameter_classification} continued}} ' row_break]
        [bs 'toprule']
        [header_row ' ' row_break]
        [bs 'midrule']
        [bs 'endhead']
        [bs 'multicolumn{' num2str(column_count) '}{r}{Continued on next page} ' row_break]
        [bs 'endfoot']
        [bs 'bottomrule']
        [bs 'endlastfoot']
    };

    current_group = '';
    for idx = 1:numel(row_specs)
        spec = row_specs(idx);
        if ~strcmp(current_group, spec.group)
            current_group = spec.group;
            lines{end + 1} = [bs 'multicolumn{' num2str(column_count) '}{l}{' bs 'textit{' spec.group '}} ' row_break]; %#ok<AGROW>
            lines{end + 1} = [bs 'midrule']; %#ok<AGROW>
        end

        row_cells = {spec.label, spec.symbol};
        for country_idx = 1:numel(country_refs)
            row_cells{end + 1} = format_value(get_row_value(country_refs(country_idx), spec), spec.decimals); %#ok<AGROW>
        end
        row_cells{end + 1} = spec.note;
        lines{end + 1} = [strjoin(row_cells, ' & ') ' ' row_break]; %#ok<AGROW>
    end

    lines = [lines; {
        [bs 'end{longtable}']
        [bs 'endgroup']
        [bs 'end{landscape}']
    }];

    latex_text = strjoin(lines, newline);

    if options.write_file && ~isempty(output_file)
        render_latex_table(output_file, latex_text, 'generated_by', 'render_dsge_parameter_classification_table');
    end

    result = struct();
    result.countries = {country_refs.country};
    result.output_file = output_file;
    result.latex_text = latex_text;
end

function country_refs = load_country_references(summary_files, calibration_dir)
    country_names = cell(1, numel(summary_files));
    country_refs = repmat(struct('country', '', 'summary', struct(), 'calibration', struct(), 'posterior', struct()), 1, numel(summary_files));

    for idx = 1:numel(summary_files)
        summary = jsondecode(fileread(fullfile(summary_files(idx).folder, summary_files(idx).name)));
        country_names{idx} = summary.metadata.country;
    end

    [~, order] = sort(lower(country_names));
    for list_idx = 1:numel(order)
        idx = order(list_idx);
        summary = jsondecode(fileread(fullfile(summary_files(idx).folder, summary_files(idx).name)));
        calibration_file = fullfile(calibration_dir, sprintf('%s_calibration.mod', summary.metadata.country));
        country_refs(list_idx) = load_dsge_country_reference(summary.metadata.country, calibration_file, summary);
    end
end

function specs = get_row_specs()
    bs = char(92);
    specs = [ ...
        row_spec('Estimated Parameters (posterior means)', 'Technology shock std.', ['$' bs 'sigma_a$'], 'posterior', 'sigma_a', 3, 'Estimated (posterior mean)')
        row_spec('Estimated Parameters (posterior means)', 'Demand shock std.', ['$' bs 'sigma_d$'], 'posterior', 'sigma_d', 3, 'Estimated (posterior mean)')
        row_spec('Estimated Parameters (posterior means)', 'Monetary shock std.', ['$' bs 'sigma_r$'], 'posterior', 'sigma_r', 3, 'Estimated (posterior mean)')
        row_spec('Estimated Parameters (posterior means)', 'Cost-push shock std.', ['$' bs 'sigma_p$'], 'posterior', 'sigma_p', 3, 'Estimated (posterior mean)')
        row_spec('Estimated Parameters (posterior means)', 'Hours shock std.', ['$' bs 'sigma_h$'], 'posterior', 'sigma_h', 3, 'Estimated (posterior mean)')
        row_spec('Estimated Parameters (posterior means)', 'Labour-force shock std.', ['$' bs 'sigma_L$'], 'posterior', 'sigma_L', 3, 'Estimated (posterior mean)')
        row_spec('Estimated Parameters (posterior means)', 'Investment shock std.', ['$' bs 'sigma_{' bs 'mathrm{inv}}$'], 'posterior', 'sigma_inv', 3, 'Estimated (posterior mean)')
        row_spec('Estimated Parameters (posterior means)', 'Hours output elasticity', ['$' bs 'omega_h$'], 'posterior', 'omega_h', 3, 'Estimated (posterior mean)')
        row_spec('Estimated Parameters (posterior means)', 'Investment-rate sensitivity', ['$' bs 'phi_{' bs 'mathrm{inv},r}$'], 'posterior', 'phi_inv_r', 3, 'Estimated (posterior mean)')
        row_spec('Calibrated Parameters -- Preferences and Technology', 'Discount factor', ['$' bs 'beta$'], 'calibration', 'beta', 2, 'Fixed, standard quarterly value')
        row_spec('Calibrated Parameters -- Preferences and Technology', 'Inverse IES', ['$' bs 'sigma$'], 'calibration', 'sigma', 2, 'Fixed (not identified)')
        row_spec('Calibrated Parameters -- Preferences and Technology', 'Habit persistence', ['$hab$'], 'calibration', 'hab', 2, 'Fixed external habit parameter')
        row_spec('Calibrated Parameters -- Preferences and Technology', 'Labour share', ['$' bs 'alpha_n$'], 'calibration', 'alpha_n', 2, 'National-accounts calibration')
        row_spec('Calibrated Parameters -- Preferences and Technology', 'Capital share', ['$' bs 'alpha_k$'], 'calibration', 'alpha_k', 2, 'National-accounts calibration')
        row_spec('Calibrated Parameters -- Preferences and Technology', 'Capital depreciation', ['$' bs 'delta_k$'], 'calibration', 'delta_k', 3, 'Quarterly capital law of motion')
        row_spec('Calibrated Parameters -- Preferences and Technology', 'Investment share in GDP', ['$s_{' bs 'mathrm{inv}}$'], 'calibration', 's_inv', 2, 'Expenditure-share calibration')
        row_spec('Calibrated Parameters -- Labour Market', 'Matching elasticity', ['$' bs 'alpha_m$'], 'calibration', 'alpha_m', 2, 'Literature-based matching elasticity')
        row_spec('Calibrated Parameters -- Labour Market', 'Bargaining power', ['$' bs 'eta$'], 'calibration', 'eta', 2, 'Hosios condition')
        row_spec('Calibrated Parameters -- Labour Market', 'Vacancy cost', ['$' bs 'kappa$'], 'calibration', 'kappa', 2, 'Vacancy posting cost calibration')
        row_spec('Calibrated Parameters -- Labour Market', 'Separation rate', ['$' bs 'delta$'], 'calibration', 'delta', 3, 'Quarterly separation rate')
        row_spec('Calibrated Parameters -- Labour Market', 'Wage stickiness (Calvo)', ['$' bs 'lambda_w$'], 'calibration', 'lambda_w', 2, 'Average wage duration calibration')
        row_spec('Calibrated Parameters -- Labour Market', 'Direct $L \to w$ elasticity', ['$' bs 'psi_{wL}$'], 'calibration', 'psi_wL', 2, 'Literature-guided wage-drift channel')
        row_spec('Calibrated Parameters -- Monetary Policy', 'Taylor: inflation', ['$' bs 'phi_' bs 'pi$'], 'calibration', 'phi_pi', 2, 'Taylor-principle calibration')
        row_spec('Calibrated Parameters -- Monetary Policy', 'Taylor: output', ['$' bs 'phi_y$'], 'calibration', 'phi_y', 3, 'Output-gap response')
        row_spec('Calibrated Parameters -- Monetary Policy', 'Interest smoothing', ['$' bs 'rho_r$'], 'calibration', 'rho_r', 2, 'Central-bank smoothing parameter')
        row_spec('Calibrated Parameters -- New Keynesian', 'Phillips curve slope', ['$' bs 'lambda_p$'], 'calibration', 'lambda_p', 2, 'Country-specific NKPC slope')
        row_spec('Calibrated Parameters -- New Keynesian', 'MC gap sensitivity', ['$' bs 'phi_{mc}$'], 'calibration', 'phi_mc', 2, 'Demand channel in marginal cost')
        row_spec('Calibrated Parameters -- New Keynesian', 'Vacancy gap response', ['$' bs 'phi_{v,y}$'], 'calibration', 'phi_v_y', 1, 'Demand amplification in vacancy posting')
        row_spec('Calibrated Parameters -- New Keynesian', 'Inflation indexation', ['$' bs 'iota_p$'], 'calibration', 'iota_p', 2, 'Hybrid NKPC indexation')
        row_spec('Calibrated Parameters -- Shock Persistence', 'Technology persistence', ['$' bs 'rho_a$'], 'calibration', 'rho_a', 2, 'Fixed persistence')
        row_spec('Calibrated Parameters -- Shock Persistence', 'Labour force persistence', ['$' bs 'rho_L$'], 'calibration', 'rho_L', 2, 'Fixed persistence')
        row_spec('Calibrated Parameters -- Shock Persistence', 'Hours persistence', ['$' bs 'rho_h$'], 'calibration', 'rho_h', 2, 'Fixed persistence')
        row_spec('Calibrated Parameters -- Shock Persistence', 'Vacancy persistence', ['$' bs 'rho_v$'], 'calibration', 'rho_v', 2, 'Fixed persistence')
        row_spec('Calibrated Parameters -- Shock Persistence', 'Separation persistence', ['$' bs 'rho_{sep}$'], 'calibration', 'rho_sep', 2, 'Fixed persistence')
        row_spec('Calibrated Parameters -- Shock Persistence', 'Demand persistence', ['$' bs 'rho_d$'], 'calibration', 'rho_d', 2, 'Fixed persistence')
        row_spec('Calibrated Parameters -- Shock Persistence', 'Investment persistence', ['$' bs 'rho_{' bs 'mathrm{inv}}$'], 'calibration', 'rho_inv', 2, 'Fixed persistence')
        row_spec('Calibrated Parameters -- Shock Persistence', 'Investment accelerator', ['$' bs 'phi_{' bs 'mathrm{inv},y}$'], 'calibration', 'phi_inv_y', 2, ['Fixed (collinear with $' bs 'rho_{' bs 'mathrm{inv}}$ in estimation)'])
        row_spec('Fixed Shock Standard Deviations', 'Separation shock std.', ['$' bs 'sigma_{sep}$'], 'calibration', 'sigma_sep', 2, 'Fixed for identification stability') ...
    ];
end

function spec = row_spec(group, label, symbol, value_source, field_name, decimals, note)
    spec = struct('group', group, 'label', label, 'symbol', symbol, 'value_source', value_source, 'field_name', field_name, 'decimals', decimals, 'note', note);
end

function value = get_row_value(country_ref, spec)
    switch spec.value_source
        case 'posterior'
            if ~isfield(country_ref.posterior, spec.field_name)
                error('Posterior parameter %s missing for %s.', spec.field_name, country_ref.country);
            end
            value = country_ref.posterior.(spec.field_name);
        case 'calibration'
            if ~isfield(country_ref.calibration, spec.field_name)
                error('Calibration parameter %s missing for %s.', spec.field_name, country_ref.country);
            end
            value = country_ref.calibration.(spec.field_name);
        otherwise
            error('Unknown value source: %s', spec.value_source);
    end
end

function text = format_value(value, decimals)
    text = sprintf(['%0.' num2str(decimals) 'f'], value);
end