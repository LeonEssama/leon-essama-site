function B = busbar_check(Input, opts)
%BUSBAR_CHECK  Thermal ampacity check of the SR-module busbars.
%
%   B = busbar_check(Input)
%   B = busbar_check(Input, Name, Value, ...)
%
%   Replaces Schienenueberpruefung.xlsx. Takes the cycloconverter
%   dimensioning inputs, derives the load current and frequency of every
%   busbar section, applies the k1..k5 derating factors, and reports the
%   reserve of each section for both surface finishes.
%
%   REQUIRED FIELDS OF Input
%     IM          [A]   nominal machine current
%     u_L         [pu]  uL,min -- minimum line voltage, undervoltage case
%     n_nom       [rpm] nominal speed
%     PolePairs   [-]   pole pairs
%     fL          [Hz]  line frequency
%     Altitude    [m]   site altitude (optional, default 0)
%
%   Name-Value arguments
%     Sections    struct - section list, default BusbarSectionDefaults()
%     Threshold   double - minimum acceptable reserve [p.u.], default 1.0
%     Location    char   - 'indoor' | 'outdoor', default 'indoor'
%     k1, k2, k5  double - global overrides [-], NaN = compute
%     BandGapRule char   - 'conservative' | 'error', default 'conservative'
%
%   OUTPUT
%     B.Bare / B.Painted  table, one row per section, with columns
%         Section, Profile, I_load_A, f_Hz, Band, k1..k5, kTotal,
%         I_max_A, Reserve_pu, OK
%     B.Summary   table, both finishes side by side
%     B.Currents  struct, the three load currents and their formulas
%     B.Altitude_m, B.Location   site conditions actually used for k5
%     B.Sources   cell,  provenance of every k factor, per section
%     B.AllOK     logical, true when every section of both finishes passes
%
%   LOAD CURRENT DEFINITIONS
%     Motor sections   I = IM/u_L                 [A]
%     Line sections    I = IM/u_L * sqrt(2/3)     [A]
%     Stack sections   I = IM/u_L / sqrt(3)       [A]
%
%     IM/u_L (u_L = uL,min) is the same undervoltage current-scaling
%     already established in CycloGUI_v2_0/generateNetzMatrix and
%     derive_cyclo_operating_point_voltage_current.m: at reduced line
%     voltage the motor current rises by 1/u_L to hold shaft power
%     roughly constant, so every busbar section (motor, line and stack)
%     sees its worst case at uL,min, not at rated line voltage. This is
%     not a new formula -- it reuses the tool's existing uLmin
%     convention rather than reasoning about busbar loading in
%     isolation.
%
%     The line-side factor sqrt(2/3) = 0.8165 is the converter valve-side
%     RMS current of a 6-pulse bridge and matches R.Iv_used in calculate.m.
%     The stack factor 1/sqrt(3) = 0.5774 is the per-branch RMS current of
%     a bridge arm conducting 120 electrical degrees. This is an
%     INTERPRETATION of the source workbook's '=B14/SQRT(3)': the workbook
%     documents no derivation, and the ratio has no counterpart in
%     calculate.m. Confirm it before issuing a design.
%
%   FREQUENCY BAND
%     The base table has data for f < 16 Hz and f > 20 Hz only. Motor-side
%     sections normally fall in the first band (f_motor = PolePairs *
%     n_nom / 60), line-side sections at fL in the second. If a frequency
%     lands in the undefined 16..20 Hz gap, 'conservative' selects the
%     lower (>20 Hz) rating and warns; 'error' refuses to compute.
%
%   STANDARDS
%     No IEC/IEEE requirement found for this item. Base ratings and k
%     factors are BBC/ABB Schaltanlagen-Handbuch ch. 13; see
%     BusbarAmpacityTable.m and busbar_k_factors.m for the full note.
%
%   NOT EXECUTED: statically reviewed only, no MATLAB runtime was
%   available when this was written. The k-factor/ampacity-table machinery
%   (unchanged by the IM/u_L current basis above) was verified numerically
%   against all 16 rows of Schienenueberpruefung.xlsx (both sheets, 8
%   sections each) at I = IM; every I_max and Reserve reproduced to within
%   2e-6. The IM/u_L current basis itself is a user-directed deviation
%   from that workbook (which used IM, not IM/uL,min) and is NOT
%   separately re-verified against it -- I_load_A simply scales by
%   1/Input.u_L relative to the workbook-matched values.

arguments
    Input             (1,1) struct
    opts.Sections     (1,:) struct  = BusbarSectionDefaults()
    opts.Threshold    (1,1) double {mustBePositive} = 1.0
    opts.Location     (1,:) char {mustBeMember(opts.Location, ...
                             {'indoor','outdoor'})} = 'indoor'
    opts.k1           (1,1) double = NaN
    opts.k2           (1,1) double = NaN
    opts.k5           (1,1) double = NaN
    opts.BandGapRule  (1,:) char {mustBeMember(opts.BandGapRule, ...
                             {'conservative','error'})} = 'conservative'
end

%% ---------------- Input validation -------------------------------------
required = {'IM','u_L','n_nom','PolePairs','fL'};
missing  = required(~isfield(Input, required));
if ~isempty(missing)
    error('busbar_check:MissingFields', ...
        'Input is missing required field(s): %s', strjoin(missing, ', '));
end
if isfield(Input, 'Altitude')
    altitude = Input.Altitude;
else
    altitude = 0;
    warning('busbar_check:NoAltitude', ...
        'Input.Altitude not supplied; assuming sea level (k5 = 1).');
end

validateattributes(Input.IM,        {'double'}, {'scalar','positive','finite'});
validateattributes(Input.u_L,       {'double'}, {'scalar','positive','finite'});
validateattributes(Input.n_nom,     {'double'}, {'scalar','positive','finite'});
validateattributes(Input.PolePairs, {'double'}, {'scalar','positive','finite'});
validateattributes(Input.fL,        {'double'}, {'scalar','positive','finite'});
validateattributes(altitude,        {'double'}, {'scalar','nonnegative','finite'});

%% ---------------- Load currents and frequencies ------------------------
% Motor electrical frequency from speed and pole pairs [Hz]:
%     f_M = PolePairs * n_nom / 60
f_motor = Input.PolePairs * Input.n_nom / 60;
f_line  = Input.fL;

% Worst-case (uL,min undervoltage) machine current: same 1/u_L scaling
% already used for IM_op in derive_cyclo_operating_point_voltage_current.m
% -- see LOAD CURRENT DEFINITIONS above.
IM_used = Input.IM / Input.u_L;

I_motor = IM_used;
I_line  = IM_used * sqrt(2/3);
I_stack = IM_used / sqrt(3);

B.Currents = struct( ...
    'I_motor_A', I_motor, 'I_motor_formula', 'IM / u_L', ...
    'I_line_A',  I_line,  'I_line_formula',  'IM / u_L * sqrt(2/3)', ...
    'I_stack_A', I_stack, 'I_stack_formula', 'IM / u_L / sqrt(3)', ...
    'f_motor_Hz', f_motor, 'f_motor_formula', 'PolePairs * n_nom / 60', ...
    'f_line_Hz',  f_line,  'f_line_formula',  'fL');

%% ---------------- Resolve k5 once for the whole run --------------------
% k5 depends only on altitude and location, both constant across the run.
% Resolving it here rather than inside evaluateFinish means the
% above-4000 m extrapolation warning is raised once, not once per section
% per surface finish (16 identical messages for an 8-section list).
if isnan(opts.k5)
    [k5val, k5src, k5rule] = busbar_altitude_factor(altitude, opts.Location);
else
    k5val  = opts.k5;
    k5src  = sprintf('user override at %g m', altitude);
    k5rule = 'override';
end
k5info = struct('value', k5val, 'source', k5src, 'rule', k5rule);

%% ---------------- Evaluate both finishes -------------------------------
DB       = BusbarAmpacityTable();
Sections = opts.Sections;

[B.Bare,    srcBare]    = evaluateFinish(Sections, DB, false, ...
    I_motor, I_line, I_stack, f_motor, f_line, altitude, opts, k5info);
[B.Painted, srcPainted] = evaluateFinish(Sections, DB, true, ...
    I_motor, I_line, I_stack, f_motor, f_line, altitude, opts, k5info);

B.Sources = struct('Bare', {srcBare}, 'Painted', {srcPainted});

%% ---------------- Summary ----------------------------------------------
B.Summary = table( ...
    B.Bare.Section, B.Bare.Profile, B.Bare.I_load_A, ...
    B.Bare.I_max_A,    B.Bare.Reserve_pu,    B.Bare.OK, ...
    B.Painted.I_max_A, B.Painted.Reserve_pu, B.Painted.OK, ...
    'VariableNames', {'Section','Profile','I_load_A', ...
                      'Imax_bare_A','Reserve_bare_pu','OK_bare', ...
                      'Imax_painted_A','Reserve_painted_pu','OK_painted'});

B.Threshold  = opts.Threshold;
B.Altitude_m = altitude;
B.Location   = opts.Location;
B.AllOK      = all(B.Bare.OK) && all(B.Painted.OK);

%% ---------------- Advisory ---------------------------------------------
if ~all(B.Bare.OK) && all(B.Painted.OK)
    warning('busbar_check:PaintRequired', ...
        ['%d section(s) fail bare but pass painted. Painting the bars ' ...
         'is then a design requirement, not an option.'], ...
        sum(~B.Bare.OK));
end

end

%% ========================================================================
function [T, sources] = evaluateFinish(Sections, DB, painted, ...
    I_motor, I_line, I_stack, f_motor, f_line, altitude, opts, k5info)
%EVALUATEFINISH  Evaluate every section for one surface finish.

n = numel(Sections);

Section    = strings(n,1);
Profile    = strings(n,1);
I_load_A   = zeros(n,1);
f_Hz       = zeros(n,1);
Band       = strings(n,1);
k1 = zeros(n,1); k2 = zeros(n,1); k3 = zeros(n,1);
k4 = zeros(n,1); k5 = zeros(n,1); kTotal = zeros(n,1);
I_base_A   = zeros(n,1);
I_max_A    = zeros(n,1);
Reserve_pu = zeros(n,1);
OK         = false(n,1);
sources    = cell(n,1);

for i = 1:n
    S = Sections(i);

    % -- profile lookup --------------------------------------------------
    idx = find(strcmp({DB.Profile}, S.Profile), 1);
    if isempty(idx)
        error('busbar_check:UnknownProfile', ...
            'Section "%s" references unknown profile "%s". Available: %s', ...
            S.Name, S.Profile, strjoin({DB.Profile}, ', '));
    end
    P = DB(idx);

    % -- load current ----------------------------------------------------
    switch S.CurrentBasis
        case 'Motor', I_load_A(i) = I_motor;
        case 'Line',  I_load_A(i) = I_line;
        case 'Stack', I_load_A(i) = I_stack;
        otherwise
            error('busbar_check:BadCurrentBasis', ...
                'Section "%s": CurrentBasis "%s" is not recognised.', ...
                S.Name, S.CurrentBasis);
    end

    % -- frequency and band ----------------------------------------------
    switch S.FreqBasis
        case 'Motor', f_Hz(i) = f_motor;
        case 'Line',  f_Hz(i) = f_line;
        otherwise
            error('busbar_check:BadFreqBasis', ...
                'Section "%s": FreqBasis "%s" is not recognised.', ...
                S.Name, S.FreqBasis);
    end
    [isLowBand, Band(i)] = selectBand(f_Hz(i), S.Name, opts.BandGapRule);

    % -- base rating -----------------------------------------------------
    if painted
        if isLowBand, I_base_A(i) = P.I_painted_lt16;
        else,         I_base_A(i) = P.I_painted_gt20; end
    else
        if isLowBand, I_base_A(i) = P.I_bare_lt16;
        else,         I_base_A(i) = P.I_bare_gt20; end
    end

    % -- k3 override sentinel --------------------------------------------
    % -1 means 'the workbook's linked 2-bar horizontal value'
    k3in = S.k3_override;
    if k3in == -1
        if painted, k3in = 0.85; else, k3in = 0.80; end
    end

    % -- k factors -------------------------------------------------------
    K = busbar_k_factors( ...
        'Painted',      painted, ...
        'nBars',        P.nBars, ...
        'Width_mm',     P.Width_mm, ...
        'Thickness_mm', P.Thickness_mm, ...
        'Orientation',  S.Orientation, ...
        'RunLength_m',  S.RunLength_m, ...
        'Altitude_m',   altitude, ...
        'Location',     opts.Location, ...
        'k1', opts.k1, 'k2', opts.k2, 'k3', k3in, 'k5', k5info.value);

    % k5 was resolved once for the whole run, so busbar_k_factors saw it
    % as an override. Restore the provenance it actually came from.
    K.k5_source = k5info.source;
    K.k5_rule   = k5info.rule;

    k1(i) = K.k1; k2(i) = K.k2; k3(i) = K.k3;
    k4(i) = K.k4; k5(i) = K.k5; kTotal(i) = K.kTotal;

    sources{i} = struct( ...
        'k1', K.k1_source, 'k2', K.k2_source, 'k3', K.k3_source, ...
        'k4', K.k4_source, 'k5', K.k5_source, 'base', P.Source, ...
        'k1_rule', K.k1_rule, 'k2_rule', K.k2_rule, 'k3_rule', K.k3_rule, ...
        'k4_rule', K.k4_rule, 'k5_rule', K.k5_rule);

    % -- rating and reserve ----------------------------------------------
    I_max_A(i)    = I_base_A(i) * kTotal(i);
    Reserve_pu(i) = I_max_A(i) / I_load_A(i);
    OK(i)         = Reserve_pu(i) >= opts.Threshold;

    Section(i) = string(S.Name);
    Profile(i) = string(S.Profile);
end

T = table(Section, Profile, I_load_A, f_Hz, Band, ...
          k1, k2, k3, k4, k5, kTotal, I_base_A, I_max_A, Reserve_pu, OK);

end

%% ========================================================================
function [isLowBand, label] = selectBand(f, sectionName, rule)
%SELECTBAND  Map a frequency to one of the two tabulated bands.
%
%   The base table is defined for f < 16 Hz and f > 20 Hz only.

F_LOW_MAX  = 16;   % [Hz]
F_HIGH_MIN = 20;   % [Hz]

if f < F_LOW_MAX
    isLowBand = true;
    label     = "< 16 Hz";

elseif f > F_HIGH_MIN
    isLowBand = false;
    label     = "> 20 Hz";

else
    if strcmp(rule, 'error')
        error('busbar_check:FrequencyBandGap', ...
            ['Section "%s" runs at %.2f Hz, inside the undefined ' ...
             '%g..%g Hz gap of the base table. Supply a rating for this ' ...
             'band or set BandGapRule to ''conservative''.'], ...
            sectionName, f, F_LOW_MAX, F_HIGH_MIN);
    end
    isLowBand = false;            % the > 20 Hz column is the lower rating
    label     = "> 20 Hz (gap)";
    warning('busbar_check:FrequencyBandGap', ...
        ['Section "%s" runs at %.2f Hz, inside the undefined %g..%g Hz ' ...
         'gap of the base table. The lower (> 20 Hz) rating has been ' ...
         'used. This is an engineering estimate, not tabulated data.'], ...
        sectionName, f, F_LOW_MAX, F_HIGH_MIN);
end

end
