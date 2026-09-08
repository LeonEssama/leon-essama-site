function Thermal = ...
    calculate_cyclo_cooling_thermal( ...
    ThermalInput)
%CALCULATE_CYCLO_COOLING_THERMAL
% Coolant temperature rise and required intake temperature.
%
% Source:
%   "Cooling design" sheet, rows 33-38:
%     DeltaT_KD        [K]  = (Pthy+Pres)[kW] * 60 / (cp[kJ/kgK] * Q[l/min])
%     Tin_required_KD  [C]  = Tout_max_KD - DeltaT_KD
%     DeltaT_Converter [K]  = Pconverter[kW] * 60 / (cp[kJ/kgK] * Q[l/min])
%     Tin_required_Conv[C]  = Tout_max_Conv - DeltaT_Converter
%
%   Both formulas are dimensionally consistent only if cp is taken in
%   kJ/(kg.K) (4.1868 for water) -- the workbook labels the cell
%   "[J/kg/K]" but the value and formula are unambiguous once
%   checked against its own computed numbers; calculate_cyclo_
%   cooling_glycol.m already returns Cp_kJkgK in the correct unit.
%
% Change vs. the previous version of this function: ThyristorLoss_kW
% was previously divided by 2 before adding ResistorLoss_kW. The
% workbook formula (Cooling design row 35: ($C$16+$C$17)*60/...) adds
% the two losses directly, with no such factor -- C16 "Max. loss of
% thyristor Thy" is already the loss attributed to one KD branch.
% The /2 has been removed to match the workbook exactly. If the /2
% was actually compensating for a different loss-input convention
% upstream (e.g. ThyristorLoss_kW previously meaning "per pair"),
% that upstream convention needs to be checked before this change is
% relied on -- flagged here explicitly rather than silently kept.

arguments

    ThermalInput (1,1) struct

end

%% Fluid properties

Fluid = ...
    calculate_cyclo_cooling_glycol( ...
    ThermalInput.GlycolPercent);

cp = ...
    Fluid.Cp_kJkgK;

%% Cooling branch (KD = Kuehldose / cooling can)

Thermal.DeltaTKD_C = ...
    ( ...
      ThermalInput.ThyristorLoss_kW ...
    + ThermalInput.ResistorLoss_kW ...
    ) ...
    * 60 ...
    / ( ...
        ThermalInput.QwKD ...
        * cp);

Thermal.InletTemperatureKD_C = ...
    ThermalInput.MaxOutletTemperatureKD_C ...
    - Thermal.DeltaTKD_C;

%% Converter

Thermal.DeltaTConverter_C = ...
    ThermalInput.ConverterLoss_kW ...
    * 60 ...
    / ( ...
       ThermalInput.QConverter_lpm ...
       * cp);

Thermal.InletTemperatureConverter_C = ...
    ThermalInput.MaxOutletTemperatureConverter_C ...
    - Thermal.DeltaTConverter_C;

%% Metadata

Thermal.Cp_kJkgK = ...
    cp;

Thermal.Status = ...
    "PASS";

end
