function result = render_inline_value_macros(ramsey_summary_dir, dsge_summary_dir, comparison_summary_dir, curated_dir, output_file, options)
% RENDER_INLINE_VALUE_MACROS  Generate LaTeX macros for inline numeric references.
%
% Reads the Ramsey, DSGE and detrending-benchmark summaries of Germany and Poland
% from their folders under output/documentation_data/, the hand-curated
% version_comparison_metrics.json and literature_reference_metrics.json from
% CURATED_DIR, the calibration files from country_params/ and the shock order
% from Macromodel_template.mod. Run from the model root.

    arguments
        ramsey_summary_dir (1,:) char
        dsge_summary_dir (1,:) char
        comparison_summary_dir (1,:) char
        curated_dir (1,:) char
        output_file (1,:) char
        options.write_file (1,1) logical = true
    end

    this_dir = fileparts(mfilename('fullpath'));
    model_root = fileparts(this_dir);
    calibration_dir = fullfile(model_root, 'country_params');

    germany_ramsey = load_summary(fullfile(ramsey_summary_dir, 'ramsey_summary_Germany.json'));
    poland_ramsey = load_summary(fullfile(ramsey_summary_dir, 'ramsey_summary_Poland.json'));
    germany_ref = load_dsge_country_reference('Germany', fullfile(calibration_dir, 'Germany_calibration.mod'), fullfile(dsge_summary_dir, 'dsge_postestimation_Germany.json'));
    poland_ref = load_dsge_country_reference('Poland', fullfile(calibration_dir, 'Poland_calibration.mod'), fullfile(dsge_summary_dir, 'dsge_postestimation_Poland.json'));
    germany_dsge = germany_ref.summary;
    poland_dsge = poland_ref.summary;
    germany_benchmark = load_required_summary(fullfile(comparison_summary_dir, 'detrending_benchmark_Germany.json'));
    poland_benchmark = load_required_summary(fullfile(comparison_summary_dir, 'detrending_benchmark_Poland.json'));
    comparison_metrics = load_required_summary(fullfile(curated_dir, 'version_comparison_metrics.json'));
    literature_metrics = load_required_summary(fullfile(curated_dir, 'literature_reference_metrics.json'));
    [germany_std_ratio_min, germany_std_ratio_max] = compute_std_ratio_bounds(germany_dsge.moments);
    [poland_std_ratio_min, poland_std_ratio_max] = compute_std_ratio_bounds(poland_dsge.moments);
    germany_benchmark_output_ratio = compute_benchmark_std_ratio(germany_benchmark, 'y');
    poland_benchmark_output_ratio = compute_benchmark_std_ratio(poland_benchmark, 'y');
    germany_sample_start_quarter = read_sample_start_quarter('Germany');
    poland_sample_start_quarter = read_sample_start_quarter('Poland');
    [shock_order_math, shock_order_names] = read_shock_order(model_root);

    validate_documentation_summary(germany_ramsey, 'ramsey');
    validate_documentation_summary(poland_ramsey, 'ramsey');
    validate_documentation_summary(germany_dsge, 'dsge');
    validate_documentation_summary(poland_dsge, 'dsge');

    bs = char(92);
    lines = {
        [bs 'newcommand{' bs 'RamseyGermanySolverHorizon}{' format_integer(germany_ramsey.structural.solver_horizon_quarters) '}']
        [bs 'newcommand{' bs 'RamseyPolandSolverHorizon}{' format_integer(poland_ramsey.structural.solver_horizon_quarters) '}']
        [bs 'newcommand{' bs 'RamseyGermanyBaseYear}{' format_integer(germany_ramsey.structural.base_year) '}']
        [bs 'newcommand{' bs 'RamseyGermanyCYShare}{' format_decimal(germany_ramsey.base_year_values.CY, 3) '}']
        [bs 'newcommand{' bs 'RamseyGermanyIYShare}{' format_decimal(germany_ramsey.base_year_values.IY, 3) '}']
        [bs 'newcommand{' bs 'RamseyGermanyGYShare}{' format_decimal(germany_ramsey.base_year_values.GY, 3) '}']
        [bs 'newcommand{' bs 'RamseyGermanyNXYShare}{' format_decimal(germany_ramsey.base_year_values.NXY, 3) '}']
        [bs 'newcommand{' bs 'RamseyGermanyShareSum}{' format_decimal(compute_share_sum(germany_ramsey.base_year_values), 3) '}']
        [bs 'newcommand{' bs 'RamseyGermanyKZeroTrillion}{' format_decimal(germany_ramsey.base_year_values.K0 / 1e6, 2) '}']
        [bs 'newcommand{' bs 'RamseyGermanyKyZero}{' format_decimal(germany_ramsey.base_year_values.K0 / germany_ramsey.base_year_values.Y0_annual, 2) '}']
        [bs 'newcommand{' bs 'RamseyGermanyAZero}{' format_decimal(germany_ramsey.base_year_values.A0, 3) '}']
        [bs 'newcommand{' bs 'RamseyGermanySolverIterations}{' format_integer(germany_ramsey.validation.solver_iterations) '}']
        [bs 'newcommand{' bs 'RamseyGermanyAlphaK}{' format_decimal(germany_ramsey.structural.alpha_K, 2) '}']
        [bs 'newcommand{' bs 'RamseyGermanyDeltaAnnual}{' format_decimal(germany_ramsey.structural.delta_annual, 2) '}']
        [bs 'newcommand{' bs 'RamseyGermanyBetaAnnual}{' format_decimal(germany_ramsey.structural.beta_annual, 2) '}']
        [bs 'newcommand{' bs 'RamseyGermanySigma}{' format_decimal(germany_ramsey.structural.sigma, 1) '}']
        [bs 'newcommand{' bs 'RamseyGermanyTfpGrowthAnnual}{' format_decimal(germany_ramsey.structural.tfp_growth_annual, 4) '}']
        [bs 'newcommand{' bs 'RamseyGermanyRStarAnnualPct}{' format_decimal(germany_ramsey.structural.r_star_annual * 100, 1) '}']
        [bs 'newcommand{' bs 'RamseyPolandTfpGrowthAnnualPct}{' format_decimal(poland_ramsey.structural.tfp_growth_annual * 100, 1) '}']
        [bs 'newcommand{' bs 'RamseyPolandTfpGrowthTerminalPct}{' format_decimal(poland_ramsey.structural.tfp_growth_terminal_annual * 100, 1) '}']
        [bs 'newcommand{' bs 'RamseyPolandTerminalRhoQ}{' format_decimal(poland_ramsey.structural.rho_g, 3) '}']
        [bs 'newcommand{' bs 'RamseyPolandTerminalHalfLifeYears}{' format_decimal(log(0.5) / log(poland_ramsey.structural.rho_g) / 4, 1) '}']
        [bs 'newcommand{' bs 'RamseyGermanyHpCorrY}{' format_decimal(germany_ramsey.validation.y, 2) '}']
        [bs 'newcommand{' bs 'RamseyGermanyHpCorrInv}{' format_decimal(germany_ramsey.validation.inv, 2) '}']
        [bs 'newcommand{' bs 'RamseyGermanyHpCorrC}{' format_decimal(germany_ramsey.validation.c, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanySampleStartYear}{' format_integer(germany_dsge.fit.sample_start) '}']
        [bs 'newcommand{' bs 'DsgePolandSampleStartYear}{' format_integer(poland_dsge.fit.sample_start) '}']
        [bs 'newcommand{' bs 'DsgeGermanySampleStartQuarter}{' germany_sample_start_quarter '}']
        [bs 'newcommand{' bs 'DsgePolandSampleStartQuarter}{' poland_sample_start_quarter '}']
        [bs 'newcommand{' bs 'DetrendingGermanyLaplaceDeltaAbs}{' format_decimal(abs(germany_benchmark.comparison.log_mdd_laplace_ramsey_minus_hp), 0) '}']
        [bs 'newcommand{' bs 'DetrendingPolandLaplaceDeltaAbs}{' format_decimal(abs(poland_benchmark.comparison.log_mdd_laplace_ramsey_minus_hp), 0) '}']
        [bs 'newcommand{' bs 'DetrendingGermanyOutputStdRatio}{' format_decimal(germany_benchmark_output_ratio, 1) '}']
        [bs 'newcommand{' bs 'DetrendingPolandOutputStdRatio}{' format_decimal(poland_benchmark_output_ratio, 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyMhm}{' format_decimal(germany_dsge.fit.log_mdd_mhm, 2) '}']
        [bs 'newcommand{' bs 'DsgePolandMhm}{' format_decimal(poland_dsge.fit.log_mdd_mhm, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanySigmaInv}{' format_decimal(get_posterior_mean(germany_dsge.posterior_parameters, 'sigma_inv'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanySigmaP}{' format_decimal(get_posterior_mean(germany_dsge.posterior_parameters, 'sigma_p'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyPiCostPushVdShare}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'pi', 'eps_p'), 0) '}']
        [bs 'newcommand{' bs 'DsgeNkpcIndexationDampeningPct}{' format_decimal(comparison_metrics.nkpc_indexation.dampening_percent, 0) '}']
        [bs 'newcommand{' bs 'DsgeGermanySigmaPBaselineVFourteen}{' format_decimal(comparison_metrics.nkpc_indexation.sigma_p_v14, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyLongRunWageElasticity}{' format_decimal(literature_metrics.labour_supply_wage_elasticity.model_target, 2) '}']
        [bs 'newcommand{' bs 'DsgeWageElasticityLiteratureLow}{' format_decimal(literature_metrics.labour_supply_wage_elasticity.literature_range_low, 1) '}']
        [bs 'newcommand{' bs 'DsgeWageElasticityLiteratureHigh}{' format_decimal(literature_metrics.labour_supply_wage_elasticity.literature_range_high, 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyAlphaK}{' format_decimal(germany_ref.calibration.alpha_k, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyAlphaN}{' format_decimal(germany_ref.calibration.alpha_n, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyRhoA}{' format_decimal(germany_ref.calibration.rho_a, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyDeltaK}{' format_decimal(germany_ref.calibration.delta_k, 3) '}']
        [bs 'newcommand{' bs 'DsgeGermanyDeltaKAnnualPct}{' format_decimal((1 - (1 - germany_ref.calibration.delta_k)^4) * 100, 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyRhoInv}{' format_decimal(germany_ref.calibration.rho_inv, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyPhiInvY}{' format_decimal(germany_ref.calibration.phi_inv_y, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanySigma}{' format_decimal(germany_ref.calibration.sigma, 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyHab}{' format_decimal(germany_ref.calibration.hab, 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanySInv}{' format_decimal(germany_ref.calibration.s_inv, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyBeta}{' format_decimal(germany_ref.calibration.beta, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyIotaP}{' format_decimal(germany_ref.calibration.iota_p, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyRhoR}{' format_decimal(germany_ref.calibration.rho_r, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyPhiPi}{' format_decimal(germany_ref.calibration.phi_pi, 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyPhiY}{' format_decimal(germany_ref.calibration.phi_y, 3) '}']
        [bs 'newcommand{' bs 'DsgeGermanyAlphaM}{' format_decimal(germany_ref.calibration.alpha_m, 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyDelta}{' format_decimal(germany_ref.calibration.delta, 3) '}']
        [bs 'newcommand{' bs 'DsgeGermanyChiL}{' format_decimal(germany_ref.calibration.chi_L, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyChiN}{' format_decimal(germany_ref.calibration.chi_n, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyChiU}{' format_decimal(germany_ref.calibration.chi_u, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyRhoV}{' format_decimal(germany_ref.calibration.rho_v, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyLambdaW}{' format_decimal(germany_ref.calibration.lambda_w, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyPsiWL}{' format_decimal(germany_ref.calibration.psi_wL, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyRhoH}{' format_decimal(germany_ref.calibration.rho_h, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyRhoL}{' format_decimal(germany_ref.calibration.rho_L, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyOmegaH}{' format_decimal(get_posterior_mean(germany_dsge.posterior_parameters, 'omega_h'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyPhiInvR}{' format_decimal(get_posterior_mean(germany_dsge.posterior_parameters, 'phi_inv_r'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandSigmaInv}{' format_decimal(get_posterior_mean(poland_dsge.posterior_parameters, 'sigma_inv'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandSigmaP}{' format_decimal(get_posterior_mean(poland_dsge.posterior_parameters, 'sigma_p'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandSigmaL}{' format_decimal(get_posterior_mean(poland_dsge.posterior_parameters, 'sigma_L'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdYModel}{' format_decimal(get_moment_value(germany_dsge.moments, 'y', 'model_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdYData}{' format_decimal(get_moment_value(germany_dsge.moments, 'y', 'data_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdInvModel}{' format_decimal(get_moment_value(germany_dsge.moments, 'inv', 'model_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdInvData}{' format_decimal(get_moment_value(germany_dsge.moments, 'inv', 'data_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdCModel}{' format_decimal(get_moment_value(germany_dsge.moments, 'c', 'model_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdCData}{' format_decimal(get_moment_value(germany_dsge.moments, 'c', 'data_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdPiModel}{' format_decimal(get_moment_value(germany_dsge.moments, 'pi', 'model_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdPiData}{' format_decimal(get_moment_value(germany_dsge.moments, 'pi', 'data_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdRatioMin}{' format_decimal(germany_std_ratio_min, 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyStdRatioMax}{' format_decimal(germany_std_ratio_max, 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdYModel}{' format_decimal(get_moment_value(poland_dsge.moments, 'y', 'model_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdYData}{' format_decimal(get_moment_value(poland_dsge.moments, 'y', 'data_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdInvModel}{' format_decimal(get_moment_value(poland_dsge.moments, 'inv', 'model_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdInvData}{' format_decimal(get_moment_value(poland_dsge.moments, 'inv', 'data_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdCData}{' format_decimal(get_moment_value(poland_dsge.moments, 'c', 'data_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdPiData}{' format_decimal(get_moment_value(poland_dsge.moments, 'pi', 'data_std'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandAcOneHModel}{' format_decimal(get_moment_value(poland_dsge.moments, 'h', 'model_ac1'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandAcOneHData}{' format_decimal(get_moment_value(poland_dsge.moments, 'h', 'data_ac1'), 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdRatioMin}{' format_decimal(poland_std_ratio_min, 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdRatioMax}{' format_decimal(poland_std_ratio_max, 2) '}']
        [bs 'newcommand{' bs 'DsgePolandStdRatioH}{' format_decimal(compute_std_ratio(get_moment_value(poland_dsge.moments, 'h', 'model_std'), get_moment_value(poland_dsge.moments, 'h', 'data_std')), 2) '}']
        [bs 'newcommand{' bs 'DsgeGermanyVdYTech}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'y', 'eps_a'), 1) '}']
        [bs 'newcommand{' bs 'DsgePolandVdYTech}{' format_decimal(get_variance_share(poland_dsge.variance_decomposition, 'y', 'eps_a'), 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyVdYCostPush}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'y', 'eps_p'), 1) '}']
        [bs 'newcommand{' bs 'DsgePolandVdYCostPush}{' format_decimal(get_variance_share(poland_dsge.variance_decomposition, 'y', 'eps_p'), 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyVdPiCostPush}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'pi', 'eps_p'), 1) '}']
        [bs 'newcommand{' bs 'DsgePolandVdPiCostPush}{' format_decimal(get_variance_share(poland_dsge.variance_decomposition, 'pi', 'eps_p'), 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyVdInvOwn}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'inv', 'eps_inv'), 1) '}']
        [bs 'newcommand{' bs 'DsgePolandVdInvOwn}{' format_decimal(get_variance_share(poland_dsge.variance_decomposition, 'inv', 'eps_inv'), 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyVdInvCostPush}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'inv', 'eps_p'), 1) '}']
        [bs 'newcommand{' bs 'DsgePolandVdInvCostPush}{' format_decimal(get_variance_share(poland_dsge.variance_decomposition, 'inv', 'eps_p'), 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyVdInvMonetary}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'inv', 'eps_r'), 1) '}']
        [bs 'newcommand{' bs 'DsgePolandVdInvMonetary}{' format_decimal(get_variance_share(poland_dsge.variance_decomposition, 'inv', 'eps_r'), 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyVdNLaborForce}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'n', 'eps_L'), 1) '}']
        [bs 'newcommand{' bs 'DsgeGermanyVdNSeparation}{' format_decimal(get_variance_share(germany_dsge.variance_decomposition, 'n', 'eps_sep'), 1) '}']
        [bs 'newcommand{' bs 'DsgePolandVdNLaborForce}{' format_decimal(get_variance_share(poland_dsge.variance_decomposition, 'n', 'eps_L'), 1) '}']
        [bs 'newcommand{' bs 'DsgeVdExogenousOwnShare}{' format_decimal(100, 0) '}']
        [bs 'newcommand{' bs 'DsgeShockOrder}{' shock_order_math '}']
        [bs 'newcommand{' bs 'DsgeShockOrderNames}{' shock_order_names '}']
    };

    latex_text = strjoin(lines, newline);

    if options.write_file
        render_latex_table(output_file, latex_text, ...
            'generated_by', 'render_inline_value_macros', ...
            'header_lines', {'% Inline numeric macros for prose references.'});
    end

    result = struct();
    result.output_file = output_file;
    result.latex_text = latex_text;
end

function summary = load_summary(summary_file)
    if ~exist(summary_file, 'file')
        error('Summary file not found: %s', summary_file);
    end
    summary = jsondecode(fileread(summary_file));
end

function summary = load_required_summary(summary_file)
    if ~exist(summary_file, 'file')
        error(['Required summary not found: %s\n' ...
               'The detrending benchmark summaries are written by run_detrending_benchmark(''<Country>''); ' ...
               'the curated ones are tracked in documentation_tables/curated/.'], summary_file);
    end
    summary = jsondecode(fileread(summary_file));
end

function value = get_posterior_mean(rows, row_name)
    for idx = 1:numel(rows)
        if strcmp(rows(idx).name, row_name)
            value = rows(idx).posterior_mean;
            return;
        end
    end
    error('Posterior parameter %s not found.', row_name);
end

function value = compute_share_sum(base_year_values)
    value = base_year_values.CY + base_year_values.IY + base_year_values.GY + base_year_values.NXY;
end

function value = get_variance_share(vd_payload, observable_name, shock_name)
    rows = vd_payload.rows;
    for idx = 1:numel(rows)
        if strcmp(rows(idx).observable, observable_name)
            if isfield(rows(idx).shares_percent, shock_name)
                value = rows(idx).shares_percent.(shock_name);
                return;
            end
            error('Shock %s not found in variance decomposition for %s.', shock_name, observable_name);
        end
    end
    error('Variance decomposition row for %s not found.', observable_name);
end

function value = get_moment_value(rows, observable_name, field_name)
    for idx = 1:numel(rows)
        if strcmp(rows(idx).observable, observable_name)
            if isfield(rows(idx), field_name)
                value = rows(idx).(field_name);
                return;
            end
            error('Moment field %s not found for observable %s.', field_name, observable_name);
        end
    end
    error('Moment row for observable %s not found.', observable_name);
end

function [min_ratio, max_ratio] = compute_std_ratio_bounds(rows)
    ratios = zeros(numel(rows), 1);
    for idx = 1:numel(rows)
        ratios(idx) = compute_std_ratio(rows(idx).model_std, rows(idx).data_std);
    end
    min_ratio = min(ratios);
    max_ratio = max(ratios);
end

function value = compute_std_ratio(model_std, data_std)
    value = model_std / data_std;
end

function value = compute_benchmark_std_ratio(benchmark_summary, observable_name)
    hp_run = find_benchmark_run(benchmark_summary.runs, 'hp');
    ramsey_run = find_benchmark_run(benchmark_summary.runs, 'ramsey');

    hp_std = get_moment_value(hp_run.moments, observable_name, 'data_std');
    ramsey_std = get_moment_value(ramsey_run.moments, observable_name, 'data_std');
    value = ramsey_std / hp_std;
end

function run_summary = find_benchmark_run(runs, method_name)
    for idx = 1:numel(runs)
        if strcmp(runs(idx).method, method_name)
            run_summary = runs(idx);
            return;
        end
    end
    error('Benchmark method %s not found.', method_name);
end

function token = read_sample_start_quarter(country)
    data_file = artifact_path('data', sprintf('data_for_dynare_%s.csv', country));
    if ~exist(data_file, 'file')
        error('Data file not found for sample start quarter lookup: %s', data_file);
    end

    lines = splitlines(fileread(data_file));
    if numel(lines) < 2
        error('Data file %s does not contain observations.', data_file);
    end

    first_row = strtrim(lines{2});
    first_field = regexp(first_row, '^[^,]+', 'match', 'once');
    token = upper(first_field);
end

function [math_text, name_text] = read_shock_order(model_root)
% Read the varexo declaration order from the template, so the documentation
% cannot drift from it. Contract 22 in docs/Integration_Contracts.md.
    template_file = fullfile(model_root, 'Macromodel_template.mod');
    if ~exist(template_file, 'file')
        error('Template not found for shock order lookup: %s', template_file);
    end

    text = fileread(template_file);
    block = regexp(text, 'varexo\s+(.*?);', 'tokens', 'once');
    if isempty(block)
        error('No varexo block found in %s.', template_file);
    end

    stripped = regexprep(block{1}, '//[^\n]*', '');
    names = regexp(stripped, 'eps_\w+', 'match');
    if isempty(names)
        error('varexo block in %s declares no eps_* shocks.', template_file);
    end

    % Prose labels keyed by shock name. A new shock must be named here or the
    % documentation refresh fails loudly rather than silently omitting it.
    labels = struct( ...
        'eps_a', 'technology', ...
        'eps_r', 'monetary', ...
        'eps_d', 'demand', ...
        'eps_p', 'cost-push', ...
        'eps_L', 'labour supply', ...
        'eps_sep', 'separation', ...
        'eps_h', 'hours', ...
        'eps_inv', 'investment');

    bs = char(92);
    math_parts = cell(1, numel(names));
    name_parts = cell(1, numel(names));
    for i = 1:numel(names)
        suffix = names{i}(5:end);
        if numel(suffix) == 1
            math_parts{i} = [bs 'eps_' suffix];
        else
            math_parts{i} = [bs 'eps_{' bs 'mathrm{' suffix '}}'];
        end
        if ~isfield(labels, names{i})
            error(['Shock %s is declared in the template varexo block but has no ' ...
                   'prose label in read_shock_order. Add one so the documentation ' ...
                   'stays complete.'], names{i});
        end
        name_parts{i} = labels.(names{i});
    end

    math_text = strjoin(math_parts, ',');
    name_text = [strjoin(name_parts(1:end-1), ', ') ', and ' name_parts{end}];
end

function text = format_decimal(value, decimals)
    text = sprintf(['%0.' num2str(decimals) 'f'], value);
end

function text = format_integer(value)
    text = sprintf('%d', round(value));
end