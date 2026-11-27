function status = refresh_documentation_tables(country, options)
% REFRESH_DOCUMENTATION_TABLES  Regenerate the Overleaf numerical tables from the JSON summaries.
%
%   refresh_documentation_tables('Poland')
%   refresh_documentation_tables('Poland', 'overleaf_root', 'C:\...\WELLSIM_SVEC_Overleaf')
%   refresh_documentation_tables('overleaf_root', '...')   shared tables only
%
% Run from the model root (the folder holding run_full_workflow.m) after setup_path.
% The summaries are the ones the workflow writes into output/documentation_data/:
% ramsey/ramsey_summary_{Country}.json (calibrate_growth_model, ramsey_trend),
% dsge/dsge_postestimation_{Country}.json (postestimation_analysis) and
% comparisons/detrending_benchmark_{Country}.json (run_detrending_benchmark). The
% two hand-curated summaries the prose cites, version_comparison_metrics.json and
% literature_reference_metrics.json, are tracked in documentation_tables/curated/.
%
% The shared tables (Ramsey structural and base-year values, DSGE parameter
% classification, detrending benchmark, inline values) are built from every
% summary in those folders. COUNTRY selects the per-country DSGE tables
% (posterior means, moments, variance decomposition and its figure) and the
% Ramsey diagnostic figure; without it, the DSGE tables are skipped and the
% Ramsey figures are drawn for every country with a summary.
%
% OVERLEAF_ROOT defaults to the WELLSIM_SVEC_Overleaf folder beside the
% SimPathsEU repository root.

    arguments
        country (1,:) char = ''
        options.refresh_ramsey (1,1) logical = true
        options.refresh_dsge (1,1) logical = true
        options.overleaf_root (1,:) char = ''
        options.fail_on_validation_error (1,1) logical = true
    end

    this_dir = fileparts(mfilename('fullpath'));
    model_root = fileparts(this_dir);
    % artifact_path also checks that the working directory is the model root.
    summary_root = artifact_path('output', 'documentation_data');
    ramsey_summary_dir = fullfile(summary_root, 'ramsey');
    dsge_summary_dir = fullfile(summary_root, 'dsge');
    comparison_summary_dir = fullfile(summary_root, 'comparisons');
    curated_dir = fullfile(this_dir, 'curated');

    if isempty(options.overleaf_root)
        overleaf_root = fullfile(fileparts(repository_root(model_root)), 'WELLSIM_SVEC_Overleaf');
    else
        overleaf_root = options.overleaf_root;
    end

    status = struct();
    status.country = country;
    status.overleaf_root = overleaf_root;
    status.ramsey = 'skipped';
    status.ramsey_figures = 'skipped';
    status.dsge = 'skipped';
    status.dsge_fit_tables = 'skipped';
    status.dsge_variance_figure = 'skipped';
    status.dsge_parameter_table = 'skipped';
    status.comparison_tables = 'skipped';
    status.inline_values = 'skipped';

    if ~exist(overleaf_root, 'dir')
        error('Overleaf root not found: %s', overleaf_root);
    end

    if options.refresh_ramsey
        structural_output = fullfile(overleaf_root, 'Tables', 'generated', 'ramsey', 'table_ramsey_country_structural.tex');
        base_output = fullfile(overleaf_root, 'Tables', 'generated', 'ramsey', 'table_ramsey_country_base_values.tex');
        ramsey_summary_files = dir(fullfile(ramsey_summary_dir, 'ramsey_summary_*.json'));
        if isempty(ramsey_summary_files)
            status.ramsey = sprintf('skipped: no Ramsey summary files found in %s', ramsey_summary_dir);
            warning('refresh_documentation_tables:MissingRamseySummaries', '%s', status.ramsey);
        else
            try
                render_ramsey_country_tables(ramsey_summary_dir, ...
                    'structural_output_file', structural_output, ...
                    'base_values_output_file', base_output, ...
                    'write_files', true);
                status.ramsey = 'refreshed';

                figure_output_dir = fullfile(overleaf_root, 'Figures', 'generated');
                figure_status = render_ramsey_diagnostic_figures(ramsey_summary_dir, figure_output_dir, ...
                    'country', country, ...
                    'fail_on_missing_inputs', false);
                if isempty(figure_status.generated)
                    if isempty(figure_status.skipped)
                        status.ramsey_figures = 'skipped';
                    else
                        status.ramsey_figures = ['skipped: ' strjoin(figure_status.skipped, '; ')];
                    end
                else
                    status.ramsey_figures = sprintf('refreshed (%d figure(s))', numel(figure_status.generated));
                end
            catch refresh_error
                status.ramsey = ['failed: ' refresh_error.message];
                status.ramsey_figures = ['failed: ' refresh_error.message];
                if options.fail_on_validation_error
                    rethrow(refresh_error);
                end
            end
        end
    end

    if options.refresh_dsge
        if isempty(country)
            status.dsge = 'skipped: no country provided for DSGE summary refresh';
            warning('refresh_documentation_tables:MissingCountry', '%s', status.dsge);
        else
            dsge_summary_file = fullfile(dsge_summary_dir, sprintf('dsge_postestimation_%s.json', country));
            if ~exist(dsge_summary_file, 'file')
                status.dsge = sprintf('skipped: DSGE summary not found: %s', dsge_summary_file);
                warning('refresh_documentation_tables:MissingDsgesummary', '%s', status.dsge);
            else
                posterior_output = fullfile(overleaf_root, 'Tables', 'generated', 'dsge', ...
                    sprintf('table_post_means_%s.tex', lower(country)));
                moments_output = fullfile(overleaf_root, 'Tables', 'generated', 'dsge', ...
                    sprintf('table_moments_%s.tex', lower(country)));
                vd_output = fullfile(overleaf_root, 'Tables', 'generated', 'dsge', ...
                    sprintf('table_vd_%s.tex', lower(country)));
                vd_figure_output = fullfile(overleaf_root, 'Figures', 'generated', ...
                    sprintf('variance_decomposition_%s.pdf', country));
                try
                    render_posterior_parameter_table(dsge_summary_file, posterior_output, 'write_file', true);
                    status.dsge = 'refreshed';

                    render_dsge_fit_tables(dsge_summary_file, moments_output, vd_output, 'write_files', true);
                    status.dsge_fit_tables = ['refreshed (' country ')'];

                    render_variance_decomposition_figure(dsge_summary_file, vd_figure_output, 'write_file', true);
                    status.dsge_variance_figure = ['refreshed (' country ')'];
                catch refresh_error
                    status.dsge = ['failed: ' refresh_error.message];
                    status.dsge_fit_tables = ['failed: ' refresh_error.message];
                    status.dsge_variance_figure = ['failed: ' refresh_error.message];
                    if options.fail_on_validation_error
                        rethrow(refresh_error);
                    end
                end
            end
        end

        parameter_output = fullfile(overleaf_root, 'Tables', 'generated', 'dsge', 'table_parameter_classification.tex');
        try
            render_dsge_parameter_classification_table(dsge_summary_dir, fullfile(model_root, 'country_params'), parameter_output, 'write_file', true);
            status.dsge_parameter_table = 'refreshed';
        catch refresh_error
            status.dsge_parameter_table = ['failed: ' refresh_error.message];
            if options.fail_on_validation_error
                rethrow(refresh_error);
            end
        end
    end

    comparison_output = fullfile(overleaf_root, 'Tables', 'generated', 'comparisons', 'table_detrending_benchmark.tex');
    comparison_summary_files = dir(fullfile(comparison_summary_dir, 'detrending_benchmark_*.json'));
    if isempty(comparison_summary_files)
        status.comparison_tables = sprintf('skipped: no detrending benchmark summaries found in %s', comparison_summary_dir);
    else
        try
            render_detrending_comparison_table(comparison_summary_dir, comparison_output, 'write_file', true);
            status.comparison_tables = 'refreshed';
        catch refresh_error
            status.comparison_tables = ['failed: ' refresh_error.message];
            if options.fail_on_validation_error
                rethrow(refresh_error);
            end
        end
    end

    inline_values_output = fullfile(overleaf_root, 'Tables', 'generated', 'inline_values.tex');
    try
        render_inline_value_macros(ramsey_summary_dir, dsge_summary_dir, comparison_summary_dir, curated_dir, ...
            inline_values_output, 'write_file', true);
        status.inline_values = 'refreshed';
    catch refresh_error
        status.inline_values = ['failed: ' refresh_error.message];
        if options.fail_on_validation_error
            rethrow(refresh_error);
        end
    end
end

function root = repository_root(model_root)
% The SimPathsEU root, as many levels above the model root as model_location's
% repo_rel has segments, so a move of the model root changes model_location only.
    root = model_root;
    segments = strsplit(model_location().repo_rel, '/');
    for k = 1:numel(segments)
        root = fileparts(root);
    end
end
