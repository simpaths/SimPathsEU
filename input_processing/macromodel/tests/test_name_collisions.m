function test_name_collisions()
% TEST_NAME_COLLISIONS  No file may assign a variable named like one of our functions.
%
% THE FAILURE THIS GUARDS AGAINST
%   MATLAB decides whether an identifier is a variable or a function ONCE, for
%   the whole function scope, based on whether it is assigned ANYWHERE in the
%   body. So this fails:
%
%       function f()
%           x = helper('a');          % line 10  -> "Unrecognized ... 'helper'"
%           ...
%           helper = 'something.mod'; % line 99  -> makes helper a VARIABLE
%       end
%
%   The call on line 10 is parsed as indexing a variable that has not been
%   assigned yet. It does not matter that the assignment comes later, or that
%   the function exists on the path.
%
%   checkcode reports nothing, and the unit tests pass because none of them
%   calls an entry point, so such a collision surfaces only on a real run. A
%   helper named `model_file`, for example, would collide with local variables
%   of that name in run_full_workflow.m and run_detrending_benchmark.m, both
%   holding a .mod filename (see the NAME note in internal/artifact_path.m).
%
% WHAT IS CHECKED
%   For every .m file we own, every assignment `name = ...` whose name is also
%   one of our function files. Any hit is at best confusing and at worst the
%   failure above, so all of them fail.

    fprintf('\n');
    fprintf('=================================================================\n');
    fprintf('  FUNCTION/VARIABLE NAME COLLISIONS\n');
    fprintf('=================================================================\n\n');

    root = fileparts(fileparts(mfilename('fullpath')));
    folders = {'', 'internal', 'diagnostics', 'documentation_tables', 'tests'};

    % Every function we own, by file name.
    ours = containers.Map('KeyType', 'char', 'ValueType', 'char');
    files = {};
    for i = 1:numel(folders)
        d = dir(fullfile(root, folders{i}, '*.m'));
        for j = 1:numel(d)
            f = fullfile(d(j).folder, d(j).name);
            files{end+1} = f; %#ok<AGROW>
            ours(d(j).name(1:end-2)) = f;
        end
    end

    % `name = ` at the start of a statement, skipping comments and ==, <=, ...
    assign = '^\s*([A-Za-z]\w*)\s*=(?![=~<>])';

    collisions = {};
    for i = 1:numel(files)
        lines = splitlines(fileread(files{i}));
        [~, this_name] = fileparts(files{i});
        for k = 1:numel(lines)
            line = lines{k};
            if isempty(strtrim(line)) || startsWith(strtrim(line), '%')
                continue;
            end
            tok = regexp(line, assign, 'tokens', 'once');
            if isempty(tok)
                continue;
            end
            name = tok{1};
            if isKey(ours, name) && ~strcmp(name, this_name)
                [~, short] = fileparts(files{i});
                collisions{end+1} = sprintf('%-34s line %-5d assigns "%s", which is also %s', ...
                    [short '.m'], k, name, strrep(ours(name), [root filesep], '')); %#ok<AGROW>
            end
        end
    end

    if isempty(collisions)
        fprintf('  [PASS] no variable shadows one of our %d functions\n\n', ours.Count);
    else
        fprintf('  [FAIL] %d collision(s):\n', numel(collisions));
        fprintf('         %s\n', collisions{:});
        fprintf(['\n  MATLAB treats the name as a VARIABLE for the whole function, so every\n' ...
                 '  call to that function in the same file is parsed as indexing it.\n' ...
                 '  Rename one of the two -- usually the newer function.\n\n']);
        error('test_name_collisions:Shadowed', ...
              '%d variable(s) shadow one of our functions; see the list above.', ...
              numel(collisions));
    end
end
