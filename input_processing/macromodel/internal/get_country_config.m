function config = get_country_config(country)
% GET_COUNTRY_CONFIG  Validate supported country names and return metadata.
%
% Usage:
%   cfg = get_country_config('Spain')
%
% Returns a struct with fields:
%   name          - Canonical country name used by the DSGE wrappers
%   simpaths_code - SimPaths input folder code (e.g. DE, PL, SE, ES, UK)

    arguments
        country (1,:) char
    end

    supported = struct(...
        'Germany', struct('name', 'Germany', 'simpaths_code', 'DE'), ...
        'Poland',  struct('name', 'Poland',  'simpaths_code', 'PL'), ...
        'Sweden',  struct('name', 'Sweden',  'simpaths_code', 'SE'), ...
        'Spain',   struct('name', 'Spain',   'simpaths_code', 'ES'), ...
        'UK',      struct('name', 'UK',      'simpaths_code', 'UK'));

    if ~isfield(supported, country)
        valid_countries = fieldnames(supported);
        error('Unsupported country ''%s''. Valid options: %s.', ...
            country, strjoin(valid_countries', ', '));
    end

    config = supported.(country);
end