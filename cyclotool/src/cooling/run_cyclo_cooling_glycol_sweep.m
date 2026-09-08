function Sweep = ...
    run_cyclo_cooling_glycol_sweep( ...
    CoolingInput)

arguments
    CoolingInput (1,1) struct
end

GlycolVector = [ ...
     0
    10
    20
    30
    40
    50
    60];

nPoints = ...
    numel(GlycolVector);

Sweep.GlycolPercent = ...
    GlycolVector(:);

Sweep.Cp_kJkgK = ...
    zeros(nPoints,1);

Sweep.ViscosityFactor = ...
    zeros(nPoints,1);

Sweep.DpConverter_kPa = ...
    zeros(nPoints,1);

Sweep.DeltaTKD_C = ...
    zeros(nPoints,1);

Sweep.TinKD_C = ...
    zeros(nPoints,1);

for k = 1:nPoints

    Input = CoolingInput;

    Input.GlycolPercent = ...
        GlycolVector(k);

    Cooling = ...
        calculate_cyclo_water_cooling(Input);

    Sweep.Cp_kJkgK(k) = ...
        Cooling.Fluid.Cp_kJkgK;

    Sweep.ViscosityFactor(k) = ...
        Cooling.Fluid.ViscosityCorrection;

    Sweep.DpConverter_kPa(k) = ...
        Cooling.TotalPressureDrop_kPa;

    Sweep.DeltaTKD_C(k) = ...
        Cooling.DeltaTKD_C;

    Sweep.TinKD_C(k) = ...
        Cooling.InletTemperatureKD_C;

end

Sweep.Status = ...
    "PASS";

end