function test_demographic_pair_coherence
% The demographic pair check must accept a one-vintage pair (same post-handoff
% growth, different units) and flag divergent growth or a missing forward tail.

    setup_path();
    td = tempname; mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's')); %#ok<NASGU>

    pop_file = fullfile(td, 'population_projection_Testland.csv');
    demo_file = fullfile(td, 'demographic_L_testland.csv');

    write_two_col(pop_file, 'time,N', {'2023q1','2023q2','2023q3'}, [1000; 1010; 1020.1]);
    write_two_col(demo_file, 'time,L_demo', {'2022q4','2023q1','2023q2','2023q3'}, ...
                  [1990; 2000; 2020; 2040.2]);
    problems = check_demographic_pair_coherence(pop_file, demo_file, '2023q1');
    assert(isempty(problems), 'coherent pair flagged: %s', strjoin(problems, '; '));

    write_two_col(demo_file, 'time,L_demo', {'2022q4','2023q1','2023q2','2023q3'}, ...
                  [1990; 2000; 2030; 2060]);
    problems = check_demographic_pair_coherence(pop_file, demo_file, '2023q1');
    assert(~isempty(problems), 'divergent post-handoff growth not flagged');

    write_two_col(demo_file, 'time,L_demo', {'2022q4','2023q1'}, [1990; 2000]);
    problems = check_demographic_pair_coherence(pop_file, demo_file, '2023q1');
    assert(~isempty(problems), 'missing forward tail not flagged');

    fprintf('test_demographic_pair_coherence: PASS\n');
end

function write_two_col(path, header, times, vals)
    fid = fopen(path, 'w');
    fprintf(fid, '%s\n', header);
    for i = 1:numel(times)
        fprintf(fid, '%s,%.6f\n', times{i}, vals(i));
    end
    fclose(fid);
end
