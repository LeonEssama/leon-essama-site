function R = calculate(Input)
%CALCULATE  Core cycloconverter dimensioning calculation.
%
%   R = calculate(Input) performs the full electrical/thermal
%   dimensioning of the converter for a given operating point:
%     - Current dimensioning (arm, system and waveform currents)
%     - Voltage dimensioning (iterative Uv0N solve against commutation
%       reactance dxN)
%     - Short-circuit current (IkN) and voltage-class checks
%     - Iterative thyristor junction-temperature (Tj) solve
%     - Recovery time, snubber sizing, and all engineering margins
%     - Pass/fail checks bundled into R.SOA_OK
%
%   All formulas are unchanged from the original. This version:
%     - Removes two dead-code duplicate field assignments that were
%       silently overwritten later in the original (R.I1S was computed
%       once early and once from I1S_used; only the second value was
%       ever used. R.VoltageMarginOK was likewise computed once without
%       the 1% tolerance and once with it; only the toleranced value was
%       ever used in R.SOA_OK). Final output values are identical.
%     - Adds a small set of divide-by-zero guards and an iteration cap
%       on the Uv0N convergence loop (with a warning if it does not
%       converge), mirroring the cap already present on the thermal
%       loop below.
%     - Reformats the arithmetic for readability; no formula changed.
%     - Resolves R.Ls_used / R.Ls_source: either Input.Ls as supplied
%       (manual entry) or, when Input.LsMode is 'Estimate
%       (Salient-Pole)', a nameplate-based engineering estimate via
%       estimate_salient_pole_Ls.m. Ls itself is not consumed by any
%       formula in this function -- this only makes a single,
%       traceable value available to downstream consumers.

%% ==========================================================
% INPUTS
%% ==========================================================
Thy = Input.Thy;
UM          = Input.UM;
IM          = Input.IM;
PulseNumber = Input.PulseNumber;
N_SerieN    = PulseNumber/6;      % Number of series thyristors
u_r         = Input.u_r;
exT         = Input.exT;
u_L         = Input.uL_used;
g_Faktor    = Input.g_Faktor;
overload    = Input.overload;
aN          = Input.a_Nmin;
aN_therm    = pi/2;
SC_min      = Input.SC_min;
k_C         = Input.k_C;
fL          = Input.fL;

if g_Faktor == 0
    error('calculate:ZeroGFactor', 'Input.g_Faktor must be nonzero.');
end
if u_L == 0
    error('calculate:ZeroULused', 'Input.uL_used must be nonzero.');
end
if PulseNumber == 0
    error('calculate:ZeroPulseNumber', 'Input.PulseNumber must be nonzero.');
end
if SC_min == 0
    error('calculate:ZeroSCmin', 'Input.SC_min must be nonzero.');
end

%% ==========================================================
% Stator inductance Ls (per-phase series R-L stator model)
%% ==========================================================
% ENGINEERING ESTIMATE -- see estimate_salient_pole_Ls.m for the
% formula and its assumptions (salient-pole synchronous motor,
% scalar Xd'' reactance). This function does not use Ls in any
% formula below; it is resolved once here, with full traceability
% (R.Ls_used, R.Ls_source, R.Ls_info), so a single consistent value
% is available to any downstream consumer (e.g. the detailed
% simulation stage) regardless of whether the Motor tab supplied Ls
% manually or asked for the salient-pole estimate.
if isfield(Input,'LsMode') && ...
        strcmpi(Input.LsMode,'Estimate (Salient-Pole)')

    if ~isfield(Input,'Xdpp_pu') || isempty(Input.Xdpp_pu) || ...
            isnan(Input.Xdpp_pu)
        error('calculate:MissingXdpp', ...
            ['Input.LsMode requests the salient-pole Ls estimate but ', ...
            'Input.Xdpp_pu (assumed subtransient reactance, per unit) ', ...
            'was not supplied.']);
    end
    if ~isfield(Input,'n_nom') || ~isfield(Input,'PolePairs')
        error('calculate:MissingMotorSpeedData', ...
            ['Input.LsMode requests the salient-pole Ls estimate but ', ...
            'Input.n_nom and/or Input.PolePairs was not supplied.']);
    end

    [R.Ls_used, R.Ls_info] = estimate_salient_pole_Ls( ...
        UM, IM, Input.n_nom, Input.PolePairs, Input.Xdpp_pu);
    R.Ls_source = 'Estimated (salient-pole, Xdpp assumption)';

elseif isfield(Input,'Ls') && ~isempty(Input.Ls) && ~isnan(Input.Ls) && ...
        Input.Ls > 0

    R.Ls_used   = Input.Ls;
    R.Ls_source = 'Manual entry';

else
    error('calculate:MissingLs', ...
        ['Input.Ls was not supplied and Input.LsMode does not request ', ...
        'the salient-pole estimate. Provide a stator inductance value ', ...
        'or switch the Motor tab Ls Source to Estimate (Salient-Pole).']);
end

%% ==========================================================
% Uv0 Max / kN minimum
%% ==========================================================
DeltaUL = 1 + (1 - u_L);
R.Uv0Max = N_SerieN * Thy.UDRM / (2*sqrt(2)*DeltaUL);
R.kN_min = 2*DeltaUL;

%% ==========================================================
% Converter mode
%% ==========================================================
if g_Faktor > 1
    uR  = 1;
    x_L = 1;
    y_L = u_L;
else
    uR  = 1.02;
    x_L = u_L;
    y_L = 1;
end
if y_L == 0
    error('calculate:ZeroYL', 'y_L evaluated to zero (check uL_used).');
end

%% ==========================================================
% Current dimensioning
%% ==========================================================
R.Psh        = overload * sqrt(3) * UM * IM * Input.cosphi_M * Input.eta_M;
R.Id_DBeff   = overload * 0.5 * sqrt(2) * IM / y_L;
R.Id_DBpeak  = overload * sqrt(2) * IM / y_L;
R.Id_DBmax   = Input.startup * sqrt(2) * IM;

%% ==========================================================
% VBA Waveform Currents
% Source: Excel VBA MEGADRIVE CYCLO
%% ==========================================================
R.IM_uL      = IM / u_L;
R.IM_ovld    = IM * Input.overload;
R.IM_ovld_uL = IM * Input.overload / u_L;
R.IM_start   = IM * Input.startup;

R.Id_DBeff_nom   = IM / (u_L * sqrt(2));
R.Id_DBpeak_nom  = 2 * R.Id_DBeff_nom;
R.Id_DBeff_ovld  = Input.overload * IM / (u_L * sqrt(2));
R.Id_DBpeak_ovld = 2 * R.Id_DBeff_ovld;

if Input.sicherung == 0
    R.ISi = NaN;
else
    R.ISi = Input.k_alt * Input.overload * sqrt(Input.sicherung/3) * IM / u_L;
end

R.I1S_nom   = sqrt(2/3) * IM / u_L / (pi/3);
R.I1S_ovld  = Input.overload * sqrt(2/3) * IM / u_L / (pi/3);
R.I1S_start = Input.startup * sqrt(2/3) * IM / (pi/3);

%% ==========================================================
% Operating Point Selection
%% ==========================================================
I1S_used = Input.I1S_used;
IM_used  = Input.IM_used;
uL_used  = Input.uL_used;

R.I1S_used = I1S_used;
R.IM_used  = IM_used;
R.uL_used  = uL_used;
R.I1S      = I1S_used;   % Actual operating-point system current

R.Id_DBeff_used  = IM_used / sqrt(2);
R.Id_DBpeak_used = sqrt(2) * IM_used;

if strcmpi(Input.Mode, 'rms')
    R.Id_DBeff = IM_used / sqrt(2);
elseif strcmpi(Input.Mode, 'peak')
    R.Id_DBeff  = Input.IM / sqrt(2);   % ABB Therm keeps RMS equivalent
    R.Id_DBpeak = sqrt(2) * IM_used;
end

R.Iv_used  = sqrt(2/3) * IM_used;
R.Iv_nom   = sqrt(2/3) * IM / u_L;
R.Iv_ovld  = Input.overload * sqrt(2/3) * IM / u_L;
R.Iv_start = Input.startup * sqrt(2/3) * IM;

%% ==========================================================
% Voltage dimensioning (iterative Uv0N solve)
%% ==========================================================
R.Udmax = (1/g_Faktor) * sqrt(2/3) * UM;

d_c = 0.008;
dxN = (pi/3) * exT/2;
err = 1;
MAX_ITER = 500;
iterCount = 0;

while err > 1e-5
    iterCount = iterCount + 1;
    if iterCount > MAX_ITER
        warning('calculate:UvConvergence', ...
            'Uv0N iteration did not converge after %d iterations (err = %.3g).', ...
            MAX_ITER, err);
        break;
    end

    dxOld = dxN;
    den = x_L*cos(aN) - (dxN + Input.d_r)*sqrt(2)*overload - d_c;
    if den == 0
        error('calculate:ZeroDenominator', ...
            'Voltage iteration denominator evaluated to zero.');
    end

    R.Udi0N = R.Udmax * u_r * uR / den;
    R.Uv0N  = pi/sqrt(18) * R.Udi0N;
    R.STN   = sqrt(3) * R.Uv0N * I1S_used;
    dxN = (pi/3) * (exT/2 + (3/PulseNumber) * R.STN/SC_min);
    err = abs(1 - dxOld/dxN);
end
R.dxN = dxN;

%% ==========================================================
% IkN (short-circuit current)
%% ==========================================================
R.IkN = sqrt(2) * I1S_used * k_C / (2*R.dxN);

%% ==========================================================
% Voltage checks
%% ==========================================================
R.k_N = N_SerieN * Thy.UDRM / (sqrt(2) * R.Uv0N);
R.Uv0ClassOK = (R.Uv0N <= R.Uv0Max);

%% ==========================================================
% Actual thyristor voltage
%% ==========================================================
R.Uv = uL_used * sqrt(2) * R.Uv0N / N_SerieN * sin(aN_therm);

%% ==========================================================
% Actual di/dt
%% ==========================================================
R.didtv  = pi*fL*sqrt(3/2) * I1S_used/R.dxN * uL_used * sin(aN_therm) / 1e6;
R.didt90 = pi*fL*sqrt(3/2) * I1S_used/R.dxN * uL_used / 1e6;

%% ==========================================================
% Thermal resistances
%% ==========================================================
Rthjc = Thy.Rth_jc / 1000;
Rthch = Thy.Rth_ch / 1000;
Rthha = Thy.Rth_ha / 1000;
R.Rthtot = Rthjc + Rthch + Rthha;

%% ==========================================================
% Iterative thermal computation (junction temperature Tj)
%% ==========================================================
Tj = 1;
TjHist = [];
for iter = 1:200
    if Thy.i + Thy.j*Tj/Thy.Tj_b > 1
        f_Tj = Thy.i + Thy.j*Tj/Thy.Tj_b;
    else
        f_Tj = 1;
    end

    PVS = 1.05/Thy.PL_ThS_b ...
        * (Thy.a*(R.Uv/Thy.Uv0_b) + Thy.b*(R.Uv/Thy.Uv0_b)^2) ...
        * (Thy.c*(R.didtv/Thy.di_dt_b) + Thy.d*sqrt(R.didtv/Thy.di_dt_b)) ...
        * fL/Thy.f_b * f_Tj;

    if strcmpi(Input.Mode, 'rms')
        PLTh = ((2*sqrt(2)/pi)*Thy.UT0*IM + Thy.rT*IM^2)/6 + PVS;
    else
        PLTh = (sqrt(2)*IM_used/3)*Thy.UT0 + 3*Thy.rT*(sqrt(2)*IM_used/3)^2 + PVS;
    end

    PLR = NaN;
    Taus_KD = NaN;
    Tein = NaN;
    Tav_KD = NaN;
    red = 0;

    if strcmpi(Input.Cooling, 'Water')
        if PulseNumber == 6*N_SerieN
            red = 1;
        else
            red = 0.85;
        end
        PLR     = 1.75*fL*Input.CB*(R.Uv/red)^2;
        Taus_KD = Input.Taus_max - PLR/1000*60/Input.Qw/4.187;
        Tein    = Taus_KD - 0.5*PLTh/1000*60/Input.Qw/4.187;
        Tav_KD  = Tein;
        TjNew   = PLTh*R.Rthtot + Tav_KD;
    else
        TjNew = Input.Tamb + PLTh*R.Rthtot;
    end

    TjHist(end+1) = TjNew; %#ok<AGROW>
    if abs(1 - TjNew/Tj) < 1e-5
        break
    end
    Tj = TjNew;
end

%% ==========================================================
% Thermal outputs
%% ==========================================================
R.Tj = TjNew;
R.TjMax = TjNew;
R.PVS = PVS;
R.PLTh = PLTh;
R.PLR = PLR;
R.Taus_KD = Taus_KD;
R.Tein = Tein;
R.Tav_KD = Tav_KD;
R.Taus_W = Input.Taus_max;
R.tThermal = 1:length(TjHist);
R.TjVector = TjHist;
R.Rthjc = Rthjc;
R.Rthch = Rthch;
R.Rthha = Rthha;
R.red = red;
R.CB = Input.CB;
R.Qw = Input.Qw;

%% ==========================================================
% Recovery time
%% ==========================================================
R.tq_actual = Thy.tq1 ...
    * (Thy.k + Thy.e*R.Tj + Thy.f*R.Tj^2) ...
    * (Thy.l + Thy.g*R.didtv + Thy.h*sqrt(R.didtv));

%% ==========================================================
% Snubber
%% ==========================================================
R.Csnub = max(Thy.Csnub, R.IkN/(Input.dvdt_limit*1e6));
R.Rsnub = 2*sqrt(Input.Lc/R.Csnub);

%% ==========================================================
% Margins
%% ==========================================================
R.IkN_Margin      = 100 * (Thy.IKS0 - R.IkN) / Thy.IKS0;
R.Uv0Margin       = 100 * (R.Uv0Max - R.Uv0N) / R.Uv0Max;
R.ThermalMargin   = Thy.Tjmax - R.Tj;
R.RecoveryMargin  = (R.tq_actual - 350e-6) * 1e6;
R.DiDt_Margin     = 100 * (Thy.di_dt_b - R.didtv) / Thy.di_dt_b;
R.Tj_Margin       = 100 * (Thy.Tjmax - R.Tj) / Thy.Tjmax;
R.Uv0Target_Error = 100 * (R.Uv0N - Input.Uv0N_target) / Input.Uv0N_target;

%% ==========================================================
% Checks (1% engineering tolerance)
%% ==========================================================
tol = 0.01;
R.ShortCircuitOK  = (R.IkN <= (1+tol)*Thy.IKS0);
R.VoltageMarginOK = (R.k_N >= (1-tol)*R.kN_min);
R.TargetVoltageOK = abs(R.Uv0N - Input.Uv0N_target) <= tol * Input.Uv0N_target;
R.SOA_OK = R.Uv0ClassOK && R.VoltageMarginOK && R.TargetVoltageOK && R.ShortCircuitOK;

R.Thy = Thy;

end
