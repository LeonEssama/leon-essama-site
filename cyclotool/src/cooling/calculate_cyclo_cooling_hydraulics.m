function Hydraulic = ...
    calculate_cyclo_cooling_hydraulics( ...
    CoolingInput)
%CALCULATE_CYCLO_COOLING_HYDRAULICS
% Converter water-cooling flow and pressure drop.
%
% Source:
%   "Design of Water-Cooling System for Cycloconverters" workbook,
%   sheet "Calculation of flow & pressure", rows 49-128.
%
% Replaces the previous version of this function, which implemented
% an unrelated "Nthy/Ncol thyristor column" topology (different
% component coefficients, different pipe network) matching neither
% this reference workbook nor the GUI's converter-type inputs.
%
% Model summary (see cyclo_cooling_component_database.m for the
% numeric basis):
%   1. Upper/lower cooling-can branches are balanced to equal
%      pressure drop for the target flow CoolingInput.QwKD
%      (calculate_cyclo_stack_hydraulics.m).
%   2. Each converter type stacks a fixed number of upper/lower
%      cans (7 for 6-pulse, 14 for 12-pulse, 13 for 6-pulse w/
%      fuses); 2 stacks per phase, 3 phases.
%   3. A staged DN50 header/collector pipe network is added on top
%      (branch->stack, then phase-by-phase accumulation to the
%      final 3-phase collector).
%   4. 18-pulse is the 6-pulse converter's own result combined with
%      the 12-pulse converter's own result (workbook: "12-pulse +
%      6-pulse = 18-pulse"), reusing the 6-pulse Phase-T pressure as
%      a base and adding three further header stages at the
%      combined flow -- reproduced exactly as formulated in the
%      workbook (see inline comments), not re-derived.
%   5. The ethylene-glycol viscosity correction is applied once, to
%      the final pressure drop of the selected type.
%
% Required CoolingInput fields:
%   QwKD_lpm        : target upper-branch (heat sink) flow [l/min]
%   GlycolPercent   : 0-60 [%]
%   ConverterType   : "6-pulse" | "12-pulse" | "18-pulse" |
%                      "6-pulse-fused"

arguments

    CoolingInput (1,1) struct

end

validTypes = ...
    ["6-pulse","12-pulse","18-pulse","6-pulse-fused"];

if ~isfield(CoolingInput,'ConverterType') || ...
        ~ismember(string(CoolingInput.ConverterType), validTypes)

    error( ...
        'Cyclo:InvalidCoolingConverterType', ...
        'CoolingInput.ConverterType must be one of: %s.', ...
        strjoin(validTypes,', '));

end

DB = ...
    cyclo_cooling_component_database();

%% =========================================================
% 1. Branch balance (shared by every converter type)
%% =========================================================

Branch = ...
    calculate_cyclo_stack_hydraulics( ...
    CoolingInput.QwKD_lpm);

QUpper = Branch.QUpper_lpm;
QLower = Branch.QLower_lpm;
DpBranch = Branch.DpBranch_kPa;

pipe = ...
    @(flow_lpm, length_m) ...
    length_m ...
    * calculate_cyclo_pressure_drop( ...
        flow_lpm, DB.PipeDN50.a, DB.PipeDN50.c);

%% =========================================================
% 2. Fluid properties / glycol correction
%% =========================================================

Fluid = ...
    calculate_cyclo_cooling_glycol( ...
    CoolingInput.GlycolPercent);

%% =========================================================
% 3. Per-type stack + header network build
%% =========================================================

Result.SixPulse      = build_type(DB.CansPerStack.SixPulse);
Result.TwelvePulse   = build_type(DB.CansPerStack.TwelvePulse);
Result.SixPulseFused = build_type(DB.CansPerStack.SixPulseFused);

%% =========================================================
% 4. 18-pulse = 6-pulse (own, full) + 12-pulse (own, full)
%% =========================================================
%
% Workbook rows 106-122 (columns L-T): base pressure = the 6-pulse
% block's own "Phase T" cumulative pressure (stage0+stage1 only, NOT
% its full 3-phase total); the running flow used for every
% subsequent header stage already includes the 6-pulse converter's
% complete 3-phase flow plus the 12-pulse converter's phase-by-phase
% contribution. This asymmetry (pressure base = 1 phase, flow base =
% 3 phases) is exactly what the workbook computes -- reproduced
% verbatim, not rationalized or corrected.

s6  = Result.SixPulse.Stages;
s12 = Result.TwelvePulse.Stages;

base18_Dp   = s6.PhaseT_Dp_kPa;
flow18_step = s12.PhaseT_Flow_lpm;

flow_a = flow18_step + Result.SixPulse.QConverter_lpm_preVisc;
Dp_a   = base18_Dp + pipe(flow_a,1.2) + pipe(flow_a,1.2);

flow_b = flow_a + flow18_step;
Dp_b   = Dp_a + pipe(flow_b,1.2) + pipe(flow_b,1.2);

flow_c = flow_b + flow18_step;
Dp_c   = Dp_b + pipe(flow_c,2.36) + pipe(flow_c,1.18);

Result.EighteenPulse.QConverter_lpm_preVisc = flow_c;
Result.EighteenPulse.DpConverter_kPa_preVisc = Dp_c;
Result.EighteenPulse.QConverter_lpm = flow_c;
Result.EighteenPulse.DpConverter_kPa = ...
    Dp_c * Fluid.ViscosityCorrection;

%% =========================================================
% 5. Apply glycol viscosity correction to the plain types
%% =========================================================

typeNames = ["SixPulse","TwelvePulse","SixPulseFused"];

for k = 1:numel(typeNames)

    name = typeNames(k);

    Result.(name).QConverter_lpm = ...
        Result.(name).QConverter_lpm_preVisc;

    Result.(name).DpConverter_kPa = ...
        Result.(name).DpConverter_kPa_preVisc ...
        * Fluid.ViscosityCorrection;

end

%% =========================================================
% 6. Select the requested type
%% =========================================================

typeFieldMap = containers.Map( ...
    {'6-pulse','12-pulse','18-pulse','6-pulse-fused'}, ...
    {'SixPulse','TwelvePulse','EighteenPulse','SixPulseFused'});

selectedField = ...
    typeFieldMap(char(string(CoolingInput.ConverterType)));

Selected = Result.(selectedField);

%% =========================================================
% Output
%% =========================================================

Hydraulic.Branch = Branch;
Hydraulic.ByType = Result;

Hydraulic.QConverter_lpm = Selected.QConverter_lpm;
Hydraulic.DpConverter_kPa = Selected.DpConverter_kPa;

Hydraulic.DpBranch_kPa = DpBranch;
Hydraulic.ViscosityFactor = Fluid.ViscosityCorrection;
Hydraulic.ConverterType = CoolingInput.ConverterType;

Hydraulic.Status = "PASS";

    %% -----------------------------------------------------
    % Nested helper: build one converter type's stack + header
    % network (workbook rows 66-93, replicated per type).
    % -----------------------------------------------------
    function R = build_type(Cans)

        qStack = ...
            Cans.Upper * QUpper ...
            + Cans.Lower * QLower;

        %% Stage 0: branch -> stack (1.0 m, asymmetric flow)

        flow2 = 2 * qStack;
        flow1 = 1 * qStack;

        Dp_stage0 = ...
            DpBranch ...
            + pipe(flow2,1.0) ...
            + pipe(flow1,1.0);

        %% Stage 1: Phase T header (1.2 m, symmetric, 2 stacks)

        Dp_phaseT = ...
            Dp_stage0 ...
            + pipe(flow2,1.2) ...
            + pipe(flow2,1.2);

        %% Stage 2: Phases S+T header (1.2 m, symmetric, 4 stacks)

        flow4 = 2 * flow2;

        Dp_ST = ...
            Dp_phaseT ...
            + pipe(flow4,1.2) ...
            + pipe(flow4,1.2);

        %% Stage 3: Main collector (2.36 / 1.18 m, 6 stacks)

        flow6 = 3 * flow2;

        Dp_RST = ...
            Dp_ST ...
            + pipe(flow6,2.36) ...
            + pipe(flow6,1.18);

        R.CansUpper = Cans.Upper;
        R.CansLower = Cans.Lower;
        R.QStack_lpm = qStack;

        R.Stages.Base_Dp_kPa = Dp_stage0;
        R.Stages.PhaseT_Dp_kPa = Dp_phaseT;
        R.Stages.PhaseT_Flow_lpm = flow2;
        R.Stages.PhasesST_Dp_kPa = Dp_ST;
        R.Stages.PhasesST_Flow_lpm = flow4;

        R.QConverter_lpm_preVisc = flow6;
        R.DpConverter_kPa_preVisc = Dp_RST;

    end

end
