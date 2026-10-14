function test_data_loading()
% TEST_DATA_LOADING  Guards the ragged-edge handling of the level data files.
%
% make_datasets.do exports a full quarterly calendar, so the last rows of
% data_for_dynare_levels_{COUNTRY}.csv routinely carry no observables yet: the
% calendar runs ahead of published national accounts. Averaging a "last year"
% window over that tail yields NaN, which propagates into g_Y, K_0 and the
% N trend and finally makes the Ramsey initial guess infeasible - the failure
% that silently kept the Ramsey pipeline from running between 2026-05 and
% 2026-08 while the Stata HP fallback stood in for its output.
%
% Usage:
%   >> test_data_loading

    fprintf('\n');
    fprintf('=================================================================\n');
    fprintf('  LEVEL DATA LOADING TESTS\n');
    fprintf('=================================================================\n\n');

    n_pass = 0;
    n_fail = 0;
    value_vars = {'y_level', 'n_level'};

    %% ================================================================
    fprintf('TEST 1: trailing rows with no observables are dropped\n');
    tbl = make_table({'2024q1','2024q2','2024q3','2024q4'}, ...
                     [100; 101; NaN; NaN], [50; 51; NaN; NaN]);
    [out, n_trimmed] = trim_trailing_missing(tbl, value_vars);
    [n_pass, n_fail] = check(height(out) == 2 && n_trimmed == 2, ...
        sprintf('kept %d rows, trimmed %d', height(out), n_trimmed), n_pass, n_fail);

    %% ================================================================
    fprintf('\nTEST 2: a row with ANY observable present is kept\n');
    tbl = make_table({'2024q1','2024q2','2024q3'}, ...
                     [100; 101; NaN], [50; 51; 52]);
    [out, n_trimmed] = trim_trailing_missing(tbl, value_vars);
    [n_pass, n_fail] = check(height(out) == 3 && n_trimmed == 0, ...
        sprintf('kept %d rows, trimmed %d', height(out), n_trimmed), n_pass, n_fail);

    %% ================================================================
    fprintf('\nTEST 3: interior gaps are preserved (only the tail is trimmed)\n');
    tbl = make_table({'2024q1','2024q2','2024q3','2024q4'}, ...
                     [100; NaN; 102; NaN], [50; NaN; 52; NaN]);
    [out, n_trimmed] = trim_trailing_missing(tbl, value_vars);
    interior_kept = height(out) == 3 && isnan(out.y_level(2));
    [n_pass, n_fail] = check(interior_kept && n_trimmed == 1, ...
        sprintf('kept %d rows (interior NaN intact), trimmed %d', height(out), n_trimmed), ...
        n_pass, n_fail);

    %% ================================================================
    fprintf('\nTEST 4: a fully empty table is an error, not a silent zero-row result\n');
    tbl = make_table({'2024q1','2024q2'}, [NaN; NaN], [NaN; NaN]);
    try
        trim_trailing_missing(tbl, value_vars);
        fprintf('  [FAIL] expected an error, none raised\n');
        n_fail = n_fail + 1;
    catch ME
        if strcmp(ME.identifier, 'trim_trailing_missing:noData')
            fprintf('  [PASS] raised %s\n', ME.identifier);
            n_pass = n_pass + 1;
        else
            fprintf('  [FAIL] wrong error id: %s\n', ME.identifier);
            n_fail = n_fail + 1;
        end
    end

    %% ================================================================
    fprintf('\nTEST 5: the default column set is the production trio, not every column\n');
    % L_level and u_level run past y_level/n_level/h_level in the real files, so
    % trimming on the full set would keep rows the production function cannot use.
    tbl = make_full_table({'2024q1','2024q2','2024q3'}, ...
                          [100; 101; NaN], ...   % y_level
                          [50; 51; NaN], ...     % n_level
                          [10; 11; NaN], ...     % h_level
                          [70; 71; 72]);         % L_level runs one quarter longer
    [out, n_trimmed] = trim_trailing_missing(tbl);
    [n_pass, n_fail] = check(height(out) == 2 && n_trimmed == 1, ...
        sprintf('kept %d rows, trimmed %d (L_level tail ignored)', height(out), n_trimmed), ...
        n_pass, n_fail);

    %% ================================================================
    fprintf('\nTEST 6: the real Poland level file trims to its last usable quarter\n');
    level_file = artifact_path('data', 'data_for_dynare_levels_Poland.csv');
    if exist(level_file, 'file')
        raw = readtable(level_file);
        [trimmed, n_trimmed] = trim_trailing_missing(raw);
        core_complete = ~isnan(trimmed.y_level(end)) && ~isnan(trimmed.n_level(end)) ...
                        && ~isnan(trimmed.h_level(end));
        [n_pass, n_fail] = check(core_complete && height(trimmed) > 0, ...
            sprintf('%d rows -> %d (%d ragged trimmed, last kept %s with complete inputs)', ...
                    height(raw), height(trimmed), n_trimmed, ...
                    char(string(trimmed.time(end)))), n_pass, n_fail);
    else
        fprintf('  [SKIP] %s not present\n', level_file);
    end

    %% ================================================================
    fprintf('\nTEST 7: the interest rate is not missing at either end of the sample\n');
    % Unlike the ragged national-accounts tail, a missing R is not trimmed: the
    % rows stay, the Kalman filter runs without the rate observable, and
    % ramsey_trend.m extrapolates the ex-ante real rate linearly over the gap,
    % which tilts the HP trend of R across the WHOLE sample. Poland ran that way
    % from 2024q1 to 2025q1 because its OECD source had stopped updating.
    synthetic = table({'2024q1'; '2024q2'; '2024q3'}, [100; 101; 102], [50; 51; 52], ...
                      [10; 11; 12], [5.8; NaN; NaN], ...
                      'VariableNames', {'time', 'y_level', 'n_level', 'h_level', 'R'});
    [n_lead, n_trail] = count_edge_missing(synthetic.R);
    [n_pass, n_fail] = check(n_lead == 0 && n_trail == 2, ...
        sprintf('a 2-quarter missing tail is detected (found %d)', n_trail), n_pass, n_fail);

    countries = {'Germany', 'Poland', 'Spain', 'Sweden'};
    for i = 1:numel(countries)
        level_file = artifact_path('data', sprintf('data_for_dynare_levels_%s.csv', countries{i}));
        if ~exist(level_file, 'file')
            fprintf('  [SKIP] %s not present\n', level_file);
            continue;
        end
        trimmed = trim_trailing_missing(readtable(level_file));
        [n_lead, n_trail] = count_edge_missing(trimmed.R);
        [n_pass, n_fail] = check(n_lead == 0 && n_trail == 0, ...
            sprintf('%-8s R complete at both ends (%d leading, %d trailing missing)', ...
                    countries{i}, n_lead, n_trail), n_pass, n_fail);
    end

    %% ================================================================
    fprintf('\n-----------------------------------------------------------------\n');
    fprintf('  %d passed, %d failed\n', n_pass, n_fail);
    fprintf('-----------------------------------------------------------------\n\n');

    if n_fail > 0
        error('test_data_loading: %d check(s) failed', n_fail);
    end
end


function [n_lead, n_trail] = count_edge_missing(x)
% Number of missing values before the first and after the last observation.
    present = find(~isnan(x));
    if isempty(present)
        n_lead = numel(x);
        n_trail = numel(x);
        return;
    end
    n_lead = present(1) - 1;
    n_trail = numel(x) - present(end);
end


function tbl = make_table(times, y, n)
    tbl = table(times(:), y, n, 'VariableNames', {'time', 'y_level', 'n_level'});
end

function tbl = make_full_table(times, y, n, h, l)
    tbl = table(times(:), y, n, h, l, 'VariableNames', ...
                {'time', 'y_level', 'n_level', 'h_level', 'L_level'});
end

function [n_pass, n_fail] = check(condition, label, n_pass, n_fail)
    if condition
        fprintf('  [PASS] %s\n', label);
        n_pass = n_pass + 1;
    else
        fprintf('  [FAIL] %s\n', label);
        n_fail = n_fail + 1;
    end
end
