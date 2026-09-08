function EnvelopeCooling = ...
    run_operating_envelope_cooling( ...
    Envelope)

arguments

    Envelope (1,1) struct

end

nPoints = ...
    numel(Envelope.SpeedRpm);

%% Preallocate

EnvelopeCooling.SpeedRpm = ...
    Envelope.SpeedRpm;

EnvelopeCooling.Flow_lpm = ...
    zeros(nPoints,1);

EnvelopeCooling.PressureDrop_kPa = ...
    zeros(nPoints,1);

EnvelopeCooling.TinKD_C = ...
    zeros(nPoints,1);

EnvelopeCooling.TinConverter_C = ...
    zeros(nPoints,1);

%% Loop

for k = 1:nPoints

    OperatingPoint = struct();

    OperatingPoint.Name = ...
        sprintf("Point_%02d",k);

    OperatingPoint.SpeedRpm = ...
        Envelope.SpeedRpm(k);

    Result = ...
        run_operating_point_cooling( ...
        OperatingPoint);

    EnvelopeCooling.Flow_lpm(k) = ...
        Result.TotalFlow_lpm;

    EnvelopeCooling.PressureDrop_kPa(k) = ...
        Result.TotalPressureDrop_kPa;

    EnvelopeCooling.TinKD_C(k) = ...
        Result.InletTemperatureKD_C;

    EnvelopeCooling.TinConverter_C(k) = ...
        Result.InletTemperatureConverter_C;

end

EnvelopeCooling.Status = ...
    "PASS";

end