function test_demographic_pair_coherence
% The demographic pair check must accept a one-vintage pair (same post-handoff
% growth, different units) for workers (N vs L_demo) and consumers (P vs
% P_demo), and flag divergent growth, a missing forward tail or a projection
% without the named column.

    setup_path();
    td = tempname; mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's'));

    pop_file = fullfile(td, 'population_projection_Testland.csv');
    demo_L = fullfile(td, 'demographic_L_testland.csv');
    demo_P = fullfile(td, 'demographic_P_testland.csv');
    quarters = {'2022q4','2023q1','2023q2','2023q3'};

    write_cols(pop_file, {'time','N','P'}, {'2023q1','2023q2','2023q3'}, ...
               [1000 1010 1020.1; 1500 1530 1545.3]');
    write_cols(demo_L, {'time','L_demo'}, quarters, [1990; 2000; 2020; 2040.2]);
    write_cols(demo_P, {'time','P_demo'}, quarters, [3000; 3000; 3060; 3090.6]);
    problems = check_demographic_pair_coherence(pop_file, 'N', demo_L, 'L_demo', '2023q1');
    assert(isempty(problems), 'coherent N pair flagged: %s', strjoin(problems, '; '));
    problems = check_demographic_pair_coherence(pop_file, 'P', demo_P, 'P_demo', '2023q1');
    assert(isempty(problems), 'coherent P pair flagged: %s', strjoin(problems, '; '));

    % divergent L growth is flagged
    write_cols(demo_L, {'time','L_demo'}, quarters, [1990; 2000; 2030; 2060]);
    problems = check_demographic_pair_coherence(pop_file, 'N', demo_L, 'L_demo', '2023q1');
    assert(~isempty(problems), 'divergent post-handoff growth not flagged');

    % a missing forward tail is flagged
    write_cols(demo_L, {'time','L_demo'}, {'2022q4','2023q1'}, [1990; 2000]);
    problems = check_demographic_pair_coherence(pop_file, 'N', demo_L, 'L_demo', '2023q1');
    assert(~isempty(problems), 'missing forward tail not flagged');

    % divergent P growth is flagged
    write_cols(demo_P, {'time','P_demo'}, quarters, [3000; 3000; 3090; 3150]);
    problems = check_demographic_pair_coherence(pop_file, 'P', demo_P, 'P_demo', '2023q1');
    assert(~isempty(problems), 'divergent P growth not flagged');

    % a projection without the named column is a problem, not a crash
    write_cols(pop_file, {'time','N'}, {'2023q1','2023q2','2023q3'}, [1000; 1010; 1020.1]);
    problems = check_demographic_pair_coherence(pop_file, 'P', demo_P, 'P_demo', '2023q1');
    assert(~isempty(problems) && contains(problems{1}, 'P'), ...
           'projection without P column not flagged');

    fprintf('test_demographic_pair_coherence: PASS\n');
end

function write_cols(path, names, times, vals)
    fid = fopen(path, 'w');
    fprintf(fid, '%s\n', strjoin(names, ','));
    for i = 1:numel(times)
        fprintf(fid, '%s', times{i});
        fprintf(fid, ',%.6f', vals(i, :));
        fprintf(fid, '\n');
    end
    fclose(fid);
end
