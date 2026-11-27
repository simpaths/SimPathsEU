function test_insample_population
% TEST_INSAMPLE_POPULATION  The planner's in-sample consumers come from the data.
%
% In sample the planner's population P is the HP trend (lambda = 160,000) of
% the log resident population pop_level, as its workers N are the HP trend of
% n_level, and the workbook's growth enters the in-sample solve only after the
% last data quarter. Checked on Poland, whose workbook steps by +2.5% between
% its 2023 and 2024 columns, inside the estimation sample.
%
%   1. The bundle's reference CSV carries that trend in every quarter through
%      the handoff, its last row included (handoff_P0).
%   2. After a ramsey_trend('Poland') run (output/ramsey_trend_poland.mat), the
%      in-sample solve's population P_ext equals that trend through the last
%      data quarter and grows into the next quarter at demographic_P's own
%      growth, so the splice adds no step of its own.
%
% Usage (from the model root):
%   >> test_insample_population

    setup_path();
    level_file = artifact_path('data', 'data_for_dynare_levels_Poland.csv');
    data = trim_trailing_missing(readtable(level_file));
    T = height(data);
    P_hp = exp(hp_filter_trend(log(data.pop_level), 160000));

    %% 1. Reference CSV (tracked bundle file)
    % The smoke test deletes the bundle before run_all_tests and regenerates it
    % afterwards, so the file is absent while this test runs there.
    ref_file = artifact_path('bundle', 'growth_model_reference_poland.csv', 'country', 'Poland');
    if ~exist(ref_file, 'file')
        fprintf('  [SKIP] %s not present; the bundle export writes it\n', ref_file);
    else
        ref = readtable(ref_file);
        n_ref = height(ref);
        assert(n_ref <= T, '%s has %d rows, more than the %d sample quarters', ref_file, n_ref, T);
        err_ref = max(abs(ref.P ./ P_hp(1:n_ref) - 1));
        assert(err_ref < 1e-12, ...
               '%s: P differs from the HP trend of pop_level by up to %.3e (relative)', ref_file, err_ref);
        fprintf('  [PASS] reference CSV P = HP trend of pop_level in all %d quarters through %s (max rel. error %.1e)\n', ...
                n_ref, char(string(ref.time(end))), err_ref);
    end

    %% 2. The in-sample solve's population, after a run
    mat_file = artifact_path('output', 'ramsey_trend_poland.mat');
    if ~exist(mat_file, 'file')
        fprintf('  [SKIP] %s not present; run ramsey_trend(''Poland'') for the splice check\n', mat_file);
        return;
    end
    S = load(mat_file);
    if ~isfield(S, 'P_ext')
        fprintf(['  [SKIP] %s has no P_ext, so an older ramsey_trend wrote it; ' ...
                 're-run ramsey_trend(''Poland'') for the splice check\n'], mat_file);
        return;
    end
    assert(numel(S.P_ext) > T, '%s: P_ext ends inside the sample', mat_file);
    err_in = max(abs(S.P_ext(1:T) ./ P_hp - 1));
    assert(err_in < 1e-12, ...
           'in-sample P differs from the HP trend of pop_level by up to %.3e (relative)', err_in);
    fprintf('  [PASS] in-sample P = HP trend of pop_level through %s (max rel. error %.1e)\n', ...
            char(string(data.time(T))), err_in);

    demo = readtable(artifact_path('data', 'demographic_P_poland.csv'));
    if height(demo) > T
        g_model = S.P_ext(T+1) / S.P_ext(T);
        g_demo = demo.P_demo(T+1) / demo.P_demo(T);
        assert(abs(g_model / g_demo - 1) < 1e-12, ...
               'P grows %+.5f%% into the quarter after %s, demographic_P %+.5f%%', ...
               100 * (g_model - 1), char(string(data.time(T))), 100 * (g_demo - 1));
        fprintf('  [PASS] P grows %+.5f%% into the quarter after %s, as demographic_P does (%+.5f%%)\n', ...
                100 * (g_model - 1), char(string(data.time(T))), 100 * (g_demo - 1));
    end
    fprintf('test_insample_population: PASS\n');
end
