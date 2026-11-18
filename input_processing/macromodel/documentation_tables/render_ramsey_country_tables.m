function outputs = render_ramsey_country_tables(summary_dir, options)
% RENDER_RAMSEY_COUNTRY_TABLES  Render the cross-country Ramsey comparison tables.

    arguments
        summary_dir (1,:) char = fullfile('output', 'documentation_data', 'ramsey')
        options.structural_output_file (1,:) char = ''
        options.base_values_output_file (1,:) char = ''
        options.country_order (1,:) cell = {'Germany', 'Poland', 'Spain', 'Sweden', 'UK'}
        options.write_files (1,1) logical = true
    end

    summary_files = dir(fullfile(summary_dir, 'ramsey_summary_*.json'));
    if isempty(summary_files)
        error('No Ramsey summary files found in %s.', summary_dir);
    end

    summaries = cell(1, numel(summary_files));
    for idx = 1:numel(summary_files)
        summary_path = fullfile(summary_files(idx).folder, summary_files(idx).name);
        summary = jsondecode(fileread(summary_path));
        validate_documentation_summary(summary, 'ramsey');
        summaries{idx} = summary;
    end

    summaries = order_summaries(summaries, options.country_order);
    countries = cellfun(@(item) item.metadata.country, summaries, 'UniformOutput', false);

    structural_text = build_structural_table(summaries, countries);
    base_values_text = build_base_values_table(summaries, countries);

    if options.write_files && ~isempty(options.structural_output_file)
        render_latex_table(options.structural_output_file, structural_text, ...
            'generated_by', 'render_ramsey_country_tables');
    end

    if options.write_files && ~isempty(options.base_values_output_file)
        render_latex_table(options.base_values_output_file, base_values_text, ...
            'generated_by', 'render_ramsey_country_tables');
    end

    outputs = struct();
    outputs.countries = countries;
    outputs.structural_latex = structural_text;
    outputs.base_values_latex = base_values_text;
end

function ordered = order_summaries(summaries, country_order)
    ordered = {};

    for idx = 1:numel(country_order)
        for jdx = 1:numel(summaries)
            if strcmp(summaries{jdx}.metadata.country, country_order{idx})
                ordered{end + 1} = summaries{jdx}; %#ok<AGROW>
            end
        end
    end

    for idx = 1:numel(summaries)
        country = summaries{idx}.metadata.country;
        if ~any(strcmp(country_order, country))
            ordered{end + 1} = summaries{idx}; %#ok<AGROW>
        end
    end
end

function latex_text = build_structural_table(summaries, countries)
    bs = char(92);
    column_spec = ['ll' repmat('r', 1, numel(countries))];
    row_break = [char(92) char(92)];
    header_line = [[bs 'textbf{Quantity} & ' bs 'textbf{Symbol / field}'], format_country_headers(countries), ' ', row_break];

    lines = {
        [bs 'begin{table}[H]']
        [bs 'centering']
        [bs 'small']
        [bs 'caption{Current structural Ramsey calibrations by country}']
        [bs 'label{tab:ramsey_country_structural}']
        shrink_to_textwidth_open()
        [bs 'begin{tabular}{' column_spec '}']
        [bs 'toprule']
        header_line
        [bs 'midrule']
    };

    row_specs = {
        'Base year', '--', @(s) format_integer(s.structural.base_year)
        ['Capital share'], ['$' bs 'alpha_K$'], @(s) format_decimal(s.structural.alpha_K, 2)
        ['Annual depreciation'], ['$' bs 'delta_{' bs 'mathrm{ann}}$'], @(s) format_decimal(s.structural.delta_annual, 3)
        ['Annual discount factor'], ['$' bs 'beta_{' bs 'mathrm{ann}}$'], @(s) format_decimal(s.structural.beta_annual, 3)
        ['CRRA coefficient'], ['$' bs 'sigma$'], @(s) format_decimal(s.structural.sigma, 2)
        ['Annual TFP growth (in-sample)'], ['$g_A^{' bs 'mathrm{ann}}$'], @(s) format_decimal(s.structural.tfp_growth_annual, 4)
        ['Annual TFP growth (terminal)'], ['$g_{A,' bs 'infty}^{' bs 'mathrm{ann}}$'], @(s) format_optional_decimal(s.structural, 'tfp_growth_terminal_annual', 4)
        ['TFP-growth convergence'], ['$' bs 'rho_g$'], @(s) format_optional_decimal(s.structural, 'rho_g', 3)
        ['Annual inflation target'], ['$' bs 'pi^{' bs 'ast}_{' bs 'mathrm{ann}}$'], @(s) format_optional_decimal(s.structural, 'inflation_target_annual', 2)
        ['Quarterly discount factor'], ['$' bs 'beta$'], @(s) format_decimal(s.structural.beta_quarterly, 6)
        ['Quarterly depreciation'], ['$' bs 'delta$'], @(s) format_decimal(s.structural.delta_quarterly, 6)
        ['Annual BGP real interest rate'], ['$r^{' bs 'ast}_{' bs 'mathrm{ann}}$'], @(s) format_decimal(s.structural.r_star_annual, 4)
        ['Quarterly BGP capital-output ratio'], ['$(K/Y)^{' bs 'ast}$'], @(s) format_decimal(s.structural.ky_bgp_quarterly, 3)
        'Terminal tail (quarters)', 'solver horizon', @(s) format_integer(s.structural.solver_horizon_quarters)
        'Capital-stock override', [bs 'texttt{K' bs '_override}'], @(s) format_optional_integer(s.structural, 'K_override')
    };

    for idx = 1:size(row_specs, 1)
        values = cell(1, numel(summaries));
        for jdx = 1:numel(summaries)
            values{jdx} = row_specs{idx, 3}(summaries{jdx});
        end
        lines{end + 1} = sprintf('%s & %s%s %s', row_specs{idx, 1}, row_specs{idx, 2}, join_value_columns(values), row_break); %#ok<AGROW>
    end

    lines = [lines; {
        [bs 'bottomrule']
        [bs 'end{tabular}%']
        '}'
        [bs 'end{table}']
    }];

    latex_text = strjoin(lines, newline);
end

function latex_text = build_base_values_table(summaries, countries)
    bs = char(92);
    column_spec = ['ll' repmat('r', 1, numel(countries))];
    row_break = [char(92) char(92)];
    header_line = [[bs 'textbf{Quantity} & ' bs 'textbf{Unit}'], format_country_headers(countries), ' ', row_break];

    lines = {
        [bs 'begin{table}[H]']
        [bs 'centering']
        [bs 'small']
        [bs 'caption{Current base-year levels and expenditure shares used in the Ramsey calibration}']
        [bs 'label{tab:ramsey_country_base_values}']
        shrink_to_textwidth_open()
        [bs 'begin{tabular}{' column_spec '}']
        [bs 'toprule']
        header_line
        [bs 'midrule']
    };

    row_specs = {
        'Capital stock $K_0$', 'million EUR', @(s) format_with_commas(s.base_year_values.K0, 0)
        'Annual GDP $Y_0$', 'million EUR', @(s) format_with_commas(s.base_year_values.Y0_annual, 0)
        'Employment $N_0$', 'thousand persons in employment', @(s) format_with_commas(s.base_year_values.N0, 0)
        'Labour force $L_0$', 'thousand persons', @(s) format_with_commas(s.base_year_values.L0, 2)
        'Population $P_0$', 'thousand residents', @(s) format_with_commas(s.base_year_values.P0, 0)
        'Dependency ratio $P_0/N_0$', 'residents per person employed', @(s) format_decimal(s.base_year_values.dependency_ratio0, 3)
        'Hours per person employed $h_0$', 'quarterly hours', @(s) format_decimal(s.base_year_values.h0, 3)
        'Implied TFP $A_0$', 'model units', @(s) format_decimal(s.base_year_values.A0, 5)
        'Consumption share $C/Y$', 'ratio', @(s) format_decimal(s.base_year_values.CY, 4)
        'Investment share $I/Y$', 'ratio', @(s) format_decimal(s.base_year_values.IY, 4)
        'Government share $G/Y$', 'ratio', @(s) format_decimal(s.base_year_values.GY, 4)
        'Net-exports share $NX/Y$', 'ratio', @(s) format_decimal(s.base_year_values.NXY, 4)
    };

    for idx = 1:size(row_specs, 1)
        values = cell(1, numel(summaries));
        for jdx = 1:numel(summaries)
            values{jdx} = row_specs{idx, 3}(summaries{jdx});
        end
        lines{end + 1} = sprintf('%s & %s%s %s', row_specs{idx, 1}, row_specs{idx, 2}, join_value_columns(values), row_break); %#ok<AGROW>
    end

    lines = [lines; {
        [bs 'bottomrule']
        [bs 'end{tabular}%']
        '}'
        [bs 'end{table}']
    }];

    latex_text = strjoin(lines, newline);
end

function header = format_country_headers(countries)
    bs = char(92);
    header = '';
    for idx = 1:numel(countries)
        header = [header ' & ' bs 'textbf{' countries{idx} '}']; %#ok<AGROW>
    end
end

function suffix = join_value_columns(values)
    suffix = '';
    for idx = 1:numel(values)
        suffix = [suffix sprintf(' & %s', values{idx})]; %#ok<AGROW>
    end
end

function text = format_decimal(value, decimals)
    text = sprintf(['%0.' num2str(decimals) 'f'], value);
end

function text = format_optional_decimal(payload, field_name, decimals)
    if isfield(payload, field_name) && ~isempty(payload.(field_name)) && isfinite(payload.(field_name))
        text = format_decimal(payload.(field_name), decimals);
    else
        text = '--';
    end
end

function text = format_integer(value)
    text = sprintf('%d', round(value));
end

function text = format_optional_integer(payload, field_name)
    if isfield(payload, field_name) && ~isempty(payload.(field_name)) && isfinite(payload.(field_name))
        text = format_with_commas(payload.(field_name), 0);
    else
        text = '--';
    end
end

function text = format_with_commas(value, decimals)
    text = sprintf(['%0.' num2str(decimals) 'f'], value);
    parts = strsplit(text, '.');
    integer_part = add_commas_to_integer(parts{1});
    if numel(parts) > 1 && decimals > 0
        text = [integer_part '.' parts{2}];
    else
        text = integer_part;
    end
end

function text = add_commas_to_integer(integer_text)
    if isempty(integer_text)
        text = integer_text;
        return;
    end

    is_negative = startsWith(integer_text, '-');
    digits = integer_text;
    if is_negative
        digits = integer_text(2:end);
    end

    reversed = fliplr(digits);
    pieces = cell(1, ceil(numel(reversed) / 3));
    piece_idx = 1;
    for idx = 1:3:numel(reversed)
        pieces{piece_idx} = reversed(idx:min(idx + 2, numel(reversed))); %#ok<AGROW>
        piece_idx = piece_idx + 1;
    end

    joined = strjoin(pieces, ',');
    text = fliplr(joined);
    if is_negative
        text = ['-' text]; %#ok<AGROW>
    end
end

function line = shrink_to_textwidth_open()
% Opens a \resizebox that scales the tabular down to the text width only when
% it is wider, and leaves it at its natural size otherwise. These tables gain
% one column per documented country, and with four the structural table is
% wider than the page. The caller closes the box with a lone "}".
    bs = char(92);
    line = [bs 'resizebox{' bs 'ifdim' bs 'width>' bs 'textwidth' bs 'textwidth' ...
            bs 'else' bs 'width' bs 'fi}{!}{%'];
end