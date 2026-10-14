function test_labor_foc()
% TEST_LABOR_FOC  Guards the intratemporal participation FOC.
%
% Preferences are  sum beta^t WAP_t [ u(c) - psi*l^(1+phi)/(1+phi) ].
% The extensive margin is participation, so the wage that clears it is what a
% participant EARNS - per-participant earnings w*h - not the hourly wage w:
%
%   psi * l^phi = w * h * c^(-sigma),   w = (1-alpha) A K^alpha (l WAP h)^(-alpha)
%   => psi * l^(phi+alpha) = (1-alpha) A K^alpha WAP^(-alpha) h^(1-alpha) c^(-sigma)
%   => l ~ h^((1-alpha)/(phi+alpha))            [POSITIVE exponent]
%
% Pricing the margin at the hourly wage instead gives l ~ h^(-alpha/(phi+alpha)),
% a NEGATIVE exponent: a falling hours trend would then RAISE participation.
% Poland's hours trend is about -0.21%/yr, so that sign matters out of sample.
%
% Usage:
%   >> test_labor_foc

    fprintf('\n');
    fprintf('=================================================================\n');
    fprintf('  INTRATEMPORAL LABOR FOC TESTS\n');
    fprintf('=================================================================\n\n');

    n_pass = 0;
    n_fail = 0;

    % Representative Poland-like quarterly values. psi is chosen so the solution
    % sits in the interior (l ~ 0.7) rather than on a clamp, so the elasticity
    % checks below measure the FOC rather than the clamp.
    alpha = 0.33; sigma = 1.5; phi = 2.0;
    K = 1.37e6; A = 0.0345; WAP = 23430; h = 490; c = 4.0; psi = 1.615;

    %% ================================================================
    fprintf('TEST 1: lower hours per participant REDUCE participation\n');
    l_base = solve_labor_foc(c, K, A, WAP, h,        alpha, sigma, phi, psi);
    l_low  = solve_labor_foc(c, K, A, WAP, 0.95 * h, alpha, sigma, phi, psi);
    if l_low < l_base
        fprintf('  [PASS] h -5%%: l %.6f -> %.6f (falls, as the FOC requires)\n', l_base, l_low);
        n_pass = n_pass + 1;
    else
        fprintf(['  [FAIL] h -5%%: l %.6f -> %.6f (rises or flat). The FOC is ' ...
                 'pricing the margin at the hourly wage, not w*h.\n'], l_base, l_low);
        n_fail = n_fail + 1;
    end

    %% ================================================================
    fprintf('\nTEST 2: implied h-elasticity equals (1-alpha)/(phi+alpha)\n');
    expected = (1 - alpha) / (phi + alpha);
    actual = log(l_low / l_base) / log(0.95);
    if abs(actual - expected) < 1e-8
        fprintf('  [PASS] elasticity %.6f (expected %.6f)\n', actual, expected);
        n_pass = n_pass + 1;
    else
        fprintf('  [FAIL] elasticity %.6f, expected %.6f\n', actual, expected);
        n_fail = n_fail + 1;
    end

    %% ================================================================
    fprintf('\nTEST 3: the solution satisfies psi*l^phi = w*h*c^(-sigma)\n');
    l = solve_labor_foc(c, K, A, WAP, h, alpha, sigma, phi, psi);
    w = (1 - alpha) * A * K^alpha * (l * WAP * h)^(-alpha);
    lhs = psi * l^phi;
    rhs = w * h * c^(-sigma);
    if abs(lhs / rhs - 1) < 1e-10
        fprintf('  [PASS] psi*l^phi = %.6e, w*h*c^-sigma = %.6e (ratio %.12f)\n', ...
                lhs, rhs, lhs / rhs);
        n_pass = n_pass + 1;
    else
        fprintf('  [FAIL] psi*l^phi = %.6e, w*h*c^-sigma = %.6e (ratio %.12f)\n', ...
                lhs, rhs, lhs / rhs);
        n_fail = n_fail + 1;
    end

    %% ================================================================
    % CONTRACT: solve_labor_foc and backout_labor_psi are exact inverses.
    % The forward FOC (used by the projection) and the inverse (used for the
    % base-year seed and the in-sample psi wedge) were separate expressions until
    % 2026-08 and silently disagreed by a factor of h for three months. This
    % round-trip binds them: any future edit to one that is not mirrored in the
    % other fails here immediately, without needing a full pipeline run.
    fprintf('\nTEST 3b: FOC and psi-backout round-trip to the same psi\n');
    round_trip_ok = true;
    for psi_in = [1e-2, 1.615, 25.0]
        l_rt = solve_labor_foc(c, K, A, WAP, h, alpha, sigma, phi, psi_in);
        if l_rt <= 0.011 || l_rt >= 0.989
            continue;  % clamped: not an interior solution, round-trip undefined
        end
        w_rt = (1 - alpha) * A * K^alpha * (l_rt * WAP * h)^(-alpha);
        psi_out = backout_labor_psi(w_rt, h, c, l_rt, sigma, phi);
        rel = abs(psi_out / psi_in - 1);
        if rel < 1e-12
            fprintf('  [PASS] psi %.4g -> l %.6f -> psi %.4g (rel %.1e)\n', ...
                    psi_in, l_rt, psi_out, rel);
            n_pass = n_pass + 1;
        else
            fprintf('  [FAIL] psi %.4g -> l %.6f -> psi %.4g (rel %.1e)\n', ...
                    psi_in, l_rt, psi_out, rel);
            n_fail = n_fail + 1;
            round_trip_ok = false;
        end
    end
    if ~round_trip_ok
        fprintf(['         solve_labor_foc.m and backout_labor_psi.m have ' ...
                 'diverged - they must express the same FOC.\n']);
    end

    %% ================================================================
    fprintf('\nTEST 4: participation is clamped to [0.01, 0.99]\n');
    l_hi = solve_labor_foc(c, K, A, WAP, h, alpha, sigma, phi, 1e-30);
    l_lo = solve_labor_foc(c, K, A, WAP, h, alpha, sigma, phi, 1e30);
    if abs(l_hi - 0.99) < 1e-12 && abs(l_lo - 0.01) < 1e-12
        fprintf('  [PASS] clamps at %.2f and %.2f\n', l_lo, l_hi);
        n_pass = n_pass + 1;
    else
        fprintf('  [FAIL] clamps gave %.6f and %.6f\n', l_lo, l_hi);
        n_fail = n_fail + 1;
    end

    %% ================================================================
    % CONTRACT: MATLAB and Java must solve the same FOC. The two implementations
    % exist by architecture (MATLAB detrends and projects, Java projects inside
    % SimPaths) and nothing structural keeps them in step. Both sides assert
    % against this shared fixture, so drift on either side fails without needing a
    % full pipeline run. Java side: RamseyTrendModelTest.
    fprintf('\nTEST 5: solver reproduces the MATLAB<->Java parity fixture\n');
    parity_file = fullfile(fileparts(mfilename('fullpath')), 'fixtures', 'foc_parity_cases.csv');
    if ~exist(parity_file, 'file')
        fprintf('  [FAIL] %s missing - run generate_foc_parity_cases\n', parity_file);
        n_fail = n_fail + 1;
    else
        cases = readtable(parity_file);
        worst = 0;
        for i = 1:height(cases)
            got = solve_labor_foc(cases.c(i), cases.K(i), cases.A(i), cases.WAP(i), ...
                                  cases.h(i), cases.alpha(i), cases.sigma(i), ...
                                  cases.phi(i), cases.psi(i));
            worst = max(worst, abs(got / cases.expected_l(i) - 1));
        end
        if worst < 1e-12
            fprintf('  [PASS] %d cases reproduced (worst rel dev %.1e)\n', ...
                    height(cases), worst);
            n_pass = n_pass + 1;
        else
            fprintf(['  [FAIL] worst rel dev %.1e across %d cases. Either the FOC ' ...
                     'changed (regenerate the fixture AND re-run the Java suite) ' ...
                     'or it regressed.\n'], worst, height(cases));
            n_fail = n_fail + 1;
        end
    end

    %% ================================================================
    fprintf('\n-----------------------------------------------------------------\n');
    fprintf('  %d passed, %d failed\n', n_pass, n_fail);
    fprintf('-----------------------------------------------------------------\n\n');

    if n_fail > 0
        error('test_labor_foc: %d check(s) failed', n_fail);
    end
end
