function loc = model_location()
% MODEL_LOCATION  Where the model root sits in the SimPathsEU tree, in one place.
%
%   loc.repo_rel    model root relative to the repository root
%   loc.input_tree  SimPaths input tree relative to the model root
%
% Every path that depends on where the model lives goes through here: the bundle
% role of artifact_path, the population-file default, the exporters' provenance
% lists and repo_relative in write_bundle_provenance. test_artifact_layout checks
% both values against the checkout, so a move that forgets this file fails the
% fast set instead of writing into the wrong folder. BundleProvenanceTest.java
% holds the same root as MODEL_ROOT; the regenerated bundle pins the two together.
% The helper covers a move at the same depth (two levels below the repository root),
% which also edits the literal pathspecs in smoke_test.ps1; another depth also edits the
% repository-root sites in refresh_java_parity_fixtures.m, diagnostics/generate_foc_parity_cases.m,
% smoke_test.ps1 and stata/make_datasets.do.
    loc = struct('repo_rel',   'input_processing/macromodel', ...
                 'input_tree', fullfile('..', '..', 'input'));
end
