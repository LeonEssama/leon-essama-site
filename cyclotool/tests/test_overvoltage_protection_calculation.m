function test_overvoltage_protection_calculation()
%TEST_OVERVOLTAGE_PROTECTION_CALCULATION  Regression test for
%overvoltage_protection_calculation against the reference workbook's own
%example (user-supplied "Atalaya_Kurzschliesser.xlsx", sheet "SAG Mill",
%project "Atalaya SAG Mill 23'000 kW").
%
%   Confirms the gaps found in the original implementation are now
%   covered:
%     1. Rotor BOD-window VDRM is calculated (workbook I18, 2*sqrt(2)*
%        1.32*Uv0_Rotor), not the stator's VDRM.
%     2. The "Dauergrenzstrom des Cyclo-Thyristors" continuous-current
%        check for the main/cyclo converter thyristor (workbook rows
%        37-47) is implemented, matched against OV_ThyristorDatabase by
%        Input.Thy.UDRM (the Dimensioning-selected thyristor), not an
%        independent selection.
%     3. uL,max is derived (2 - Input.u_L), the same relationship used
%        elsewhere in the tool, not an independent input.
%     4. Stator VDRM is Input.Thy.UDRM (the Dimensioning-selected
%        thyristor's own voltage class), not an independent input.
%
%   Input.Thy.UDRM = 6500 V here because this is the same Atalaya SAG
%   Mill project as tests/test_calculateLosses.m, whose Thy.UT0=1.02 /
%   Thy.rT=2.9e-4 match ThyristorDatabase.m's HUEL 412323 (UDRM=6500)
%   exactly -- confirming the Dauergrenzstrom check below must use the
%   workbook's "E" column (VDRM=6500), not "D" (VDRM=5200) as an earlier,
%   disconnected "Protection Thyristor" dropdown selection had assumed.
%
%   Crowbar-thyristor thermal check (Rth_jc_05s/DeltaTheta/VT0_OV/rT_OV)
%   uses the workbook's "D" column (deltaTheta=85 K) -- an independent,
%   separate device (the crowbar/Kurzschliesser thyristor itself, not the
%   main converter thyristor) with no pass/fail formula in the workbook,
%   so this test only verifies the ITh_zul VALUE against D12.
%
%   The stator BOD check FAILS in this example (selected BOD 2600 V is
%   below the workbook's own required window [4341.3, 5366.7] V) -- this
%   is the reference workbook's own data, not a tool defect, and is
%   asserted here as such.

TOL = 1e-3;   % 0.1% relative
fprintf('--- overvoltage_protection_calculation regression test (reference workbook example) ---\n');

Input = struct();
Input.Rth_jc_05s = 0.018;
Input.DeltaTheta = 85;      % workbook D7 ("D" column)
Input.VT0_OV     = 1.1;
Input.rT_OV      = 0.00057;
Input.IMmax_OV   = 4038;    % workbook D10

Input.Thy = struct('UDRM', 6500);   % Dimensioning-selected thyristor (see header)

Input.Uv0_stator = 1710;    % workbook D16
Input.deltaUBOD  = 50;      % workbook D19 = I19
Input.BOD_Stator = 2600;    % workbook D24 (per-unit; workbook shows a single unstacked BOD)
Input.BOD_Stator_Count = 1;
Input.kStator    = 0.805;   % workbook D28
Input.TKS        = 0.5;     % workbook D29 = I29

Input.Uv0_Rotor = 690;      % workbook I16
Input.BOD_Rotor = 2000;     % workbook I24 (per-unit; workbook shows a single unstacked BOD)
Input.BOD_Rotor_Count = 1;
Input.kRotor    = 0.813;    % workbook I28
Input.IeDCmax   = 635;      % workbook I20

Input.startup  = 1.5;       % workbook D51 (Hochlauf)
Input.overload = 1;         % workbook D50 (Ueberlast)
Input.u_L      = 0.95;      % workbook D52 (uL,min) -- also feeds uLmax=2-u_L
Input.IM       = 2692;      % workbook D49 (IM1)
Input.PolePairs = 36;       % workbook I49
Input.nc_OV     = 0.3;      % workbook I50

O = overvoltage_protection_calculation(Input);

%% ===== uL,max and stator VDRM: now derived, not independent inputs =====
check('uLmax [pu] (=2-u_L)', O.uLmax, 1.05, 1e-9);
check('VDRM_Stator [V] (=Input.Thy.UDRM)', O.VDRM_Stator, 6500, 1e-9);

%% ===== Crowbar thyristor thermal limit (workbook C12/D12, D13) =====
check('ITh_zul [A]', O.ITh_zul, 2070.817631413717, TOL*2070.82);
check('IMmax_half [A]', O.IMmax_half, 2019, 1e-9);
check('Thermal_OK', O.Thermal_OK, true, 0);

%% ===== Stator BOD window (workbook D22/D23) -- FAILS in this example =====
check('UBoD_min [V]', O.UBoD_min, 4341.282562597109, TOL*4341.28);
check('UBoD_max [V]', O.UBoD_max, 5366.666666666667, TOL*5366.67);
check('BOD_OK (workbook data: selected BOD below required window)', O.BOD_OK, false, 0);
check('BOD_Stator_Unit [V]', O.BOD_Stator_Unit, 2600, 1e-9);
check('BOD_Stator_Count [-]', O.BOD_Stator_Count, 1, 1e-9);

%% ===== Stator resistor sizing (workbook D31/D32/D33) =====
check('RKS [Ohm]', O.RKS, 0.7998547955909542, TOL*0.8);
check('Ieff [A]', O.Ieff, 1876.7290115251058, TOL*1876.73);
check('EKS [kWs]', O.EKS, 1408.589, TOL*1408.589);

%% ===== BOD stacking (new feature): 2x2600V passes the window the
%% workbook's own single 2600V selection fails =====
Input2 = Input;
Input2.BOD_Stator_Count = 2;
O2 = overvoltage_protection_calculation(Input2);
check('UBoD_selected (2x2600V) [V]', O2.UBoD_selected, 5200, 1e-9);
check('BOD_OK (2x2600V, now within window)', O2.BOD_OK, true, 0);
check('RKS (2x2600V) [Ohm]', O2.RKS, 1.5997095911819084, TOL*1.6);
check('EKS (2x2600V) [kWs]', O2.EKS, 2817.178, TOL*2817.18);

%% ===== Rotor VDRM: calculated, NOT the stator's VDRM_OV -- gap #1 =====
% (workbook I18 = 2*sqrt(2)*1.32*Uv0_Rotor, independent of D18=6500)
check('VDRM_Rotor_calc [V]', O.VDRM_Rotor_calc, 2576.1314252188304, TOL*2576.13);
check('UBoD_min_Rotor [V]', O.UBoD_min_Rotor, 1781.5701568374297, TOL*1781.57);
check('UBoD_max_Rotor [V]', O.UBoD_max_Rotor, 2096.776187682359, TOL*2096.78);
check('BOD_OK_Rotor', O.BOD_OK_Rotor, true, 0);

%% ===== Rotor resistor sizing (workbook I31/I32/I33) =====
check('RKS_Rotor [Ohm]', O.RKS_Rotor, 3.8740544885763817, TOL*3.874);
check('Ieff_Rotor [A]', O.Ieff_Rotor, 298.05996322049026, TOL*298.06);
check('EKS_Rotor [kWs]', O.EKS_Rotor, 172.08499999999998, TOL*172.085);

%% ===== Protective settings / Schutzblock (workbook D54-D59, G51/G54/G55) =====
check('IGA [A]', O.IGA, 5710.594364862559, TOL*5710.59);
check('IGB [A]', O.IGB, 4007.4346420088127, TOL*4007.43);
check('IGmax [A]', O.IGmax, 5710.594364862559, TOL*5710.59);
check('I115 [A]', O.I115, 6567.183519591942, TOL*6567.18);
check('I135 [A]', O.I135, 7709.302392564455, TOL*7709.30);
check('ILimit [A]', O.ILimit, 4038, 1e-9);
check('fc [Hz]', O.fc, 0.18, 1e-9);
check('Tc2 [s]', O.Tc2, 2.7777777777777777, TOL*2.78);

%% ===== Dauergrenzstrom des Cyclo-Thyristors -- matched by Input.Thy.UDRM
%% =6500 to workbook's "E" column (E39:E47), NOT "D"/5200 =====
check('OVThyType (matched class)', O.OVThyType, '4in_6500V', 0);
check('ITh_zul_Cyclo [A]', O.ITh_zul_Cyclo, 5984.1914161849445, TOL*5984.19);
check('CycloThermalMargin [A]', O.CycloThermalMargin, 1946.1914161849445, TOL*1946.19);
check('CycloThermal_OK', O.CycloThermal_OK, true, 0);

%% ===== BOD count validation: non-integer / zero must error, not guess =====
InputBadCount = Input;
InputBadCount.BOD_Stator_Count = 0;
try
    overvoltage_protection_calculation(InputBadCount);
    error('CycloTool:TestFailed', 'BOD_Stator_Count=0 should have errored.');
catch ME
    if strcmp(ME.identifier, 'overvoltage_protection_calculation:InvalidBODStatorCount')
        fprintf('  OK    BOD_Stator_Count=0 correctly rejected\n');
    else
        rethrow(ME);
    end
end

fprintf('All overvoltage_protection_calculation tests passed.\n');

end

%% ==========================================================
function check(label, actual, expected, tol)
if ischar(actual) || isstring(actual)
    if ~strcmp(actual, expected)
        error('CycloTool:TestFailed', '%s mismatch: got ''%s'', expected ''%s''', ...
            label, char(actual), char(expected));
    end
elseif islogical(actual) || islogical(expected)
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
