function build_population_projection(dsge_country, simpaths_pop_file, options)
% BUILD_POPULATION_PROJECTION  Build the quarterly N projection from SimPaths population data.
%
% Reads align_popProjections.xlsx from the SimPaths input directory,
% extracts working-age (15–64) population totals by year, and applies
% their growth rates to the terminal N (employees) of the reference CSV to
% build a forward path for the Ramsey model.
%
% Design principle: keep the DSGE/Ramsey calibration for the selected
% country (K₀, A₀, α, δ, σ, g_A) but replace the forward N path with
% the demographic trend from the matching SimPaths population projections.
% This ensures that:
%   (1) The Ramsey growth model's demographic path is consistent with
%       what SimPaths agents experience in the chosen country
%   (2) All other model structure remains from the estimation country
%
% The output file is read by DSGEModelManager.initializeRamseyTrend() in
% SimPaths to override the default forward extrapolation of N.
%
% Usage:
%   build_population_projection('Spain', '../../input/ES/align_popProjections.xlsx')
%   build_population_projection('Poland', '...', 'projection_start', '2023q1')
%
% Inputs:
%   dsge_country       - DSGE model country name (Germany, Poland, Sweden, Spain, UK)
%   simpaths_pop_file  - Full path to align_popProjections.xlsx
%
% Output:
%   population_projection_[COUNTRY].csv in the current directory, columns
%   time, N.
%
% The CSV starts at projection_start (default: shared SimPaths integration
% handoff quarter) and extends through the final projection
% year. Quarters beyond the last year-to-year growth increment reuse the
% last available annual growth rate.
%
% Author: WELLSIM Project
% Date: June 2025
% =========================================================================
    arguments
        dsge_country (1,:) char = 'Poland'
        simpaths_pop_file (1,:) char = ''
        options.projection_start (1,:) char = ''
    end
    % Resolve the model's code folders (internal/, diagnostics/, ...).
    % Idempotent; see setup_path.m for why MATLAB cannot do this itself.
    setup_path();
    country_config = get_country_config(dsge_country);
    dsge_country = country_config.name;
    options.projection_start = resolve_projection_start(options.projection_start);

    if isempty(simpaths_pop_file)
        % Default: the matching SimPaths country input in this repository.
        simpaths_pop_file = fullfile(model_location().input_tree, ...
                                     country_config.simpaths_code, 'align_popProjections.xlsx');
    end
    
    fprintf('\n');
    box_width = 62;
    fprintf('╔%s╗\n', repmat('═', 1, box_width));
    print_box_line('POPULATION PROJECTION: SimPaths → Ramsey N path', box_width, 'center');
    fprintf('╚%s╝\n', repmat('═', 1, box_width));
    fprintf('\n');

    %% =====================================================================
    %% 1. READ SIMPATHS POPULATION PROJECTIONS
    %% =====================================================================
    
    if ~exist(simpaths_pop_file, 'file')
        error(['Population projections file not found: %s\n' ...
               'Provide the path to align_popProjections.xlsx from SimPaths.'], ...
              simpaths_pop_file);
    end
    
    fprintf('Reading population projections from:\n  %s\n', simpaths_pop_file);
    
    % Read the Excel file
    % Format: Gender | Region | Age | 2011 | 2012 | ... | 2060
    %
    % CRITICAL: MATLAB's readtable cannot use numeric values (2011, 2012, ...)
    % as variable names. Depending on MATLAB version, it either:
    %   (a) prepends 'x' → x2011, x2012  (older versions)
    %   (b) falls back to Var1, Var2, ...  (common with mixed string/numeric headers)
    % To handle ALL versions robustly, we read the header row separately
    % using xlsread/readcell, then read data starting from row 2.
    
    % --- Step 1: Read the actual header values from the Excel file ---
    try
        % R2019a+: readcell reads everything as-is
        header_raw = readcell(simpaths_pop_file, 'Sheet', 'Population_projections', ...
                              'Range', '1:1');
    catch
        % Older MATLAB: use xlsread
        [~, header_raw, ~] = xlsread(simpaths_pop_file, 'Population_projections', '1:1');
    end
    
    % Flatten and convert header values to strings for display/matching
    n_cols = length(header_raw);
    header_str = cell(1, n_cols);
    header_num = nan(1, n_cols);  % numeric value if the header is a number
    for i = 1:n_cols
        val = header_raw{i};
        if isnumeric(val) && ~isnan(val)
            header_str{i} = num2str(val);
            header_num(i) = val;
        elseif ischar(val) || isstring(val)
            header_str{i} = char(val);
        else
            header_str{i} = '';
        end
    end
    
    fprintf('  Excel headers (%d): %s ...\n', n_cols, ...
            strjoin(header_str(1:min(6, n_cols)), ', '));
    
    % --- Step 2: Read the data (skip header row) ---
    opts = detectImportOptions(simpaths_pop_file, 'Sheet', 'Population_projections');
    opts.DataRange = 'A2';  % start from row 2
    raw = readtable(simpaths_pop_file, opts);
    var_names = raw.Properties.VariableNames;  % these may be Var1, Var2, ...
    
    fprintf('  Table variable names (%d): %s ...\n', length(var_names), ...
            strjoin(var_names(1:min(6, length(var_names))), ', '));
    
    % --- Step 3: Detect age column from ACTUAL Excel headers ---
    age_col_idx = find(strcmpi(header_str, 'Age'), 1);
    if isempty(age_col_idx)
        age_col_idx = find(contains(header_str, 'age', 'IgnoreCase', true), 1);
    end
    if isempty(age_col_idx)
        % Fallback: third column is always Age in this file format
        age_col_idx = 3;
        fprintf('  ⚠ Could not find Age column in Excel headers, using column %d\n', age_col_idx);
    else
        fprintf('  Age column found at index %d (header: "%s")\n', age_col_idx, header_str{age_col_idx});
    end
    
    % --- Step 4: Detect year columns from ACTUAL Excel headers ---
    % Year columns have numeric headers in range 2000-2100
    years = [];
    year_col_indices = [];
    for i = 1:n_cols
        if ~isnan(header_num(i)) && header_num(i) >= 2000 && header_num(i) <= 2100
            years(end+1) = header_num(i); %#ok<AGROW>
            year_col_indices(end+1) = i;   %#ok<AGROW>
        else
            % Also try parsing the string representation for 4-digit years
            num_str = regexp(header_str{i}, '^\d{4}$', 'match', 'once');
            if ~isempty(num_str)
                num_val = str2double(num_str);
                if num_val >= 2000 && num_val <= 2100
                    years(end+1) = num_val; %#ok<AGROW>
                    year_col_indices(end+1) = i; %#ok<AGROW>
                end
            end
        end
    end
    
    if isempty(years)
        error(['No year columns detected in %s.\n' ...
               'Expected numeric headers like 2011, 2012, ...\n' ...
               'Actual Excel headers: %s'], simpaths_pop_file, strjoin(header_str, ', '));
    end
    
    fprintf('  Year range: %d – %d (%d years)\n', min(years), max(years), length(years));
    fprintf('  Total rows: %d\n', height(raw));
    
    % Filter working-age population (15-64)
    % Access by column index since variable names may be Var1, Var2, ...
    age_col = raw{:, age_col_idx};
    % Handle case where age was read as cell array of strings/chars
    if iscell(age_col)
        age_col = cellfun(@(x) str2double(string(x)), age_col);
    end
    wap_mask = age_col >= 15 & age_col <= 64;
    wap_data = raw(wap_mask, :);
    
    fprintf('  Working-age (15-64) rows: %d\n', sum(wap_mask));
    
    % Sum across all genders and regions for each year
    % Use column INDICES (not names) to access data
    wap_annual = zeros(length(years), 1);
    for i = 1:length(year_col_indices)
        col_data = wap_data{:, year_col_indices(i)};
        if iscell(col_data)
            col_data = cellfun(@(x) str2double(string(x)), col_data);
        end
        wap_annual(i) = sum(col_data, 'omitnan');
    end
    
    % %,.0f is not a valid MATLAB format (no thousands-separator flag); it printed
    % the year and silently dropped the value.
    fprintf('\n  Working-age population (15-64):\n');
    fprintf('    %d: %.0f\n', years(1), wap_annual(1));
    fprintf('    %d: %.0f\n', years(end), wap_annual(end));
    fprintf('    Change: %.1f%%\n', 100 * (wap_annual(end) / wap_annual(1) - 1));
    
    %% =====================================================================
    %% 2. LOAD TERMINAL VALUES FROM RAMSEY REFERENCE CSV
    %% =====================================================================
    
    ref_file = artifact_path('output', sprintf('growth_model_reference_%s.csv', lower(dsge_country)));
    if ~exist(ref_file, 'file')
        error(['Reference CSV not found: %s\n' ...
               'Run ramsey_trend(''%s'') first.'], ref_file, dsge_country);
    end
    
    ref = readtable(ref_file);
    N_terminal = ref.N(end);
    terminal_time = ref.time{end};  % e.g., '2025q1'
    
    % Parse terminal year and quarter
    tokens = regexp(terminal_time, '(\d+)q(\d)', 'tokens', 'once');
    terminal_year = str2double(tokens{1});
    terminal_quarter = str2double(tokens{2});
    
    fprintf('\n  Reference CSV: %s (%d rows)\n', ref_file, height(ref));
    fprintf('  Terminal N: %.1f (at %s)\n', N_terminal, terminal_time);

    projection_start = options.projection_start;

    start_tokens = regexp(projection_start, '(\d+)q(\d)', 'tokens', 'once');
    if isempty(start_tokens)
        error('projection_start must have format YYYYqQ, got ''%s''.', projection_start);
    end
    start_year = str2double(start_tokens{1});
    start_quarter = str2double(start_tokens{2});

    if start_quarter < 1 || start_quarter > 4
        error('projection_start quarter must be in 1..4, got %d.', start_quarter);
    end
    if start_year > terminal_year || (start_year == terminal_year && start_quarter > terminal_quarter)
        error(['projection_start (%s) must not be later than terminal reference date (%s).'], ...
              projection_start, terminal_time);
    end

    fprintf('  Projection start: %s\n', projection_start);

    %% =====================================================================
    %% 3. COMPUTE QUARTERLY PROJECTION FROM POPULATION GROWTH RATES
    %% =====================================================================
    %
    % Strategy:
    %   - Annual population data gives WAP(y) for y = 2011, ..., 2060
    %   - Annual growth rate: g_a(y) = WAP(y+1)/WAP(y) - 1
    %   - Quarterly growth rate (uniform within year): g_q = (1+g_a)^(1/4) - 1
    %   - Apply growth rates to terminal N, preserving level continuity:
    %     N_proj(terminal) = N_terminal
    %     N_proj(t+1) = N_proj(t) * (1 + g_q(year(t)))
    
    fprintf('\n--- Computing quarterly projection ---\n');
    
    % Find the start and terminal years in the projection data
    start_idx = find(years == start_year, 1);
    if isempty(start_idx)
        error('Projection start year %d not found in population projections (range: %d-%d).', ...
              start_year, years(1), years(end));
    end

    terminal_idx = find(years == terminal_year, 1);
    if isempty(terminal_idx)
        error('Terminal year %d not found in population projections (range: %d-%d).', ...
              terminal_year, years(1), years(end));
    end
    
    % Compute annual growth rates over the full span needed for backward and forward construction.
    % g_a(y) = WAP(y+1)/WAP(y) - 1, for y = start_year, ..., last_year-1
    last_proj_year = years(end);
    n_growth_years = last_proj_year - start_year;
    
    annual_growth = zeros(n_growth_years, 1);
    for i = 1:n_growth_years
        y_idx = start_idx + i - 1;
        annual_growth(i) = wap_annual(y_idx + 1) / wap_annual(y_idx) - 1;
    end
    
    fprintf('  Annual growth rates (first 5 years):\n');
    for i = 1:min(5, n_growth_years)
        fprintf('    %d→%d: %+.3f%%\n', start_year + i - 1, ...
                start_year + i, 100 * annual_growth(i));
    end
    if n_growth_years > 5
        fprintf('    ...\n');
        fprintf('    %d→%d: %+.3f%%\n', last_proj_year - 1, last_proj_year, ...
                100 * annual_growth(end));
    end
    
    % Build quarterly projection around the Ramsey terminal anchor.
    % Growth within year y is distributed uniformly across its four quarters.
    % The final projection year reuses the last available annual growth rate
    % so the CSV covers the full SimPaths simulation horizon.
    final_output_year = last_proj_year;
    total_quarters = (final_output_year - start_year) * 4 + (4 - start_quarter + 1);
    proj_primary = nan(total_quarters, 1);
    time_labels = cell(total_quarters, 1);

    for i = 1:total_quarters
        quarter_offset = i - 1;
        absolute_quarter = (start_quarter - 1) + quarter_offset;
        current_year = start_year + floor(absolute_quarter / 4);
        current_quarter = mod(absolute_quarter, 4) + 1;
        time_labels{i} = sprintf('%dq%d', current_year, current_quarter);
    end

    terminal_position = find(strcmp(time_labels, terminal_time), 1);
    if isempty(terminal_position)
        error(['Terminal reference date %s is outside the requested projection span (%s to %s).'], ...
              terminal_time, time_labels{1}, time_labels{end});
    end

    proj_primary(terminal_position) = N_terminal;

    quarter_growth = nan(size(annual_growth));
    for i = 1:length(annual_growth)
        quarter_growth(i) = (1 + annual_growth(i))^(1/4) - 1;
    end

    % Backfill periods before the terminal anchor.
    for idx = terminal_position-1:-1:1
        current_year = start_year + floor((start_quarter - 1 + idx - 1) / 4);
        growth_idx = current_year - start_year + 1;
        if growth_idx < 1 || growth_idx > length(quarter_growth)
            error('Missing annual growth for backfill year %d.', current_year);
        end
        proj_primary(idx) = proj_primary(idx + 1) / (1 + quarter_growth(growth_idx));
    end

    % Forward-fill periods after the terminal anchor.
    for idx = terminal_position+1:total_quarters
        prev_year = start_year + floor((start_quarter - 1 + idx - 2) / 4);
        growth_idx = prev_year - start_year + 1;
        if growth_idx < 1
            error('Missing annual growth for forward year %d.', prev_year);
        end
        growth_idx = min(growth_idx, length(quarter_growth));
        proj_primary(idx) = proj_primary(idx - 1) * (1 + quarter_growth(growth_idx));
    end
    
    N_proj = proj_primary;
    fprintf('\n  Quarterly N projection:\n');
    fprintf('    Start: %s, N = %.1f\n', time_labels{1}, N_proj(1));
    fprintf('    Anchor: %s, N = %.1f\n', terminal_time, N_terminal);
    fprintf('    End:   %s, N = %.1f\n', time_labels{end}, N_proj(end));
    fprintf('    Total change: %.1f%%\n', 100 * (N_proj(end) / N_proj(1) - 1));
    fprintf('    Quarters: %d (%.0f years)\n', total_quarters, total_quarters / 4);

    %% =====================================================================
    %% 4. WRITE OUTPUT CSV
    %% =====================================================================

    output_file = artifact_path('output', sprintf('population_projection_%s.csv', dsge_country), 'create', true);

    fid = fopen(output_file, 'w');
    fprintf(fid, 'time,N\n');
    for i = 1:total_quarters
        fprintf(fid, '%s,%.6f\n', time_labels{i}, N_proj(i));
    end
    fclose(fid);

    fprintf('\n  ✓ %s (%d rows, columns: time, N)\n', output_file, total_quarters);
    
    %% =====================================================================
    %% 5. DIAGNOSTIC SUMMARY
    %% =====================================================================
    
    fprintf('\n--- Diagnostic summary ---\n');
    
    % Compare with the default extrapolation, i.e. continuing the estimation
    % country's own trailing N growth instead of the SimPaths projection.
    n_ref = height(ref);
    window = min(20, n_ref - 1);
    g_N_trend = (ref.N(end) / ref.N(end - window))^(1/window) - 1;

    fprintf('  %s trailing N growth (last %d quarters): %+.4f/q (%.2f%% annual)\n', ...
            dsge_country, window, g_N_trend, 100 * ((1 + g_N_trend)^4 - 1));
    
    % SimPaths country growth rate at start of projection
    g_q_simpaths_start = (1 + annual_growth(1))^(1/4) - 1;
    fprintf('  SimPaths WAP growth rate (%d→%d): %+.4f/q (%.2f%% annual)\n', ...
            terminal_year, terminal_year + 1, g_q_simpaths_start, ...
            100 * annual_growth(1));
    
    % What N would be in 2050 under each scenario.
    % N_proj is indexed from PROJECTION_START, while the trailing-growth
    % extrapolation compounds from TERMINAL_TIME. Those are equal in the default
    % configuration but the function explicitly allows projection_start to be
    % earlier, in which case indexing N_proj by quarters-from-terminal reads the
    % path early and the two scenarios get compared at different dates. Offset
    % each from its own anchor.
    quarters_terminal_to_2050 = (2050 - terminal_year) * 4 + (1 - terminal_quarter);
    quarters_start_to_2050 = (2050 - start_year) * 4 + (1 - start_quarter);

    idx_2050 = min(quarters_start_to_2050 + 1, total_quarters);
    if idx_2050 < 1
        idx_2050 = 1;
    end
    N_2050_simpaths = N_proj(idx_2050);
    N_2050_trend = N_terminal * (1 + g_N_trend)^quarters_terminal_to_2050;

    fprintf('\n  N at 2050 (projection):\n');
    fprintf('    %s trailing extrapolation: %.0f (%.1f%% change)\n', ...
            dsge_country, N_2050_trend, 100 * (N_2050_trend / N_terminal - 1));
    fprintf('    SimPaths WAP growth:      %.0f (%.1f%% change)\n', ...
            N_2050_simpaths, 100 * (N_2050_simpaths / N_terminal - 1));
    fprintf('    Difference:               %.0f (%.1f pp)\n', ...
            N_2050_trend - N_2050_simpaths, ...
            100 * (N_2050_trend / N_terminal - N_2050_simpaths / N_terminal));

    %% =====================================================================
    %% 6. EXTEND demographic_L_{country}.csv WITH SAME SimPaths GROWTH PATH
    %% =====================================================================
    % MATLAB ramsey_trend.m reads demographic_L_{country}.csv for the
    % in-sample labor force trend and uses its post-sample tail to override
    % the forward N extrapolation. To keep MATLAB and Java consuming the
    % same demographic story, append/replace the post-projection_start rows
    % of L_demo with the SimPaths-aligned growth path computed above. Rows
    % before projection_start are preserved as user-maintained historical
    % data.

    demo_L_file = artifact_path('data', sprintf('demographic_L_%s.csv', lower(dsge_country)));
    if exist(demo_L_file, 'file')
        demo_tbl = readtable(demo_L_file);
        pivot_idx = find(strcmpi(demo_tbl.time, projection_start), 1);
        proj_anchor_idx = find(strcmp(time_labels, projection_start), 1);
        if isempty(pivot_idx)
            fprintf('\n  ⚠ %s missing %s anchor row; demographic_L extension skipped.\n', ...
                    demo_L_file, projection_start);
        elseif isempty(proj_anchor_idx)
            fprintf('\n  ⚠ projection_start %s not in proj time axis; demographic_L extension skipped.\n', ...
                    projection_start);
        else
            L_anchor = demo_tbl.L_demo(pivot_idx);
            forward_time = time_labels(proj_anchor_idx+1:end);
            forward_L = L_anchor * proj_primary(proj_anchor_idx+1:end) / proj_primary(proj_anchor_idx);
            new_demo = [demo_tbl(1:pivot_idx, :); ...
                        table(forward_time, forward_L, 'VariableNames', {'time','L_demo'})];
            writetable(new_demo, demo_L_file);
            fprintf('\n  ✓ Extended %s: %d historical rows preserved (through %s), %d projection rows written (through %s)\n', ...
                    demo_L_file, pivot_idx, demo_tbl.time{pivot_idx}, ...
                    length(forward_time), forward_time{end});
        end
    else
        fprintf('\n  (skipped %s update — file does not exist; run calibrate_growth_model first)\n', ...
                demo_L_file);
    end

    fprintf('\n✓ Population projection complete\n\n');
end
