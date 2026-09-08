function H = harmonic_calculation(Input, R)
%HARMONIC_CALCULATION  Line-side current/voltage harmonic spectrum.
%
%   H = harmonic_calculation(Input, R)
%
%   Based on the original ABB VBA "OS" harmonic model: computes the
%   commutation overlap angle u, then for each characteristic harmonic
%   order (5, 7, 11, ... 49) the current harmonic percentage (KI),
%   absolute harmonic current (IL), and voltage harmonic percentage (KU)
%   from the network short-circuit power. Applies the VBA 5th-harmonic
%   correction factor, then reports THD-U (up to the 25th, and total)
%   and THD-I.
%
%   Calculation logic is unchanged from the original; the per-harmonic
%   for-loop has been vectorized (identical math, no loop), and the
%   fprintf/disp debug statements from the original have been removed
%   (they printed intermediate values to the console on every call).

alpha = pi/2;   % VBA default a(N) = 90 deg
dx = R.dxN / R.uL_used;
if dx <= 0
    error('harmonic_calculation:InvalidDx', 'dx must be positive.');
end

I1S = R.I1S;
PulseNumber = Input.PulseNumber;
w = 0.1;

ULgrid = R.Uv0N;   % Secondary side of transformer U(L)
Uv0N   = R.Uv0N;   % Converter voltage

SCC = Input.SC_min;
if isfield(Input, 'SCact')
    SCC = Input.SCact;
end

%% Commutation overlap angle (argument clamped to avoid complex result)
arg = max(-1, min(1, cos(alpha) - 2*dx));
u = acos(arg) - alpha;
H.u = u;

%% Harmonic orders
H.HOrder = [5; 7; 11; 13; 17; 19; 23; 25; 29; 31; 35; 37; 41; 43; 47; 49];

%% Apparent power / fundamental line current
S = sqrt(3) * Uv0N * I1S;
IL1 = S / (sqrt(3) * ULgrid);
H.IL1 = IL1;
H.Sharm = S;
H.SCact = SCC;

%% Vectorized harmonic calculation
h = H.HOrder;
coeff = unsymmetryCoeff(h, PulseNumber);
A = coeffA(h, u);
B = coeffB(h, u);

KI = coeff .* (1./h) .* (1/(2*dx)) .* ...
    sqrt(A.^2 + B.^2 - 2*A.*B*cos(2*alpha + u));

H.KI = 100 * KI;
H.IL = H.KI/100 * IL1;
H.KU = H.KI .* h * S / SCC;

%% VBA correction factor for the 5th harmonic (first entry)
korr5 = 5 * (1/5 + 6.46*2*w/4 - 7.13*2*w/5);
H.KI(1) = H.KI(1) * korr5;
H.IL(1) = H.IL(1) * korr5;
H.KU(1) = H.KU(1) * korr5;

%% Voltage distortion (up to the 25th, and total)
idx25 = H.HOrder <= 25;
H.ku25  = sqrt(sum(H.KU(idx25).^2));
H.kuTot = sqrt(sum(H.KU.^2));

%% Current THD
H.THDi = sqrt(sum(H.KI.^2));

end

%% ==========================================================
function y = coeffA(N, u)
%COEFFA  VBA coefficient a(N,u).
y = sin((N-1).*u/2) ./ (N-1);
end

%% ==========================================================
function y = coeffB(N, u)
%COEFFB  VBA coefficient b(N,u).
y = sin((N+1).*u/2) ./ (N+1);
end

%% ==========================================================
function coeff = unsymmetryCoeff(h, pulse)
%UNSYMMETRYCOEFF  VBA unsymmetry coefficient, vectorized over harmonic order h.
coeff = ones(size(h));
switch pulse
    case 12
        coeff(ismember(h, [5 7 17 19 29 31 41 43])) = 0.10;
    case 18
        coeff(ismember(h, [5 7 11 13 23 25 29 31 41 43 47 49])) = 0.15;
    case 24
        coeff(ismember(h, [5 7 17 19 29 31 41 43])) = 0.10;
        coeff(ismember(h, [11 13 35 37])) = 0.20;
end
end
