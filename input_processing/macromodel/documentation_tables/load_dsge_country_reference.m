function reference = load_dsge_country_reference(country, calibration_file, summary_input)
% LOAD_DSGE_COUNTRY_REFERENCE  Load calibrated and estimated DSGE parameters for one country.

    arguments
        country (1,:) char
        calibration_file (1,:) char
        summary_input
    end

    summary = load_summary(summary_input);
    validate_documentation_summary(summary, 'dsge');

    calibration = parse_calibration_file(calibration_file);
    estimation_file = strrep(calibration_file, '_calibration.mod', '_estimation.mod');
    calibration = merge_structs(calibration, parse_fixed_shock_stds(estimation_file));
    posterior = struct();
    posterior_rows = summary.posterior_parameters;
    for idx = 1:numel(posterior_rows)
        posterior.(posterior_rows(idx).name) = posterior_rows(idx).posterior_mean;
    end

    reference = struct();
    reference.country = country;
    reference.summary = summary;
    reference.calibration = calibration;
    reference.posterior = posterior;
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

function shock_stds = parse_fixed_shock_stds(estimation_file)
    shock_stds = struct();
    if ~exist(estimation_file, 'file')
        return;
    end

    lines = splitlines(fileread(estimation_file));
    pattern = '^\s*var\s+eps_([A-Za-z][A-Za-z0-9_]*)\s*;\s*stderr\s+([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\s*;';
    for idx = 1:numel(lines)
        tokens = regexp(lines{idx}, pattern, 'tokens', 'once');
        if isempty(tokens)
            continue;
        end

        field_name = ['sigma_' tokens{1}];
        shock_stds.(field_name) = str2double(tokens{2});
    end
end

function merged = merge_structs(left_struct, right_struct)
    merged = left_struct;
    field_names = fieldnames(right_struct);
    for idx = 1:numel(field_names)
        merged.(field_names{idx}) = right_struct.(field_names{idx});
    end
end