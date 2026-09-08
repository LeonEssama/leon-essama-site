function uM = solveUM( ...
    targetPin, Speed, UM, i_M, IM, cosphi_M, g_Faktor, Uv0N, u_Lstar, SCmin, deltaBeta)
%SOLVEUM  Solve for u_M such that calculateNetzPavg(u_M, ...) = targetPin.
%
%   uM = solveUM(targetPin, Speed, UM, i_M, IM, cosphi_M, g_Faktor, Uv0N, ...
%       u_Lstar, SCmin, deltaBeta)
%
%   Strategy:
%     1. Bracket a sign change of f(u) = Pavg(u)/targetPin - 1 by
%        expanding the upper bound geometrically.
%     2. If a bracket is found, solve with fzero (robust, no derivative).
%     3. Otherwise fall back to an unconstrained least-squares search
%        (fminsearch) as a best-effort solution.
%     4. Sanity-check the sensitivity of Pavg to u_M and warn if the
%        Netz model appears saturated (i.e. barely changes over a
%        1..2 pu range), and verify the final solution meets a 1% target
%        tolerance.
%
%   Calculation logic and tolerances are unchanged from the original.

TOL = 0.01;             % 1% target tolerance
LB0 = 0.05;             % Initial lower bound for u_M
UB0 = 1.0;              % Initial upper bound for u_M
UB_GROWTH = 1.5;        % Bracket expansion factor
UB_MAX = 20;            % Maximum bracket to try before giving up

if targetPin == 0
    error('solveUM:ZeroTarget', 'targetPin must be nonzero.');
end

netzPavg = @(u) calculateNetzPavg( ...
    u, Speed, UM, i_M, IM, cosphi_M, g_Faktor, Uv0N, u_Lstar, SCmin, deltaBeta);
f = @(u) netzPavg(u) / targetPin - 1;

%% Find an upper bound that brackets the root
LB = LB0;
UB = UB0;
fLB = f(LB);
fUB = f(UB);

while sign(fLB) == sign(fUB) && UB <= UB_MAX
    UB = UB * UB_GROWTH;
    fUB = f(UB);
end

%% Root solution
if sign(fLB) ~= sign(fUB)
    uM = fzero(f, [LB UB]);
else
    % No sign change found within range: fall back to least-squares search
    objective = @(u) f(u)^2;
    options = optimset( ...
        'Display', 'off', ...
        'TolX', 1e-8, ...
        'TolFun', 1e-8, ...
        'MaxFunEvals', 5000, ...
        'MaxIter', 5000);
    uM = fminsearch(objective, UB, options);
end

%% Sensitivity check (is the Netz model saturated w.r.t. u_M?)
P1 = netzPavg(1.0);
P2 = netzPavg(2.0);
if abs(P2 - P1) / max(P1, 1) < 0.01
    warning('solveUM:ModelSaturation', ...
        'Pavg nearly insensitive to u_M. Possible Netz model saturation.');
end

%% Verification against target tolerance
Pavg = netzPavg(uM);
ratio = Pavg / targetPin;
if abs(ratio - 1) > TOL
    warning('solveUM:ToleranceNotMet', ...
        'Could not meet 1%% tolerance. Final ratio = %.4f', ratio);
end

end
