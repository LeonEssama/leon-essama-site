function Loss = calculateLosses(Input, DimResult, Thy, Speed, uLcase, Psh, PshNom)
%CALCULATELOSSES  Converter, machine and transformer loss breakdown.
%
%   Loss = calculateLosses(Input, DimResult, Thy, Speed, uLcase, Psh, PshNom)
%
%   Computes:
%     - Converter losses: thyristor conduction/switching + snubber losses
%     - Machine losses: ABB current/voltage/friction-windage split,
%       scaled by speed ratio and operating point (uLcase, Speed vs.
%       nominal) exactly as in the original ABB loss model. All three
%       components (current/voltage/friction-windage) use the FIXED
%       nominal shaft power PshNom as their base, not the
%       per-operating-point Psh -- constant-torque assumption below
%       base speed, per user-reported correction: each component must
%       equal its BaseSpeed/uL=1 value at every point except where its
%       own speed-ratio/uLcase scaling factor explicitly changes it
%       (Creeping/MinSpeed for voltage/friction-windage; field weakening,
%       Speed>=n_nom & uLcase<1, for all three).
%     - Transformer losses: no-load + load losses scaled by uLcase^2
%     - Air/water cooling split (PV_Luft/PV_Wasser/PV_TotRes), per the
%       MEGADRIVE-CYCLO VBA (Verlustrechnung, P. Burmeister, 2000):
%         Water-cooled: PV_Luft = k_res*PV_Zus
%                       PV_Wasser = k_res*(PV_Th+PV_Besch)
%         Air-cooled:   PV_Luft = k_res*(PV_Th+PV_Besch+PV_Zus)
%                       PV_Wasser = 0
%         PV_TotRes = PV_Luft + PV_Wasser
%       The VBA's PV_3GL and PV_Si terms are omitted here (out of scope
%       for this tool -- no n(s)>1 series-thyristor or fuse-datasheet
%       inputs exist), so PV_Wasser is not identical to the VBA's for a
%       converter that has a fuse and/or n(s)>1.
%     - Total loss and required input power (Psh + Loss.Total)
%
%   Calculation logic is unchanged from the original, except k_res is
%   now Input.k_res (a GUI input, "k(Reserve)" on the VBA's Verluste
%   sheet) instead of a hardcoded 1.05.

if Input.eta_M <= 0
    error('calculateLosses:InvalidEfficiency', 'Input.eta_M must be > 0.');
end
if uLcase == 0
    error('calculateLosses:ZeroULcase', 'uLcase must be nonzero.');
end

Loss = struct();

%% -------------------------------------------------
% ABB Converter Losses
%% -------------------------------------------------
n_DB = Input.PulseNumber;
n_Th = 6 * n_DB;

% Number of secondary transformer windings (1/2/3 for 6/12/18-pulse).
% DimResult.Uv0N is the per-winding (per 6-pulse bridge-group) voltage
% times N_series when computed by the dimensioning stage for a >6-pulse
% converter -- consistent with N_SerieN = PulseNumber/6 already used
% for the thyristor voltage-class check in calculate.m/cyclo_dimensioning.m.
% The individual-snubber ("Einzelbeschaltung") loss formula needs the
% per-winding value, so Uv0N must be divided back down by N_series here.
N_series = Input.PulseNumber / 6;

PVSch = DimResult.PVS;

PV_Th = n_DB * ...
    (Thy.UT0 * Input.IM * 2 * sqrt(2) / pi + Thy.rT * Input.IM^2) + ...
    PVSch * n_Th / 2;
Loss.PV_Th = PV_Th;

n_B = n_Th / 2;
PV_Besch = n_B * (1.75 * Input.fL * Input.CB * ...
    (uLcase * DimResult.Uv0N/N_series * sqrt(2))^2);
Loss.PV_Besch = PV_Besch;

% Exposed so callers needing the PER-DEVICE loss (e.g. the Water
% Cooling Design "Thy Loss"/"Resistor Loss" inputs, which are per one
% thyristor / per one snubber resistor, per cooling-can (KD) branch --
% not the whole-converter totals PV_Th/PV_Besch above) can divide by
% them: PV_Th / n_Th and PV_Besch / (n_Th/N_series) respectively.
Loss.n_Th = n_Th;
Loss.N_series = N_series;

PV_Zus = 0;
Loss.PV_Zus = PV_Zus;

if isfield(Input,'k_res')
    k_res = Input.k_res;   % Safety/rounding factor, VBA "k(Reserve)"
else
    k_res = 1.1;   % Default for a dimensioning result saved before
                    % k_res was a GUI input (was hardcoded 1.05 then)
end
Loss.Converter = k_res * (PV_Th + PV_Besch + PV_Zus);

%% -------------------------------------------------
% Air / Water Cooling Split
%% -------------------------------------------------
if strcmpi(Input.Cooling,'Water')
    PV_Luft   = k_res * PV_Zus;
    PV_Wasser = k_res * (PV_Th + PV_Besch);
else
    PV_Luft   = k_res * (PV_Th + PV_Besch + PV_Zus);
    PV_Wasser = 0;
end
Loss.PV_Luft   = PV_Luft;
Loss.PV_Wasser = PV_Wasser;
Loss.PV_TotRes = PV_Luft + PV_Wasser;

%% -------------------------------------------------
% ABB Machine Loss Model
%% -------------------------------------------------
etaM = Input.eta_M;
% Fixed nominal reference for all three machine-loss components -- see
% the function header. Independent of this row's (possibly
% speed-reduced) Psh; the row-varying speed/voltage scaling is applied
% explicitly below instead.
PmachineNominalRated = PshNom * (1/etaM - 1);

% ABB fixed split of nominal machine losses
PcurrentBase = 0.30 * PmachineNominalRated;
PvoltageBase = 0.50 * PmachineNominalRated;
PfwBase      = 0.20 * PmachineNominalRated;

speedRatio = Speed / Input.n_nom;

%% Current-dependent component
if Speed < Input.n_nom
    % Creeping + MinSpeed
    Pcurrent = PcurrentBase;
elseif uLcase < 1
    % BaseSpeed + MaxSpeed, field weakening
    Pcurrent = PcurrentBase / uLcase;
else
    Pcurrent = PcurrentBase;
end

%% Voltage-dependent component
if Speed < Input.n_nom
    % Creeping + MinSpeed
    Pvoltage = PvoltageBase * speedRatio;
elseif uLcase < 1
    % BaseSpeed + MaxSpeed, field weakening
    Pvoltage = PvoltageBase * uLcase^2;
else
    Pvoltage = PvoltageBase;
end

%% Friction & windage (speed-squared)
Pfw = PfwBase * speedRatio^2;

Loss.MachineCurrent = Pcurrent;
Loss.MachineVoltage = Pvoltage;
Loss.MachineFW      = Pfw;
Loss.Machine        = Pcurrent + Pvoltage + Pfw;

%% -------------------------------------------------
% Transformer Losses
%% -------------------------------------------------
nTransformer = 3;
P0 = Input.TrafoP0_kW * 1000;
Pk = Input.TrafoPk_kW * 1000;

Loss.Transformer = nTransformer * (Pk + P0 * uLcase^2);

%% -------------------------------------------------
% Total Losses & Required Input Power
%% -------------------------------------------------
Loss.Total = Loss.Machine + Loss.Transformer + Loss.Converter;
Loss.Pin   = Psh + Loss.Total;

end
