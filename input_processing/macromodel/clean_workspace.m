function removed = clean_workspace(options)
% CLEAN_WORKSPACE  Delete the macro model's generated files.
%
%   clean_workspace                     list what WOULD be deleted (default)
%   clean_workspace('execute', true)    actually delete it
%   clean_workspace('what', 'dynare')   restrict to one group
%   removed = clean_workspace(...)      return the paths
%
% Groups:
%   dynare    Dynare's own output: +Macromodel_*/ package folders,
%             Macromodel_*/ result folders, its logs and .mat files. These are
%             written into the working directory unconditionally -- Dynare has
%             no output-directory option -- so deleting is the only way to keep
%             the root tidy.
%   output    output/  the model's own generated series and state
%   logs      logs/    diaries and text reports
%   figures   figures/ figures written by our plotting code
%   data      data/    NOT included in 'all'. These are pipeline INPUTS: the
%             Stata exports and the NAWRU/demographic files. Deleting them
%             means re-running make_datasets.do.
%
% 'all' means dynare + output + logs + figures. Ask for 'data' explicitly.
%
% Dry run by default, because the difference between "tidy the workspace" and
% "throw away a day of estimation" is one flag.

    arguments
        options.execute (1,1) logical = false
        options.what (1,:) char = 'all'
    end

    if ~exist(fullfile(pwd, 'run_full_workflow.m'), 'file')
        error('clean_workspace:WrongFolder', ...
              'Run this from the macro model root. Current folder: %s', pwd);
    end

    groups = {'dynare', 'output', 'logs', 'figures', 'data'};
    if strcmp(options.what, 'all')
        selected = {'dynare', 'output', 'logs', 'figures'};
    elseif ismember(options.what, groups)
        selected = {options.what};
    else
        error('clean_workspace:UnknownGroup', ...
              'Unknown group "%s". Valid: all, %s.', options.what, strjoin(groups, ', '));
    end

    targets = {};
    for i = 1:numel(selected)
        targets = [targets collect(selected{i})]; %#ok<AGROW>
    end
    targets = unique(targets);

    if isempty(targets)
        fprintf('clean_workspace: nothing to remove (%s).\n', strjoin(selected, ', '));
        removed = {};
        if nargout == 0; clear removed; end
        return;
    end

    total_bytes = 0;
    for i = 1:numel(targets)
        total_bytes = total_bytes + entry_size(targets{i});
    end

    if options.execute
        fprintf('clean_workspace: removing %d entr(ies), %.1f MB\n', ...
                numel(targets), total_bytes / 1e6);
    else
        fprintf(['clean_workspace: DRY RUN -- %d entr(ies), %.1f MB would be removed.\n' ...
                 'Pass ''execute'', true to do it.\n'], numel(targets), total_bytes / 1e6);
    end

    for i = 1:numel(targets)
        t = targets{i};
        fprintf('  %s%s\n', t, dir_marker(t));
        if options.execute
            if isfolder(t)
                rmdir(t, 's');
            else
                delete(t);
            end
        end
    end

    removed = targets;
    if nargout == 0; clear removed; end
end

function items = collect(group)
    items = {};
    switch group
        case 'dynare'
            % Dynare package folders, result folders and stray logs/mat files.
            items = [items listing('+Macromodel_*')];
            items = [items listing('Macromodel_*')];
            items = [items listing('dynareParallelLogFiles')];
            % Keep the sources: the .mod files are not generated.
            items = items(~endsWith(items, '.mod'));
        case 'output'
            items = [items listing(fullfile('output', '*'))];
        case 'logs'
            items = [items listing(fullfile('logs', '*'))];
        case 'figures'
            items = [items listing(fullfile('figures', '*'))];
        case 'data'
            items = [items listing(fullfile('data', '*'))];
    end
end

function names = listing(pattern)
    d = dir(pattern);
    d = d(~ismember({d.name}, {'.', '..'}));
    names = arrayfun(@(e) fullfile(relative_folder(e.folder), e.name), d, ...
                     'UniformOutput', false)';
    if isempty(names); names = {}; end
end

function r = relative_folder(absolute_folder)
    root = pwd;
    if strcmp(absolute_folder, root)
        r = '';
    elseif startsWith(absolute_folder, [root filesep])
        r = absolute_folder(numel(root) + 2 : end);
    else
        r = absolute_folder;
    end
end

function b = entry_size(p)
    if isfolder(p)
        d = dir(fullfile(p, '**', '*'));
        d = d(~[d.isdir]);
        b = sum([d.bytes]);
        if isempty(b); b = 0; end
    else
        info = dir(p);
        if isempty(info); b = 0; else; b = info(1).bytes; end
    end
end

function m = dir_marker(p)
    if isfolder(p); m = '/'; else; m = ''; end
end
