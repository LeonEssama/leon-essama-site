function Result = ...
    run_cyclo_cooling_case( ...
    CoolingCase)

arguments

    CoolingCase (1,1) struct

end

%% Convert case into cooling input

CoolingInput = CoolingCase;

%% Temporary workbook values
%

if isfield(CoolingCase,'Losses')

    CoolingInput.ThyristorLoss_kW = ...
        CoolingCase.Losses.ThyristorLoss_kW;

    CoolingInput.ResistorLoss_kW = ...
        CoolingCase.Losses.ResistorLoss_kW;

    CoolingInput.ConverterLoss_kW = ...
        CoolingCase.Losses.ConverterLoss_kW;

else

    % Temporary validation values

    CoolingInput.ThyristorLoss_kW = 1.51;

    CoolingInput.ResistorLoss_kW = 0.7;

    CoolingInput.ConverterLoss_kW = 140;

end

%% Execute cooling engine

Result = ...
    calculate_cyclo_water_cooling( ...
    CoolingInput);

%% Metadata

Result.OperatingPoint = ...
    CoolingCase.OperatingPoint;
