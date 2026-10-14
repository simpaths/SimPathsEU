%% Plot Bayesian IRFs with 90% Credible Intervals
% IRFs are already computed from the estimation (bayesian_irf option)
%
% Creates:
%   1. One 3x4 figure per shock (available variables)
%   2. One combined mega-figure (all shocks, available variables)
%
% NOTE: Dynare only computes posterior IRFs for observed variables by default.
%       To get IRFs for ALL variables, add to estimation command:
%           bayesian_irf, irf=40
%       And ensure oo_.PosteriorIRF exists.
%
% V9 Note (Feb 2026):
%   - L (labor force) and h (hours) are EXOGENOUS AR(1) processes
%   - L responds ONLY to eps_L (rho_L = 0.95, CALIBRATED)
%   - h responds ONLY to eps_h (rho_h = 0.85, CALIBRATED)  
%   - IRFs of L and h to other shocks will show zero response (correct)
%
% =========================================================================

% All variables in preferred order (including hours h and consumption c)
vars_all = {'y', 'w', 'n', 'h', 'u', 'v', 'theta', 'pi', 'R', 'gap', 'd', 'c', 'x', 'L', 'u_rate', 'k', 'inv'};
var_titles_all = {'Output', 'Real Wage', 'Employment', 'Hours', 'Unemployment', 'Vacancies', ...
                  'Tightness', 'Inflation', 'Interest Rate', 'Output Gap', ...
                  'Demand', 'Consumption', 'Matching Rate', 'Labor Force', 'Unemp. Rate', 'Capital', 'Investment'};

% Shocks in preferred order (matching combined plot layout) - v12: includes eps_p
shocks = {'eps_L', 'eps_a', 'eps_d', 'eps_p', 'eps_h', 'eps_inv', 'eps_r', 'eps_sep'};
shock_titles = {'Labor Force', 'Technology', 'Demand', 'Cost-Push', 'Hours', 'Investment', 'Monetary Policy', 'Separation'};

% =========================================================================
% DIAGNOSTICS: Check what IRFs are actually available
% =========================================================================
if ~isfield(oo_, 'PosteriorIRF') || ~isfield(oo_.PosteriorIRF, 'dsge')
    error('No posterior IRFs found. Run estimation with bayesian_irf option first.');
end

available_irfs = fieldnames(oo_.PosteriorIRF.dsge.Mean);
fprintf('\n=== Posterior IRF Diagnostics ===\n');
fprintf('Found %d IRF series in oo_.PosteriorIRF.dsge.Mean\n', length(available_irfs));

% Determine which variables have IRFs (check first shock)
vars = {};
var_titles = {};
for i = 1:length(vars_all)
    test_irf = [vars_all{i} '_' shocks{1}];
    if isfield(oo_.PosteriorIRF.dsge.Mean, test_irf)
        vars{end+1} = vars_all{i};
        var_titles{end+1} = var_titles_all{i};
    end
end

fprintf('Variables with posterior IRFs: %s\n', strjoin(vars, ', '));
fprintf('Variables WITHOUT IRFs: ');
missing_vars = setdiff(vars_all, vars);
if isempty(missing_vars)
    fprintf('(none - all available)\n');
else
    fprintf('%s\n', strjoin(missing_vars, ', '));
    fprintf('\n*** To get IRFs for ALL variables, ensure estimation includes:\n');
    fprintf('    bayesian_irf, irf=40\n\n');
end

nvars = length(vars);

% Ensure output directory exists: Dynare's graphs folder of the loaded model, as in plot_custom_irfs.m
graphs_dir = fullfile(M_.fname, 'graphs');
if ~exist(graphs_dir, 'dir')
    mkdir(graphs_dir);
end

% =========================================================================
% PART 1: Individual figures (one per shock)
% =========================================================================
% Determine layout based on number of available variables
if nvars <= 6
    nrows = 2; ncols = 3;  % 2x3 for 6 or fewer
elseif nvars <= 9
    nrows = 3; ncols = 3;  % 3x3 for 7-9
else
    nrows = 3; ncols = 4;  % 3x4 for 10-12
end

for s = 1:length(shocks)
    fig = figure('Name', ['IRFs to ' shock_titles{s} ' Shock'], ...
                 'NumberTitle', 'off', ...
                 'Position', [50 50 1920 1080]);  % Full HD
    
    % Set paper size for export
    set(fig, 'PaperPositionMode', 'auto');
    set(fig, 'PaperUnits', 'inches');
    set(fig, 'PaperSize', [19.2 10.8]);
    
    for v = 1:nvars
        subplot(nrows, ncols, v);
        
        irf_name = [vars{v} '_' shocks{s}];
        
        if isfield(oo_.PosteriorIRF.dsge.Mean, irf_name)
            % Get mean and HPD bounds (ensure row vectors)
            irf_mean = oo_.PosteriorIRF.dsge.Mean.(irf_name);
            irf_low = oo_.PosteriorIRF.dsge.HPDinf.(irf_name);
            irf_high = oo_.PosteriorIRF.dsge.HPDsup.(irf_name);
            
            % Convert to row vectors if needed
            irf_mean = irf_mean(:)';
            irf_low = irf_low(:)';
            irf_high = irf_high(:)';
            
            T = length(irf_mean);
            x_fill = [1:T, T:-1:1];
            y_fill = [irf_low, fliplr(irf_high)];
            
            % Plot credible interval as shaded area
            fill(x_fill, y_fill, [0.7 0.85 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
            hold on;
            
            % Plot mean
            plot(1:T, irf_mean, 'b-', 'LineWidth', 1.5);
            
            % Zero line
            plot(1:T, zeros(1,T), 'k--', 'LineWidth', 0.5);
            hold off;
            
            title(var_titles{v}, 'FontSize', 10);
            xlabel('Quarters', 'FontSize', 8);
            ylabel('% dev.', 'FontSize', 8);
            grid on;
        else
            title([var_titles{v} ' (N/A)'], 'FontSize', 10);
        end
    end
    
    sgtitle([shock_titles{s} ' Shock - 90% Credible Interval'], 'FontSize', 14, 'FontWeight', 'bold');
    
    % Save figure
    fig_filename = sprintf('IRF_CI_%s', shocks{s});
    print(gcf, fullfile(graphs_dir, [fig_filename '.jpeg']), '-djpeg', '-r300');
    fprintf('Saved: %s.jpeg\n', fig_filename);
end

% =========================================================================
% PART 2: Combined mega-figure (2x3 shock blocks, each with variables)
% =========================================================================
% Layout: 2 rows x 3 columns of "shock blocks"
% Each shock block has nrows x ncols variables
% Total subplots: (2*nrows) x (3*ncols)

fprintf('\nCreating combined mega-figure...\n');

fig_mega = figure('Name', 'Combined IRFs with Credible Intervals', ...
                  'NumberTitle', 'off', ...
                  'Position', [10 10 1920 1080]);  % Full HD

% Set paper size for high-quality export
set(fig_mega, 'PaperPositionMode', 'auto');
set(fig_mega, 'PaperUnits', 'inches');
set(fig_mega, 'PaperSize', [19.2 10.8]);

% Define the 2x3 grid of shocks
% Row 1: shocks 1-4 (Labor Force, Technology, Demand, Hours)
% Row 2: shocks 5-8 (Investment, Matching, Monetary, Separation)
shock_grid = [1, 2, 3, 4; 5, 6, 7, 8];

nrows_var = nrows;   % rows per shock block (from Part 1)
ncols_var = ncols;   % cols per shock block (from Part 1)
nrows_shock = 2;     % rows of shock blocks
ncols_shock = 4;     % cols of shock blocks

% =========================================================================
% SPACING PARAMETERS (adjust for visual separation)
% =========================================================================
% Margins
margin_left = 0.04;
margin_right = 0.02;
margin_top = 0.06;      % Space for overall title
margin_bottom = 0.04;

% Gaps between shock blocks
gap_h = 0.03;           % Horizontal gap between shock columns
gap_v = 0.06;           % Vertical gap between shock rows (includes title space)

% Calculate available space for shock blocks
total_width = 1 - margin_left - margin_right - (ncols_shock - 1) * gap_h;
total_height = 1 - margin_top - margin_bottom - (nrows_shock - 1) * gap_v;

% Size of each shock block
block_width = total_width / ncols_shock;
block_height = total_height / nrows_shock;

% Small gaps within each shock block (between variable subplots)
inner_gap_h = 0.008;
inner_gap_v = 0.015;

% Space for shock title above each block
title_space = 0.025;

for shock_row = 1:nrows_shock
    for shock_col = 1:ncols_shock
        shock_idx = shock_grid(shock_row, shock_col);
        
        if shock_idx == 0
            continue;  % Skip empty cell
        end
        
        shock = shocks{shock_idx};
        
        % Calculate the position of this shock block
        block_left = margin_left + (shock_col - 1) * (block_width + gap_h);
        block_bottom = 1 - margin_top - shock_row * block_height - (shock_row - 1) * gap_v;
        
        % Add centered shock title above this block
        title_x = block_left + block_width / 2;
        title_y = block_bottom + block_height + title_space * 0.6;
        annotation('textbox', [title_x - 0.08, title_y - 0.015, 0.16, 0.03], ...
                   'String', shock_titles{shock_idx}, ...
                   'HorizontalAlignment', 'center', ...
                   'VerticalAlignment', 'middle', ...
                   'FontSize', 9, 'FontWeight', 'bold', ...
                   'EdgeColor', 'none', ...
                   'BackgroundColor', 'none');
        
        % Size of each subplot within the block
        subplot_width = (block_width - (ncols_var - 1) * inner_gap_h) / ncols_var;
        subplot_height = (block_height - title_space - (nrows_var - 1) * inner_gap_v) / nrows_var;
        
        for v = 1:nvars
            % Variable position within shock block
            var_row = ceil(v / ncols_var);  % row within shock block
            var_col = mod(v - 1, ncols_var) + 1;  % col within shock block
            
            % Calculate subplot position
            sp_left = block_left + (var_col - 1) * (subplot_width + inner_gap_h);
            sp_bottom = block_bottom + block_height - title_space - var_row * subplot_height - (var_row - 1) * inner_gap_v;
            
            % Create axes at calculated position
            ax = axes('Position', [sp_left, sp_bottom, subplot_width * 0.92, subplot_height * 0.85]);
            
            irf_name = [vars{v} '_' shock];
            
            if isfield(oo_.PosteriorIRF.dsge.Mean, irf_name)
                % Get mean and HPD bounds
                irf_mean = oo_.PosteriorIRF.dsge.Mean.(irf_name)(:)';
                irf_low = oo_.PosteriorIRF.dsge.HPDinf.(irf_name)(:)';
                irf_high = oo_.PosteriorIRF.dsge.HPDsup.(irf_name)(:)';
                
                T = length(irf_mean);
                x_fill = [1:T, T:-1:1];
                y_fill = [irf_low, fliplr(irf_high)];
                
                % Plot credible interval
                fill(x_fill, y_fill, [0.7 0.85 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
                hold on;
                plot(1:T, irf_mean, 'b-', 'LineWidth', 0.8);
                plot(1:T, zeros(1,T), 'k--', 'LineWidth', 0.3);
                hold off;
                
                % Minimal formatting for tiny plots
                set(gca, 'FontSize', 5);
                xlim([1 T]);
                
                % Variable label above each subplot
                short_var = get_short_var_name(vars{v});
                title(short_var, 'FontSize', 6, 'FontWeight', 'bold');
            end
        end
    end
end

% Add overall title
annotation('textbox', [0.3, 0.96, 0.4, 0.03], ...
           'String', 'Bayesian IRFs with 90% Credible Intervals - All Shocks', ...
           'HorizontalAlignment', 'center', ...
           'VerticalAlignment', 'middle', ...
           'FontSize', 12, 'FontWeight', 'bold', ...
           'EdgeColor', 'none');

% Save mega-figure
print(fig_mega, fullfile(graphs_dir, 'IRF_CI_combined.jpeg'), '-djpeg', '-r300');
fprintf('Saved: IRF_CI_combined.jpeg\n');

disp('IRF plots with credible intervals generated!');

% =========================================================================
% Helper function for short variable names
% =========================================================================
function short_name = get_short_var_name(var_name)
    switch var_name
        case 'y',      short_name = 'Y';
        case 'w',      short_name = 'W';
        case 'n',      short_name = 'N';
        case 'h',      short_name = 'H';
        case 'u',      short_name = 'U';
        case 'u_rate', short_name = 'u%';
        case 'v',      short_name = 'V';
        case 'theta',  short_name = 'θ';
        case 'pi',     short_name = 'π';
        case 'R',      short_name = 'R';
        case 'gap',    short_name = 'Gap';
        case 'd',      short_name = 'D';
        case 'x',      short_name = 'X';
        case 'L',      short_name = 'L';
        case 'k',      short_name = 'K';
        case 'inv',    short_name = 'Inv';
        otherwise,     short_name = var_name;
    end
end