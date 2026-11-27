function status = render_ramsey_diagnostic_figures(ramsey_summary_dir, output_dir, options)
% RENDER_RAMSEY_DIAGNOSTIC_FIGURES  Export Ramsey trend diagnostics to Overleaf PDFs.
%
% One figure per country with a Ramsey summary (or only OPTIONS.COUNTRY), from
% output/ramsey_trends_{country}.csv and data/data_for_dynare_levels_{Country}.csv.
% Run from the model root. The file name keeps its "_exogenous" suffix, which the
% Overleaf document includes by name.

    arguments
        ramsey_summary_dir (1,:) char
        output_dir (1,:) char
        options.country (1,:) char = ''
        options.fail_on_missing_inputs (1,1) logical = false
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    summary_files = dir(fullfile(ramsey_summary_dir, 'ramsey_summary_*.json'));

    status = struct();
    status.generated = {};
    status.skipped = {};

    for idx = 1:numel(summary_files)
        summary_path = fullfile(summary_files(idx).folder, summary_files(idx).name);
        summary = jsondecode(fileread(summary_path));
        country = summary.metadata.country;

        if ~isempty(options.country) && ~strcmpi(country, options.country)
            continue;
        end

        trend_path = artifact_path('output', sprintf('ramsey_trends_%s.csv', lower(country)));
        data_path = artifact_path('data', sprintf('data_for_dynare_levels_%s.csv', country));
        output_path = fullfile(output_dir, sprintf('ramsey_diagnostic_%s_exogenous.pdf', lower(country)));

        if ~exist(trend_path, 'file') || ~exist(data_path, 'file')
            message = sprintf('%s: missing trend/data input (%s, %s)', country, trend_path, data_path);
            if options.fail_on_missing_inputs
                error('render_ramsey_diagnostic_figures:MissingInputs', '%s', message);
            end
            status.skipped{end+1} = message; %#ok<AGROW>
            continue;
        end

        render_country_figure(country, data_path, trend_path, output_path);
        status.generated{end+1} = output_path; %#ok<AGROW>
    end
end


function render_country_figure(country, data_path, trend_path, output_path)
    data = readtable(data_path);
    trend = readtable(trend_path);

    T = min(height(data), height(trend));
    time_labels = to_cellstr(data.time(1:T));
    tick_idx = unique([1, 1:20:T, T]);

    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [100 100 1400 900]);
    layout = tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact'); %#ok<NASGU>

    nexttile;
    plot_trend_vs_actual(data.y_level(1:T), trend.Y(1:T), time_labels, tick_idx, 'Output (Y)');

    nexttile;
    plot_trend_vs_actual(data.c_level(1:T), trend.C(1:T), time_labels, tick_idx, 'Consumption (C)');

    nexttile;
    plot_trend_vs_actual(data.inv_level(1:T), trend.I(1:T), time_labels, tick_idx, 'Investment (I)');

    nexttile;
    if ismember('g_level', data.Properties.VariableNames)
        plot_trend_vs_actual(data.g_level(1:T), trend.G(1:T), time_labels, tick_idx, 'Government (G)');
    else
        title('Government (G)');
        grid on;
    end

    ax = nexttile;
    plot(1:T, trend.r_star_smooth(1:T), 'b-', 'LineWidth', 1.5);
    hold on;
    plot(1:T, trend.r_star_annual(1:T) * 100, 'r--', 'LineWidth', 1.0);
    hold off;
    format_time_axis(time_labels, tick_idx, T);
    title('r* (annual %)');
    legend(ax, 'Smoothed ex-ante', 'Ramsey MPK', 'Location', 'northwest', 'FontSize', 7, 'Box', 'on');
    grid on;

    nexttile;
    output_gap = demeaned_log_gap(data.y_level(1:T), trend.Y(1:T));
    plot(1:T, output_gap, 'b-');
    hold on;
    yline(0, 'r--');
    hold off;
    format_time_axis(time_labels, tick_idx, T);
    title('Output Gap (% dev)');
    grid on;

    nexttile;
    interest_gap = demeaned_level_gap(data.R(1:T), trend.R_trend(1:T));
    plot(1:T, interest_gap, 'b-');
    hold on;
    yline(0, 'r--');
    hold off;
    format_time_axis(time_labels, tick_idx, T);
    title('Interest Rate Gap (pp)');
    grid on;

    ax = nexttile;
    plot(1:T, trend.gY(1:T) * 100, 'b-', 'LineWidth', 1.2);
    hold on;
    plot(1:T, trend.nxY(1:T) * 100, 'r-', 'LineWidth', 1.2);
    yline(0, 'k--');
    hold off;
    format_time_axis(time_labels, tick_idx, T);
    title('G/Y and NX/Y (%)');
    legend(ax, 'G/Y', 'NX/Y', 'Location', 'southwest', 'FontSize', 7, 'Box', 'on');
    grid on;

    sgtitle(sprintf('Ramsey Growth Model Trends -- %s', country));
    exportgraphics(fig, output_path, 'ContentType', 'vector', 'BackgroundColor', 'white');
    close(fig);
end


function plot_trend_vs_actual(actual, trend_vals, time_labels, tick_idx, title_str)
    T = numel(actual);
    valid = ~isnan(actual) & ~isnan(trend_vals) & actual > 0 & trend_vals > 0;
    mean_log_gap = mean(log(actual(valid)) - log(trend_vals(valid)), 'omitnan');
    trend_centered = trend_vals .* exp(mean_log_gap);

    plot(1:T, actual, 'b-', 'LineWidth', 0.8);
    hold on;
    plot(1:T, trend_centered, 'm--', 'LineWidth', 1.5);
    plot(1:T, trend_vals, ':', 'LineWidth', 0.8, 'Color', [1 0.5 0.5]);
    hold off;

    format_time_axis(time_labels, tick_idx, T);
    title(title_str);
    legend('Actual', 'Centered Trend', 'Raw Trend', 'Location', 'best', 'FontSize', 7);
    grid on;
end


function values = demeaned_log_gap(actual, trend_vals)
    values = 100 * (log(actual) - log(trend_vals));
    valid = ~isnan(values) & isfinite(values);
    values = values - mean(values(valid), 'omitnan');
end


function values = demeaned_level_gap(actual, trend_vals)
    values = actual - trend_vals;
    valid = ~isnan(values) & isfinite(values);
    values = values - mean(values(valid), 'omitnan');
end


function format_time_axis(time_labels, tick_idx, T)
    xlim([1 T]);
    xticks(tick_idx);
    xticklabels(time_labels(tick_idx));
    xtickangle(45);
    set(gca, 'FontSize', 8);
end


function values = to_cellstr(raw_values)
    if iscell(raw_values)
        values = raw_values;
    elseif isstring(raw_values)
        values = cellstr(raw_values);
    elseif ischar(raw_values)
        values = cellstr(raw_values);
    else
        values = cellstr(string(raw_values));
    end
end