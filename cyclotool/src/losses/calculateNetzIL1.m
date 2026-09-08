function Result = calculateNetzIL1( ...
    u_M, UM, i_M, IM, cosphi_M, g_Faktor, Uv0N, u_L, u_Lstar, UL, SCmin, deltaBeta)
%CALCULATENETZIL1  Network-side line current, power and power factor.
%
%   Result = calculateNetzIL1(u_M, UM, i_M, IM, cosphi_M, g_Faktor, Uv0N, ...
%       u_L, u_Lstar, UL, SCmin, deltaBeta)
%
%   Sweeps the firing angle Beta from 0.5 deg to 180 deg, builds the
%   instantaneous DC voltage/current waveforms (same trapezoidal model as
%   calculateNetzPavg), derives the commutation-notch corrected apparent
%   power (via the short-circuit-limited reactive power term), and
%   returns the resulting average P, Q, S, line current and cosphi.
%
%   Output (Result struct):
%       Pavg, Qavg, Savg, IL1, cosphiL, Flanke, Udmax, Udvirt, Trapezbetrieb
%
%   Note: u_L is accepted for interface consistency but not used directly
%   in this formula (kept for compatibility with existing callers).
%
%   Calculation logic is unchanged from the original; only the Beta sweep
%   has been vectorized (identical math, no loop).

if deltaBeta <= 0
    error('calculateNetzIL1:InvalidStep', 'deltaBeta must be positive.');
end
if g_Faktor == 0
    error('calculateNetzIL1:ZeroGFactor', 'g_Faktor must be nonzero.');
end
if SCmin == 0
    error('calculateNetzIL1:ZeroSCmin', 'SCmin must be nonzero.');
end

Udmax = (1 / g_Faktor) * sqrt(2/3) * UM;
Flanke = (1/0.6) * (1.3 - sqrt(2/3) * UM * u_M / Udmax);

if ~(Flanke < 0.5)
    Trapezbetrieb = false;
    Flanke = 0.5;
    Udvirt = u_M * sqrt(2/3) * UM;
else
    Trapezbetrieb = true;
    Udvirt = Udmax / sin(Flanke * pi);
end

%% Vectorized Beta sweep (0.5 deg to 180 deg)
Beta    = (0.5:deltaBeta:180)';
Beta_Pi = Beta * pi / 180;

Ud_x = Udvirt * sin(Beta_Pi);
if Trapezbetrieb
    flatTop = Beta > Flanke * 180 & Beta < (1 - Flanke) * 180;
    Ud_x(flatTop) = Udmax;
end

arg = Ud_x / (u_Lstar * (sqrt(18)/pi) * Uv0N);
arg = max(min(arg, 1), -1);
Phi_x_Strich = acos(arg);

Id_x = sqrt(2) * IM * i_M * sin(Beta_Pi - acos(cosphi_M));

Pdi0_x = (sqrt(18)/pi) * Uv0N * Id_x;

tanphi_x = (1 ./ cos(Phi_x_Strich)) .* ...
    (sin(Phi_x_Strich) - abs(Pdi0_x) / SCmin);

P_x = abs(Id_x .* Ud_x);
Q_x = abs(P_x .* tanphi_x);

Pavg = 3 * mean(P_x);
Qavg = 3 * mean(Q_x);
Savg = sqrt(Pavg^2 + Qavg^2);
cosphiL = Pavg / Savg;
IL1 = Savg / (sqrt(3) * u_Lstar * UL);

Result = struct( ...
    'Pavg', Pavg, ...
    'Qavg', Qavg, ...
    'Savg', Savg, ...
    'IL1', IL1, ...
    'cosphiL', cosphiL, ...
    'Flanke', Flanke, ...
    'Udmax', Udmax, ...
    'Udvirt', Udvirt, ...
    'Trapezbetrieb', Trapezbetrieb);

end
