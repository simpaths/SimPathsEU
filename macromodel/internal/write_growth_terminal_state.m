function info = write_growth_terminal_state(growth_mat, output_dir)
% WRITE_GROWTH_TERMINAL_STATE  Write growth_terminal_state.json for SimPaths.
%
%   info = WRITE_GROWTH_TERMINAL_STATE(growth_mat, output_dir) reads the Ramsey
%   workspace at `growth_mat` and writes the handoff contract that the Java
%   runtime initialises from. Returns a struct describing what was written.
%
% CONTRACT: this is the only writer of growth_terminal_state.json. Both
% export_dynamic_for_simpaths.m (full workflow) and export_ramsey_for_simpaths.m
% (Ramsey-only refresh) call it.
%
% Two copies of this writer existed until 2026-08 and had already diverged: the
% Ramsey-only copy did not emit `projection_quarters`. Java falls back to the
% legacy 320-quarter horizon when that key is missing — with a log warning, but
% the run continues on a different forward horizon than the one the trend was
% solved over. Contract #9 in .docs/Integration_Contracts.md exists precisely to
% stop the horizon being a constant on each side; the second writer quietly
% reopened it for anyone following the "Refresh Ramsey Files Only" recipe in
% macromodel/README.md.

    arguments
        growth_mat (1,:) char
        output_dir (1,:) char
    end

    info = struct('written', false, 'file', '', 'endogenous_labor', false);

    if ~exist(growth_mat, 'file')
        return;
    end

    growth_data = load(growth_mat, 'K_terminal', 'A_terminal', 'params', ...
                       'simpaths_handoff_time', 'projection_quarters');

    mat_vars = who('-file', growth_mat);
    has_endo_labor = ismember('endogenous_labor', mat_vars) && ismember('l_trend', mat_vars);
    if has_endo_labor
        endo_data = load(growth_mat, 'endogenous_labor', 'l_trend', 'WAP_trend', ...
                         'psi_terminal', 'l_handoff', 'WAP_handoff', 'psi_handoff');
        is_endo = endo_data.endogenous_labor;
    else
        endo_data = struct();
        is_endo = false;
    end

    if isfield(growth_data, 'simpaths_handoff_time')
        handoff_label = growth_data.simpaths_handoff_time;
    else
        handoff_label = 'sample end';
    end

    lines = {};
    lines{end+1} = '{';
    % %.16e, not %.10f: A is O(0.03), so ten decimals kept only ~9 significant
    % digits — worst-case ~1.4e-9 RELATIVE, above the 1e-9 Java parity tolerance.
    % The 4.4e-11 the anchor test measured was luck of the digits. Full precision
    % takes this file out of the parity budget, as psi_terminal already is.
    lines{end+1} = sprintf('  "K_terminal": %.16e,', growth_data.K_terminal);
    lines{end+1} = sprintf('  "A_terminal": %.16e,', growth_data.A_terminal);
    lines{end+1} = sprintf('  "handoff_time": "%s",', handoff_label);

    % Forward horizon of the handoff contract. Java rebuilds the projection over
    % the same number of quarters; a mismatch silently changes the terminal
    % closure, so the value is exported and validated there rather than
    % duplicated as a constant on each side.
    if isfield(growth_data, 'projection_quarters') && ~isempty(growth_data.projection_quarters)
        lines{end+1} = sprintf('  "projection_quarters": %d,', ...
                               round(growth_data.projection_quarters));
    else
        warning('write_growth_terminal_state:MissingHorizon', ...
                ['%s carries no projection_quarters, so the bundle cannot pin the ' ...
                 'forward horizon and Java will fall back to its legacy default. ' ...
                 'Re-run ramsey_trend to regenerate the workspace.'], growth_mat);
    end

    l_terminal_out = NaN;
    psi_terminal_out = NaN;
    if is_endo
        if isfield(endo_data, 'l_handoff')
            l_terminal_out = endo_data.l_handoff;
        else
            l_terminal_out = endo_data.l_trend(end);
        end
        if isfield(endo_data, 'WAP_handoff')
            wap_terminal_out = endo_data.WAP_handoff;
        else
            wap_terminal_out = endo_data.WAP_trend(end);
        end
        lines{end+1} = '  "endogenous_labor": true,';
        lines{end+1} = sprintf('  "l_terminal": %.10f,', l_terminal_out);
        lines{end+1} = sprintf('  "WAP_terminal": %.6f,', wap_terminal_out);
        if isfield(endo_data, 'psi_handoff')
            psi_terminal_out = endo_data.psi_handoff;
        elseif isfield(endo_data, 'psi_terminal')
            psi_terminal_out = endo_data.psi_terminal;
        end
        if isfinite(psi_terminal_out)
            lines{end+1} = sprintf('  "psi_terminal": %.16e,', psi_terminal_out);
        end
    end

    lines{end+1} = ['  "comment": "Capital stock, TFP level, and (if endogenous) ' ...
                    'labor wedge at the SimPaths handoff quarter. Use as initial ' ...
                    'values for SimPaths forward projection."'];
    lines{end+1} = '}';

    terminal_file = fullfile(output_dir, 'growth_terminal_state.json');
    write_text_atomic(terminal_file, strjoin(lines, newline), 'verify_json', true);

    if is_endo
        fprintf('    ✓ growth_terminal_state.json (%s; K=%.1f, A=%.6f, l=%.4f, psi=%.6e)\n', ...
                handoff_label, growth_data.K_terminal, growth_data.A_terminal, ...
                l_terminal_out, psi_terminal_out);
    else
        fprintf('    ✓ growth_terminal_state.json (%s; K=%.1f, A=%.6f)\n', ...
                handoff_label, growth_data.K_terminal, growth_data.A_terminal);
    end

    info.written = true;
    info.file = terminal_file;
    info.endogenous_labor = is_endo;
    info.handoff_time = handoff_label;
end
