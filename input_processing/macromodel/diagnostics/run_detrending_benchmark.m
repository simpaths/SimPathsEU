function benchmark = run_detrending_benchmark(country, options)
% RUN_DETRENDING_BENCHMARK  Compare Ramsey and HP detrending under one DSGE.
%
% Usage:
%   run_detrending_benchmark('Poland')
%   run_detrending_benchmark('Poland', 'methods', ["HP", "Ramsey"])
%
% The model wrappers read data from data_for_dynare_{Country}.csv. This
% runner temporarily swaps that standard file between the Ramsey and HP
% datasets, runs Dynare with the unchanged model specification, snapshots
% the post-estimation outputs after each run, and writes a comparison JSON
% summary under output/documentation_data/comparisons/.

    arguments
        country (1,:) char = 'Poland'
        options.methods (1,:) string = ["HP", "Ramsey"]
        options.use_parallel (1,1) logical = false
        options.run_postestimation (1,1) logical = true
        options.results_dir (1,:) char = fullfile('output', 'documentation_data', 'comparisons')
        options.restore_documentation_summary (1,1) logical = true
    end

    country_config = get_country_config(country);
    country = country_config.name;

    model_name = sprintf('Macromodel_%s', country);
    model_file = [model_name '.mod'];
    ramsey_data_file = artifact_path('data', sprintf('data_for_dynare_%s.csv', country));
    hp_data_file = artifact_path('data', sprintf('data_for_dynare_hp_%s.csv', country));
    documentation_summary_file = artifact_path('output', fullfile('documentation_data', 'dsge', ...
        sprintf('dsge_postestimation_%s.json', country)));

    assert_file_exists(model_file, 'Model file');
    assert_file_exists(ramsey_data_file, 'Ramsey data file');
    assert_file_exists(hp_data_file, 'HP benchmark data file');

    methods = normalize_methods(options.methods);
    benchmark_root = fullfile(options.results_dir, 'detrending_benchmark', country);
    if ~exist(benchmark_root, 'dir')
        mkdir(benchmark_root);
    end

    baseline_data_backup = [tempname(pwd) '.csv'];
    copyfile(ramsey_data_file, baseline_data_backup, 'f');

    documentation_summary_backup = '';
    if exist(documentation_summary_file, 'file')
        documentation_summary_backup = [tempname(pwd) '.json'];
        copyfile(documentation_summary_file, documentation_summary_backup, 'f');
    end

    cleanup_obj = onCleanup(@() restore_baseline_files( ...
        ramsey_data_file, baseline_data_backup, documentation_summary_file, ...
        documentation_summary_backup, options.restore_documentation_summary));

    fprintf('\n');
    fprintf('===============================================================\n');
    fprintf('  DETRENDING BENCHMARK FOR %s\n', upper(country));
    fprintf('===============================================================\n');
    fprintf('  Model:   %s\n', model_name);
    fprintf('  Methods: %s\n\n', strjoin(cellstr(methods), ', '));

    benchmark = struct();
    benchmark.metadata = struct();
    benchmark.metadata.country = country;
    benchmark.metadata.model_name = model_name;
    benchmark.metadata.methods = cellstr(methods);
    benchmark.metadata.source_function = 'run_detrending_benchmark';
    benchmark.runs = repmat(empty_run_summary(), 0, 1);

    for method_index = 1:numel(methods)
        method = methods(method_index);
        method_key = lower(char(method));
        source_data_file = get_source_datafile(method, ramsey_data_file, hp_data_file);

        fprintf('--- Running %s benchmark (%s) ---\n', char(method), source_data_file);
        activate_datafile_variant(method, ramsey_data_file, baseline_data_backup, source_data_file);

        run_dynare_estimation(model_name, options.use_parallel);

        if options.run_postestimation
            postestimation_analysis(model_name, source_data_file);
        end

        snapshot_dir = fullfile(benchmark_root, method_key);
        if ~exist(snapshot_dir, 'dir')
            mkdir(snapshot_dir);
        end

        run_summary = snapshot_benchmark_outputs( ...
            country, model_name, method_key, source_data_file, ...
            documentation_summary_file, snapshot_dir);
        benchmark.runs(end + 1, 1) = run_summary;

        fprintf('  Saved benchmark snapshot to %s\n\n', snapshot_dir);
    end

    benchmark.comparison = build_comparison_summary(benchmark.runs);

    output_file = fullfile(options.results_dir, ...
        sprintf('detrending_benchmark_%s.json', country));
    write_json_summary(benchmark, output_file, ...
        'country', country, ...
        'source_function', 'run_detrending_benchmark');

    benchmark.output_file = output_file;

    fprintf('Benchmark summary written to %s\n', output_file);
end

function methods = normalize_methods(methods)
    methods = upper(string(methods));
    methods = methods(methods ~= "");

    valid_methods = ["RAMSEY", "HP"];
    for index = 1:numel(methods)
        if ~any(methods(index) == valid_methods)
            error('Unsupported benchmark method ''%s''. Valid options: Ramsey, HP.', methods(index));
        end
    end

    methods = unique(methods, 'stable');

    if numel(methods) == 2 && any(methods == "RAMSEY") && any(methods == "HP")
        methods = ["HP", "RAMSEY"];
    end

    methods = replace(methods, "RAMSEY", "Ramsey");
    methods = replace(methods, "HP", "HP");
end

function source_data_file = get_source_datafile(method, ramsey_data_file, hp_data_file)
    switch upper(char(method))
        case 'RAMSEY'
            source_data_file = ramsey_data_file;
        case 'HP'
            source_data_file = hp_data_file;
        otherwise
            error('Unsupported method ''%s''.', method);
    end
end

function activate_datafile_variant(method, standard_data_file, baseline_data_backup, source_data_file)
    switch upper(char(method))
        case 'RAMSEY'
            copyfile(baseline_data_backup, standard_data_file, 'f');
        case 'HP'
            copyfile(source_data_file, standard_data_file, 'f');
        otherwise
            error('Unsupported method ''%s''.', method);
    end
end

function run_dynare_estimation(model_name, use_parallel)
    dynare_command = sprintf('dynare %s use_dll', model_name);
    if use_parallel
        dynare_command = sprintf('%s parallel', dynare_command);
    end

    evalin('base', dynare_command);
end

function run_summary = snapshot_benchmark_outputs(country, model_name, method_key, source_data_file, documentation_summary_file, snapshot_dir)
    summary_snapshot = fullfile(snapshot_dir, ...
        sprintf('dsge_postestimation_%s_%s.json', country, method_key));
    text_snapshot = fullfile(snapshot_dir, ...
        sprintf('postestimation_summary_%s.txt', method_key));
    report_snapshot = fullfile(snapshot_dir, ...
        sprintf('DSGE_Estimation_Report_%s.pdf', method_key));

    assert_file_exists(documentation_summary_file, 'DSGE documentation summary');
    copyfile(documentation_summary_file, summary_snapshot, 'f');

    text_summary_file = fullfile(model_name, 'Output', 'postestimation_summary.txt');
    if exist(text_summary_file, 'file')
        copyfile(text_summary_file, text_snapshot, 'f');
    end

    report_file = fullfile(model_name, 'Output', 'DSGE_Estimation_Report.pdf');
    if exist(report_file, 'file')
        copyfile(report_file, report_snapshot, 'f');
    end

    dsge_summary = jsondecode(fileread(summary_snapshot));

    run_summary = struct();
    run_summary.method = method_key;
    run_summary.source_data_file = source_data_file;
    run_summary.summary_snapshot = summary_snapshot;
    run_summary.text_summary_snapshot = text_snapshot;
    if exist(report_snapshot, 'file')
        run_summary.report_snapshot = report_snapshot;
    else
        run_summary.report_snapshot = '';
    end
    run_summary.fit = dsge_summary.fit;
    run_summary.posterior_parameters = dsge_summary.posterior_parameters;
    run_summary.moments = dsge_summary.moments;
    run_summary.variance_decomposition = dsge_summary.variance_decomposition;
end

function comparison = build_comparison_summary(runs)
    comparison = struct();
    comparison.available_methods = arrayfun(@(run) run.method, runs, 'UniformOutput', false);

    ramsey_index = find(strcmp(comparison.available_methods, 'ramsey'), 1);
    hp_index = find(strcmp(comparison.available_methods, 'hp'), 1);

    if isempty(ramsey_index) || isempty(hp_index)
        comparison.status = 'partial';
        return;
    end

    ramsey_run = runs(ramsey_index);
    hp_run = runs(hp_index);

    comparison.status = 'complete';
    comparison.log_mdd_laplace_ramsey_minus_hp = ...
        ramsey_run.fit.log_mdd_laplace - hp_run.fit.log_mdd_laplace;
    comparison.log_mdd_mhm_ramsey_minus_hp = ...
        ramsey_run.fit.log_mdd_mhm - hp_run.fit.log_mdd_mhm;
    comparison.n_observations = ramsey_run.fit.n_observations;
    comparison.sample_start = ramsey_run.fit.sample_start;
    comparison.sample_end = ramsey_run.fit.sample_end;
end

function template = empty_run_summary()
    template = struct( ...
        'method', '', ...
        'source_data_file', '', ...
        'summary_snapshot', '', ...
        'text_summary_snapshot', '', ...
        'report_snapshot', '', ...
        'fit', struct(), ...
        'posterior_parameters', struct([]), ...
        'moments', struct([]), ...
        'variance_decomposition', struct());
end

function restore_baseline_files(standard_data_file, baseline_data_backup, documentation_summary_file, documentation_summary_backup, restore_documentation_summary)
    if exist(baseline_data_backup, 'file')
        copyfile(baseline_data_backup, standard_data_file, 'f');
        delete(baseline_data_backup);
    end

    if restore_documentation_summary && ~isempty(documentation_summary_backup)
        if exist(documentation_summary_backup, 'file')
            copyfile(documentation_summary_backup, documentation_summary_file, 'f');
            delete(documentation_summary_backup);
        end
    elseif ~isempty(documentation_summary_backup) && exist(documentation_summary_backup, 'file')
        delete(documentation_summary_backup);
    end
end

function assert_file_exists(file_path, label)
    if ~exist(file_path, 'file')
        error('%s not found: %s', label, file_path);
    end
end