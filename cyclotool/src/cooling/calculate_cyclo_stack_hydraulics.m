function Branch = ...
    calculate_cyclo_stack_hydraulics( ...
    QwKD_lpm)
%CALCULATE_CYCLO_STACK_HYDRAULICS
% Solve the upper/lower cooling-can branch balance for one stack.
%
% Workbook rows 49-64 ("Calculation of flow & pressure" sheet): the
% upper branch (heat sink + resistor + 4 connectors + 1.0 m hose)
% carries the target flow QwKD_lpm; the lower branch (heat sink,
% no resistor, 2 connectors + 0.6 m hose) is a parallel path back to
% the same two collector rails, so at steady state its flow adjusts
% until its pressure drop equals the upper branch's. The workbook
% finds this by goal-seek; here it is solved directly with fzero.
%
% Replaces the previous version of this function, which implemented
% an unrelated topology ("Aktogay cooling workbook": stack flow =
% can flow * (6+2.35), no resistor/connector/branch split) that
% matched neither this reference workbook nor any caller in this
% project (the function was dead code).
%
% Input:
%   QwKD_lpm : target upper-branch (heat sink) flow [l/min]
%
% Output (Branch struct):
%   QUpper_lpm, QLower_lpm : branch flows [l/min]
%   DpBranch_kPa           : common branch pressure drop [kPa]
%   Status

arguments

    QwKD_lpm (1,1) double {mustBePositive}

end

DB = ...
    cyclo_cooling_component_database();

%% Upper branch pressure drop at the target flow

DpUpper = ...
    calculate_cyclo_pressure_drop( ...
        QwKD_lpm, DB.CoolingBoxTube.a, DB.CoolingBoxTube.c) ...
    + DB.Branch.Upper.NumConnectors ...
        * calculate_cyclo_pressure_drop( ...
            QwKD_lpm, DB.Connector.a, DB.Connector.c) ...
    + calculate_cyclo_pressure_drop( ...
        QwKD_lpm, DB.Resistor.a, DB.Resistor.c) ...
    + DB.Branch.Upper.HoseLength_m ...
        * calculate_cyclo_pressure_drop( ...
            QwKD_lpm, DB.Hose4mm.a, DB.Hose4mm.c);

%% Lower branch pressure drop as a function of its own flow

lowerBranchDp = ...
    @(q) ...
    calculate_cyclo_pressure_drop( ...
        q, DB.CoolingBoxTube.a, DB.CoolingBoxTube.c) ...
    + DB.Branch.Lower.NumConnectors ...
        * calculate_cyclo_pressure_drop( ...
            q, DB.Connector.a, DB.Connector.c) ...
    + DB.Branch.Lower.HoseLength_m ...
        * calculate_cyclo_pressure_drop( ...
            q, DB.Hose4mm.a, DB.Hose4mm.c);

%% Solve for the lower-branch flow giving the same pressure drop
%
% Monotonic increasing function of q for q>0, single positive root
% expected close to QwKD_lpm (workbook solutions run ~10-12% above
% the upper target flow) -- fzero with that as the starting bracket
% is robust and matches the workbook's own goal-seek result to
% numerical precision.

QLower_lpm = ...
    fzero( ...
        @(q) lowerBranchDp(q) - DpUpper, ...
        QwKD_lpm);

if QLower_lpm <= 0 || ~isfinite(QLower_lpm)

    error( ...
        'Cyclo:CoolingBranchSolveFailed', ...
        'The upper/lower cooling-can branch balance did not converge.');

end

Branch.QUpper_lpm = QwKD_lpm;
Branch.QLower_lpm = QLower_lpm;
Branch.DpBranch_kPa = DpUpper;
Branch.DpUpper_kPa = DpUpper;
Branch.DpLower_kPa = lowerBranchDp(QLower_lpm);
Branch.Status = "PASS";

end
