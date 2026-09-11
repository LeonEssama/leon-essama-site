function O = overvoltage_protection_calculation(Input)
%OVERVOLTAGE_PROTECTION_CALCULATION  Crowbar / BOD / protection settings.
%
%   O = overvoltage_protection_calculation(Input)
%
%   Computes, for both stator and rotor sides:
%     - Crowbar/Kurzschliesser thyristor thermal current limit and
%       thermal margin check (0.5 s overload)
%     - Break-Over-Diode (BOD) min/max voltage window and margin check
%     - Crowbar resistor sizing, effective current and dissipated energy
%   Also computes protection current thresholds (I115/I135), the
%   protection current limit, the protection blocking frequency, and the
%   main/cyclo converter thyristor's continuous current rating
%   ("Dauergrenzstrom") check for the VDRM class of the thyristor
%   actually selected in Dimensioning.
%
%   Source: user-supplied reference workbook "Atalaya_Kurzschliesser.xlsx",
%   sheet "SAG Mill". No IEC/IEEE/NEMA/ANSI standard is cited on that
%   workbook for any formula below; every formula is the vendor/
%   reference-document's own.
%
%   Three quantities the GUI previously treated as independent manual
%   inputs are, per the workbook and per user-confirmed engineering
%   practice, NOT independent -- they must be derived from data that
%   already exists elsewhere in the tool:
%
%   1. uL,max is the SAME "uL,max" used throughout the rest of the tool
%      (e.g. the "ABB Operating Point Voltages" block in CycloGUI_v2_0.m:
%      uLmax = 1 + (1-uLmin)), not a separate manually entered value.
%      Computed here as uLmax = 2 - Input.u_L (Input.u_L is "uL,min").
%   2. The stator BOD window's VDRM (workbook D18) is the voltage class
%      (UDRM) of the thyristor actually selected for Dimensioning
%      (Input.Thy), not an independently chosen catalog part. Computed
%      here as Input.Thy.UDRM.
%   3. The "Dauergrenzstrom des Cyclo-Thyristors" continuous-current
%      check (workbook rows 37-47, 3 columns for VDRM=2800/5200/6500)
%      must use the SAME thyristor's data, not a separately, independently
%      selected "Protection Thyristor". OV_ThyristorDatabase.m (a small
%      database transcribed from this workbook's own C39:E45 table,
%      Rth_jc/Rth_ch/Rth_ha/VT0/rT/DeltaTheta per VDRM class -- kept as a
%      dedicated database rather than reading ThyristorDatabase.m
%      directly, since the two tables' values are not always identical
%      for the same VDRM class and ThyristorDatabase.m has no DeltaTheta
%      field for this check) is now looked up by matching
%      Input.Thy.UDRM, not by a free-standing dropdown selection.
%
%   Rotor BOD-window VDRM (workbook I18) remains a genuinely separate
%   calculated quantity: VDRM_Rotor = 2*sqrt(2)*1.32*Uv0_Rotor (not tied
%   to Input.Thy -- the rotor/field circuit's blocking-voltage
%   requirement comes from the DCS880 excitation voltage, not the main
%   converter thyristor).
%
%   Required Input fields include Thy (the struct selected in
%   Dimensioning; must have UDRM) -- see calculate.m / ThyristorDatabase.m.

if Input.Rth_jc_05s == 0
    error('overvoltage_protection_calculation:ZeroRth', ...
        'Input.Rth_jc_05s must be nonzero.');
end
if Input.rT_OV == 0
    error('overvoltage_protection_calculation:ZeroRT', ...
        'Input.rT_OV must be nonzero.');
end
if isempty(Input.Thy) || ~isfield(Input.Thy, 'UDRM')
    error('overvoltage_protection_calculation:NoThyristor', ...
        ['Input.Thy must be the Dimensioning-selected thyristor struct ', ...
         '(with a UDRM field) -- run Dimensioning first.']);
end

O = struct();

%% ====================================================
% Crowbar/Kurzschliesser thyristor thermal limit (0.5 s overload)
%% ====================================================
O.IMmax = Input.IMmax_OV;
O.ITh_zul = (-Input.VT0_OV + sqrt(Input.VT0_OV^2 + ...
    4 * Input.rT_OV * Input.DeltaTheta / Input.Rth_jc_05s)) / (2 * Input.rT_OV);
O.IMmax_half   = Input.IMmax_OV / 2;
O.Thermal_OK   = O.ITh_zul >= O.IMmax_half;
O.ThermalMargin = O.ITh_zul - O.IMmax_half;

%% ====================================================
% uL,max: same quantity used throughout the tool (uLmax = 2 - uL,min),
% not an independent manual input -- see function header.
%% ====================================================
O.uLmax = 2 - Input.u_L;

%% =====================================================
% Stator BOD limits, resistor and energy. VDRM is the Dimensioning-
% selected thyristor's own voltage class (Input.Thy.UDRM), not an
% independent manual/catalog choice -- see function header.
%% =====================================================
O.VDRM_Stator = Input.Thy.UDRM;

[O.UBoD_min, O.UBoD_max, O.UBoD_selected, O.BOD_OK, ...
    O.BOD_MarginLow, O.BOD_MarginHigh] = bodWindow( ...
    O.uLmax, Input.Uv0_stator, O.VDRM_Stator, ...
    Input.deltaUBOD, Input.BOD_Stator);

O.RKS  = O.UBoD_selected / (Input.kStator * Input.IMmax_OV);
O.Ieff = Input.kStator * Input.IMmax_OV / sqrt(3);
O.EKS  = (Input.kStator * Input.IMmax_OV)^2 * Input.TKS * O.RKS / 3000;

%% ====================================================
% Rotor BOD limits, resistor and energy
%% ====================================================
% Rotor VDRM is the calculated blocking-voltage requirement (workbook
% I18), independent of the main converter thyristor -- see function
% header.
O.VDRM_Rotor_calc = 2 * sqrt(2) * 1.32 * Input.Uv0_Rotor;

[O.UBoD_min_Rotor, O.UBoD_max_Rotor, O.UBoD_selected_Rotor, O.BOD_OK_Rotor] = ...
    bodWindow(O.uLmax, Input.Uv0_Rotor, O.VDRM_Rotor_calc, ...
    Input.deltaUBOD, Input.BOD_Rotor);

O.RKS_Rotor  = O.UBoD_selected_Rotor / (Input.kRotor * Input.IeDCmax);
O.Ieff_Rotor = Input.kRotor * Input.IeDCmax / sqrt(3);
O.EKS_Rotor  = (Input.kRotor * Input.IeDCmax)^2 * Input.TKS * O.RKS_Rotor / 3000;

%% ====================================================
% Protective settings
%% ====================================================
O.IGA = Input.startup * sqrt(2) * Input.IM;
O.IGB = Input.overload / Input.u_L * sqrt(2) * Input.IM;
O.IGmax = max(O.IGA, O.IGB);

%% ====================================================
% Protection margins
%% ====================================================
O.I115  = 1.15 * O.IGmax;
O.I135  = 1.35 * O.IGmax;
O.ILimit = Input.IM * Input.startup;

%% ====================================================
% Protection blocking frequency
%% ====================================================
O.fc  = Input.PolePairs * Input.nc_OV / 60;
O.Tc2 = 1 / (2 * O.fc);

%% ====================================================
% Dauergrenzstrom des Cyclo-Thyristors: continuous current rating for
% the Dimensioning-selected thyristor's VDRM class (Input.Thy.UDRM),
% checked against the protection current limit ILimit (=IM*startup).
%% ====================================================
OVDB = OV_ThyristorDatabase();
cycloIdx = find([OVDB.VDRM] == Input.Thy.UDRM, 1);
if isempty(cycloIdx)
    error('overvoltage_protection_calculation:NoOVThyristorMatch', ...
        ['Dimensioning thyristor UDRM = %g V has no matching entry in ', ...
         'OV_ThyristorDatabase (available: %s V). Add a workbook-sourced ', ...
         'entry for this VDRM class before running OV Protection.'], ...
        Input.Thy.UDRM, mat2str([OVDB.VDRM]));
end
CycloThy = OVDB(cycloIdx);
RthSum = CycloThy.Rth_jc + CycloThy.Rth_ch + CycloThy.Rth_ha;
O.ITh_zul_Cyclo = (-CycloThy.VT0 + sqrt(CycloThy.VT0^2 + ...
    4 * CycloThy.rT * CycloThy.DeltaTheta / RthSum)) / (2 * CycloThy.rT) ...
    * 3 / sqrt(2);
O.CycloThermal_OK     = O.ITh_zul_Cyclo >= O.ILimit;
O.CycloThermalMargin  = O.ITh_zul_Cyclo - O.ILimit;
O.OVThyType            = CycloThy.Type;

end

%% ==========================================================
function [UBoD_min, UBoD_max, UBoD_selected, BOD_OK, marginLow, marginHigh] = ...
    bodWindow(uLmax, Uv0, VDRM, deltaUBOD, BOD_selected)
%BODWINDOW  Break-Over-Diode min/max voltage window and margin check.
%   Shared by the stator and rotor BOD calculations (identical formula).

UBoD_min = uLmax * 1.3 * 1.3 * sqrt(2) * Uv0 + deltaUBOD;
UBoD_max = VDRM / 1.2 - deltaUBOD;

UBoD_selected = BOD_selected;
BOD_OK = (UBoD_selected >= UBoD_min) && (UBoD_selected <= UBoD_max);

marginLow  = UBoD_selected - UBoD_min;
marginHigh = UBoD_max - UBoD_selected;

end
