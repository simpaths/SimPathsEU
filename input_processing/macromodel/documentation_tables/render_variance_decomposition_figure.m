function result = render_variance_decomposition_figure(summary_input, output_file, options)
% RENDER_VARIANCE_DECOMPOSITION_FIGURE  Render DSGE posterior-mean variance decomposition as a PDF figure.

    arguments
        summary_input
        output_file (1,:) char = ''
        options.write_file (1,1) logical = true
    end

    summary = load_summary(summary_input);
    validate_documentation_summary(summary, 'dsge');

    if ~isfield(summary, 'variance_decomposition') || ~isfield(summary.variance_decomposition, 'rows')
        error('Variance decomposition rows not found in DSGE summary.');
    end

    country = summary.metadata.country;
    observables = {'y', 'inv', 'c', 'pi', 'R', 'n', 'L', 'h'};
    observable_labels = { ...
        'Output Gap (%)', 'Investment Gap (%)', 'Consumption Gap (%)', ...
        'Inflation (% ann.)', 'Interest Rate (%)', 'Employment Gap (%)', ...
        'Labor Force Gap (%)', 'Hours Gap (%)'};
    shock_order = {'eps_a', 'eps_d', 'eps_r', 'eps_p', 'eps_L', 'eps_sep', 'eps_h', 'eps_inv'};
    shock_labels = {'Technology', 'Demand', 'Monetary', 'Cost-Push', 'Labor Force', 'Separation', 'Hours', 'Investment'};
    cmap = [0.00 0.45 0.70; ...
        0.84 0.15 0.16; ...
        0.00 0.62 0.45; ...
        0.80 0.47 0.65; ...
        0.58 0.40 0.74; ...
        0.94 0.89 0.26; ...
        0.60 0.60 0.60; ...
        0.90 0.62 0.00];

    rows = summary.variance_decomposition.rows;
    vd_matrix = zeros(numel(observables), numel(shock_order));

    for obs_idx = 1:numel(observables)
        row = find_vd_row(rows, observables{obs_idx});
        if isempty(row)
            error('Variance decomposition row %s not found in summary for %s.', observables{obs_idx}, country);
        end

        for shock_idx = 1:numel(shock_order)
            shock_name = shock_order{shock_idx};
            if ~isfield(row.shares_percent, shock_name)
                error('Variance decomposition row %s is missing shock %s.', observables{obs_idx}, shock_name);
            end
            vd_matrix(obs_idx, shock_idx) = row.shares_percent.(shock_name);
        end
    end

    fig = figure('Name', 'Variance Decomposition', ...
        'Visible', 'off', ...
        'Color', 'w', ...
        'Units', 'pixels', ...
        'Position', [50 50 1000 600]);

    cat_labels = categorical(observable_labels, observable_labels, 'Ordinal', true);
    bars = bar(cat_labels, vd_matrix, 'stacked');
    for idx = 1:numel(bars)
        bars(idx).FaceColor = cmap(idx, :);
    end

    ylabel('Variance Share (%)', 'FontSize', 11);
    title('Variance Decomposition at Posterior Mean', 'FontSize', 14, 'FontWeight', 'bold');
    legend(shock_labels, 'Location', 'eastoutside', 'FontSize', 10);
    ylim([0 100]);
    grid on;
    box on;

    for obs_idx = 1:size(vd_matrix, 1)
        cumulative_share = 0;
        for shock_idx = 1:size(vd_matrix, 2)
            share_value = vd_matrix(obs_idx, shock_idx);
            if share_value > 5
                text(obs_idx, cumulative_share + share_value / 2, sprintf('%.0f%%', share_value), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'white');
            end
            cumulative_share = cumulative_share + share_value;
        end
    end

    if options.write_file && ~isempty(output_file)
        output_dir = fileparts(output_file);
        if ~isempty(output_dir) && ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        exportgraphics(fig, output_file, 'ContentType', 'vector', 'BackgroundColor', 'white');
    end

    close(fig);

    result = struct();
    result.country = country;
    result.output_file = output_file;
    result.matrix = vd_matrix;
end

function summary = load_summary(summary_input)
    if isstruct(summary_input)
        summary = summary_input;
        return;
    end

    if isstring(summary_input)
        summary_input = char(summary_input);
    end

    if ischar(summary_input)
        if ~exist(summary_input, 'file')
            error('Summary file not found: %s', summary_input);
        end
        summary = jsondecode(fileread(summary_input));
        return;
    end

    error('summary_input must be a struct or a JSON file path.');
end

function row = find_vd_row(rows, observable_name)
    row = [];
    for idx = 1:numel(rows)
        if strcmp(rows(idx).observable, observable_name)
            row = rows(idx);
            return;
        end
    end
end