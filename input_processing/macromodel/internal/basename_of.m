function name = basename_of(p)
% BASENAME_OF  File name and extension of a path, without its folders.
%
%   basename_of('output/growth_model_reference_poland.csv')
%       -> 'growth_model_reference_poland.csv'
%
% WHY THIS EXISTS
%   Artefact paths now carry a role folder (artifact_path returns
%   'output/foo.csv', not 'foo.csv'). Anything that copies such a file into a
%   DIFFERENT directory must strip that folder first:
%
%       copyfile(src, fullfile(dest_dir, src))            % WRONG
%           -> dest_dir/output/foo.csv, and dest_dir/output does not exist
%       copyfile(src, fullfile(dest_dir, basename_of(src)))  % right
%           -> dest_dir/foo.csv
%
%   The wrong form is what the exporters had after the reorganisation: it read
%   correctly when the source was a bare filename and silently started composing
%   a nested destination once the source gained a folder. It failed loudly at
%   copyfile, but only after the exporter had already written the policy
%   matrices -- leaving a half-updated SimPaths bundle.

    [~, stem, ext] = fileparts(p);
    name = [stem ext];
end
