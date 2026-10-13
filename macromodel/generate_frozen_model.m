% =========================================================================
% GENERATE FROZEN MODEL FROM ESTIMATION RESULTS
% =========================================================================
% This script reads posterior modes from Dynare estimation output and
% creates Macromodel_[COUNTRY]_frozen.mod with hardcoded parameters.
%
% VERSION: v12 (Option C, February 2026)
%   - Option C: Smets-Wouters-style C/I decomposition
%     - New endogenous variable: c (consumption, Euler equation)
%     - New parameter: s_inv (investment share of GDP)
%     - IS curve replaced with: consumption Euler + demand aggregation identity
%     - Measurement errors for c and inv
%   - Capital extension: k (capital stock), inv (investment)
%   - New parameters: alpha_k, delta_k, rho_inv, phi_inv_r, s_inv
%   - New shock: eps_inv (investment-specific)
%   - Hours is pure AR(1) (no psi_hy, psi_hw estimated)
%   - rho_h and rho_L are CALIBRATED (not estimated)
%   - Estimated: sigma_a, sigma_d, sigma_r, sigma_h, sigma_L, sigma_inv, omega_h
%
% Usage:
%   1. Run estimation: dynare Macromodel_{COUNTRY}.mod
%   2. Run this script: generate_frozen_model('{COUNTRY}')
%   3. Verify/export: dynare Macromodel_{COUNTRY}_frozen.mod noclearall
%                     followed by export_dynamic_for_simpaths
%
% The frozen model can then be used for:
%   - Simulation without re-estimation
%   - Dynamic policy-function export for SimPaths
%   - Comparison across estimation runs
%
% Author: WELLSIM Project
% Date: February 2026
% =========================================================================

function generate_frozen_model(country)
    % Resolve the model's code folders (internal/, diagnostics/, ...).
    % Idempotent; see setup_path.m for why MATLAB cannot do this itself.
    setup_path();
    if nargin < 1
        country = 'Germany';
    end

    country_config = get_country_config(country);
    country = country_config.name;
    
    fprintf('\n');
    fprintf('=========================================================================\n');
    fprintf('  GENERATING FROZEN MODEL FOR %s\n', upper(country));
    fprintf('=========================================================================\n\n');
    
    % -------------------------------------------------------------------------
    % 1. Load estimation results
    % -------------------------------------------------------------------------
    model_name = sprintf('Macromodel_%s', country);
    mode_file = fullfile(model_name, 'Output', [model_name '_mode.mat']);
    
    if ~exist(mode_file, 'file')
        % Try alternative location (Dynare sometimes puts it in current dir)
        mode_file = [model_name '_mode.mat'];
    end
    
    if ~exist(mode_file, 'file')
        error('Mode file not found: %s\nRun estimation first: dynare %s.mod', ...
              mode_file, model_name);
    end
    
    % Load from results file (contains oo_ with properly named posterior modes)
    results_file = fullfile(model_name, 'Output', [model_name '_results.mat']);
    if ~exist(results_file, 'file')
        error('Results file not found: %s\nRun estimation first: dynare %s.mod', ...
              results_file, model_name);
    end
    
    fprintf('Loading estimation results from: %s\n', results_file);
    load(results_file, 'oo_');
    
    % -------------------------------------------------------------------------
    % 2. Extract parameter names and estimated values from oo_.posterior_mode
    % -------------------------------------------------------------------------
    % Using oo_.posterior_mode.parameters and oo_.posterior_mode.shocks_std
    % which have named fields - much safer than parsing xparam1 vector
    
    % Get estimated parameter names and values
    if isfield(oo_, 'posterior_mode') && isfield(oo_.posterior_mode, 'parameters')
        est_param_names = fieldnames(oo_.posterior_mode.parameters);
        est_param_values = zeros(length(est_param_names), 1);
        for i = 1:length(est_param_names)
            est_param_values(i) = oo_.posterior_mode.parameters.(est_param_names{i});
        end
    else
        error('No posterior mode found in results. Did estimation complete successfully?');
    end
    
    % Get estimated shock std devs
    if isfield(oo_.posterior_mode, 'shocks_std')
        est_shock_names = fieldnames(oo_.posterior_mode.shocks_std);
        est_shock_values = zeros(length(est_shock_names), 1);
        for i = 1:length(est_shock_names)
            est_shock_values(i) = oo_.posterior_mode.shocks_std.(est_shock_names{i});
        end
    else
        est_shock_names = {};
        est_shock_values = [];
    end
    
    fprintf('\nEstimated parameters:\n');
    fprintf('---------------------\n');
    for i = 1:length(est_param_names)
        fprintf('  %-12s = %.6f\n', est_param_names{i}, est_param_values(i));
    end
    
    fprintf('\nEstimated shock std devs:\n');
    fprintf('-------------------------\n');
    for i = 1:length(est_shock_names)
        fprintf('  %-12s = %.6f\n', est_shock_names{i}, est_shock_values(i));
    end
    
    % -------------------------------------------------------------------------
    % 3. Read model source and expand wrapper/template includes
    % -------------------------------------------------------------------------
    template_file = [model_name '.mod'];
    frozen_file = [model_name '_frozen.mod'];
    
    fprintf('\nReading source model: %s\n', template_file);
    template = expand_dynare_includes(template_file, struct('country', country));
    
    % -------------------------------------------------------------------------
    % 4. Modify template for frozen model
    % -------------------------------------------------------------------------
    frozen = template;

    % Numeric literal as written in a .mod calibration line: optional sign, digits with
    % optional decimal point, optional exponent.
    VALUE_PATTERN = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';

    % Every substitution below goes through subst_verified, which fails if the pattern
    % did not match exactly the expected number of times. Previously these were all
    % fire-and-forget regexprep calls: any reformatting upstream would silently leave the
    % original text in a file whose header claims "FROZEN (estimated parameters)". The
    % most dangerous case is 4b - a missed substitution there leaves
    % do_parameter_estimation = true, so the "frozen" model re-runs estimation on export.

    % 4a. Change header
    frozen = subst_verified(frozen, ...
        '// DSGE Model for Microsimulation Coupling', ...
        '// DSGE Model for Microsimulation Coupling - FROZEN (estimated parameters)', ...
        'model header', 1);

    % 4b. Disable estimation
    frozen = subst_verified(frozen, ...
        '@#define do_parameter_estimation = true', ...
        '@#define do_parameter_estimation = false  // FROZEN: estimation disabled', ...
        'do_parameter_estimation switch', 1);

    % 4b2. Disable custom IRFs (frozen model is for export, not interactive plotting)
    % Handle both true and false in template (Option C sets false in main .mod)
    frozen = subst_verified(frozen, ...
        '@#define use_custom_irfs = (true|false)[^\n]*', ...
        '@#define use_custom_irfs = false   // FROZEN: use standard IRFs for export', ...
        'use_custom_irfs switch', 1);

    % The estimation-mode branch of the rho_L / rho_h blocks below records the
    % value the model was estimated with, so it must come from this country's
    % calibration. Both were constants once (Germany's 0.95 / 0.85), which
    % misrecorded every country calibrated differently.
    rho_L_calibrated = read_calibrated_value(template, 'rho_L');
    rho_h_calibrated = read_calibrated_value(template, 'rho_h');

    % 4b3. Add SimPaths export switch (after use_custom_irfs line)
    % This switch sets rho_L=0 and rho_h=0 so that L and h equal eps_L and eps_h directly
    simpaths_switch = sprintf([...
        '\n\n// =========================================================================\n' ...
        '// SIMPATHS INTEGRATION SWITCH\n' ...
        '// =========================================================================\n' ...
        '// Set to true when exporting policy functions for SimPaths Java integration.\n' ...
        '// When true, rho_L and rho_h are set to ZERO so that:\n' ...
        '//   - L = eps_L (labor force directly equals SimPaths input)\n' ...
        '//   - h = eps_h (hours directly equals SimPaths input)\n' ...
        '//\n' ...
        '// RATIONALE: During estimation, rho_L=%s and rho_h=%s capture the observed\n' ...
        '// persistence in the estimation sample. But for SimPaths coupling, SimPaths sends LEVELS\n' ...
        '// (deviation from baseline), not innovations. Setting rho=0 ensures the DSGE\n' ...
        '// interprets SimPaths inputs as levels, not as innovations that accumulate.\n' ...
        '//\n' ...
        '// UNITS: eps_L/eps_h are PERCENT log-deviations (100*ln ratio), matching the\n' ...
        '// 100x-log-deviation data the model is estimated on. +5%% labour force = eps_L ~= 4.879.\n' ...
        '//\n' ...
        '// Without this switch: SimPaths input eps_L=5 would cause L to grow to\n' ...
        '// 5/(1-%s) = %.4g (i.e. +%.4g%%) due to AR(1) accumulation.\n' ...
        '// With this switch: L = eps_L = 5 directly (5%%), as intended.\n' ...
        '@#define for_simpaths_export = true\n'], ...
        rho_L_calibrated, rho_h_calibrated, rho_L_calibrated, ...
        5 / (1 - str2double(rho_L_calibrated)), 5 / (1 - str2double(rho_L_calibrated)));

    % Insert after use_custom_irfs line
    frozen = subst_verified(frozen, ...
        '(@#define use_custom_irfs = false[^\n]*\n)', ...
        ['$1' simpaths_switch], ...
        'SimPaths export switch insertion', 1);

    % 4b4. Replace rho_L calibration with conditional block
    rho_L_conditional = [...
        '// Labor force persistence: CONDITIONAL on SimPaths export switch\n' ...
        '@#if for_simpaths_export\n' ...
        '    rho_L    = 0;       // SimPaths mode: L = eps_L directly (no accumulation)\n' ...
        '                        // SimPaths sends LEVELS, not innovations\n' ...
        '@#else\n' ...
        '    rho_L    = ' rho_L_calibrated ';    // Estimation mode: AR(1) captures observed persistence\n' ...
        '                        // (Perplexity fix: rho_L and SE_eps_L were perfectly collinear)\n' ...
        '@#endif\n'];

    % Replace the rho_L line (handles various comment formats)
    frozen = subst_verified(frozen, ...
        'rho_L\s*=\s*[0-9.]+\s*;[^\n]*\n(\s*//[^\n]*\n)?', ...
        rho_L_conditional, 'rho_L conditional block', 1);

    % 4b5. rho_inv is NOT zeroed for the SimPaths export.
    % The rho_L/rho_h zeroing above exists because SimPaths sends those two as
    % LEVELS, so DSGE-internal accumulation would double-count. eps_inv is not
    % a SimPaths input, so that rationale does not extend to it. Zeroing it
    % while keeping the estimated phi_inv_r destroyed the long-run investment
    % multiplier phi_inv_r/(1 - rho_inv) that estimation actually identifies
    % (~6.7x weaker at rho_inv = 0.85). rho_inv now flows through the normal
    % estimated-parameter substitution in 4c: calibrated value if not
    % estimated, posterior mode if it is.

    % 4b6. Replace rho_h calibration with conditional block
    rho_h_conditional = [...
        '// Hours persistence: CONDITIONAL on SimPaths export switch\n' ...
        '@#if for_simpaths_export\n' ...
        '    rho_h    = 0;       // SimPaths mode: h = eps_h directly (no accumulation)\n' ...
        '                        // SimPaths sends LEVELS, not innovations\n' ...
        '@#else\n' ...
        '    rho_h    = ' rho_h_calibrated ';    // Estimation mode: AR(1) captures observed persistence\n' ...
        '                        // (calibrated in country_params/' country '_calibration.mod)\n' ...
        '@#endif\n'];

    % Replace the rho_h line (handles various comment formats)
    frozen = subst_verified(frozen, ...
        'rho_h\s*=\s*[0-9.]+\s*;[^\n]*\n(\s*//[^\n]*\n)*', ...
        rho_h_conditional, 'rho_h conditional block', 1);

    % 4c. Update estimated parameters in calibration section
    % NOTE: Skip parameters wrapped in @#if/@#else blocks by 4b4/4b6. Neither is
    % estimated today, but if one ever were, substituting it here would rewrite
    % BOTH branches - including the `rho_L = 0;` line the entire level-input
    % coupling depends on. Any future conditional parameter belongs in this list.
    conditional_params = {'rho_L', 'rho_h'};
    for i = 1:length(est_param_names)
        pname = est_param_names{i};
        pvalue = est_param_values(i);
        
        % Skip parameters with conditional blocks (already handled above)
        if any(strcmp(pname, conditional_params))
            continue;
        end
        
        % Pattern: parameter = value; with possible comment
        % Replace value while preserving comment
        % Use (?<![a-zA-Z_]) negative lookbehind to avoid matching 'eta' in 'beta'
        % VALUE_PATTERN accepts negatives and scientific notation: psi_wL is -0.08
        % (Poland) / -0.05 (Germany), so the old [0-9.]+ would silently fail to
        % substitute it the moment such a parameter is estimated.
        pattern = sprintf('((?<![a-zA-Z_])%s\\s*=\\s*)%s\\s*;', pname, VALUE_PATTERN);
        replacement = sprintf('$1%.6f;  // ESTIMATED (posterior mode)', pvalue);
        frozen = subst_verified(frozen, pattern, replacement, ...
            sprintf('estimated parameter %s', pname), 1);
    end

    % 4d. Update shock std devs in shocks block
    for i = 1:length(est_shock_names)
        sname = est_shock_names{i};
        svalue = est_shock_values(i);

        % Pattern: var shock_name; stderr value;
        % Shock names start with 'eps_' so no word boundary issue, but add for safety
        pattern = sprintf('(var\\s+%s\\s*;\\s*stderr\\s*)%s\\s*;', sname, VALUE_PATTERN);
        replacement = sprintf('$1%.4f;  // ESTIMATED', svalue);
        frozen = subst_verified(frozen, pattern, replacement, ...
            sprintf('shock stderr %s', sname), 1);
    end
    
    % 4e. Add generation timestamp
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    header_addition = sprintf([...
        '// =========================================================================\n' ...
        '// FROZEN MODEL - AUTO-GENERATED\n' ...
        '// Generated: %s\n' ...
        '// Source: %s (estimation results)\n' ...
        '// DO NOT EDIT MANUALLY - regenerate with generate_frozen_model.m\n' ...
        '// =========================================================================\n\n'], ...
        timestamp, model_name);
    frozen = [header_addition, frozen];
    
    % -------------------------------------------------------------------------
    % 5. Write frozen model
    % -------------------------------------------------------------------------
    fprintf('Writing frozen model: %s\n', frozen_file);
    fid = fopen(frozen_file, 'w');
    if fid == -1
        error('Cannot write to: %s', frozen_file);
    end
    fwrite(fid, frozen);
    fclose(fid);
    
    % -------------------------------------------------------------------------
    % 6. Summary
    % -------------------------------------------------------------------------
    fprintf('\n');
    fprintf('=========================================================================\n');
    fprintf('  FROZEN MODEL GENERATED SUCCESSFULLY\n');
    fprintf('=========================================================================\n');
    fprintf('\n');
    fprintf('Next steps:\n');
    fprintf('  1. Run frozen model:      dynare %s noclearall nograph\n', frozen_file);
    fprintf('  2. Export for SimPaths:   export_dynamic_for_simpaths\n');
    fprintf('  3. Or run full pipeline:  run_full_workflow(''%s'')\n', country);
    fprintf('\n');
    
    % -------------------------------------------------------------------------
    % 7. Create parameter summary file (for documentation)
    % -------------------------------------------------------------------------
    summary_file = sprintf('params_%s_estimated.txt', country);
    fid = fopen(summary_file, 'w');
    fprintf(fid, 'ESTIMATED PARAMETERS FOR %s\n', upper(country));
    fprintf(fid, 'Generated: %s\n', timestamp);
    fprintf(fid, '==========================================\n\n');
    
    fprintf(fid, 'STRUCTURAL PARAMETERS:\n');
    fprintf(fid, '----------------------\n');
    for i = 1:length(est_param_names)
        fprintf(fid, '%-15s = %.6f\n', est_param_names{i}, est_param_values(i));
    end
    
    fprintf(fid, '\nSHOCK STANDARD DEVIATIONS:\n');
    fprintf(fid, '--------------------------\n');
    for i = 1:length(est_shock_names)
        fprintf(fid, '%-15s = %.6f\n', est_shock_names{i}, est_shock_values(i));
    end
    
    fclose(fid);
    fprintf('Parameter summary written to: %s\n\n', summary_file);
end

function expanded = expand_dynare_includes(file_path, macros)
    if nargin < 2
        macros = struct();
    end

    fid = fopen(file_path, 'r');
    if fid == -1
        error('Cannot open source file: %s', file_path);
    end
    cleanup = onCleanup(@() fclose(fid));
    raw_text = fread(fid, '*char')';

    lines = regexp(raw_text, '\r\n|\n|\r', 'split');
    base_dir = fileparts(file_path);
    expanded_parts = {};

    for i = 1:length(lines)
        line = lines{i};

        define_tokens = regexp(line, '^\s*@#define\s+(\w+)\s*=\s*"([^"]*)"\s*$', 'tokens', 'once');
        if ~isempty(define_tokens)
            macros.(define_tokens{1}) = define_tokens{2};
            continue;
        end

        include_path = resolve_dynare_include(line, macros);
        if ~isempty(include_path)
            include_file = fullfile(base_dir, include_path);
            expanded_parts{end+1} = expand_dynare_includes(include_file, macros); %#ok<AGROW>
            continue;
        end

        expanded_parts{end+1} = line; %#ok<AGROW>
    end

    expanded = strjoin(expanded_parts, newline);
end

function include_path = resolve_dynare_include(line, macros)
    include_path = '';

    direct_tokens = regexp(line, '^\s*@#include\s+"([^"]+)"\s*$', 'tokens', 'once');
    if ~isempty(direct_tokens)
        include_path = direct_tokens{1};
        return;
    end

    concat_tokens = regexp(line, '^\s*@#include\s+"([^"]*)"\s*\+\s*(\w+)\s*\+\s*"([^"]*)"\s*$', 'tokens', 'once');
    if isempty(concat_tokens)
        return;
    end

    macro_name = concat_tokens{2};
    if ~isfield(macros, macro_name)
        error('Undefined Dynare macro "%s" while resolving include: %s', macro_name, line);
    end

    include_path = [concat_tokens{1}, macros.(macro_name), concat_tokens{3}];
end