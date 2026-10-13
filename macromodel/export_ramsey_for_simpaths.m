function export_ramsey_for_simpaths(country)
% EXPORT_RAMSEY_FOR_SIMPATHS  Export the Ramsey-only bundle for SimPaths.
%
% Usage:
%   >> export_ramsey_for_simpaths('Poland')
%
% This helper refreshes the SimPaths-facing Ramsey files without requiring
% Dynare decision rules in memory. It is intended for Ramsey-only workflows
% where `growth_params`, `growth_model_reference`, `ramsey_trend_*.mat`, and
% optionally `population_projection_*` have already been generated.

    arguments
        country (1,:) char = 'Germany'
    end
    % Resolve the model's code folders (internal/, diagnostics/, ...).
    % Idempotent; see setup_path.m for why MATLAB cannot do this itself.
    setup_path();

    country_config = get_country_config(country);
    country = country_config.name;
    json_paths = get_growth_params_paths(country);

    fprintf('\n');
    box_width = 62;
    fprintf('╔%s╗\n', repmat('═', 1, box_width));
    print_box_line(sprintf('EXPORT RAMSEY BUNDLE FOR %s', upper(country)), box_width, 'center');
    fprintf('╚%s╝\n', repmat('═', 1, box_width));
    fprintf('\n');

    output_dir = json_paths.export_dir;
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % Unverified until verify_export_bundle passes at the end; see
    % mark_bundle_unverified for why the verdict lives in the bundle.
    mark_bundle_unverified(output_dir, country, ...
        {'export started but did not reach verification'});

    growth_json = json_paths.export;
    growth_ref = artifact_path('output', sprintf('growth_model_reference_%s.csv', lower(country)));
    growth_mat = artifact_path('output', sprintf('ramsey_trend_%s.mat', lower(country)));
    pop_proj_file = artifact_path('output', sprintf('population_projection_%s.csv', country));

    if exist(growth_json, 'file')
        fprintf('    ✓ %s\n', growth_json);
    else
        error(['Calibrated Ramsey JSON not found: %s\n' ...
               'Run calibrate_growth_model(''%s'', ''ramsey_labor_supply'', ...) first.'], ...
              growth_json, country);
    end

    if exist(growth_ref, 'file')
        copyfile(growth_ref, fullfile(output_dir, basename_of(growth_ref)));
        fprintf('    ✓ %s\n', growth_ref);
    else
        error(['Ramsey reference CSV not found: %s\n' ...
               'Run ramsey_trend(''%s'', ..., ''ramsey_labor_supply'', ...) first.'], ...
              growth_ref, country);
    end

    if ~exist(growth_mat, 'file')
        error(['Ramsey workspace not found: %s\n' ...
               'Run ramsey_trend(''%s'', ..., ''ramsey_labor_supply'', ...) first.'], ...
              growth_mat, country);
    end

    % Shared with export_dynamic_for_simpaths.m. This path used to carry its own
    % copy of the writer, and that copy omitted projection_quarters - so a bundle
    % refreshed this way silently reverted Java to its legacy 320-quarter horizon.
    write_growth_terminal_state(growth_mat, output_dir);

    % Same reason: one writer for the hours path, both export paths call it.
    hours_info = write_hours_projection(growth_mat, output_dir, country);
    if hours_info.written
        fprintf('    ✓ %s (planner hours path, %d quarters from %s)\n', ...
                basename_of(hours_info.file), hours_info.quarters, hours_info.handoff_time);
    end

    if exist(pop_proj_file, 'file')
        copyfile(pop_proj_file, fullfile(output_dir, basename_of(pop_proj_file)));
        fprintf('    ✓ %s\n', pop_proj_file);
    else
        fprintf('    ℹ %s not found (using default demographic extrapolation)\n', pop_proj_file);
    end

    fprintf('\n');
    % A partial or mixed bundle must not reach SimPaths.
    verify_export_bundle(output_dir, country);

    fprintf('Output directory: %s\n', output_dir);
    fprintf('Copy this folder''s Ramsey files to SimPathsEU/input/%s/MacroModel/ as needed.\n', ...
            country_config.simpaths_code);
end