function test_export_bundle_marker
% A bundle that verify_export_bundle refuses must say so INSIDE the bundle.
%
% The refusal used to live only in the error message of the run that produced
% it. The files it refused stayed in simpaths_export/{COUNTRY}/, the folder
% whose contract is "copy this to SimPathsEU", and nothing there distinguished
% them from a shippable bundle. The marker file is that distinction: written on
% every failed (or never-reached) verification, removed by one that passes.

    setup_path();
    td = tempname; mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's')); %#ok<NASGU>

    country = 'Testland';
    marker = fullfile(td, 'BUNDLE_NOT_VERIFIED.txt');

    % 1. An incomplete bundle is refused AND marked, naming what is missing.
    raised = false;
    try
        verify_export_bundle(td, country);
    catch ME
        raised = strcmp(ME.identifier, 'verify_export_bundle:Inconsistent');
    end
    assert(raised, 'incomplete bundle was not refused');
    assert(exist(marker, 'file') == 2, 'refused bundle carries no marker file');
    txt = fileread(marker);
    assert(contains(txt, 'population_projection_Testland.csv'), ...
           'marker does not name the missing file');
    assert(contains(txt, 'DO NOT COPY'), 'marker does not say what it means');

    % 2. The marker is deterministic: a second identical refusal rewrites the
    %    same bytes, so a re-run leaves git status clean.
    try, verify_export_bundle(td, country); catch, end %#ok<CTCH>
    assert(strcmp(txt, fileread(marker)), 'marker content is not deterministic');

    % 3. Completing the bundle and verifying again removes the marker.
    needed = {sprintf('growth_params_%s.json', country), 'growth_terminal_state.json', ...
              sprintf('growth_model_reference_%s.csv', lower(country)), ...
              sprintf('population_projection_%s.csv', country), ...
              sprintf('hours_projection_%s.csv', country)};
    for i = 1:numel(needed)
        fid = fopen(fullfile(td, needed{i}), 'w');
        fprintf(fid, '{}\n');
        fclose(fid);
    end
    verify_export_bundle(td, country);
    assert(exist(marker, 'file') == 0, 'verified bundle still carries the marker');

    % 4. An export that starts marks the bundle before it writes anything, so
    %    one that dies partway cannot leave a clean-looking mixed bundle.
    mark_bundle_unverified(td, country, {'export started but did not reach verification'});
    assert(exist(marker, 'file') == 2, 'in-progress marker was not written');
    assert(contains(fileread(marker), 'did not reach verification'), ...
           'in-progress marker does not carry its reason');
    verify_export_bundle(td, country);
    assert(exist(marker, 'file') == 0, 'verification did not clear the in-progress marker');

    fprintf('test_export_bundle_marker: PASS\n');
end
