function Loss = calculateLosses(Input, DimResult, Thy, Speed, uLcase, Psh)
%CALCULATELOSSES  Converter, machine and transformer loss breakdown.
%
%   Loss = calculateLosses(Input, DimResult, Thy, Speed, uLcase, Psh)
%
%   Computes:
%     - Converter losses: thyristor conduction/switching + snubber losses
%     - Machine losses: ABB current/voltage/friction-windage split,
%       scaled by speed ratio and operating point (uLcase, Speed vs.
%       nominal) exactly as in the original ABB loss model
%     - Transformer losses: no-load + load losses scaled by uLcase^2
%     - Total loss and required input power (Psh + Loss.Total)
%
%   Calculation logic is unchanged from the original.

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

PV_Zus = 0;
Loss.PV_Zus = PV_Zus;

k_res = 1.05;   % Empirical safety/rounding factor on converter losses
Loss.Converter = k_res * (PV_Th + PV_Besch + PV_Zus);

%% -------------------------------------------------
% ABB Machine Loss Model
%% -------------------------------------------------
etaM = Input.eta_M;
PmachineNominal = Psh * (1/etaM - 1);

% ABB fixed split of nominal machine losses
PcurrentBase = 0.30 * PmachineNominal;
PvoltageBase = 0.50 * PmachineNominal;
PfwBase      = 0.20 * PmachineNominal;

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
