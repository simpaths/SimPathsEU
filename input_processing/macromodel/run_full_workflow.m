% =========================================================================
% MASTER WORKFLOW: Growth Model → Estimation → Frozen → Dynamic Export
% =========================================================================
% This script automates the complete workflow for generating SimPaths-ready
% DSGE model outputs from raw estimation.
%
% Usage:
%   >> run_full_workflow('Spain')
%
% Steps executed:
%   0a. Calibrate Ramsey growth model (if not already done)
%   0b. Solve Ramsey model and detrend observables
%   0c. Build SimPaths-consistent population projection
%   0d. Render Ramsey forward-projection diagnostic plot
%   1. Run Bayesian estimation (if not already done)
%   2. Generate frozen model with estimated parameters
%   3. Export DYNAMIC model (A,B,C,D matrices for quarterly approach)
%   4. Run postestimation_analysis (diagnostics + summary report)
%
% INTEGRATION APPROACH:
%   DYNAMIC: DSGE runs quarterly, feeds back w,π to SimPaths annually
%            → ../../input/{CC}/MacroModel/policy_A.csv, policy_Bs.csv, etc.
%
% Prerequisites:
%   - Macromodel_[COUNTRY].mod exists
%   - Data file exists (data_for_dynare_{COUNTRY}.csv and level counterpart)
%
% Author: WELLSIM Project
% Date: February 2026
% =========================================================================

function run_full_workflow(country, options)
    arguments
        country (1,:) char = 'Poland'
        options.skip_growth_calibration (1,1) logical = false
        options.skip_detrending (1,1) logical = false
        options.skip_estimation (1,1) logical = false
        options.skip_frozen (1,1) logical = false
        options.skip_dynamic_export (1,1) logical = false
        options.skip_postestimation (1,1) logical = false
        options.skip_population_projection (1,1) logical = false
        options.skip_projection_plot (1,1) logical = false
        options.use_parallel (1,1) logical = false
        options.simpaths_pop_file (1,:) char = ''
        options.projection_start (1,:) char = ''
    end
    % Resolve the model's code folders (internal/, diagnostics/, ...).
    % Idempotent; see setup_path.m for why MATLAB cannot do this itself.
    setup_path();

    country_config = get_country_config(country);
    country = country_config.name;
    options.projection_start = resolve_projection_start(options.projection_start);

    fprintf('\n');
    box_width = 62;
    fprintf('╔%s╗\n', repmat('═', 1, box_width));
    print_box_line(sprintf('WELLSIM DSGE WORKFLOW FOR %s', upper(country)), box_width, 'center');
    fprintf('╚%s╝\n', repmat('═', 1, box_width));
    fprintf('\n');
    
    start_time = tic;
    workflow_start_clock = clock;  % fallback if Dynare clears tic handle variable
    % -------------------------------------------------------------------------
    % Step 0a: Calibrate Ramsey Growth Model
    % -------------------------------------------------------------------------
    if ~options.skip_growth_calibration
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('  STEP 0a: Calibrating Ramsey Growth Model\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        % Check if level data exists
        level_file = artifact_path('data', sprintf('data_for_dynare_levels_%s.csv', country));
        if ~exist(level_file, 'file')
            error(['Level data not found: %s\n' ...
                   'Run make_datasets.do first (exports level data for Ramsey model).'], level_file);
        end
        
        calibrate_growth_model(country);
        fprintf('✓ Growth model calibrated\n\n');
    else
        fprintf('  STEP 0a: Growth calibration SKIPPED\n\n');
    end
    
    % -------------------------------------------------------------------------
    % Step 0b: Solve Ramsey Model and Detrend Observables
    % -------------------------------------------------------------------------
    if ~options.skip_detrending
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('  STEP 0b: Solving Ramsey Model & Detrending Observables\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        [~, ~, diag] = ramsey_trend(country, [], ...
            'projection_start', options.projection_start);

        if ~diag.converged
            warning('Ramsey stacked-time Newton solve did not converge! Check diagnostics.');
        end
        
        fprintf('✓ Ramsey detrending complete (r* = %.2f%% annual)\n\n', ...
                100 * diag.r_star_mean);
    else
        fprintf('  STEP 0b: Ramsey detrending SKIPPED (using existing data_for_dynare_%s.csv)\n\n', country);
    end
    
    % -------------------------------------------------------------------------
    % Step 0c: Build Population Projection (SimPaths-consistent N path)
    % -------------------------------------------------------------------------
    if ~options.skip_population_projection
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('  STEP 0c: Building Population Projection from SimPaths Data\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        if ~isempty(options.simpaths_pop_file)
            pop_file = options.simpaths_pop_file;
        else
            % Default: the matching SimPaths country input in this repository
            pop_file = fullfile(model_location().input_tree, ...
                                country_config.simpaths_code, 'align_popProjections.xlsx');
        end
        
        if exist(pop_file, 'file')
            % Steps 0b and 0c are mutually dependent: 0c reads the terminal anchor
            % from 0b's growth_model_reference_*.csv, while 0b reads the post-sample
            % tail of demographic_L_*.csv that 0c writes and injects it into a GLOBAL
            % stacked-time solve - so the demographic tail shapes the in-sample trend,
            % the detrended estimation data and the handoff contract, not just the
            % projection. Running 0b once before 0c therefore built every run on the
            % PREVIOUS run's demographics.
            %
            % The dependency is strongly asymmetric: 0c consumes a single in-sample
            % terminal level, 0b consumes ~140 quarters of forward path. So one extra
            % 0b pass after 0c closes the loop where it matters. The anchor drift is
            % measured below rather than assumed negligible.
            demo_L_file = artifact_path('data', sprintf('demographic_L_%s.csv', lower(country)));
            demo_before = read_file_if_exists(demo_L_file);
            anchor_before = reference_terminal_anchor(country);

            build_population_projection(country, pop_file, ...
                'projection_start', options.projection_start);
            fprintf('✓ Population projection built\n\n');

            demo_after = read_file_if_exists(demo_L_file);
            demographics_changed = ~strcmp(demo_before, demo_after);

            if demographics_changed && ~options.skip_detrending
                fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
                fprintf('  STEP 0b (2nd pass): Re-solving Ramsey on refreshed demographics\n');
                fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
                fprintf('  %s changed in step 0c; the first pass used the previous\n', demo_L_file);
                fprintf('  demographics. Re-solving so the trend and the detrended\n');
                fprintf('  estimation data reflect the current projection.\n\n');

                [~, ~, diag2] = ramsey_trend(country, [], ...
                    'projection_start', options.projection_start);

                if ~diag2.converged
                    warning('Ramsey stacked-time Newton did not converge on the second pass!');
                end

                % Second-order residual: 0c anchored on the FIRST pass's reference, so
                % the refreshed reference no longer matches it exactly. Report the gap
                % so this stays a measured quantity.
                anchor_after = reference_terminal_anchor(country);
                report_anchor_drift(anchor_before, anchor_after);

                fprintf('✓ Ramsey re-solved on current demographics (r* = %.2f%% annual)\n\n', ...
                        100 * diag2.r_star_mean);
            elseif demographics_changed && options.skip_detrending
                warning('run_full_workflow:staleDemographics', ...
                        ['%s changed but detrending was skipped: the Ramsey trend and ' ...
                         'data_for_dynare_%s.csv still embed the previous demographics.'], ...
                        demo_L_file, country);
            else
                fprintf('  Demographics unchanged; Ramsey re-solve not required.\n\n');
            end
        else
            fprintf('  ⚠ SimPaths population file not found: %s\n', pop_file);
            fprintf('    Skipping (Ramsey will use default N extrapolation)\n\n');
        end
    else
        fprintf('  STEP 0c: Population projection SKIPPED\n\n');
    end

    % -------------------------------------------------------------------------
    % Step 0d: Render Ramsey Projection Diagnostic Plot
    % -------------------------------------------------------------------------
    if ~options.skip_projection_plot
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('  STEP 0d: Rendering Ramsey Projection Plot\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        try
            ramsey_projection_plot(country, 'projection_start', options.projection_start);
            ramsey_plot_status = 'generated';
            fprintf('✓ Ramsey projection plot generated\n\n');
        catch plot_error
            ramsey_plot_status = sprintf('failed: %s', plot_error.message);
            warning('run_full_workflow:RamseyProjectionPlotFailed', '%s', plot_error.message);
            fprintf('  ⚠ Ramsey projection plot not generated\n\n');
        end
    else
        ramsey_plot_status = 'skipped';
        fprintf('  STEP 0d: Ramsey projection plot SKIPPED\n\n');
    end
    
    % -------------------------------------------------------------------------
    % Step 1: Estimation
    % -------------------------------------------------------------------------
    if ~options.skip_estimation
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('  STEP 1: Running Bayesian Estimation\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        model_file = sprintf('Macromodel_%s.mod', country);
        
        if ~exist(model_file, 'file')
            error('Model file not found: %s', model_file);
        end
        
        fprintf('Running: dynare %s\n', model_file);
        fprintf('This may take 10-30 minutes...\n\n');
        
        % Run Dynare estimation
        dynare_cmd = sprintf('dynare %s use_dll', model_file(1:end-4));
        if options.use_parallel
            dynare_cmd = sprintf('%s parallel', dynare_cmd);
        end
        evalin('base', dynare_cmd);
        
        fprintf('\n✓ Estimation complete\n\n');
    else
        fprintf('  STEP 1: Estimation SKIPPED (using existing results)\n\n');
    end
    
    % -------------------------------------------------------------------------
    % Step 2: Generate Frozen Model
    % -------------------------------------------------------------------------
    if ~options.skip_frozen
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('  STEP 2: Generating Frozen Model\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        generate_frozen_model(country);
        
        fprintf('✓ Frozen model generated\n\n');
    else
        fprintf('  STEP 2: Frozen model generation SKIPPED\n\n');
    end
    
    % -------------------------------------------------------------------------
    % Step 3: Export DYNAMIC Model for SimPaths (quarterly approach)
    % -------------------------------------------------------------------------
    if ~options.skip_dynamic_export
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('  STEP 3: Exporting DYNAMIC Model for SimPaths\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        % Run the frozen model to get policy functions
        frozen_file = sprintf('Macromodel_%s_frozen.mod', country);
        
        if ~exist(frozen_file, 'file')
            fprintf('  ⚠ Frozen model not found: %s\n', frozen_file);
            fprintf('    Skipping dynamic export (run generate_frozen_model first)\n\n');
        else
            fprintf('Running: dynare %s noclearall nograph\n', frozen_file);
            evalin('base', sprintf('dynare %s noclearall nograph', frozen_file(1:end-4)));
            
            % Export dynamic policy functions (run in base workspace where oo_ and M_ exist)
            evalin('base', 'export_dynamic_for_simpaths');
            
            fprintf('✓ Dynamic export complete\n\n');
        end
    else
        fprintf('  STEP 3: Dynamic export SKIPPED\n\n');
    end

    % -------------------------------------------------------------------------
    % Step 4: Postestimation Analysis
    % -------------------------------------------------------------------------
    if ~options.skip_postestimation
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('  STEP 4: Running Postestimation Analysis\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        if exist('postestimation_analysis', 'file')
            postestimation_analysis(sprintf('Macromodel_%s', country), '');
            fprintf('✓ Postestimation analysis complete\n\n');
        else
            fprintf('  ⚠ postestimation_analysis.m not found on path\n');
            fprintf('    Skipping postestimation analysis\n\n');
        end
    else
        fprintf('  STEP 4: Postestimation analysis SKIPPED\n\n');
    end

    % Documentation summaries were written by the stages above into
    % output/documentation_data/. Rendering them into the Overleaf tables is a
    % separate step run from WELLSIM_SVEC_Overleaf, which reads that folder.
    if options.skip_growth_calibration && options.skip_detrending && options.skip_postestimation
        documentation_status = 'no summary-writing stage ran';
    else
        documentation_status = 'summaries in output/documentation_data/ (render from WELLSIM_SVEC_Overleaf)';
    end

    % -------------------------------------------------------------------------
    % Summary
    % -------------------------------------------------------------------------
    if exist('start_time', 'var')
        elapsed = toc(start_time);
    elseif exist('workflow_start_clock', 'var')
        elapsed = etime(clock, workflow_start_clock);
        fprintf('  ⚠ Timing handle was cleared during execution; using wall-clock fallback.\n');
    else
        elapsed = NaN;
        fprintf('  ⚠ Could not compute elapsed time (timing variables were cleared).\n');
    end
    
    % For printing only: one separator, whatever the platform built the path with.
    bundle_dir = strrep(artifact_path('bundle', '', 'country', country), '\', '/');
    fprintf('╔%s╗\n', repmat('═', 1, box_width));
    print_box_line('WORKFLOW COMPLETE', box_width, 'center');
    fprintf('╠%s╣\n', repmat('═', 1, box_width));
    print_box_line(sprintf('  Country: %s', country), box_width);
    print_box_line(sprintf('  Elapsed: %.1f minutes', elapsed/60), box_width);
    print_box_line(sprintf('  Ramsey plot: %s', ramsey_plot_status), box_width);
    print_box_line(sprintf('  Docs: %s', documentation_status), box_width);
    fprintf('╠%s╣\n', repmat('═', 1, box_width));
    print_box_line('  Generated files:', box_width);
    print_box_line(sprintf('    • Macromodel_%s_frozen.mod', country), box_width);
    print_box_line(sprintf('    • params_%s_estimated.txt', country), box_width);
    print_box_line(sprintf('    • Macromodel_%s/Output/postestimation_summary.txt', country), box_width);
    print_box_line('  DYNAMIC integration (quarterly):', box_width);
    print_box_line(sprintf('    • %s/policy_A.csv (state transition)', bundle_dir), box_width);
    print_box_line(sprintf('    • %s/policy_Bs.csv (shock→states)', bundle_dir), box_width);
    print_box_line(sprintf('    • %s/policy_C.csv (states→jumps)', bundle_dir), box_width);
    print_box_line(sprintf('    • %s/policy_D.csv (shocks→jumps)', bundle_dir), box_width);
    print_box_line('  RAMSEY growth model:', box_width);
    print_box_line(sprintf('    • country_params/%s_growth_params.json (source template)', country), box_width);
    print_box_line(sprintf('    • %s/growth_params_%s.json (calibrated)', bundle_dir, country), box_width);
    print_box_line(sprintf('    • ramsey_trends_%s.csv (trend paths)', lower(country)), box_width);
    print_box_line(sprintf('    • ramsey_projection_%s.png (diagnostic plot)', lower(country)), box_width);
    print_box_line(sprintf('    • growth_model_reference_%s.csv (Java xval)', lower(country)), box_width);
    print_box_line(sprintf('    • %s/population_projection_%s.csv', bundle_dir, country), box_width);
    fprintf('╚%s╝\n', repmat('═', 1, box_width));
    fprintf('\n');
    
    % -------------------------------------------------------------------------
    % Verification suggestions
    % -------------------------------------------------------------------------
    fprintf('Verification steps:\n');
    fprintf('  1. Check estimation diagnostics in Macromodel_%s/Output/\n', country);
    fprintf('  2. Compare params_%s_estimated.txt with literature values\n', country);
    fprintf('  3. DYNAMIC: Check IRFs in %s/irfs_eps_L.csv\n', bundle_dir);
    fprintf('  4. Run SimPaths dynamic-integration smoke test\n');
    fprintf('\n');
    fprintf('Integration approach:\n');
    fprintf('  DYNAMIC: Use policy_*.csv for quarterly DSGE with annual feedback\n');
    fprintf('\n');
end


function txt = read_file_if_exists(file_path)
% Returns the file's contents, or '' when it does not exist. Used to detect whether
% step 0c rewrote the demographic tail; the file is small enough that comparing
% contents directly is cheaper and more obvious than hashing.
    if exist(file_path, 'file')
        txt = fileread(file_path);
    else
        txt = '';
    end
end

function anchor = reference_terminal_anchor(country)
% Terminal values step 0c anchors its projection on, read from step 0b's reference.
    anchor = struct('N', NaN, 'time', '');
    ref_file = artifact_path('output', sprintf('growth_model_reference_%s.csv', lower(country)));
    if ~exist(ref_file, 'file')
        return;
    end
    ref = readtable(ref_file);
    if ismember('N', ref.Properties.VariableNames) && ~isempty(ref.N)
        anchor.N = ref.N(end);
    end
    if ismember('time', ref.Properties.VariableNames) && ~isempty(ref.time)
        anchor.time = char(string(ref.time(end)));
    end
end

function report_anchor_drift(before, after)
% The second Ramsey pass changes the reference that step 0c already anchored on.
% That feedback is second order - 0c consumes one in-sample terminal level, while
% 0b consumes ~140 quarters of forward path - but report it rather than assume it.
    if isnan(before.N) || isnan(after.N) || before.N == 0
        fprintf('  Anchor drift: not available (no prior reference).\n');
        return;
    end

    drift_pct = 100 * (after.N - before.N) / before.N;
    fprintf('  Anchor drift at %s: N %.1f -> %.1f (%+.4f%%)\n', ...
            after.time, before.N, after.N, drift_pct);

    if abs(drift_pct) > 0.5
        warning(['Terminal N anchor moved %.3f%% on the second Ramsey pass. Step 0c ' ...
                 'anchored on the pre-refresh reference, so the 0b/0c fixed point has ' ...
                 'not converged. Re-run the workflow and check whether the drift shrinks.'], ...
                drift_pct);
    end
end
