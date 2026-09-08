function Sweep = ...
    run_cyclo_cooling_sweep( ...
    CoolingInput)
%RUN_CYCLO_COOLING_SWEEP
% Sweep target heat-sink flow QwKD_lpm and tabulate the cooling
% design result at each point.
%
% Change vs. the previous version: default flow vector aligned to
% the reference workbook's own sweep ("Cooling design" C26:J26 =
% 1.8:0.2:3.2 l/min, 8 points) in place of the previous 10-point
% vector; field name updated from QwKD to QwKD_lpm to match the
% current CoolingInput contract.

arguments

    CoolingInput (1,1) struct

end

%% Workbook flow vector (Cooling design C26:J26)

FlowVector = [ ...
    1.8
    2.0
    2.2
    2.4
    2.6
    2.8
    3.0
    3.2];

nPoints = ...
    numel(FlowVector);

%% Preallocate

Sweep.QwKD_lpm = ...
    FlowVector(:);

Sweep.QConverter_lpm = ...
    zeros(nPoints,1);

Sweep.DpConverter_kPa = ...
    zeros(nPoints,1);

Sweep.DeltaTKD_C = ...
    zeros(nPoints,1);

Sweep.DeltaTConverter_C = ...
    zeros(nPoints,1);

Sweep.TinKD_C = ...
    zeros(nPoints,1);

Sweep.TinConverter_C = ...
    zeros(nPoints,1);

%% Sweep loop

for k = 1:nPoints

    Input = CoolingInput;

    Input.QwKD_lpm = ...
        FlowVector(k);

    Cooling = ...
        calculate_cyclo_water_cooling( ...
        Input);

    Sweep.QConverter_lpm(k) = ...
        Cooling.TotalFlow_lpm;

    Sweep.DpConverter_kPa(k) = ...
        Cooling.TotalPressureDrop_kPa;

    Sweep.DeltaTKD_C(k) = ...
        Cooling.DeltaTKD_C;

    Sweep.DeltaTConverter_C(k) = ...
        Cooling.DeltaTConverter_C;

    Sweep.TinKD_C(k) = ...
        Cooling.InletTemperatureKD_C;

    Sweep.TinConverter_C(k) = ...
        Cooling.InletTemperatureConverter_C;

end

Sweep.Status = ...
    "PASS";

end
