function [Ls, info] = estimate_salient_pole_Ls(UM, IM, n_nom, PolePairs, Xdpp_pu)
%ESTIMATE_SALIENT_POLE_LS  Engineering estimate of per-phase stator
%inductance for a salient-pole synchronous motor, derived from
%nameplate data and an assumed subtransient reactance.
%
%   [Ls, info] = estimate_salient_pole_Ls(UM, IM, n_nom, PolePairs, Xdpp_pu)
%
%   INPUTS (rated/nameplate values, SI units unless noted):
%     UM         - rated line-to-line stator voltage            [V]
%     IM         - rated stator line current                    [A]
%     n_nom      - rated mechanical speed                        [rpm]
%     PolePairs  - number of pole pairs                          [-]
%     Xdpp_pu    - assumed subtransient reactance Xd'', per unit [pu]
%
%   OUTPUTS:
%     Ls   - estimated per-phase stator inductance                [H]
%     info - struct with intermediate values for traceability:
%              info.Zbase_ohm   - base impedance                  [Ohm]
%              info.f_motor_Hz  - motor rated electrical frequency [Hz]
%              info.Xs_ohm      - stator reactance                [Ohm]
%              info.Xdpp_pu     - the Xdpp_pu input, echoed back
%
%   METHOD (ENGINEERING ESTIMATE -- NOT AN IEC/IEEE-MANDATED FORMULA):
%
%     Zbase   = (UM/sqrt(3)) / IM              [Ohm]
%     f_motor = n_nom * PolePairs / 60         [Hz]
%     Xs      = Xdpp_pu * Zbase                [Ohm]
%     Ls      = Xs / (2*pi*f_motor)            [H]
%
%   ASSUMPTIONS AND LIMITATIONS:
%     - Salient-pole synchronous motor, represented for this estimate
%       by a single scalar subtransient reactance Xd'' -- no
%       distinction between d- and q-axis subtransient values.
%     - Xdpp_pu is assumed defined at the MOTOR's own rated electrical
%       frequency (from n_nom and PolePairs), NOT the supply/grid
%       frequency. For low-speed, high-pole-count, gearless drives
%       these two frequencies can differ by more than an order of
%       magnitude; using the wrong one produces a badly wrong Ls.
%     - No IEC/IEEE requirement specifies Xdpp_pu numerically for an
%       arbitrary machine. Confirm with the manufacturer's test
%       report (IEEE 115 / IEC 60034-4) whenever one is available
%       instead of relying on a typical-range assumption.

validateattributes(UM, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'UM');
validateattributes(IM, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'IM');
validateattributes(n_nom, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'n_nom');
validateattributes(PolePairs, {'numeric'}, ...
    {'scalar','positive','finite','integer'}, mfilename, 'PolePairs');
validateattributes(Xdpp_pu, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'Xdpp_pu');

Zbase = (UM/sqrt(3)) / IM;
f_motor = n_nom * PolePairs / 60;

if f_motor <= 0
    error('estimate_salient_pole_Ls:ZeroMotorFrequency', ...
        ['Computed motor electrical frequency is zero or negative; ', ...
        'check n_nom and PolePairs.']);
end

Xs_ohm = Xdpp_pu * Zbase;
Ls = Xs_ohm / (2*pi*f_motor);

info = struct();
info.Zbase_ohm  = Zbase;
info.f_motor_Hz = f_motor;
info.Xs_ohm     = Xs_ohm;
info.Xdpp_pu    = Xdpp_pu;

end
