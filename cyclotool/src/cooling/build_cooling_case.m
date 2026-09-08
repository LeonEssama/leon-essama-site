function CoolingCase = ...
    build_cooling_case()
%BUILD_COOLING_CASE
% Default water-cooling design case.
%
% Defaults taken from the reference workbook's own example
% ("Cooling design" sheet, cells C6/C10/C16-C21/C26): 12-pulse
% cycloconverter, 0% glycol, 1.8 l/min target heat-sink flow.
%
% Change vs. the previous version: field names and topology updated
% to the current reference workbook (upper/lower branch + pulse-type
% cans-per-stack model) in place of the previous Nthy/Ncol
% thyristor-column topology.

CoolingCase = struct();

%% Operating point

CoolingCase.OperatingPoint = ...
    "SCmin";

%% Cooling settings

CoolingCase.QwKD_lpm = ...
    1.8;

CoolingCase.GlycolPercent = ...
    0;

CoolingCase.ConverterType = ...
    "12-pulse";

%% Losses (Cooling design C16, C17, C20)

CoolingCase.ThyristorLoss_kW = ...
    5.7;

CoolingCase.ResistorLoss_kW = ...
    14.3;

CoolingCase.ConverterLoss_kW = ...
    210;

%% Temperature limits (Cooling design C18, C21)

CoolingCase.MaxOutletTemperatureKD_C = ...
    52;

CoolingCase.MaxOutletTemperatureConverter_C = ...
    60;

end
