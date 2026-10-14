function psi = backout_labor_psi(w, h, c, l, sigma, phi)
% BACKOUT_LABOR_PSI  Invert the intratemporal participation FOC for psi.
%
%   psi = BACKOUT_LABOR_PSI(w, h, c, l, sigma, phi)
%
% This is the exact inverse of solve_labor_foc: given observed participation l,
% recover the disutility weight that rationalises it.
%
%   FOC:      psi * l^phi = w * h * c^(-sigma)
%   inverse:  psi         = w * h * c^(-sigma) / l^phi
%
% w is the HOURLY wage (marginal product per effective labour unit); h converts it
% to what a participant earns over the period. See solve_labor_foc.m for why the
% margin is priced at w*h rather than w.
%
% There is one inverse in the MATLAB codebase and it is this function. It is used
% for the base-year psi seed (calibrate_growth_model) and for the in-sample psi
% wedge (ramsey_trend/solve_endo_psi_pass). Those two drifted apart from the
% forward FOC for three months in 2026 because each carried its own copy of this
% expression; test_labor_foc.m now round-trips solve_labor_foc against this
% function so any future divergence fails immediately.

    psi = w .* h .* c.^(-sigma) ./ l.^phi;
end
