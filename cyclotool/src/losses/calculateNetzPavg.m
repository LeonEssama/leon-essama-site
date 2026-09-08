function Pavg = calculateNetzPavg( ...
    u_M, Speed, UM, i_M, IM, cosphi_M, g_Faktor, Uv0N, u_Lstar, SCmin, deltaBeta)
%CALCULATENETZPAVG  Average network-side active power over one half-cycle.
%
%   Pavg = calculateNetzPavg(u_M, Speed, UM, i_M, IM, cosphi_M, g_Faktor, ...
%       Uv0N, u_Lstar, SCmin, deltaBeta)
%
%   Sweeps the firing angle Beta from 0.5 deg to 180 deg (step deltaBeta),
%   builds the instantaneous DC voltage waveform (trapezoidal in the flat
%   -top / "Trapezbetrieb" region, sinusoidal otherwise) and the
%   instantaneous DC current waveform, then averages the resulting
%   instantaneous power to get the 3-phase average power.
%
%   Note: Uv0N, u_Lstar and SCmin are accepted for interface consistency
%   with calculateNetzIL1 (same call signature is reused by solveUM) but
%   are not used in this particular power calculation.
%
%   Calculation logic is unchanged from the original; only the Beta sweep
%   has been vectorized (identical math, no loop).

if deltaBeta <= 0
    error('calculateNetzPavg:InvalidStep', 'deltaBeta must be positive.');
end
if g_Faktor == 0
    error('calculateNetzPavg:ZeroGFactor', 'g_Faktor must be nonzero.');
end

Udmax = sqrt(2/3) * UM / g_Faktor;

if Speed < 1
    % Special ABB creeping mode: fixed 30-degree flank, sinusoidal Ud.
    Trapezbetrieb = false;
    Udvirt = u_M * sqrt(2/3) * UM;
else
    Flanke = (1/0.6) * (1.3 - sqrt(2/3) * UM * u_M / Udmax);
    if Flanke >= 0.5
        Trapezbetrieb = false;
        Flanke = 0.5;
        Udvirt = u_M * sqrt(2/3) * UM;
    else
        Trapezbetrieb = true;
        Udvirt = Udmax / sin(Flanke * pi);
    end
end

%% Vectorized Beta sweep (0.5 deg to 180 deg)
Beta    = (0.5:deltaBeta:180)';
Beta_Pi = Beta * pi / 180;

Ud_x = Udvirt * sin(Beta_Pi);
if Trapezbetrieb
    flatTop = Beta > Flanke * 180 & Beta < (1 - Flanke) * 180;
    Ud_x(flatTop) = Udmax;
end

Id_x = sqrt(2) * IM * i_M * sin(Beta_Pi - acos(cosphi_M));

P_x = abs(Id_x .* Ud_x);

Pavg = 3 * mean(P_x);

end
