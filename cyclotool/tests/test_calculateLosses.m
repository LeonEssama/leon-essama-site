function test_calculateLosses()
%TEST_CALCULATELOSSES  Regression test for PV_Besch against the
%reference Excel loss sheet (12-pulse, HUEL 412323 thyristor).
%
%   Confirms Loss.PV_Besch divides DimResult.Uv0N by N_series =
%   PulseNumber/6 (the number of secondary transformer windings, 1/2/3
%   for 6/12/18-pulse) before use, consistent with N_SerieN already
%   used for the thyristor voltage-class check in calculate.m /
%   cyclo_dimensioning.m. DimResult.Uv0N here is 3420 V (the full
%   dimensioning-stage value for this 12-pulse case); the reference
%   sheet's own PV(Besch) = 24939 W corresponds to the per-winding
%   value 3420/2 = 1710 V used inside the "Einzelbeschaltung" formula.
%   Before this fix, PV_Besch used the undivided Uv0N and came out
%   N_series^2 = 4x too high (99754 W), matching a real discrepancy
%   report against this exact sheet.

TOL = 1e-3;   % 0.1% relative
fprintf('--- calculateLosses regression test (PV_Besch, 12-pulse) ---\n');

Input = struct();
Input.eta_M       = 0.965;
Input.PulseNumber = 12;
Input.fL          = 50;
Input.CB          = 1.5e-6;
Input.IM          = 2692;
Input.n_nom       = 10;
Input.TrafoP0_kW  = 5.5;
Input.TrafoPk_kW  = 100;

DimResult = struct();
DimResult.PVS  = 456;
DimResult.Uv0N = 3420;      % full dimensioning-stage value (2 x 1710 V)
DimResult.Psh  = 703400;

Thy = struct();
Thy.UT0 = 1.02;
Thy.rT  = 2.9e-4;

Speed  = 10;
uLcase = 0.95;
Psh    = 703400;

Loss = calculateLosses(Input, DimResult, Thy, Speed, uLcase, Psh);

check('PV_Besch [W]', Loss.PV_Besch, 24938.55, TOL*24938.55);

%% ===== Per-case Psh: PmachineNominal must use the passed Psh arg,
% not DimResult.Psh (a real bug this test would have missed if both
% were left equal, since runLosses() passes a per-operating-point Psh
% that differs from the fixed dimensioning-time DimResult.Psh) =======
etaM = Input.eta_M;
DimResultOtherPsh = DimResult;
DimResultOtherPsh.Psh = 999999;   % deliberately wrong, must be ignored

Loss2 = calculateLosses(Input, DimResultOtherPsh, Thy, Speed, uLcase, Psh);

PmachineNominalExpected = Psh * (1/etaM - 1);
% Speed(10) >= n_nom(10) and uLcase(0.95)<1 -> field-weakening branches
MachineExpected = PmachineNominalExpected*0.30/uLcase ...
    + PmachineNominalExpected*0.50*uLcase^2 ...
    + PmachineNominalExpected*0.20*(Speed/Input.n_nom)^2;

check('Machine (uses Psh, not DimResult.Psh) [W]', ...
    Loss2.Machine, MachineExpected, TOL*MachineExpected);
check('PV_Besch unaffected by DimResult.Psh [W]', ...
    Loss2.PV_Besch, Loss.PV_Besch, TOL*Loss.PV_Besch);

fprintf('All calculateLosses tests passed.\n');

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
