benchmark = run_detrending_benchmark('Poland', 'restore_documentation_summary', false);
status = refresh_documentation_tables('Poland', ...
    'refresh_ramsey', false, ...
    'refresh_dsge', true, ...
    'fail_on_validation_error', true);

disp('Benchmark output file:');
disp(benchmark.output_file);
disp('Documentation refresh status:');
disp(status);