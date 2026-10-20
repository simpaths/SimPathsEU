function test_compare_bundles
% compare_bundles says whether two bundles agree numerically within a tolerance,
% and must not pass vacuously: a missing file, a different header, a different
% row count or a NaN where the other side has a number are all differences.

    setup_path();
    td = tempname; mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's'));
    a = fullfile(td, 'a'); b = fullfile(td, 'b'); mkdir(a); mkdir(b);

    put(a, 'policy_A.csv', sprintf('var,k,a\nk,0.95,0.10\na,0.00,0.90\n'));
    put(b, 'policy_A.csv', sprintf('var,k,a\nk,0.9500001,0.10\na,0.00,0.90\n'));
    put(a, 'growth_terminal_state.json', '{"K_terminal": 1.5e6, "handoff_time": "2024Q1"}');
    put(b, 'growth_terminal_state.json', '{"K_terminal": 1.5000001e6, "handoff_time": "2024Q1"}');
    put(a, 'SIMPATHS_INTERFACE.md', sprintf('# Export\n**Generated:** 01-Jan-2026\nn_state 13\n'));
    put(b, 'SIMPATHS_INTERFACE.md', sprintf('# Export\n**Generated:** 02-Feb-2026\nn_state 13\n'));
    put(a, 'BUNDLE_PROVENANCE.txt', sprintf('BUNDLE_PROVENANCE\nexported_at  2026-01-01 00:00:00\nsha256 t abc x\n'));
    put(b, 'BUNDLE_PROVENANCE.txt', sprintf('BUNDLE_PROVENANCE\nexported_at  2026-02-02 00:00:00\nsha256 t abc x\n'));

    r = compare_bundles(a, b, 'rel_tol', 1e-6);
    assert(r.ok, 'within tolerance, timestamps ignored: %s', strjoin(r.differences, '; '));
    assert(r.files_compared == 4, 'all four files compared, got %d', r.files_compared);

    r = compare_bundles(a, b, 'rel_tol', 1e-9);
    assert(~r.ok && any(contains(r.differences, 'policy_A.csv')), 'tighter tolerance must flag the CSV');

    % Row count, header, NaN and a missing file are differences, not passes.
    put(b, 'policy_A.csv', sprintf('var,k,a\nk,0.95,0.10\n'));
    r = compare_bundles(a, b); assert(~r.ok && any(contains(r.differences, 'rows')), 'row count');
    put(b, 'policy_A.csv', sprintf('var,k,b\nk,0.95,0.10\na,0.00,0.90\n'));
    r = compare_bundles(a, b); assert(~r.ok && any(contains(r.differences, 'columns')), 'header');
    put(b, 'policy_A.csv', sprintf('var,k,a\nk,NaN,0.10\na,0.00,0.90\n'));
    r = compare_bundles(a, b); assert(~r.ok && any(contains(r.differences, 'policy_A.csv')), 'NaN vs number');
    delete(fullfile(b, 'policy_A.csv'));
    r = compare_bundles(a, b); assert(~r.ok && any(contains(r.differences, 'only in')), 'missing file');

    raised = false;
    try
        compare_bundles(a, b, 'fail', true);
    catch ME
        raised = strcmp(ME.identifier, 'compare_bundles:Different');
    end
    assert(raised, '''fail'', true must throw on differences');

    % An empty text cell reads as <missing>, which isequal never calls equal: on
    % both sides it is agreement, facing text it is a difference.
    c = fullfile(td, 'c'); e = fullfile(td, 'e'); mkdir(c); mkdir(e);
    put(c, 'notes.csv', sprintf('key,label\nx,\ny,z\n'));
    put(e, 'notes.csv', sprintf('key,label\nx,\ny,z\n'));
    r = compare_bundles(c, e); assert(r.ok, 'missing text on both sides: %s', strjoin(r.differences, '; '));
    put(e, 'notes.csv', sprintf('key,label\nx,w\ny,z\n'));
    r = compare_bundles(c, e); assert(~r.ok && any(contains(r.differences, 'notes.csv')), 'missing text vs text');

    % An excluded name is neither compared nor counted, whether it differs or is on one side only.
    g = fullfile(td, 'g'); h = fullfile(td, 'h'); mkdir(g); mkdir(h);
    put(g, 'policy_A.csv', sprintf('var,k\nk,0.95\n'));
    put(h, 'policy_A.csv', sprintf('var,k\nk,0.95\n'));
    put(g, '_macroScenario_x.csv', sprintf('year,g_A\n2023,0.0025\n'));
    put(h, '_macroScenario_x.csv', sprintf('year,g_A\n2023,0.0050\n'));
    put(h, '_macroScenario_y.csv', sprintf('year,g_A\n2023,0.0025\n'));
    r = compare_bundles(g, h);
    assert(~r.ok && r.files_compared == 2, 'without exclude the scenario files count and differ');
    r = compare_bundles(g, h, 'exclude', '_macroScenario_*.csv');
    assert(r.ok, 'excluded files must not fail: %s', strjoin(r.differences, '; '));
    assert(r.files_compared == 1, 'excluded files must not count, got %d', r.files_compared);

    % Text files: numbers within tolerance, everything around them exact, line count exact.
    p = fullfile(td, 'p'); q = fullfile(td, 'q'); mkdir(p); mkdir(q);
    put(p, 'SIMPATHS_INTERFACE.md', sprintf('# Export\n| beta | 0.95000 |\n'));
    put(q, 'SIMPATHS_INTERFACE.md', sprintf('# Export\n| beta | 0.9500001 |\n'));
    r = compare_bundles(p, q, 'rel_tol', 1e-6); assert(r.ok, 'numeric noise in text within tolerance: %s', strjoin(r.differences, '; '));
    r = compare_bundles(p, q, 'rel_tol', 1e-9); assert(~r.ok && any(contains(r.differences, 'SIMPATHS_INTERFACE.md')), 'numeric noise in text beyond tolerance');
    put(q, 'SIMPATHS_INTERFACE.md', sprintf('# Export\n| beta | 0.95000 |\nextra\n'));
    r = compare_bundles(p, q); assert(~r.ok && any(contains(r.differences, 'line')), 'line count in text');
    put(q, 'SIMPATHS_INTERFACE.md', sprintf('# Export\n\n| beta | 0.95000 |\n'));
    r = compare_bundles(p, q); assert(~r.ok && any(contains(r.differences, 'line')), 'a blank line counts');

    % Provenance: the digest is the Java test's business; kind and path are compared.
    s = fullfile(td, 's'); u = fullfile(td, 'u'); mkdir(s); mkdir(u);
    put(s, 'BUNDLE_PROVENANCE.txt', sprintf('BUNDLE_PROVENANCE\nsha256 t 3f2a9c51 input_processing/macromodel/data/data_for_dynare_Poland.csv\n'));
    put(u, 'BUNDLE_PROVENANCE.txt', sprintf('BUNDLE_PROVENANCE\nsha256 t 7b1e0482 input_processing/macromodel/data/data_for_dynare_Poland.csv\n'));
    r = compare_bundles(s, u); assert(r.ok, 'digest must be ignored: %s', strjoin(r.differences, '; '));
    put(u, 'BUNDLE_PROVENANCE.txt', sprintf('BUNDLE_PROVENANCE\nsha256 t 7b1e0482 input_processing/macromodel/data/data_for_dynare_Spain.csv\n'));
    r = compare_bundles(s, u); assert(~r.ok && any(contains(r.differences, 'BUNDLE_PROVENANCE.txt')), 'path must be compared');

    % JSON arrays of objects: compared element by element, and their length counts.
    j1 = fullfile(td, 'j1'); j2 = fullfile(td, 'j2'); mkdir(j1); mkdir(j2);
    put(j1, 'model_info.json', '{"x": [{"k": 1}, {"k": 2}]}');
    put(j2, 'model_info.json', '{"x": [{"k": 1}, {"k": 2.0000001}]}');
    r = compare_bundles(j1, j2, 'rel_tol', 1e-6); assert(r.ok, 'object array within tolerance: %s', strjoin(r.differences, '; '));
    put(j2, 'model_info.json', '{"x": [{"k": 1}, {"k": 3}]}');
    r = compare_bundles(j1, j2); assert(~r.ok && any(contains(r.differences, 'model_info.json')), 'object array value');
    put(j2, 'model_info.json', '{"x": [{"k": 1}, {"k": 2}, {"k": 3}]}');
    r = compare_bundles(j1, j2); assert(~r.ok && any(contains(r.differences, 'model_info.json')), 'object array length');

    % Ragged JSON arrays decode to cells; the numbers in them keep the tolerance.
    put(j1, 'model_info.json', '{"r": [[1, 2], [3]]}');
    put(j2, 'model_info.json', '{"r": [[1, 2.0000001], [3]]}');
    r = compare_bundles(j1, j2, 'rel_tol', 1e-6); assert(r.ok, 'ragged array within tolerance: %s', strjoin(r.differences, '; '));
    put(j2, 'model_info.json', '{"r": [[1, 2], [4]]}');
    r = compare_bundles(j1, j2); assert(~r.ok && any(contains(r.differences, 'model_info.json')), 'ragged array value');
    put(j2, 'model_info.json', '{"r": [[1, 2], [3], [5]]}');
    r = compare_bundles(j1, j2); assert(~r.ok && any(contains(r.differences, 'model_info.json')), 'ragged array length');

    % Equal infinities agree; opposite ones do not.
    i1 = fullfile(td, 'i1'); i2 = fullfile(td, 'i2'); mkdir(i1); mkdir(i2);
    put(i1, 'inf.csv', sprintf('key,v\nx,Inf\ny,-Inf\n'));
    put(i2, 'inf.csv', sprintf('key,v\nx,Inf\ny,-Inf\n'));
    r = compare_bundles(i1, i2); assert(r.ok, 'equal infinities: %s', strjoin(r.differences, '; '));
    put(i2, 'inf.csv', sprintf('key,v\nx,-Inf\ny,-Inf\n'));
    r = compare_bundles(i1, i2); assert(~r.ok && any(contains(r.differences, 'inf.csv')), 'opposite infinities');
    put(i2, 'inf.csv', sprintf('key,v\nx,1e300\ny,-Inf\n'));
    r = compare_bundles(i1, i2); assert(~r.ok && any(contains(r.differences, 'inf.csv')), 'infinity against a number');

    % Integers in text are compared exactly: under a relative tolerance, 1e6 or more
    % differing by 1 would pass (a date stamp, a count).
    put(p, 'SIMPATHS_INTERFACE.md', sprintf('# Export\nstamp 20261013\n'));
    put(q, 'SIMPATHS_INTERFACE.md', sprintf('# Export\nstamp 20261014\n'));
    r = compare_bundles(p, q, 'rel_tol', 1e-6); assert(~r.ok && any(contains(r.differences, 'SIMPATHS_INTERFACE.md')), 'integers in text are exact');

    % Scenario CSVs: '=' in the comment block must not become the delimiter, the data
    % keep the tolerance, and the comment lines are compared as text.
    hdr = sprintf(['# Scenario: higher TFP growth (+0.25 pp)\n#\n# Parameters:\n' ...
                   '#   g_A     = TFP growth rate deviation (annual, e.g. 0.0025 = +0.25pp)\n' ...
                   '#   delta   = depreciation rate deviation (annual)\n#\n']);
    v1 = fullfile(td, 'v1'); v2 = fullfile(td, 'v2'); mkdir(v1); mkdir(v2);
    put(v1, '_macroScenario_x.csv', [hdr sprintf('year,g_A\n2023,0.0025\n2024,0.0030\n')]);
    put(v2, '_macroScenario_x.csv', [hdr sprintf('year,g_A\n2023,0.0025000001\n2024,0.0030\n')]);
    r = compare_bundles(v1, v2, 'rel_tol', 1e-6); assert(r.ok, 'scenario CSV within tolerance: %s', strjoin(r.differences, '; '));
    put(v2, '_macroScenario_x.csv', [hdr sprintf('year,g_A\n2023,0.0050\n2024,0.0030\n')]);
    r = compare_bundles(v1, v2); assert(~r.ok && any(contains(r.differences, '_macroScenario_x.csv')), 'scenario CSV value');
    put(v2, '_macroScenario_x.csv', [strrep(hdr, '+0.25 pp', '+0.50 pp') sprintf('year,g_A\n2023,0.0025\n2024,0.0030\n')]);
    r = compare_bundles(v1, v2); assert(~r.ok && any(contains(r.differences, '_macroScenario_x.csv')), 'scenario CSV comment');

    fprintf('test_compare_bundles: PASS\n');
end

function put(dir, name, text)
    fid = fopen(fullfile(dir, name), 'w'); fwrite(fid, text, 'char'); fclose(fid);
end
