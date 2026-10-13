function test_calibration_identities()
% TEST_CALIBRATION_IDENTITIES  Guards the steady-state labour-share identity
% in the country calibration files, and the calibration parser that the
% documentation layer depends on.
%
% Background: the linearised unemployment identity (Macromodel_template.mod
% eq. 10) is u = (chi_L/chi_u)*L - (chi_n/chi_u)*n, which is the exact
% linearisation of U = L - N only when chi_u is the unemployment-to-
% POPULATION share, i.e. chi_u = chi_L - chi_n. Poland was calibrated with
% the U/L rate (0.05 instead of 0.03), mis-scaling the latent u -> theta ->
% matching -> bargaining chain by ~40%.
%
% Usage:
%   >> test_calibration_identities
%
% Prerequisites:
%   - Current directory must be macromodel/

    fprintf('\n');
    fprintf('=================================================================\n');
    fprintf('  CALIBRATION IDENTITY TESTS\n');
    fprintf('=================================================================\n\n');

    % Was addpath('documentation_tables') -- pwd-relative, so it silently added
    % nothing (or the wrong folder) when run from anywhere but the model root.
    setup_path();

    n_pass = 0;
    n_fail = 0;

    countries = {'Germany', 'Poland', 'Spain', 'Sweden'};

    %% ================================================================
    %% TEST 1: chi_u equals chi_L - chi_n in every country file
    %% ================================================================
    fprintf('TEST 1: Steady-state labour shares satisfy chi_u = chi_L - chi_n\n');
    for i = 1:numel(countries)
        country = countries{i};
        cal_file = fullfile('country_params', sprintf('%s_calibration.mod', country));
        cal = load_calibration_for_test(cal_file);

        required = {'chi_L', 'chi_n', 'chi_u'};
        missing = required(~isfield(cal, required));
        if ~isempty(missing)
            fprintf('  [FAIL] %-8s parser did not resolve: %s\n', ...
                    country, strjoin(missing, ', '));
            n_fail = n_fail + 1;
            continue;
        end

        implied = cal.chi_L - cal.chi_n;
        gap = abs(cal.chi_u - implied);
        if gap < 1e-12
            fprintf('  [PASS] %-8s chi_L=%.4f chi_n=%.4f chi_u=%.4f (u-rate %.2f%%)\n', ...
                    country, cal.chi_L, cal.chi_n, cal.chi_u, ...
                    100 * cal.chi_u / cal.chi_L);
            n_pass = n_pass + 1;
        else
            fprintf('  [FAIL] %-8s chi_u=%.4f but chi_L-chi_n=%.4f (gap %.4f)\n', ...
                    country, cal.chi_u, implied, gap);
            n_fail = n_fail + 1;
        end
    end

    %% ================================================================
    %% TEST 1b: the implied unemployment rate matches the ESTIMATION SAMPLE
    %% ================================================================
    % The identity alone is not enough. chi_L=0.73, chi_n=0.70, chi_u=0.03 satisfies
    % it exactly while implying a 4.1% unemployment rate on a sample that averages
    % 7.16% - the model would be linearised around a point the data never visits.
    % Since chi_u scales the whole latent u channel, that cost ~140 log points of
    % marginal likelihood. Tolerance is deliberately loose: this catches a wrong
    % window or a U/L-vs-U/pop mix-up, not ordinary rounding.
    fprintf('\nTEST 1b: implied u-rate matches the estimation-sample mean\n');
    tol_pp = 1.5;
    for i = 1:numel(countries)
        country = countries{i};
        cal = load_calibration_for_test(fullfile('country_params', ...
                sprintf('%s_calibration.mod', country)));
        level_file = artifact_path('data', sprintf('data_for_dynare_levels_%s.csv', country));
        if ~exist(level_file, 'file') || ~isfield(cal, 'chi_u')
            fprintf('  [SKIP] %s (no level data or chi_u)\n', country);
            continue;
        end

        levels = readtable(level_file);
        if ~ismember('u_level', levels.Properties.VariableNames)
            fprintf('  [SKIP] %s (no u_level column)\n', country);
            continue;
        end
        observed = levels.u_level(~isnan(levels.u_level));
        sample_rate = mean(observed);
        implied_rate = 100 * cal.chi_u / cal.chi_L;

        if abs(implied_rate - sample_rate) <= tol_pp
            fprintf('  [PASS] %-8s implied %.2f%% vs sample mean %.2f%% (|diff| %.2fpp)\n', ...
                    country, implied_rate, sample_rate, abs(implied_rate - sample_rate));
            n_pass = n_pass + 1;
        else
            fprintf(['  [FAIL] %-8s implied %.2f%% vs sample mean %.2f%% ' ...
                     '(|diff| %.2fpp > %.1fpp)\n'], ...
                    country, implied_rate, sample_rate, ...
                    abs(implied_rate - sample_rate), tol_pp);
            n_fail = n_fail + 1;
        end
    end

    %% ================================================================
    %% TEST 2: the calibration parser resolves derived expressions
    %% ================================================================
    fprintf('\nTEST 2: parse_calibration_file resolves derived parameter expressions\n');
    fixture = [tempname '.mod'];
    fid = fopen(fixture, 'w');
    if fid == -1
        error('Could not create parser fixture: %s', fixture);
    end
    fprintf(fid, 'chi_L    = 0.73;    // participation\n');
    fprintf(fid, 'chi_n    = 0.70;    // employment\n');
    fprintf(fid, 'chi_u    = chi_L - chi_n;  // derived U/pop share\n');
    fprintf(fid, 'sum_test = chi_L + chi_n;  // derived sum\n');
    fprintf(fid, 'plain    = 0.42;    // plain literal still works\n');
    fclose(fid);
    cleaner = onCleanup(@() delete(fixture));

    cal = load_calibration_for_test(fixture);
    checks = { ...
        'chi_u',    0.03,  'derived difference'; ...
        'sum_test', 1.43,  'derived sum'; ...
        'plain',    0.42,  'plain literal'};

    for i = 1:size(checks, 1)
        field = checks{i, 1};
        expected = checks{i, 2};
        label = checks{i, 3};
        if ~isfield(cal, field)
            fprintf('  [FAIL] %-9s (%s) not resolved by parser\n', field, label);
            n_fail = n_fail + 1;
        elseif abs(cal.(field) - expected) < 1e-12
            fprintf('  [PASS] %-9s = %.4f (%s)\n', field, cal.(field), label);
            n_pass = n_pass + 1;
        else
            fprintf('  [FAIL] %-9s = %.4f, expected %.4f (%s)\n', ...
                    field, cal.(field), expected, label);
            n_fail = n_fail + 1;
        end
    end

    %% ================================================================
    fprintf('\n-----------------------------------------------------------------\n');
    fprintf('  %d passed, %d failed\n', n_pass, n_fail);
    fprintf('-----------------------------------------------------------------\n\n');

    if n_fail > 0
        error('test_calibration_identities: %d check(s) failed', n_fail);
    end
end


function cal = load_calibration_for_test(cal_file)
% Exercises the same parser the documentation layer uses.
    cal = parse_calibration_file(cal_file);
end
