function test_bundle_provenance
% BUNDLE_PROVENANCE.txt names the inputs a bundle was built from, by content hash.
%
% The hash must name the content, not the checkout: this repository is CRLF on
% Windows (core.autocrlf=true) and LF on Linux CI, and BundleProvenanceTest.java
% recomputes the hashes there. So CRLF and LF copies of a text input hash the
% same, a binary input hashes raw, a missing input is recorded rather than
% invented, and the digest agrees with an independent implementation.

    setup_path();
    td = tempname; mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's')); %#ok<NASGU>

    lf   = fullfile(td, 'lf.csv');   write_bytes(lf,   uint8(sprintf('a,b\n1,2\n')));
    crlf = fullfile(td, 'crlf.csv'); write_bytes(crlf, uint8(sprintf('a,b\r\n1,2\r\n')));

    known = '492d5ea496056f1a6a6592241032fab764c321596317930b4fa0e1e8bc3b7470';
    assert(strcmp(sha256_file(lf), known), 'sha256_file disagrees with the known digest');
    assert(strcmp(sha256_file(lf), sha256_file(crlf)), 'CRLF and LF text must hash alike');
    assert(~strcmp(sha256_file(lf, 'text', false), sha256_file(crlf, 'text', false)), ...
           'raw mode must see the CR bytes');
    empty = fullfile(td, 'empty.csv'); write_bytes(empty, uint8([]));
    nothing = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    assert(strcmp(sha256_file(empty), nothing) && strcmp(sha256_file(empty, 'text', false), nothing), ...
           'an empty file must hash to the SHA-256 of nothing, as Java does');

    bundle = fullfile(td, 'bundle'); mkdir(bundle);
    prov = write_bundle_provenance(bundle, 'Testland', 'test_bundle_provenance', ...
        {lf, 't'; crlf, 'b'; fullfile(td, 'absent.xlsx'), 'b'});
    assert(strcmp(prov, fullfile(bundle, 'BUNDLE_PROVENANCE.txt')), 'wrong file name');
    raw = double(fileread(prov));
    assert(raw(end) == 10 && raw(end-1) ~= 10, 'the file must end in exactly one newline');

    lines = strsplit(strtrim(fileread(prov)), newline);
    assert(strcmp(lines{1}, 'BUNDLE_PROVENANCE'), 'first line is the format tag');
    assert(any(startsWith(lines, 'country      Testland')), 'country line');
    assert(any(startsWith(lines, 'exporter     test_bundle_provenance')), 'exporter line');
    sha_lines = lines(startsWith(lines, 'sha256 '));
    assert(numel(sha_lines) == 2, 'two hashable inputs expected, got %d', numel(sha_lines));
    assert(sum(startsWith(lines, 'missing ')) == 1, 'the absent input must be recorded as missing');
    % The path is the rest of the line: a temp folder may contain spaces.
    parts = regexp(sha_lines{1}, '^sha256 (\S+) (\S+) (.+)$', 'tokens', 'once');
    assert(numel(parts) == 3, 'line format: sha256 <kind> <hex> <path>');
    assert(strcmp(parts{1}, 't') && strcmp(parts{2}, known), 'first line hashes lf.csv in text mode');
    parts = regexp(sha_lines{2}, '^sha256 (\S+) (\S+) (.+)$', 'tokens', 'once');
    assert(numel(parts) == 3 && strcmp(parts{1}, 'b') && strcmp(parts{2}, sha256_file(crlf, 'text', false)), ...
           'second line hashes crlf.csv raw');

    % Re-running on unchanged inputs changes only the timestamp line.
    pause(1.1);
    write_bundle_provenance(bundle, 'Testland', 'test_bundle_provenance', {lf, 't'; crlf, 'b'});
    again = strsplit(strtrim(fileread(prov)), newline);
    keep = ~startsWith(lines, 'exported_at') & ~startsWith(lines, 'missing ');
    assert(isequal(lines(keep), again(~startsWith(again, 'exported_at'))), ...
           'content other than the timestamp must be deterministic');

    % Relative paths are recorded relative to the repository root: the model
    % root is model_location().repo_rel, and each leading ../ drops one of its
    % segments. Backslashes count as slashes; more ../ than segments is not an
    % error (it cannot happen from the model root, but must not crash a run).
    write_bundle_provenance(bundle, 'Testland', 'test_bundle_provenance', ...
        {'data/absent.csv', 't'; ...
         fullfile('..', '..', 'input', 'PL', 'absent.xlsx'), 'b'; ...
         fullfile('..', 'absent.do'), 't'; ...
         '..\..\input\PL\absent2.xlsx', 'b'; ...
         fullfile('..', '..', '..', 'absent3.txt'), 't'});
    mapped = strsplit(strtrim(fileread(prov)), newline);
    assert(any(strcmp(mapped, 'missing input_processing/macromodel/data/absent.csv')), ...
           'a bare path maps to input_processing/macromodel/<path>');
    assert(any(strcmp(mapped, 'missing input/PL/absent.xlsx')), ...
           'a ../../ path maps to <repository root>/<path>');
    assert(any(strcmp(mapped, 'missing input_processing/absent.do')), ...
           'a ../ path maps to input_processing/<path>');
    assert(any(strcmp(mapped, 'missing input/PL/absent2.xlsx')), ...
           'backslashes are recorded as slashes');
    assert(any(strcmp(mapped, 'missing absent3.txt')), ...
           'more ../ than the model root has segments must not error');

    % The bundle's own files are hashed after the inputs, sorted by name, in
    % text mode; the provenance file, the refusal marker, the scenario CSVs
    % (Java reads them, no exporter writes them), dotfiles and .tmp leftovers
    % are not. policy_A.csv has CRLF line endings, as a Windows export writes
    % them, so raw-mode hashing of bundle files fails the digest check below.
    write_bytes(fullfile(bundle, 'policy_A.csv'), uint8(sprintf('var,k\r\nk,0.95\r\n')));
    write_bytes(fullfile(bundle, 'growth_terminal_state.json'), uint8('{"K_terminal": 1}'));
    write_bytes(fullfile(bundle, '_macroScenario_x.csv'), uint8(sprintf('a\n1\n')));
    write_bytes(fullfile(bundle, 'BUNDLE_NOT_VERIFIED.txt'), uint8(sprintf('refused\n')));
    write_bytes(fullfile(bundle, '.DS_Store'), uint8([0 0 0 1 66 117 100 49]));
    write_bytes(fullfile(bundle, 'x.tmp'), uint8(sprintf('partial')));
    write_bundle_provenance(bundle, 'Testland', 'test_bundle_provenance', {lf, 't'});
    outs = strsplit(strtrim(fileread(prov)), newline);
    sha = outs(startsWith(outs, 'sha256 '));
    assert(numel(sha) == 3, 'one input plus two bundle files expected, got %d', numel(sha));
    paths = cellfun(@(c) c{1}, regexp(sha, '^sha256 \S+ \S+ (.+)$', 'tokens', 'once'), ...
                    'UniformOutput', false);
    assert(endsWith(paths{1}, 'lf.csv'), 'the input line comes first');
    assert(strcmp(paths{2}, [strrep(bundle, '\', '/') '/growth_terminal_state.json']) && ...
           strcmp(paths{3}, [strrep(bundle, '\', '/') '/policy_A.csv']), ...
           'bundle files follow, sorted by name, as absolute paths for a temp folder');
    assert(~any(contains(outs, '_macroScenario_')) && ~any(contains(outs, 'BUNDLE_NOT_VERIFIED')) && ...
           sum(contains(outs, 'BUNDLE_PROVENANCE.txt')) == 0, 'scenario CSVs, the marker and the file itself are excluded');
    assert(~any(contains(outs, '.DS_Store')) && ~any(contains(outs, 'x.tmp')), ...
           'dotfiles and .tmp leftovers are excluded');
    kinds = cellfun(@(c) c{1}, regexp(sha(2:3), '^sha256 (\S+) ', 'tokens', 'once'), ...
                    'UniformOutput', false);
    assert(all(strcmp(kinds, 't')), 'bundle files hash in text mode');
    policy = fullfile(bundle, 'policy_A.csv');
    hex3 = regexp(sha{3}, '^sha256 t (\S+) ', 'tokens', 'once');
    assert(strcmp(hex3{1}, sha256_file(policy)), 'bundle file digest');
    assert(~strcmp(hex3{1}, sha256_file(policy, 'text', false)), ...
           'a CRLF bundle file must hash with CR bytes dropped, not raw');

    % extra_lines (export_ramsey_for_simpaths carries the DSGE-half input lines
    % this way) go in verbatim after the hashed lines, and the file stays
    % deterministic with them.
    carried = ['sha256 t ' known ' input_processing/macromodel/Macromodel_Testland_frozen.mod'];
    write_bundle_provenance(bundle, 'Testland', 'test_bundle_provenance', {lf, 't'}, ...
                            'extra_lines', {carried});
    with_extra = strsplit(strtrim(fileread(prov)), newline);
    assert(strcmp(with_extra{end}, carried), 'the extra line must come last, verbatim');
    assert(sum(startsWith(with_extra, 'sha256 ')) == 4, 'one input, two bundle files, one extra line');
    write_bundle_provenance(bundle, 'Testland', 'test_bundle_provenance', {lf, 't'}, ...
                            'extra_lines', {carried});
    again = strsplit(strtrim(fileread(prov)), newline);
    assert(isequal(with_extra(~startsWith(with_extra, 'exported_at')), ...
                   again(~startsWith(again, 'exported_at'))), ...
           'content other than the timestamp must be deterministic with extra lines');

    % The Ramsey-only export carries the three DSGE-half input lines of the
    % previous file when the bundle still holds the policy matrices.
    old = {'BUNDLE_PROVENANCE', 'country      Testland', ...
           ['sha256 t ' known ' input_processing/macromodel/Macromodel_Testland_frozen.mod'], ...
           ['sha256 t ' known ' input_processing/macromodel/data/data_for_dynare_Testland.csv'], ...
           ['sha256 t ' known ' input_processing/macromodel/Macromodel_template.mod'], ...
           ['sha256 t ' known ' input_processing/macromodel/country_params/Testland_calibration.mod']};
    write_bytes(prov, uint8([strjoin(old, newline) newline]));
    carried3 = carried_dsge_input_lines(bundle, 'Testland');
    assert(isequal(carried3, old([3 5 6])), 'frozen model, template and calibration lines are carried, in file order');
    delete(fullfile(bundle, 'policy_A.csv'));
    assert(isempty(carried_dsge_input_lines(bundle, 'Testland')), 'nothing is carried without policy matrices');

    fprintf('test_bundle_provenance: PASS\n');
end

function write_bytes(file, bytes)
    fid = fopen(file, 'w');
    assert(fid > 0, 'cannot write %s', file);
    fwrite(fid, bytes, 'uint8');
    fclose(fid);
end
