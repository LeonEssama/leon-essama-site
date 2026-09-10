function test_estimate_ls_from_equivalent_circuit()
%TEST_ESTIMATE_LS_FROM_EQUIVALENT_CIRCUIT  Regression test against the
%Atalaya SAG mill ring-motor datasheet (DSHT-112001 Rev.2, WAZ 1440/120/72).
%
%   Zbase and f_motor are checked against the datasheet's OWN computed
%   cells (xn = 1,115 Ohm/ph, fn = 5,89 Hz), not re-derived independently.
%   Xd' and Ls are hand-derived from the datasheet's d-axis equivalent-
%   circuit reactances and checked to that precision.

TOL = 1e-4;
fprintf('--- estimate_ls_from_equivalent_circuit regression test ---\n');

UM = 5200;          % V, rated line-to-line (datasheet Un)
IM = 2692.5;         % A, rated phase current (datasheet In)
n_nom = 9.81;        % rpm, rated speed (datasheet N)
PolePairs = 36;      % 2p = 72 (datasheet)

%% ===== Case 1: "with saturation" equivalent circuit =====================
xaDelta = 0.1449;
xad     = 0.3798;
xfc     = 0.0199;

[Ls1, info1] = estimate_ls_from_equivalent_circuit( ...
    UM, IM, n_nom, PolePairs, xaDelta, xad, xfc);

% Datasheet's own computed cells (sheet 5): xn = 1,115 Ohm/ph, fn = 5,89 Hz
check('Case 1 Zbase  [Ohm]', info1.Zbase_ohm, 1.115, 1e-3);
check('Case 1 f_motor [Hz]', info1.f_motor_Hz, 5.89, 1e-2);

% Hand-derived: Xd' = xaDelta + xad*xfc/(xad+xfc)
Xd_expected = xaDelta + xad*xfc/(xad+xfc);
check('Case 1 Xd''    [pu]', info1.Xd_pu, Xd_expected, TOL);

Ls_expected = Xd_expected * info1.Zbase_ohm / (2*pi*info1.f_motor_Hz);
check('Case 1 Ls      [H] ', Ls1, Ls_expected, TOL*Ls_expected);

fprintf('  PASS  case 1 (with saturation): Zbase, f_motor, Xd'', Ls\n');

%% ===== Case 2: "without saturation" equivalent circuit ==================
xaDelta2 = 0.1449;
xad2     = 0.7527;
xfc2     = 0.0221;

[Ls2, info2] = estimate_ls_from_equivalent_circuit( ...
    UM, IM, n_nom, PolePairs, xaDelta2, xad2, xfc2);

check('Case 2 Zbase  [Ohm]', info2.Zbase_ohm, 1.115, 1e-3);
check('Case 2 f_motor [Hz]', info2.f_motor_Hz, 5.89, 1e-2);

Xd_expected2 = xaDelta2 + xad2*xfc2/(xad2+xfc2);
check('Case 2 Xd''    [pu]', info2.Xd_pu, Xd_expected2, TOL);

Ls_expected2 = Xd_expected2 * info2.Zbase_ohm / (2*pi*info2.f_motor_Hz);
check('Case 2 Ls      [H] ', Ls2, Ls_expected2, TOL*Ls_expected2);

% Saturated main-field reactance is lower -> saturated Xd' and Ls are lower.
assert(Ls1 < Ls2, ...
    'Case 2: saturated Ls should be lower than unsaturated Ls.');

fprintf('  PASS  case 2 (without saturation): Zbase, f_motor, Xd'', Ls\n');

%% ===== Error guards ======================================================
try
    estimate_ls_from_equivalent_circuit(UM, IM, 0, PolePairs, xaDelta, xad, xfc);
    assert(false, 'Expected ZeroMotorFrequency error was not thrown.');
catch ME
    assert(strcmp(ME.identifier, ...
        'estimate_ls_from_equivalent_circuit:ZeroMotorFrequency'), ...
        'Unexpected error identifier: %s', ME.identifier);
end
fprintf('  PASS  zero motor frequency raises the expected error\n');

fprintf('All estimate_ls_from_equivalent_circuit tests passed.\n');

end

%% ==========================================================
function check(label, actual, expected, tol)
if abs(actual - expected) > tol
    error('CycloTool:TestFailed', ...
        '%s mismatch: got %.6g, expected %.6g (tol %.2g)', ...
        label, actual, expected, tol);
end
fprintf('  OK    %s: %.6g (expected %.6g)\n', label, actual, expected);
end
