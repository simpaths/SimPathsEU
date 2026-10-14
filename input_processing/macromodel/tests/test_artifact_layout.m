function test_artifact_layout()
% TEST_ARTIFACT_LAYOUT  No pipeline artefact may be written to the model root.
%
% Every generated file has a declared home under data/, output/, logs/,
% figures/, the bundle or tests/fixtures/, resolved through artifact_path. This
% check exists because a MISSED write site fails in the worst possible way: the
% writer puts the file in the root, a reader looks in the subfolder and does not
% find it, and depending on the reader that is either a loud error or a silent
% fallback to a stale copy that IS in the subfolder.
%
% It runs against whatever is on disk, so it catches the miss the first time the
% pipeline is run after the reorganisation rather than at the next audit.
%
% Dynare's own output is exempt: it writes +Macromodel_*/ , Macromodel_*/ and
% its logs into the working directory unconditionally and offers no way to
% redirect them. clean_workspace removes those.

    fprintf('\n');
    fprintf('=================================================================\n');
    fprintf('  ARTEFACT LAYOUT\n');
    fprintf('=================================================================\n\n');

    if ~exist(fullfile(pwd, 'run_full_workflow.m'), 'file')
        error('test_artifact_layout:WrongFolder', ...
              'Run from the macro model root. Current folder: %s', pwd);
    end

    % Patterns that must never appear in the root. Each names where it belongs.
    rules = {
        'data_for_dynare*.csv',          'data/'
        'nawru_*.csv',                   'data/'
        'demographic_L_*.csv',           'data/'
        'ramsey_trends_*.csv',           'output/'
        'growth_model_reference_*.csv',  'output/'
        'population_projection_*.csv',   'output/'
        'ramsey_trend_*.mat',            'output/'
        'ramsey_diagnostic_*.png',       'figures/'
        'ramsey_projection_*.png',       'figures/'
        'ramsey_projection_*.pdf',       'figures/'
        'calibrate_growth_model_*.log',  'logs/'
        'ramsey_trend_*.log',            'logs/'
        'foc_parity_cases.csv',          'tests/fixtures/'
        '_macroScenario_*.csv',          '../../input/{CC}/MacroModel/'
    };

    strays = {};
    for i = 1:size(rules, 1)
        found = dir(rules{i, 1});
        found = found(~[found.isdir]);
        for j = 1:numel(found)
            strays{end+1} = sprintf('%-42s should be in %s', ...
                                    found(j).name, rules{i, 2}); %#ok<AGROW>
        end
    end

    if isempty(strays)
        fprintf('  [PASS] no pipeline artefacts in the model root\n\n');
    else
        fprintf('  [FAIL] %d artefact(s) written to the model root:\n', numel(strays));
        fprintf('         %s\n', strays{:});
        fprintf(['\n  A writer is still using a bare filename instead of artifact_path().\n' ...
                 '  Find it, route it through artifact_path, and delete the stray copy --\n' ...
                 '  a reader looking in the subfolder may otherwise pick up a stale one.\n\n']);
        error('test_artifact_layout:StrayArtifacts', ...
              '%d pipeline artefact(s) in the model root; see the list above.', ...
              numel(strays));
    end

    % The declared folders must be reachable through artifact_path, and artifact_path
    % must refuse to work outside the model root.
    kinds = {'data', 'output', 'logs', 'figures'};
    for i = 1:numel(kinds)
        p = artifact_path(kinds{i}, 'probe.txt');
        assert(startsWith(p, [kinds{i} filesep]), ...
               'artifact_path(''%s'') returned "%s"', kinds{i}, p);
    end
    fprintf('  [PASS] artifact_path resolves all %d artefact roles\n\n', numel(kinds));

    % The model root's place in the SimPathsEU tree is one helper; both of its
    % values must agree with this checkout, or a move left the helper behind.
    loc = model_location();
    here = strsplit(strrep(pwd, '\', '/'), '/');
    assert(strcmp(strjoin(here(end-1:end), '/'), loc.repo_rel), ...
           'model_location.repo_rel is "%s" but pwd is %s', loc.repo_rel, pwd);
    assert(isfolder(fullfile(loc.input_tree, 'PL', 'MacroModel')), ...
           'model_location.input_tree does not reach input/PL/MacroModel from %s', pwd);
    fprintf('  [PASS] model_location agrees with the checkout\n\n');

    % The bundle role resolves into the SimPaths input tree, per country, and
    % does not need the folder to exist. The model root is
    % input_processing/macromodel/, so the input tree is ../../input.
    p = artifact_path('bundle', 'policy_A.csv', 'country', 'Poland');
    assert(strcmp(p, fullfile('..', '..', 'input', 'PL', 'MacroModel', 'policy_A.csv')), ...
           'artifact_path(''bundle'') returned "%s"', p);
    assert(strcmp(artifact_path('bundle', '', 'country', 'Sweden'), ...
                  fullfile('..', '..', 'input', 'SE', 'MacroModel')), 'bundle dir for Sweden');
    raised = false;
    try, artifact_path('bundle', 'x'); catch ME, raised = strcmp(ME.identifier, 'artifact_path:CountryRequired'); end
    assert(raised, 'bundle role without a country must refuse');
    raised = false;
    try, artifact_path('scenarios', 'x'); catch ME, raised = strcmp(ME.identifier, 'artifact_path:UnknownKind'); end
    assert(raised, 'the scenarios role no longer exists: scenario CSVs live in input/{CC}/MacroModel/');
    fprintf('  [PASS] bundle role resolves into ../../input/{CC}/MacroModel\n\n');

    % A refused bundle must never be committed into the SimPaths input tree.
    [status, tracked] = system('git ls-files ../../input/*/MacroModel/BUNDLE_NOT_VERIFIED.txt');
    assert(status == 0, 'git ls-files failed: %s', tracked);
    assert(isempty(strtrim(tracked)), ...
           'refused bundle(s) are tracked in git:\n%s\nRemove them; only verified bundles ship.', tracked);
    fprintf('  [PASS] no refused bundle is tracked under input/*/MacroModel\n\n');
end
