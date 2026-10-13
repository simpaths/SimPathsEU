function p = artifact_path(kind, name, options)
% ARTIFACT_PATH  Path of a pipeline artefact, by role.
%
%   artifact_path('data',   'data_for_dynare_Poland.csv')  -> 'data/data_for_dynare_Poland.csv'
%   artifact_path('output', 'ramsey_trend_poland.mat')     -> 'output/ramsey_trend_poland.mat'
%   artifact_path('logs',   'ramsey_trend_poland.log')     -> 'logs/ramsey_trend_poland.log'
%   artifact_path('figures','ramsey_diagnostic_poland.png')-> 'figures/ramsey_diagnostic_poland.png'
%   artifact_path(..., 'create', true)   also creates the folder
%
% Roles:
%   data      inputs the pipeline consumes (Stata exports, NAWRU, demographics)
%   output    series and state the model produces (trends, reference CSV, .mat)
%   logs      diaries and text reports
%   figures   figures written by our own plotting code
%   scenarios scenario definition CSVs
%
% NAME: deliberately not 'model_file'. That name collided with local variables
% of the same name in run_full_workflow.m and run_detrending_benchmark.m, both
% holding a .mod filename. MATLAB classifies an identifier as a VARIABLE for the
% whole function scope if it is assigned anywhere in the body, so every call in
% those two files parsed as indexing an unassigned variable -- regardless of the
% function existing on the path. checkcode did not flag it, and the unit tests
% passed because none of them calls an entry point. tests/test_name_collisions.m
% now guards the class.
%
% Returns a path RELATIVE to the working directory, deliberately. The working
% directory has to be the model root anyway -- Dynare writes its own output
% into pwd unconditionally and resolves its datafile from there -- so anchoring
% these paths anywhere else would split the artefacts of one run across two
% places. That requirement is checked here rather than surfacing later as a
% file-not-found from whichever reader happened to run first.

    arguments
        kind (1,:) char
        name (1,:) char = ''
        options.create (1,1) logical = false
    end

    folders = struct( ...
        'data',      'data', ...
        'output',    'output', ...
        'logs',      'logs', ...
        'figures',   'figures', ...
        'scenarios', 'scenarios');

    if ~isfield(folders, kind)
        error('artifact_path:UnknownKind', ...
              'Unknown artefact role "%s". Valid roles: %s.', ...
              kind, strjoin(fieldnames(folders)', ', '));
    end

    assert_in_model_root();

    folder = folders.(kind);
    if options.create && ~exist(folder, 'dir')
        mkdir(folder);
    end

    if isempty(name)
        p = folder;
    else
        p = fullfile(folder, name);
    end
end

function assert_in_model_root()
% The model root is identifiable by its entry points. Checking costs nothing and
% turns "the CSV is missing" into "you are in the wrong folder", which is what
% actually went wrong.
    persistent checked_dir
    if ~isempty(checked_dir) && strcmp(checked_dir, pwd)
        return;
    end
    if ~exist(fullfile(pwd, 'run_full_workflow.m'), 'file')
        error('artifact_path:WrongFolder', ...
              ['The macro model must be run from its root folder (the one holding ' ...
               'run_full_workflow.m). Current folder is:\n  %s\n' ...
               'Dynare writes its output into the working directory and resolves ' ...
               'its datafile from there, so this is not something the code can ' ...
               'paper over.'], pwd);
    end
    checked_dir = pwd;
end
