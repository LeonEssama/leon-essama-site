function CoolingCase = ...
    build_cooling_case_from_operating_point( ...
    OperatingPoint)
%BUILD_COOLING_CASE_FROM_OPERATING_POINT
% Water-cooling design case for one electrical operating point.
%
% Same default cooling/loss/topology values as build_cooling_case.m;
% run_cyclo_cooling_case.m overrides ThyristorLoss_kW,
% ResistorLoss_kW and ConverterLoss_kW when OperatingPoint carries a
% populated .Losses sub-struct (e.g. from the Losses tab), so the
% values set here are only the fallback used otherwise.
%
% Change vs. the previous version: field names and topology updated
% to the current reference workbook -- see build_cooling_case.m.

arguments
    OperatingPoint (1,1) struct
end

CoolingCase = ...
    build_cooling_case();

%% Point identification

CoolingCase.OperatingPoint = ...
    OperatingPoint.Name;

CoolingCase.SpeedRpm = ...
    OperatingPoint.SpeedRpm;

end
