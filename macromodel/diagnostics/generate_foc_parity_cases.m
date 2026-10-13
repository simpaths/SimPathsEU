function generate_foc_parity_cases()
% GENERATE_FOC_PARITY_CASES  Write the MATLAB<->Java FOC parity fixture.
%
% The intratemporal participation FOC exists twice by architecture: MATLAB solves
% it while detrending and projecting, Java solves it inside SimPaths' forward
% projection. Nothing structural keeps the two in step - in 2026 they disagreed
% for three months and every run still "succeeded".
%
% This writes a small table of (inputs -> expected l) rows computed by the MATLAB
% implementation. Both sides then assert against the same numbers:
%   MATLAB: test_labor_foc.m
%   Java:   RamseyTrendModelTest.testLaborFOCMatchesMATLABParityCases
%
% A full pipeline run is not needed to catch drift - either side failing means the
% mirrors have separated.
%
% Regenerate ONLY when the FOC itself intentionally changes, and re-run both test
% suites afterwards. Regenerating to make a failing test pass would defeat the
% purpose: the fixture is the contract, not an output.
%
% Usage:
%   >> generate_foc_parity_cases

    % The fixture belongs with the tests that assert it, not in the run root.
    out_matlab = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                          'tests', 'fixtures', 'foc_parity_cases.csv');
    if ~exist(fileparts(out_matlab), 'dir'); mkdir(fileparts(out_matlab)); end
    out_java = fullfile('..', '..', 'SimPathsEU', 'src', 'test', 'resources', ...
                        'macro', 'foc_parity_cases.csv');

    % Deliberately spans interior solutions, both clamps, and a range of hours so
    % the h exponent is pinned by more than one point.
    cases = [
    %   c      K         A       WAP      h      alpha  sigma  phi    psi
        4.00,  1.37e6,   0.0345, 23430,   490,   0.33,  1.50,  2.00,  1.615
        4.00,  1.37e6,   0.0345, 23430,   245,   0.33,  1.50,  2.00,  1.615
        4.00,  1.37e6,   0.0345, 23430,   980,   0.33,  1.50,  2.00,  1.615
        4.32,  7.39e5,   0.0264, 26824,   515,   0.33,  1.50,  1.35,  1.877
        13.87, 9.00e6,   0.0580, 55000,   345,   0.33,  1.50,  1.35,  1.240
        4.00,  1.37e6,   0.0345, 23430,   490,   0.35,  2.00,  3.00,  25.0
        4.00,  1.37e6,   0.0345, 23430,   490,   0.33,  1.50,  2.00,  1.0e-8
        4.00,  1.37e6,   0.0345, 23430,   490,   0.33,  1.50,  2.00,  1.0e12
    ];

    n = size(cases, 1);
    l = zeros(n, 1);
    for i = 1:n
        l(i) = solve_labor_foc(cases(i,1), cases(i,2), cases(i,3), cases(i,4), ...
                               cases(i,5), cases(i,6), cases(i,7), cases(i,8), ...
                               cases(i,9));
    end

    tbl = array2table([cases, l], 'VariableNames', ...
        {'c', 'K', 'A', 'WAP', 'h', 'alpha', 'sigma', 'phi', 'psi', 'expected_l'});

    write_case_table(tbl, out_matlab);
    if exist(fileparts(out_java), 'dir')
        write_case_table(tbl, out_java);
        fprintf('  ✓ %s\n', out_java);
    else
        warning('Java test resources not found at %s; wrote MATLAB copy only.', ...
                fileparts(out_java));
    end
    fprintf('  ✓ %s (%d cases)\n', out_matlab, n);

    disp(tbl);
end

function write_case_table(tbl, path)
% Full precision: the fixture is compared at 1e-12, so 15 significant digits.
    fid = fopen(path, 'w');
    if fid == -1
        error('Cannot write parity fixture: %s', path);
    end
    names = tbl.Properties.VariableNames;
    fprintf(fid, '%s\n', strjoin(names, ','));
    data = table2array(tbl);
    for i = 1:size(data, 1)
        fprintf(fid, '%.15g', data(i, 1));
        fprintf(fid, ',%.15g', data(i, 2:end));
        fprintf(fid, '\n');
    end
    fclose(fid);
end
