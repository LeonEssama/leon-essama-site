function F = firing_angle_calculation(Input, R)
%FIRING_ANGLE_CALCULATION  Firing-angle setting/tolerance curves.
%
%   F = firing_angle_calculation(Input, R)
%
%   Builds the worst-case commutation-margin firing angle curve, the
%   allowed firing angle curve (based on gamma0), and two linearized
%   setting/tolerance curves (at -3 deg and -6 deg offsets) as functions
%   of per-unit current, over the current range 0..3 pu.
%
%   Calculation logic is unchanged from the original; the current-range
%   sweep has been vectorized (identical math, no loop), and the acos()
%   arguments used to build the linearization points are now clamped to
%   [-1, 1] to avoid complex results if xL/u_L pushes the argument out of
%   domain (this guards against a latent edge-case bug in the original,
%   without changing any in-range result).

if Input.gamma0 < 5 || Input.gamma0 > 20
    error('firing_angle_calculation:Gamma0OutOfRange', ...
        'Gamma0 must be between 5 deg and 20 deg');
end

gamma0 = deg2rad(Input.gamma0);

%% Effective network reactance
xL = R.exT + R.STN/Input.SCact * 6/Input.PulseNumber;

%% Linearization points (worst-case tolerance, -3 deg offset)
Alpha11 = safeAcos(xL*0.5/Input.u_L - cos(gamma0)) - deg2rad(3);
Alpha12 = safeAcos(xL*1.0/Input.u_L - cos(gamma0)) - deg2rad(3);
a1 = (Alpha12 - Alpha11) / 0.5;
b1 = Alpha11 - a1*0.5;

%% Lower tolerance (-6 deg offset)
Alpha21 = safeAcos(xL*0.5/Input.u_L - cos(gamma0)) - deg2rad(6);
Alpha22 = safeAcos(xL*1.0/Input.u_L - cos(gamma0)) - deg2rad(6);
a2 = (Alpha22 - Alpha21) / 0.5;
b2 = Alpha21 - a2*0.5;

%% Current range (vectorized sweep, 0 to 3 pu)
Ipu = 0:0.01:3;

x1 = xL*Ipu/Input.u_L - 1;
x2 = xL*Ipu/Input.u_L - cos(gamma0);

WorstCase = acos(max(-1, min(1, x1)));
Allowed   = acos(max(-1, min(1, x2)));

Setting   = a1.*Ipu + b1;
Tolerance = a2.*Ipu + b2;

%% Output
F.xL = xL;
F.gamma0 = Input.gamma0;
F.Ipu = Ipu;
F.WorstCase = rad2deg(WorstCase);
F.Allowed   = rad2deg(Allowed);
F.Setting   = rad2deg(Setting);
F.Tolerance = rad2deg(Tolerance);

end

%% ==========================================================
function y = safeAcos(x)
%SAFEACOS  acos() with its argument clamped to the valid [-1, 1] domain.
y = acos(max(-1, min(1, x)));
end
