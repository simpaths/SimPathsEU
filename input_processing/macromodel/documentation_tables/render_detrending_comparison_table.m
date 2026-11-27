function result = render_detrending_comparison_table(summary_dir, output_file, options)
% RENDER_DETRENDING_COMPARISON_TABLE  Render the HP-versus-Ramsey benchmark table.

    arguments
        summary_dir (1,:) char = fullfile('output', 'documentation_data', 'comparisons')
        output_file (1,:) char = ''
        options.country_order (1,:) cell = {'Germany', 'Poland'}
        options.write_file (1,1) logical = true
    end

    summary_files = dir(fullfile(summary_dir, 'detrending_benchmark_*.json'));
    if isempty(summary_files)
        error('No detrending benchmark summaries found in %s.', summary_dir);
    end

    summaries = cell(1, numel(summary_files));
    for idx = 1:numel(summary_files)
        summary_path = fullfile(summary_files(idx).folder, summary_files(idx).name);
        summaries{idx} = jsondecode(fileread(summary_path));
    end

    summaries = order_summaries(summaries, options.country_order);
    latex_text = build_benchmark_table(summaries);

    if options.write_file && ~isempty(output_file)
        render_latex_table(output_file, latex_text, ...
            'generated_by', 'render_detrending_comparison_table');
    end

    countries = cellfun(@(item) item.metadata.country, summaries, 'UniformOutput', false);
    result = struct();
    result.countries = countries;
    result.output_file = output_file;
    result.latex = latex_text;
end

function ordered = order_summaries(summaries, country_order)
    ordered = {};

    for idx = 1:numel(country_order)
        for jdx = 1:numel(summaries)
            if strcmp(summaries{jdx}.metadata.country, country_order{idx})
                ordered{end + 1} = summaries{jdx}; %#ok<AGROW>
            end
        end
    end

    for idx = 1:numel(summaries)
        country = summaries{idx}.metadata.country;
        if ~any(strcmp(country_order, country))
            ordered{end + 1} = summaries{idx}; %#ok<AGROW>
        end
    end
end

function latex_text = build_benchmark_table(summaries)
    bs = char(92);
    row_break = [bs bs];

    lines = {
        [bs 'begin{table}[H]']
        [bs 'centering']
        [bs 'small']
        [bs 'caption{HP-versus-Ramsey detrending benchmark under a fixed DSGE specification. The log marginal likelihoods are reported for the detrended observables used in each run and therefore serve as diagnostic fit statistics rather than formal Bayes factors.}']
        [bs 'label{tab:detrending_benchmark}']
        [bs 'begin{tabular}{llcccccc}']
        [bs 'toprule']
        ['Country & Method & Laplace & MHM & $' bs 'sigma_y$ & $' bs 'sigma_{' bs 'mathrm{inv}}$ & $' bs 'sigma_c$ & Sample ' row_break]
        [bs 'midrule']
    };

    for idx = 1:numel(summaries)
        summary = summaries{idx};
        country = summary.metadata.country;
        hp_run = find_run(summary.runs, 'hp');
        ramsey_run = find_run(summary.runs, 'ramsey');

        if isempty(hp_run) || isempty(ramsey_run)
            error('Benchmark summary for %s must include both hp and ramsey runs.', country);
        end

        sample_text = sprintf('%d--%d', hp_run.fit.sample_start, hp_run.fit.sample_end);

        lines{end + 1} = format_run_row(country, 'HP', hp_run, sample_text, row_break); %#ok<AGROW>
        lines{end + 1} = format_run_row('', 'Ramsey', ramsey_run, sample_text, row_break); %#ok<AGROW>
        lines{end + 1} = format_delta_row(summary.comparison, hp_run, ramsey_run, row_break); %#ok<AGROW>

        if idx < numel(summaries)
            lines{end + 1} = [bs 'addlinespace[0.2em]']; %#ok<AGROW>
        end
    end

    lines = [lines; {
        [bs 'bottomrule']
        [bs 'end{tabular}']
        [bs 'end{table}']
    }];

    latex_text = strjoin(lines, newline);
end

function run = find_run(runs, method_name)
    run = [];
    for idx = 1:numel(runs)
        if strcmp(runs(idx).method, method_name)
            run = runs(idx);
            return;
        end
    end
end

function row_text = format_run_row(country, method_label, run, sample_text, row_break)
    y_moment = find_moment(run.moments, 'y');
    inv_moment = find_moment(run.moments, 'inv');
    c_moment = find_moment(run.moments, 'c');

    row_text = sprintf('%s & %s & %.2f & %.2f & %.2f & %.2f & %.2f & %s %s', ...
        country, method_label, ...
        run.fit.log_mdd_laplace, run.fit.log_mdd_mhm, ...
        y_moment.data_std, inv_moment.data_std, c_moment.data_std, ...
        sample_text, row_break);
end

function row_text = format_delta_row(comparison, hp_run, ramsey_run, row_break)
    bs = char(92);
    y_ratio = ratio_of_data_std(ramsey_run.moments, hp_run.moments, 'y');
    inv_ratio = ratio_of_data_std(ramsey_run.moments, hp_run.moments, 'inv');
    c_ratio = ratio_of_data_std(ramsey_run.moments, hp_run.moments, 'c');
    delta_label = ['$' bs 'Delta$(Ramsey$-$HP)'];
    y_ratio_text = sprintf('$%.2f\\times$', y_ratio);
    inv_ratio_text = sprintf('$%.2f\\times$', inv_ratio);
    c_ratio_text = sprintf('$%.2f\\times$', c_ratio);
    format_spec = '%s & %s & %+.2f & %+.2f & %s & %s & %s & T=%d %s';

    row_text = sprintf(format_spec, ...
        '', delta_label, ...
        comparison.log_mdd_laplace_ramsey_minus_hp, ...
        comparison.log_mdd_mhm_ramsey_minus_hp, ...
        y_ratio_text, inv_ratio_text, c_ratio_text, comparison.n_observations, row_break);
end

function moment = find_moment(moments, observable)
    for idx = 1:numel(moments)
        if strcmp(moments(idx).observable, observable)
            moment = moments(idx);
            return;
        end
    end
    error('Moment row %s not found.', observable);
end

function ratio = ratio_of_data_std(ramsey_moments, hp_moments, observable)
    ramsey_row = find_moment(ramsey_moments, observable);
    hp_row = find_moment(hp_moments, observable);
    ratio = ramsey_row.data_std / hp_row.data_std;
end