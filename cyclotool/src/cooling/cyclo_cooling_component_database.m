function DB = ...
    cyclo_cooling_component_database()
%CYCLO_COOLING_COMPONENT_DATABASE
% Water-cooling hydraulic component database.
%
% Source:
%   "Design of Water-Cooling System for Cycloconverters" workbook,
%   sheet "Calculation of flow & pressure", rows 2-17.
%   Component data itself derived from < 3BHS123592_durchfluss_
%   druckabfall_komponenten.docx >.
%
% Pressure-drop law for every component (workbook row 4):
%
%   Dp[kPa] = c * q[l/min]^a
%
% Replaces the previous "Aktogay cooling workbook" component set
% (different coefficients, different topology) with the values from
% the current reference workbook.

DB = struct();

%% Cooling box (heat sink) + 2x100 mm tube, incl. Legris fitting
% Workbook row 13.

DB.CoolingBoxTube.Name = ...
    "Cooling box + 2x100mm tube (Legris)";

DB.CoolingBoxTube.a = 1.887;
DB.CoolingBoxTube.c = 20;

%% Tube connector, 90 deg Legris (each)
% Workbook row 14.

DB.Connector.Name = "Tube connector 90 deg Legris";

DB.Connector.a = 2.0;
DB.Connector.c = 1.055;

%% Snubber resistor
% Workbook row 15.

DB.Resistor.Name = "Snubber resistor";

DB.Resistor.a = 1.867;
DB.Resistor.c = 0.7;

%% Teflon tube, di = 4 mm, coefficient per 1 m
% Workbook row 16.

DB.Hose4mm.Name = "Teflon tube di=4mm (per 1 m)";

DB.Hose4mm.a = 1.802;
DB.Hose4mm.c = 8.493;

%% Pipe DN50, di = 56.3 mm, coefficient per 1 m
% Workbook row 17. The source workbook itself marks this coefficient
% "to be verified" (cell E17) -- carried through here unchanged, not
% an engineering estimate of ours.

DB.PipeDN50.Name = "Pipe DN50 di=56.3mm (per 1 m)";

DB.PipeDN50.a = 1.91;
DB.PipeDN50.c = 1.31e-05;
DB.PipeDN50.Note = "Coefficient marked 'to be verified' in source workbook.";

%% =========================================================
% Branch topology (fixed, independent of converter type)
%% =========================================================
%
% Each cooling "can" position sits in one of two parallel branch
% types, both starting from a common heat-sink target flow and
% balanced to equal pressure drop (workbook rows 49-64):
%
%   Upper branch (per can): CoolingBoxTube + Resistor
%                            + 4 x Connector + 1.0 m Hose4mm
%   Lower branch (per can): CoolingBoxTube (no resistor)
%                            + 2 x Connector + 0.6 m Hose4mm
%
% The two branches are sized (goal-seek in the workbook) so that
% their pressure drops are equal for a given upper-branch target
% flow QwKD -- see calculate_cyclo_stack_hydraulics.m.

DB.Branch.Upper.NumConnectors = 4;
DB.Branch.Upper.HoseLength_m  = 1.0;
DB.Branch.Upper.HasResistor   = true;

DB.Branch.Lower.NumConnectors = 2;
DB.Branch.Lower.HoseLength_m  = 0.6;
DB.Branch.Lower.HasResistor   = false;

%% =========================================================
% Cooling-can count per stack, by converter type
%% =========================================================
%
% Workbook rows 66 (6-pulse), L66 (12-pulse), W66 (6-pulse w/ fuses):
%   6-pulse         : 3 upper + 4 lower  =  7 cans/stack
%   12-pulse        : 6 upper + 8 lower  = 14 cans/stack
%   6-pulse w/fuses : 6 upper + 7 lower  = 13 cans/stack
%
% 18-pulse is not an independent stack pattern -- it is the 6-pulse
% converter's own full result combined with the 12-pulse converter's
% own full result (Cooling Overview sheet: "12-pulse + 6-pulse =
% 18-pulse"), handled in calculate_cyclo_cooling_hydraulics.m.

DB.CansPerStack.SixPulse       = struct('Upper',3,'Lower',4);
DB.CansPerStack.TwelvePulse    = struct('Upper',6,'Lower',8);
DB.CansPerStack.SixPulseFused  = struct('Upper',6,'Lower',7);

%% =========================================================
% Converter-level structure (fixed, all types)
%% =========================================================
%
% 2 stacks per phase (positive + negative bridge arm), 3 phases.

DB.StacksPerPhase   = 2;
DB.NumberOfPhases   = 3;

%% =========================================================
% Main header/collector pipe network (DN50), staged
%% =========================================================
%
% Workbook rows 70-93 (6-pulse block; identical pattern in the
% 12-pulse and fused blocks). Each stage adds an inlet-pipe and a
% reflow-pipe pressure drop evaluated at the stated multiple of the
% per-stack flow. Stage 1's reflow length uses the 1-stack flow while
% every other length uses the accumulated phase flow -- this
% asymmetry is reproduced exactly as given in the source workbook,
% not corrected.

DB.PipeNetwork = struct( ...
    'Name',            {'Branch to stack','Phase (1st)','Phases (2nd)','Main collector'}, ...
    'InletLength_m',   {1.0,               1.2,           1.2,           2.36}, ...
    'ReflowLength_m',  {1.0,               1.2,           1.2,           1.18}, ...
    'InletStacks',     {2,                 2,             4,             6}, ...
    'ReflowStacks',    {1,                 2,             4,             6});

end
