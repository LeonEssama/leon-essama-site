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
%   ("Dauergrenzstrom") check for the selected VDRM class.
%
%   Source: user-supplied reference workbook "Atalaya_Kurzschliesser.xlsx",
%   sheet "SAG Mill". No IEC/IEEE/NEMA/ANSI standard is cited on that
%   workbook for any formula below; every formula is the vendor/
%   reference-document's own.
%
%   Two formula/data-mapping gaps found against that workbook and fixed
%   here (both formerly conflated the crowbar thyristor with the main
%   converter thyristor -- two physically different devices):
%
%   1. Rotor BOD window VDRM (workbook I18) is NOT the manually selected/
%      catalog VDRM_OV used for the stator (workbook D18) -- it is
%      calculated directly from the rotor excitation voltage:
%      VDRM_Rotor = 2*sqrt(2)*1.32*Uv0_Rotor. The GUI previously passed
%      the same Input.VDRM_OV into both the stator and rotor BOD-window
%      calls; the rotor call now uses this formula instead.
%   2. The workbook's "Dauergrenzstrom des Cyclo-Thyristors" block
%      (continuous current rating of the MAIN/cyclo thyristor, for the
%      selected VDRM class) was entirely missing from this function. Its
%      thermal data (VT0/rT/Rth_jc/Rth_ch/Rth_ha/DeltaTheta per VDRM
%      class) already exists in OV_ThyristorDatabase.m and matches the
%      workbook's "Protective Settings" table (rows 39-47) exactly, but
%      the GUI was wiring that same data into the CROWBAR thyristor's
%      thermal-check fields (Rth_jc_05s/DeltaTheta/VT0_OV/rT_OV) instead
%      -- a different device (workbook "Kurzschliesser-Thyristor HUEL
%      412304") with its own, single-lumped-Rth thermal model. That GUI
%      wiring bug is fixed separately (updateOVThyristor() in
%      CycloGUI_v2_0.m); this function now implements the missing
%      Dauergrenzstrom formula itself, keyed by Input.OVThyType.
%
%   Required Input fields (added by this audit): OVThyType -- the
%   OV_ThyristorDatabase Type string for the selected main/cyclo
%   converter thyristor VDRM class (e.g. '4in_5200V').

if Input.Rth_jc_05s == 0
    error('overvoltage_protection_calculation:ZeroRth', ...
        'Input.Rth_jc_05s must be nonzero.');
end
if Input.rT_OV == 0
    error('overvoltage_protection_calculation:ZeroRT', ...
        'Input.rT_OV must be nonzero.');
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

%% =====================================================
% Stator BOD limits, resistor and energy
%% =====================================================
[O.UBoD_min, O.UBoD_max, O.UBoD_selected, O.BOD_OK, ...
    O.BOD_MarginLow, O.BOD_MarginHigh] = bodWindow( ...
    Input.uLmax_OV, Input.Uv0_stator, Input.VDRM_OV, ...
    Input.deltaUBOD, Input.BOD_Stator);

O.RKS  = O.UBoD_selected / (Input.kStator * Input.IMmax_OV);
O.Ieff = Input.kStator * Input.IMmax_OV / sqrt(3);
O.EKS  = (Input.kStator * Input.IMmax_OV)^2 * Input.TKS * O.RKS / 3000;

%% ====================================================
% Rotor BOD limits, resistor and energy
%% ====================================================
% Rotor VDRM is the calculated blocking-voltage requirement (workbook
% I18), not the stator's manually selected/catalog VDRM_OV -- see the
% function header.
O.VDRM_Rotor_calc = 2 * sqrt(2) * 1.32 * Input.Uv0_Rotor;

[O.UBoD_min_Rotor, O.UBoD_max_Rotor, O.UBoD_selected_Rotor, O.BOD_OK_Rotor] = ...
    bodWindow(Input.uLmax_OV, Input.Uv0_Rotor, O.VDRM_Rotor_calc, ...
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
% Dauergrenzstrom des Cyclo-Thyristors: continuous current rating of the
% MAIN/cyclo converter thyristor for the selected VDRM class, checked
% against the protection current limit ILimit (=IM*startup).
%% ====================================================
OVDB = OV_ThyristorDatabase();
cycloIdx = find(strcmp({OVDB.Type}, Input.OVThyType), 1);
if isempty(cycloIdx)
    error('overvoltage_protection_calculation:NoOVThyristorMatch', ...
        'No OV_ThyristorDatabase entry for Input.OVThyType = ''%s''.', ...
        Input.OVThyType);
end
CycloThy = OVDB(cycloIdx);
RthSum = CycloThy.Rth_jc + CycloThy.Rth_ch + CycloThy.Rth_ha;
O.ITh_zul_Cyclo = (-CycloThy.VT0 + sqrt(CycloThy.VT0^2 + ...
    4 * CycloThy.rT * CycloThy.DeltaTheta / RthSum)) / (2 * CycloThy.rT) ...
    * 3 / sqrt(2);
O.CycloThermal_OK     = O.ITh_zul_Cyclo >= O.ILimit;
O.CycloThermalMargin  = O.ITh_zul_Cyclo - O.ILimit;

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
