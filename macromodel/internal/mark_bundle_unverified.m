function marker_file = mark_bundle_unverified(output_dir, country, problems)
% MARK_BUNDLE_UNVERIFIED  Record inside an export bundle that it must not ship.
%
%   mark_bundle_unverified(dir, 'Sweden', {'missing: ...'})   write the marker
%   mark_bundle_unverified(dir, 'Sweden', {})                 remove it
%
% WHY THIS EXISTS
%   verify_export_bundle refuses a bundle by raising an error, which is seen by
%   whoever ran that export and by nobody afterwards. The files stay in
%   simpaths_export/{COUNTRY}/ - the folder whose contract is "copy this to
%   SimPathsEU/input/{CC}/MacroModel/" - and get committed looking exactly like
%   a shippable bundle. The Spain and Sweden bundles were committed that way in
%   2026-09: complete except for the population projection, which Java treats
%   as optional and silently replaces with its default extrapolation.
%
%   The marker makes the refusal a property of the bundle. Both exporters write
%   it before their first file, so an export that dies partway is marked too,
%   and verify_export_bundle removes it only when the bundle passes.
%
% The content is deterministic (no timestamp): re-running an export on an
% unchanged, still-refused bundle must leave `git status` clean.

    arguments
        output_dir (1,:) char
        country (1,:) char
        problems cell
    end

    marker_file = fullfile(output_dir, 'BUNDLE_NOT_VERIFIED.txt');

    if isempty(problems)
        if exist(marker_file, 'file')
            delete(marker_file);
        end
        return;
    end

    lines = [{ ...
        'THIS BUNDLE IS NOT VERIFIED - DO NOT COPY IT TO SimPaths', ...
        '========================================================', ...
        sprintf('Country: %s', country), ...
        '', ...
        'Reason:'}, ...
        cellfun(@(p) ['  ' strrep(p, newline, [newline '  '])], problems(:)', ...
                'UniformOutput', false), ...
        {'', ...
        'Written by the export whenever verification fails or is never reached,', ...
        'and removed by the next export that verifies. While this file is here', ...
        'the bundle is incomplete or mixes vintages.', ...
        'See macromodel/internal/verify_export_bundle.m.'}];

    write_text_atomic(marker_file, strjoin(lines, newline));
end
