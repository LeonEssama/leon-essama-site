function O = overvoltage_protection_calculation(Input)
%OVERVOLTAGE_PROTECTION_CALCULATION  Crowbar / BOD / protection settings.
%
%   O = overvoltage_protection_calculation(Input)
%
%   Computes, for both stator and rotor sides:
%     - Thyristor thermal current limit and thermal margin check
%     - Break-Over-Diode (BOD) min/max voltage window and margin check
%     - Crowbar resistor sizing, effective current and dissipated energy
%   Also computes protection current thresholds (I115/I135), the
%   protection current limit, and the protection blocking frequency.
%
%   Calculation logic is unchanged from the original.

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
% Thyristor thermal limit
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
[O.UBoD_min_Rotor, O.UBoD_max_Rotor, O.UBoD_selected_Rotor, O.BOD_OK_Rotor] = ...
    bodWindow(Input.uLmax_OV, Input.Uv0_Rotor, Input.VDRM_OV, ...
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
