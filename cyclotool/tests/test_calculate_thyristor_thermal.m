function test_calculate_thyristor_thermal()
%TEST_CALCULATE_THYRISTOR_THERMAL  Regression/consistency test for the
%thyristor voltage/di-dt/PVS/Tj solve extracted from calculate.m, using
%the HUEL 412323 thyristor's real datasheet coefficients
%(ThyristorDatabase.m) -- the same device as the reference loss Excel
%sheet (UT0=1.02, rT=2.90e-4 match exactly).
%
%   Confirms:
%     - Uv and didtv scale exactly linearly with uL_used (both are
%       uL_used times a fixed factor in the formula) -- the entire
%       basis for computing a per-operating-point PVSch in runLosses()
%       instead of reusing one fixed dimensioning-point value.
%     - PVS and Tj increase monotonically with uL_used (higher
%       thyristor voltage/di-dt -> higher switching loss -> higher
%       junction temperature), the expected physical direction.
%     - Air-cooling Tj converged value satisfies Tj = Tamb + PLTh*Rthtot
%       exactly (closed-form check of the converged iteration).

TOL = 1e-3;   % 0.1% relative
fprintf('--- calculate_thyristor_thermal regression test ---\n');

Thy = struct();
Thy.Rth_jc = 5.7; Thy.Rth_ch = 1.0; Thy.Rth_ha = 6.8;
Thy.UT0 = 1.02; Thy.rT = 2.90e-4;
Thy.a = 621.0; Thy.b = 498.0; Thy.c = 6.05; Thy.d = 1113.0;
Thy.e = 0.003; Thy.f = 0.000049; Thy.g = 0.006; Thy.h = 0.048;
Thy.i = -0.927; Thy.j = 1.927; Thy.k = 0.10; Thy.l = 0.95;
Thy.Uv0_b = 3200; Thy.PL_ThS_b = 1119; Thy.di_dt_b = 12;
Thy.f_b = 60; Thy.Tj_b = 95;

I1S_used = 2692; dxN = 0.095; Uv0N = 3420; N_series = 2;
fL = 50; IM = 2692; Tamb = 40;

[Uv1, didtv1, Tj1, PVS1, PLTh1] = calculate_thyristor_thermal( ...
    1.0, I1S_used, dxN, Uv0N, N_series, fL, IM, IM, ...
    'rms', 12, 'Air', 0, 0, 0, Tamb, Thy);

[Uv2, didtv2, Tj2, PVS2, PLTh2] = calculate_thyristor_thermal( ...
    1.1, I1S_used, dxN, Uv0N, N_series, fL, IM, IM, ...
    'rms', 12, 'Air', 0, 0, 0, Tamb, Thy);

check('Uv (uL=1.0) [V]', Uv1, 2418.3052, TOL*2418.3052);
check('didtv (uL=1.0) [A/us]', didtv1, 5.451512, TOL*5.451512);
check('Tj (uL=1.0) [C]', Tj1, 56.2815, TOL*56.2815);
check('PVS (uL=1.0) [W]', PVS1, 443.7490, TOL*443.7490);

check('Uv (uL=1.1) [V]', Uv2, 2660.1357, TOL*2660.1357);
check('didtv (uL=1.1) [A/us]', didtv2, 5.996663, TOL*5.996663);
check('Tj (uL=1.1) [C]', Tj2, 57.4642, TOL*57.4642);
check('PVS (uL=1.1) [W]', PVS2, 531.3617, TOL*531.3617);

% Linear scaling in uL_used
check('Uv2/Uv1 == 1.1', Uv2/Uv1, 1.1, TOL);
check('didtv2/didtv1 == 1.1', didtv2/didtv1, 1.1, TOL);

% Monotonic increase with uL_used -- the physical basis for this fix
assert(PVS2 > PVS1, 'PVS should increase with uL_used.');
assert(Tj2 > Tj1, 'Tj should increase with uL_used.');
fprintf('  OK    PVS and Tj both increase with uL_used, as expected\n');

% Closed-form check of the converged air-cooling iteration
Rthtot = (Thy.Rth_jc + Thy.Rth_ch + Thy.Rth_ha)/1000;
check('Tj1 == Tamb + PLTh1*Rthtot', Tj1, Tamb + PLTh1*Rthtot, TOL*Tj1);

fprintf('All calculate_thyristor_thermal tests passed.\n');

end

%% ==========================================================
function check(label, actual, expected, tol)
if abs(actual - expected) > tol
    error('CycloTool:TestFailed', ...
        '%s mismatch: got %.6g, expected %.6g (tol %.3g)', ...
        label, actual, expected, tol);
end
fprintf('  OK    %s: %.6g (expected %.6g)\n', label, actual, expected);
end
