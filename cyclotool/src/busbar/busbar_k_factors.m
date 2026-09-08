function K = busbar_k_factors(opts)
%BUSBAR_K_FACTORS  Correction factors k1..k5 for busbar thermal ratings.
%
%   K = busbar_k_factors(Name, Value, ...)
%
%   Returns a struct with the five multiplicative derating factors applied
%   to the base rating from BusbarAmpacityTable.m:
%
%     I_max = I_base * k1 * k2 * k3 * k4 * k5      [A]
%
%   Every factor is returned with TWO companions:
%     K.<k>_source  human-readable provenance naming the table row or rule
%     K.<k>_rule    machine-readable classification, one of
%                     'override'        supplied by the caller
%                     'default'         no data, factor set to 1
%                     'fixed'           structurally 1 (see k4)
%                     'table'           read from a tabulated row
%                     'interpolated'    between two tabulated rows
%                     'extrapolated'    beyond the last row, ENGINEERING ESTIMATE
%                     'below_table'     below the table's first row, no derating
%                     'single_bar'      no Tab. 13-13 entry for one bar
%                     'vertical_exempt' vertical run <= 2 m, Tab. 13-13 scope
%   Assert on _rule in tests and downstream logic; _source is for humans
%   and its wording may change.
%
%   Name-Value arguments
%     Painted       logical - true for painted bars, false for bare. Req'd.
%     nBars         double  - number of parallel bars [-]. Required.
%     Width_mm      double  - bar width [mm]. Required.
%     Thickness_mm  double  - bar thickness [mm]. Required.
%     Orientation   char    - 'horizontal' | 'vertical'. Default 'horizontal'.
%     RunLength_m   double  - run length [m]. Only read when Orientation
%                             is 'vertical'; Tab. 13-13 exempts vertical
%                             runs of 2 m or less. NaN (default) means the
%                             length is unknown, which is derated
%                             conservatively and warned about.
%     Altitude_m    double  - site altitude above sea level [m]. Default 0.
%     Location      char    - 'indoor' | 'outdoor'. Default 'indoor'.
%     k1..k5        double  - explicit override [-]. NaN (default) means
%                             compute. An override is reported as such.
%
%   FACTOR DEFINITIONS (BBC/ABB Schaltanlagen-Handbuch, chapter 13)
%     k1  conductivity of the conductor material relative to the tabulated
%         reference. NO SOURCE DATA AVAILABLE - defaults to 1 and must be
%         supplied explicitly if the material differs from the reference
%         copper grade.
%     k2  deviating ambient and/or bar temperature, Bild 13-4. Reference
%         is 35 degC ambient / 65 degC bar. Bild 13-4 is a printed nomogram
%         and has NOT been digitised here, so k2 defaults to 1 and must be
%         read off the chart and supplied when the design temperatures
%         differ. The source workbook uses k2 = 1 with a note reading
%         '40 degC / 70 degC': the temperature RISE is the same 30 K, which
%         makes k2 ~ 1 a defensible engineering judgement, but it is a
%         judgement and not a chart reading.
%     k3  arrangement and position, Tabelle 13-13. Implemented below.
%     k4  AC current displacement from the arrangement, Bild 13-5/13-6.
%         NOT applied here: in this tool the frequency effect is carried by
%         the choice of the <16 Hz / >20 Hz column of the base table, so k4
%         is fixed at 1. Tabelle 13-13's note also exempts k4 where no
%         current branching occurs within 2 m.
%     k5  site influences (altitude), Tabelle 13-14. Implemented below.
%
%   STANDARDS
%     No IEC/IEEE requirement found for this item. IEC 61439-1 requires
%     temperature-rise verification of assemblies but publishes no busbar
%     ampacity or altitude-derating tables; above 2000 m it makes the
%     conditions subject to agreement between manufacturer and user.
%
%   NOT EXECUTED: statically reviewed only, no MATLAB runtime was
%   available when this was written.

arguments
    opts.Painted      (1,1) logical
    opts.nBars        (1,1) double {mustBePositive, mustBeInteger}
    opts.Width_mm     (1,1) double {mustBePositive}
    opts.Thickness_mm (1,1) double {mustBePositive}
    opts.Orientation  (1,:) char {mustBeMember(opts.Orientation, ...
                            {'horizontal','vertical'})} = 'horizontal'
    opts.RunLength_m  (1,1) double = NaN
    opts.Altitude_m   (1,1) double = 0
    opts.Location     (1,:) char {mustBeMember(opts.Location, ...
                            {'indoor','outdoor'})} = 'indoor'
    opts.k1           (1,1) double = NaN
    opts.k2           (1,1) double = NaN
    opts.k3           (1,1) double = NaN
    opts.k4           (1,1) double = NaN
    opts.k5           (1,1) double = NaN
end

K = struct();

%% ---------------- k1: conductivity -------------------------------------
if ~isnan(opts.k1)
    K.k1 = opts.k1;
    K.k1_source = 'user override';
    K.k1_rule   = 'override';
else
    K.k1 = 1;
    K.k1_source = 'default 1 (no conductivity data supplied)';
    K.k1_rule   = 'default';
end

%% ---------------- k2: temperature --------------------------------------
if ~isnan(opts.k2)
    K.k2 = opts.k2;
    K.k2_source = 'user override (read from Bild 13-4)';
    K.k2_rule   = 'override';
else
    K.k2 = 1;
    K.k2_rule   = 'default';
    K.k2_source = ['default 1 (reference 35/65 degC; Bild 13-4 not ' ...
                   'digitised - supply k2 explicitly if temperatures differ)'];
end

%% ---------------- k3: arrangement / position ---------------------------
if ~isnan(opts.k3)
    K.k3 = opts.k3;
    K.k3_source = 'user override';
    K.k3_rule   = 'override';
else
    [K.k3, K.k3_source, K.k3_rule] = k3FromTable1313( ...
        opts.nBars, opts.Width_mm, opts.Thickness_mm, ...
        opts.Painted, opts.Orientation, opts.RunLength_m);
end

%% ---------------- k4: current displacement -----------------------------
if ~isnan(opts.k4)
    K.k4 = opts.k4;
    K.k4_source = 'user override';
    K.k4_rule   = 'override';
else
    K.k4 = 1;
    K.k4_source = 'fixed 1 (frequency carried by the base-table band)';
    K.k4_rule   = 'fixed';
end

%% ---------------- k5: altitude -----------------------------------------
if ~isnan(opts.k5)
    K.k5 = opts.k5;
    K.k5_source = sprintf('user override at %g m', opts.Altitude_m);
    K.k5_rule   = 'override';
else
    [K.k5, K.k5_source, K.k5_rule] = ...
        busbar_altitude_factor(opts.Altitude_m, opts.Location);
end

%% ---------------- product ----------------------------------------------
K.kTotal = K.k1 * K.k2 * K.k3 * K.k4 * K.k5;

end

%% ========================================================================
function [k3, src, rule] = k3FromTable1313(nBars, W, T, painted, orientation, L)
%K3FROMTABLE1313  Arrangement factor, BBC Schaltanlagen-Handbuch Tab. 13-13.
%
%   Tabelle 13-13 applies to bars in HORIZONTAL position, or to vertical
%   runs LONGER THAN 2 m. A short vertical run is not derated.
%
%   Tabulated rows (painted / bare):
%       2 bars,  W =  50..200,  T = 5..10   ->  0.85 / 0.80
%       3 bars,  W =  50.. 80,  T = 5..10   ->  0.85 / 0.80
%       3 bars,  W = 100..120,  T = 5..10   ->  0.80 / 0.75
%       4 bars,  W = 160,       T = 5..10   ->  0.75 / 0.70
%       4 bars,  W = 200,       T = 5..10   ->  0.70 / 0.65
%   (The closed-tube row of Tabelle 13-13, 0.95/0.90, is not implemented -
%   this tool has no tube profiles.)
%
%   A SINGLE bar has no entry in Tabelle 13-13 and is not derated: k3 = 1.

VERTICAL_EXEMPT_LENGTH_M = 2;   % Tabelle 13-13 scope note

% Position exemption ----------------------------------------------------
if strcmpi(orientation, 'vertical') && ~isfinite(L)
    warning('busbar_k_factors:UnknownVerticalRunLength', ...
        ['A vertical section has no run length. Tab. 13-13 exempts ' ...
         'vertical runs of %g m or less, so the derating is applied ' ...
         'conservatively. Enter the run length to remove this ' ...
         'assumption.'], VERTICAL_EXEMPT_LENGTH_M);
end
if strcmpi(orientation, 'vertical') && isfinite(L) && ...
        L <= VERTICAL_EXEMPT_LENGTH_M
    k3   = 1;
    src  = sprintf(['Tab. 13-13 not applicable: vertical run of %.2f m ' ...
                   '(<= %g m)'], L, VERTICAL_EXEMPT_LENGTH_M);
    rule = 'vertical_exempt';
    return
end

% Single bar ------------------------------------------------------------
if nBars == 1
    k3   = 1;
    src  = 'Tab. 13-13 has no single-bar entry; not derated';
    rule = 'single_bar';
    return
end

% Thickness validity ----------------------------------------------------
T_MIN = 5; T_MAX = 10;   % [mm], validity range of Tabelle 13-13
if T < T_MIN || T > T_MAX
    warning('busbar_k_factors:ThicknessOutOfTable', ...
        ['Bar thickness %g mm is outside the Tab. 13-13 validity range ' ...
         '%g..%g mm. k3 is applied anyway; verify against the source ' ...
         'table.'], T, T_MIN, T_MAX);
end

% Table lookup ----------------------------------------------------------
%          nBars  Wmin  Wmax  k3_painted  k3_bare
TAB = [        2,   50,  200,      0.85,    0.80
               3,   50,   80,      0.85,    0.80
               3,  100,  120,      0.80,    0.75
               4,  160,  160,      0.75,    0.70
               4,  200,  200,      0.70,    0.65 ];

row = find(TAB(:,1) == nBars & W >= TAB(:,2) & W <= TAB(:,3), 1);

if isempty(row)
    error('busbar_k_factors:NoTab1313Entry', ...
        ['No Tabelle 13-13 entry for %d bars of width %g mm. Supply k3 ' ...
         'explicitly, or correct the profile.'], nBars, W);
end

if painted
    k3 = TAB(row,4);  finish = 'painted';
else
    k3 = TAB(row,5);  finish = 'bare';
end

src  = sprintf('Tab. 13-13: %d bars, W = %g..%g mm, %s', ...
    nBars, TAB(row,2), TAB(row,3), finish);
rule = 'table';

end
