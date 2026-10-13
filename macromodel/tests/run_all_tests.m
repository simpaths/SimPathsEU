function failures = run_all_tests(options)
% RUN_ALL_TESTS  Run the macro model's MATLAB checks and report a summary.
%
%   run_all_tests                 run the fast checks (default)
%   run_all_tests('slow', true)   also run the checks that solve the model
%   failures = run_all_tests(...) return the number of failed checks
%
% Must be run with the working directory set to the model root (the folder
% containing run_full_workflow.m), because the checks read data files by
% pwd-relative paths -- see setup_path.m for why that is deliberate.
%
% The slow set is opt-in because test_endogenous_labor runs several full
% Ramsey solves and mutates the country's growth-params JSON while it does so.
% It restores the file, but it is not something to run casually.

    arguments
        options.slow (1,1) logical = false
        options.country (1,:) char = 'Poland'
    end

    here = fileparts(mfilename('fullpath'));
    root = fileparts(here);
    if ~exist(fullfile(pwd, 'run_full_workflow.m'), 'file')
        error('run_all_tests:WrongFolder', ...
              ['Run this from the model root (%s), not from %s. The checks read ' ...
               'data files by pwd-relative paths.'], root, pwd);
    end
    setup_path();

    fast = {'test_name_collisions', 'test_artifact_layout', 'test_labor_foc', 'test_calibration_identities', ...
            'test_frozen_model_generator', 'test_data_loading', 'test_demographic_pair_coherence', ...
            'test_export_bundle_marker'};
    slow = {'test_endogenous_labor'};

    names = fast;
    if options.slow
        names = [names slow];
    end

    results = cell(numel(names), 1);
    failures = 0;

    fprintf('\n');
    fprintf('==========================================================\n');
    fprintf('  MACRO MODEL CHECKS  (%d selected%s)\n', numel(names), ...
            ternary(options.slow, '', ', slow set skipped'));
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
    if ~options.slow
        fprintf('  (%s not run; pass ''slow'', true to include)\n', strjoin(slow, ', '));
    end
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

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
