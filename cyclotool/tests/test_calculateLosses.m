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
Input.k_res       = 1.1;
Input.Cooling     = 'Water';

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
PshNom = 703400;   % Speed == n_nom here, so PshNom == Psh for this case

Loss = calculateLosses(Input, DimResult, Thy, Speed, uLcase, Psh, PshNom);

check('PV_Besch [W]', Loss.PV_Besch, 24938.55, TOL*24938.55);

%% ===== Air/Water cooling split (VBA Verlustrechnung, minus the PV_3GL
% and PV_Si terms this tool has no inputs for) =============================
PV_Th_expected = 71300.58136268196;
check('PV_Th [W]', Loss.PV_Th, PV_Th_expected, TOL*PV_Th_expected);

% Water-cooled: PV_Luft = k_res*PV_Zus (=0 here); PV_Wasser = k_res*(PV_Th+PV_Besch)
check('PV_Luft (Water-cooled) [W]', Loss.PV_Luft, 0, 1e-6);
check('PV_Wasser (Water-cooled) [W]', Loss.PV_Wasser, 105863.0445, ...
    TOL*105863.0445);
check('PV_TotRes (Water-cooled) [W]', Loss.PV_TotRes, 105863.0445, ...
    TOL*105863.0445);

% Air-cooled: PV_Luft = k_res*(PV_Th+PV_Besch+PV_Zus); PV_Wasser = 0
InputAir = Input;
InputAir.Cooling = 'Air';
LossAir = calculateLosses(InputAir, DimResult, Thy, Speed, uLcase, Psh, PshNom);
check('PV_Luft (Air-cooled) [W]', LossAir.PV_Luft, 105863.0445, ...
    TOL*105863.0445);
check('PV_Wasser (Air-cooled) [W]', LossAir.PV_Wasser, 0, 1e-6);
check('PV_TotRes (Air-cooled) [W]', LossAir.PV_TotRes, 105863.0445, ...
    TOL*105863.0445);

%% ===== Per-case Psh: PmachineNominal must use the passed Psh arg,
% not DimResult.Psh (a real bug this test would have missed if both
% were left equal, since runLosses() passes a per-operating-point Psh
% that differs from the fixed dimensioning-time DimResult.Psh) =======
etaM = Input.eta_M;
DimResultOtherPsh = DimResult;
DimResultOtherPsh.Psh = 999999;   % deliberately wrong, must be ignored

Loss2 = calculateLosses(Input, DimResultOtherPsh, Thy, Speed, uLcase, Psh, PshNom);

PmachineNominalExpected = Psh * (1/etaM - 1);
PmachineNominalRatedExpected = PshNom * (1/etaM - 1);
% Speed(10) >= n_nom(10) and uLcase(0.95)<1 -> field-weakening branches
MachineExpected = PmachineNominalRatedExpected*0.30/uLcase ...
    + PmachineNominalExpected*0.50*uLcase^2 ...
    + PmachineNominalExpected*0.20*(Speed/Input.n_nom)^2;

check('Machine (uses Psh, not DimResult.Psh) [W]', ...
    Loss2.Machine, MachineExpected, TOL*MachineExpected);
check('PV_Besch unaffected by DimResult.Psh [W]', ...
    Loss2.PV_Besch, Loss.PV_Besch, TOL*Loss.PV_Besch);

%% ===== Current-dependent machine loss must use the FIXED nominal Psh
% (PshNom), not this row's own (possibly speed-reduced) Psh --
% constant-torque/constant-current assumption below base speed. Per
% user report: MachineCurrent must equal its BaseSpeed/uL=1 value at
% every point except where field weakening (Speed>=n_nom & uLcase<1)
% explicitly scales it by 1/uLcase; below base speed it must NOT scale
% down with the reduced shaft power actually delivered at that speed.
SpeedLow  = 3;                                  % below Input.n_nom (10)
PshRowLow = 703400 * SpeedLow / Input.n_nom;    % this row's own (reduced) Psh
uLcaseLow = 1.0;                                % irrelevant below base speed

Loss3 = calculateLosses(Input, DimResult, Thy, SpeedLow, uLcaseLow, PshRowLow, PshNom);

MachineCurrentExpected = 0.30 * PmachineNominalRatedExpected;
check('MachineCurrent (below base speed, uses fixed PshNom) [W]', ...
    Loss3.MachineCurrent, MachineCurrentExpected, TOL*MachineCurrentExpected);

% Voltage/friction-windage are unaffected by this fix -- still scale
% from this row's own (reduced) Psh, per the existing speed-ratio model.
PmachineNominalRow = PshRowLow * (1/etaM - 1);
speedRatioLow = SpeedLow / Input.n_nom;
MachineVoltageExpected = 0.50 * PmachineNominalRow * speedRatioLow;
MachineFWExpected = 0.20 * PmachineNominalRow * speedRatioLow^2;
check('MachineVoltage (below base speed, uses row Psh) [W]', ...
    Loss3.MachineVoltage, MachineVoltageExpected, TOL*MachineVoltageExpected);
check('MachineFW (below base speed, uses row Psh) [W]', ...
    Loss3.MachineFW, MachineFWExpected, TOL*MachineFWExpected);

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
