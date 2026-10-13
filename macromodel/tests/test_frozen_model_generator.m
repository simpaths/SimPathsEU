function test_frozen_model_generator()
% TEST_FROZEN_MODEL_GENERATOR  Guards the frozen-model substitution machinery.
%
% generate_frozen_model.m rewrites the expanded template with regexprep. A pattern
% that stops matching (because the source .mod was reformatted) returns the input
% unchanged, shipping a frozen model that still carries calibrated values - or
% do_parameter_estimation = true - under a header claiming it is frozen.
% subst_verified turns that into an error; these tests prove the guard fires.
%
% Usage:
%   >> test_frozen_model_generator
%
% Prerequisites:
%   - Current directory must be macromodel/

    fprintf('\n');
    fprintf('=================================================================\n');
    fprintf('  FROZEN MODEL GENERATOR GUARD TESTS\n');
    fprintf('=================================================================\n\n');

    n_pass = 0;
    n_fail = 0;

    % VALUE_PATTERN as used by generate_frozen_model.m
    value_pattern = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';

    %% ================================================================
    fprintf('TEST 1: guard fires when a pattern no longer matches\n');
    [n_pass, n_fail] = expect_error(@() subst_verified( ...
            'alpha = 0.5;', 'beta\s*=\s*[0-9.]+;', 'beta = 9;', 'missing param', 1), ...
        'generate_frozen_model:substitutionFailed', ...
        'zero matches', n_pass, n_fail);

    %% ================================================================
    fprintf('\nTEST 2: guard fires when a pattern matches too often\n');
    [n_pass, n_fail] = expect_error(@() subst_verified( ...
            sprintf('rho_L = 0;\nrho_L = 0.95;\n'), ...
            'rho_L\s*=\s*[0-9.]+;', 'rho_L = 1;', 'duplicated param', 1), ...
        'generate_frozen_model:substitutionFailed', ...
        'two matches when one expected', n_pass, n_fail);

    %% ================================================================
    fprintf('\nTEST 3: a correct substitution still succeeds\n');
    try
        out = subst_verified('omega_h  = 0.35;  // calibrated', ...
            sprintf('((?<![a-zA-Z_])omega_h\\s*=\\s*)%s\\s*;', value_pattern), ...
            '$10.318781;  // ESTIMATED (posterior mode)', 'omega_h', 1);
        if contains(out, '0.318781') && contains(out, 'ESTIMATED')
            fprintf('  [PASS] substitution applied: %s\n', strtrim(out));
            n_pass = n_pass + 1;
        else
            fprintf('  [FAIL] unexpected result: %s\n', out);
            n_fail = n_fail + 1;
        end
    catch ME
        fprintf('  [FAIL] unexpected error: %s\n', ME.message);
        n_fail = n_fail + 1;
    end

    %% ================================================================
    fprintf('\nTEST 4: value pattern accepts negative and scientific notation\n');
    % psi_wL is -0.08 (Poland) / -0.05 (Germany). The previous [0-9.]+ pattern
    % could not match either, so estimating such a parameter would have silently
    % left the calibrated value in the "frozen" model.
    cases = { ...
        'psi_wL   = -0.08;',  'psi_wL',  'negative value'; ...
        'lambda_p = 1.5e-3;', 'lambda_p', 'scientific notation'; ...
        'sigma    = 2.0;',    'sigma',    'plain positive'};

    for i = 1:size(cases, 1)
        line = cases{i, 1};
        pname = cases{i, 2};
        label = cases{i, 3};
        pattern = sprintf('((?<![a-zA-Z_])%s\\s*=\\s*)%s\\s*;', pname, value_pattern);
        hits = regexp(line, pattern, 'match');
        if numel(hits) == 1
            fprintf('  [PASS] %-22s matched (%s)\n', label, strtrim(line));
            n_pass = n_pass + 1;
        else
            fprintf('  [FAIL] %-22s matched %d time(s): %s\n', label, numel(hits), line);
            n_fail = n_fail + 1;
        end
    end

    %% ================================================================
    fprintf('\nTEST 5: calibrated value is read as written, and only when unambiguous\n');
    % The estimation-mode branch of the rho_L / rho_h conditional blocks must
    % carry the country's own calibrated value. It used to be a constant
    % (Germany's 0.95 / 0.85), which misrecorded Poland and Spain (rho_h = 0.80).
    calib = sprintf(['rho_L    = 0.95;    // labor force persistence\n' ...
                     'rho_h    = 0.80;    // hours persistence (below Germany''s 0.85)\n' ...
                     '// RATIONALE: rho_L=0.95 and rho_h=0.85 capture persistence\n']);
    try
        got = read_calibrated_value(calib, 'rho_h');
        if strcmp(got, '0.80')
            fprintf('  [PASS] rho_h read as written: %s\n', got);
            n_pass = n_pass + 1;
        else
            fprintf('  [FAIL] rho_h read as "%s", expected "0.80"\n', got);
            n_fail = n_fail + 1;
        end
    catch ME
        fprintf('  [FAIL] unexpected error: %s\n', ME.message);
        n_fail = n_fail + 1;
    end
    [n_pass, n_fail] = expect_error(@() read_calibrated_value(calib, 'rho_inv'), ...
        'generate_frozen_model:calibratedValueNotFound', ...
        'parameter absent', n_pass, n_fail);
    [n_pass, n_fail] = expect_error(@() read_calibrated_value( ...
            sprintf('rho_h = 0;\nrho_h = 0.85;\n'), 'rho_h'), ...
        'generate_frozen_model:calibratedValueNotFound', ...
        'parameter assigned twice', n_pass, n_fail);

    %% ================================================================
    fprintf('\nTEST 6: every frozen model records its own country''s persistence\n');
    % End-to-end form of TEST 5, on the generated files themselves: the
    % @#else (estimation-mode) branch must equal the calibration file.
    countries = {'Germany', 'Poland', 'Spain', 'Sweden'};
    for i = 1:numel(countries)
        country = countries{i};
        frozen_file = sprintf('Macromodel_%s_frozen.mod', country);
        calib_file = fullfile('country_params', sprintf('%s_calibration.mod', country));
        if ~exist(frozen_file, 'file') || ~exist(calib_file, 'file')
            fprintf('  [SKIP] %s: no frozen model or calibration file\n', country);
            continue;
        end
        frozen_text = fileread(frozen_file);
        calib_text = fileread(calib_file);
        pnames = {'rho_L', 'rho_h'};
        for j = 1:numel(pnames)
            pname = pnames{j};
            expected = str2double(read_calibrated_value(calib_text, pname));
            tok = regexp(frozen_text, ...
                sprintf('@#else\\s*\\n\\s*%s\\s*=\\s*([0-9.]+)\\s*;', pname), 'tokens', 'once');
            if isempty(tok)
                fprintf('  [FAIL] %s: no estimation-mode %s branch in %s\n', country, pname, frozen_file);
                n_fail = n_fail + 1;
            elseif str2double(tok{1}) == expected
                fprintf('  [PASS] %-8s %s = %s in both\n', country, pname, tok{1});
                n_pass = n_pass + 1;
            else
                fprintf('  [FAIL] %-8s %s: frozen model says %s, calibration says %g\n', ...
                        country, pname, tok{1}, expected);
                n_fail = n_fail + 1;
            end
        end
    end

    %% ================================================================
    fprintf('\n-----------------------------------------------------------------\n');
    fprintf('  %d passed, %d failed\n', n_pass, n_fail);
    fprintf('-----------------------------------------------------------------\n\n');

    if n_fail > 0
        error('test_frozen_model_generator: %d check(s) failed', n_fail);
    end
end


function [n_pass, n_fail] = expect_error(fn, expected_id, label, n_pass, n_fail)
    try
        fn();
        fprintf('  [FAIL] %s: expected an error, none raised\n', label);
        n_fail = n_fail + 1;
    catch ME
        if strcmp(ME.identifier, expected_id)
            fprintf('  [PASS] %s -> %s\n', label, ME.identifier);
            n_pass = n_pass + 1;
        else
            fprintf('  [FAIL] %s: wrong error id %s\n', label, ME.identifier);
            n_fail = n_fail + 1;
        end
    end
end
