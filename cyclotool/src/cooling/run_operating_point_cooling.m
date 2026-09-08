function Result = ...
    run_operating_point_cooling( ...
    OperatingPoint)

arguments
    OperatingPoint (1,1) struct
end

%% Build cooling case

CoolingCase = ...
    build_cooling_case_from_operating_point( ...
    OperatingPoint);

%% Execute cooling

Result = ...
    run_cyclo_cooling_case( ...
    CoolingCase);

%% Metadata

Result.OperatingPoint = ...
    OperatingPoint.Name;

Result.SpeedRpm = ...
    OperatingPoint.SpeedRpm;

end