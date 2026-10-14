function test_check_dependencies
% check_dependencies returns a report a script can act on, and passes on the
% machine that produced the committed bundles.
    setup_path();
    r = check_dependencies();
    assert(islogical(r.ok) && iscell(r.problems) && iscell(r.notes), 'report shape');
    assert(isfield(r, 'matlab') && isfield(r, 'dynare_version'), 'report fields');
    assert(r.ok, 'this machine must satisfy the requirements: %s', strjoin(r.problems, '; '));
    fprintf('test_check_dependencies: PASS\n');
end
