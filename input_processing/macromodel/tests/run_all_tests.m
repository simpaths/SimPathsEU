function failures = run_all_tests()
% RUN_ALL_TESTS  Run the macro model's MATLAB checks and report a summary.
%
%   run_all_tests                 run the checks
%   failures = run_all_tests      return the number of failed checks
%
% Must be run with the working directory set to the model root (the folder
% containing run_full_workflow.m), because the checks read data files by
% pwd-relative paths -- see setup_path.m for why that is deliberate.
%
% Every check is fast and takes no country: none solves the model. (The
% former slow set, test_endogenous_labor, went with the endogenous-labour
% variant on 2026-10-20, JuergenWiemers/SimPathsEU#28.)

    here = fileparts(mfilename('fullpath'));
    root = fileparts(here);
    if ~exist(fullfile(pwd, 'run_full_workflow.m'), 'file')
        error('run_all_tests:WrongFolder', ...
              ['Run this from the model root (%s), not from %s. The checks read ' ...
               'data files by pwd-relative paths.'], root, pwd);
    end
    setup_path();

    names = {'test_name_collisions', 'test_artifact_layout', 'test_calibration_identities', ...
             'test_frozen_model_generator', 'test_data_loading', 'test_demographic_pair_coherence', ...
             'test_export_bundle_marker', 'test_bundle_provenance', 'test_compare_bundles', ...
             'test_check_dependencies'};

    results = cell(numel(names), 1);
    failures = 0;

    fprintf('\n');
    fprintf('==========================================================\n');
    fprintf('  MACRO MODEL CHECKS  (%d selected)\n', numel(names));
    fprintf('==========================================================\n');

    for i = 1:numel(names)
        name = names{i};
        try
            evalc(name);
            results{i} = 'PASS';
            fprintf('  [PASS]  %s\n', name);
        catch ME
            results{i} = sprintf('FAIL: %s', ME.message);
            failures = failures + 1;
            fprintf('  [FAIL]  %s\n          %s\n', name, ME.message);
        end
    end

    fprintf('----------------------------------------------------------\n');
    fprintf('  %d of %d passed\n', numel(names) - failures, numel(names));
    fprintf('==========================================================\n\n');

    if failures > 0
        for i = 1:numel(names)
            if ~strcmp(results{i}, 'PASS')
                fprintf('%s -> %s\n', names{i}, results{i});
            end
        end
    end

    if nargout == 0
        clear failures;
    end
end
