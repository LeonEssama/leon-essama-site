function Cooling = ...
    calculate_cyclo_water_cooling( ...
    CoolingInput)
%CALCULATE_CYCLO_WATER_COOLING
% Top-level water-cooling design calculation (orchestrator).
%
% Source: "Design of Water-Cooling System for Cycloconverters"
% workbook (sheets "Cooling design" and "Calculation of flow &
% pressure").
%
% Required CoolingInput fields:
%   QwKD_lpm                       : target heat-sink flow [l/min]
%                                     (workbook "min. water flow per
%                                     heat sink", Cooling design C26)
%   GlycolPercent                  : 0-60 [%]
%   ConverterType                  : "6-pulse" | "12-pulse" |
%                                     "18-pulse" | "6-pulse-fused"
%   ThyristorLoss_kW               : Cooling design C16
%   ResistorLoss_kW                : Cooling design C17
%   ConverterLoss_kW               : Cooling design C20
%   MaxOutletTemperatureKD_C       : Cooling design C18
%   MaxOutletTemperatureConverter_C: Cooling design C21
%
% Change vs. the previous version: CoolingInput field names updated
% to match the current reference workbook (QwKD_lpm, ConverterType)
% in place of the previous Nthy/Ncol column-based topology fields.

arguments

    CoolingInput (1,1) struct

end

%% =========================================================
% Fluid
%% =========================================================

Cooling.Fluid = ...
    calculate_cyclo_cooling_glycol( ...
    CoolingInput.GlycolPercent);

%% =========================================================
% Hydraulics
%% =========================================================

Cooling.Hydraulic = ...
    calculate_cyclo_cooling_hydraulics( ...
    CoolingInput);

%% =========================================================
% Thermal
%% =========================================================

ThermalInput = struct();

ThermalInput.GlycolPercent = ...
    CoolingInput.GlycolPercent;

ThermalInput.QwKD = ...
    CoolingInput.QwKD_lpm;

ThermalInput.QConverter_lpm = ...
    Cooling.Hydraulic.QConverter_lpm;

ThermalInput.ThyristorLoss_kW = ...
    CoolingInput.ThyristorLoss_kW;

ThermalInput.ResistorLoss_kW = ...
    CoolingInput.ResistorLoss_kW;

ThermalInput.ConverterLoss_kW = ...
    CoolingInput.ConverterLoss_kW;

ThermalInput.MaxOutletTemperatureKD_C = ...
    CoolingInput.MaxOutletTemperatureKD_C;

ThermalInput.MaxOutletTemperatureConverter_C = ...
    CoolingInput.MaxOutletTemperatureConverter_C;

Cooling.Thermal = ...
    calculate_cyclo_cooling_thermal( ...
    ThermalInput);

%% =========================================================
% Summary
%% =========================================================

Cooling.ConverterType = ...
    CoolingInput.ConverterType;

Cooling.QwKD_lpm = ...
    CoolingInput.QwKD_lpm;

Cooling.TotalFlow_lpm = ...
    Cooling.Hydraulic.QConverter_lpm;

Cooling.TotalPressureDrop_kPa = ...
    Cooling.Hydraulic.DpConverter_kPa;

Cooling.DeltaTKD_C = ...
    Cooling.Thermal.DeltaTKD_C;

Cooling.DeltaTConverter_C = ...
    Cooling.Thermal.DeltaTConverter_C;

Cooling.InletTemperatureKD_C = ...
    Cooling.Thermal.InletTemperatureKD_C;

Cooling.InletTemperatureConverter_C = ...
    Cooling.Thermal.InletTemperatureConverter_C;

%% =========================================================
% Status
%% =========================================================
%
% Workbook remarks (Introduction&Manual C27, C30): the cycloconverter
% coolant outlet temperature may not exceed 60 C; a single branch
% (KD) outlet temperature may not exceed 65 C. Flagged here as a
% design-limit check (industry note in the source document, not an
% IEC/IEEE requirement) rather than silently passing.

statusNotes = strings(0,1);

if CoolingInput.MaxOutletTemperatureConverter_C > 60

    statusNotes(end+1) = ...
        "Converter outlet temperature limit exceeds the workbook's stated 60 degC maximum.";

end

if CoolingInput.MaxOutletTemperatureKD_C > 65

    statusNotes(end+1) = ...
        "KD (single branch) outlet temperature limit exceeds the workbook's stated 65 degC maximum.";

end

if Cooling.InletTemperatureConverter_C <= 0 || ...
        Cooling.InletTemperatureKD_C <= 0

    statusNotes(end+1) = ...
        "Required intake temperature is non-positive: increase QwKD or reduce loss/outlet-temperature inputs.";

end

if isempty(statusNotes)

    Cooling.Status = "PASS";

else

    Cooling.Status = "CHECK";

end

Cooling.StatusNotes = statusNotes;

end
