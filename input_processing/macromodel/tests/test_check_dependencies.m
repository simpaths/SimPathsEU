function test_check_dependencies
% check_dependencies returns a report a script can act on, and 'strict' turns a
% failing report into check_dependencies:Missing. Whether this machine has
% Dynare and the toolbox is not asserted here: run_all_tests must pass on a
% machine without them, and the smoke test enforces them with its own strict call.
    setup_path();
    r = check_dependencies();
    assert(islogical(r.ok) && iscell(r.problems) && iscell(r.notes), 'report shape');
    assert(isfield(r, 'matlab') && isfield(r, 'dynare_version'), 'report fields');
    assert(~isempty(regexp(r.matlab, '^R\d{4}[ab]$', 'once')), ...
           'release must read like R2025b, got ''%s''', r.matlab);
    assert(r.ok == isempty(r.problems), 'ok must mean no problems');

    try
        check_dependencies('strict', true);
        threw = false;
    catch ME
        if ~strcmp(ME.identifier, 'check_dependencies:Missing'), rethrow(ME); end
        threw = true;
    end
    assert(threw == ~r.ok, 'strict must throw check_dependencies:Missing exactly when the report is not ok');

    % On a complete machine the report is ok, so the throw above is never seen:
    % take Dynare off the path for a moment to make the report fail.
    if ~isempty(which('dynare'))
        saved = path;
        restore = onCleanup(@() path(saved));
        rmpath(fileparts(which('dynare')));
        bad = check_dependencies();
        assert(~bad.ok && any(contains(bad.problems, 'Dynare')), 'without Dynare the report must fail and say why');
        try
            check_dependencies('strict', true);
            threw = false;
        catch ME
            if ~strcmp(ME.identifier, 'check_dependencies:Missing'), rethrow(ME); end
            threw = true;
        end
        assert(threw, 'strict must throw check_dependencies:Missing when Dynare is missing');
        clear restore
    end
    fprintf('test_check_dependencies: PASS\n');
end
