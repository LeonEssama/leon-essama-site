function test_derive_cyclo_operating_point_voltage_current()
%TEST_DERIVE_CYCLO_OPERATING_POINT_VOLTAGE_CURRENT  Regression test for
%derive_cyclo_operating_point_voltage_current, confirming it reproduces
%the same UM_op/IM_op field-weakening formula already used by
%CycloGUI_v2_0/generateNetzMatrix for the Netzbelastung operating
%matrix (below base speed: constant V/Hz, independent of voltage case;
%at/above base speed: field weakening, voltage held at UM*u_L or UM,
%current scaled by 1/uL_op on the uLmin case at any speed).
%
%   This is the one genuinely new formula behind
%   run_cyclo_operating_point_sweep.m (the rest of that pipeline is
%   run_detailed_cyclo_simulation.m, already exercised elsewhere) --
%   expected values below are hand-computed from generateNetzMatrix's
%   own formula, not from running the detailed simulation.

TOL = 1e-9;
fprintf('--- derive_cyclo_operating_point_voltage_current regression test ---\n');

Input = struct();
Input.UM    = 6000;   % V
Input.IM    = 2692;   % A
Input.u_L   = 0.90;   % pu (uL,min)
Input.n_nom = 10;      % rpm

%% ===== Below base speed: constant V/Hz, independent of voltage case =====
[UM_op, IM_op, uL_op, fw] = ...
    derive_cyclo_operating_point_voltage_current(Input, 3, 1);   % uLmin
check('Below-base uLmin: UM_op [V]', UM_op, 1800.0, TOL*1800);
check('Below-base uLmin: IM_op [A]', IM_op, 2991.1111111111113, TOL*2991.11);
check('Below-base uLmin: uL_op [pu]', uL_op, 0.9, TOL);
check('Below-base uLmin: FieldWeakening', fw, false, 0);

[UM_op, IM_op, ~, fw] = ...
    derive_cyclo_operating_point_voltage_current(Input, 3, 2);   % uL=1
check('Below-base uL=1: UM_op [V] (same as uLmin case)', UM_op, 1800.0, TOL*1800);
check('Below-base uL=1: IM_op [A] (unscaled)', IM_op, 2692.0, TOL*2692);
check('Below-base uL=1: FieldWeakening', fw, false, 0);

%% ===== At base speed: field weakening begins (Speed >= n_nom) =====
[UM_op, IM_op, ~, fw] = ...
    derive_cyclo_operating_point_voltage_current(Input, 10, 1);   % uLmin
check('Base-speed uLmin: UM_op [V] (=UM*u_L)', UM_op, 5400.0, TOL*5400);
check('Base-speed uLmin: IM_op [A] (=IM/u_L)', IM_op, 2991.1111111111113, TOL*2991.11);
check('Base-speed uLmin: FieldWeakening', fw, true, 0);

[UM_op, IM_op, ~, fw] = ...
    derive_cyclo_operating_point_voltage_current(Input, 10, 2);   % uL=1
check('Base-speed uL=1: UM_op [V] (=UM, unchanged)', UM_op, 6000, TOL*6000);
check('Base-speed uL=1: IM_op [A] (unscaled)', IM_op, 2692.0, TOL*2692);
check('Base-speed uL=1: FieldWeakening', fw, true, 0);

%% ===== Above base speed: field weakening (voltage held, not rising further) =====
[UM_op, IM_op, uL_op, fw] = ...
    derive_cyclo_operating_point_voltage_current(Input, 12, 3);   % uLmax
check('Above-base uLmax: UM_op [V] (=UM, current-case only affects iM)', UM_op, 6000, TOL*6000);
check('Above-base uLmax: IM_op [A] (unscaled)', IM_op, 2692.0, TOL*2692);
check('Above-base uLmax: uL_op [pu] (=2-u_L)', uL_op, 1.1, TOL);
check('Above-base uLmax: FieldWeakening', fw, true, 0);

[UM_op, IM_op, ~, fw] = ...
    derive_cyclo_operating_point_voltage_current(Input, 12, 1);   % uLmin
check('Above-base uLmin: UM_op [V] (=UM*u_L)', UM_op, 5400.0, TOL*5400);
check('Above-base uLmin: IM_op [A] (=IM/u_L)', IM_op, 2991.1111111111113, TOL*2991.11);
check('Above-base uLmin: FieldWeakening', fw, true, 0);

fprintf('All derive_cyclo_operating_point_voltage_current tests passed.\n');

end

%% ==========================================================
function check(label, actual, expected, tol)
if islogical(actual) || islogical(expected)
    if logical(actual) ~= logical(expected)
        error('CycloTool:TestFailed', '%s mismatch: got %d, expected %d', ...
            label, actual, expected);
    end
elseif abs(actual - expected) > tol
    error('CycloTool:TestFailed', ...
        '%s mismatch: got %.6g, expected %.6g (tol %.3g)', ...
        label, actual, expected, tol);
end
fprintf('  OK    %s\n', label);
end
