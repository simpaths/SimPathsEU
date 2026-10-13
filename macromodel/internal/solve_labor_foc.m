function l = solve_labor_foc(c, K, A, WAP, h, alpha, sigma, phi, psi)
% SOLVE_LABOR_FOC  Closed-form solution of the intratemporal participation FOC.
%
% Preferences:  sum beta^t WAP_t [ u(c) - psi * l^(1+phi)/(1+phi) ]
%
% The choice variable is PARTICIPATION, so the margin is priced at what a
% participant earns over the period - per-participant earnings w*h - not at the
% hourly wage w. Hours per participant are exogenous here (the h trend), so they
% scale the return to participating:
%
%   FOC:  psi * l^phi = w * h * c^{-sigma}
%
% With Cobb-Douglas:  w = (1-alpha) * A * K^alpha * (l*WAP*h)^{-alpha}
%
% Substituting and collecting l terms:
%   psi * l^{phi+alpha} = (1-alpha) * A * K^alpha * WAP^{-alpha} * h^{1-alpha} * c^{-sigma}
%
% Therefore:
%   l = [ (1-alpha) * A * K^alpha * WAP^{-alpha} * h^{1-alpha} * c^{-sigma} / psi ]^{1/(phi+alpha)}
%
% Hours therefore enter with exponent (1-alpha)/(phi+alpha) > 0: a falling hours
% trend lowers participation, because each participant earns less per period.
% Pricing the margin at the hourly wage instead would give exponent
% -alpha/(phi+alpha) < 0 and reverse that sign - which is what this function did
% before 2026-08. In sample the error was invisible because psi_t is backed out
% residually from the same expression; it only bit on the forward projection.
%
% Mirrored in RamseyTrendModel.solveLaborFOC - the two must move together.
%
% Clamped to [0.01, 0.99] to prevent numerical escape.

    rhs = (1 - alpha) * A * K^alpha * WAP^(-alpha) * h^(1 - alpha) * c^(-sigma) / psi;
    l = rhs^(1 / (phi + alpha));

    % Clamp to valid participation range
    l = max(0.01, min(0.99, l));
end
