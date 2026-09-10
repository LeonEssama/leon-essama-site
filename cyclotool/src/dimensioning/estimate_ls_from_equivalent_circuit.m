function [Ls, info] = estimate_ls_from_equivalent_circuit( ...
    UM, IM, n_nom, PolePairs, xaDelta_pu, xad_pu, xfc_pu)
%ESTIMATE_LS_FROM_EQUIVALENT_CIRCUIT  Per-phase stator inductance for a
%salient-pole synchronous motor, derived from manufacturer d-axis
%equivalent-circuit reactances (IEEE 115 / IEC 60034-4 convention)
%instead of an assumed scalar Xd''.
%
%   [Ls, info] = estimate_ls_from_equivalent_circuit( ...
%       UM, IM, n_nom, PolePairs, xaDelta_pu, xad_pu, xfc_pu)
%
%   INPUTS (rated/nameplate values, SI units unless noted):
%     UM          - rated line-to-line stator voltage              [V]
%     IM          - rated stator line current                      [A]
%     n_nom       - rated mechanical speed                          [rpm]
%     PolePairs   - number of pole pairs                            [-]
%     xaDelta_pu  - stator winding leakage reactance (xa-delta)     [pu]
%     xad_pu      - main field reactance, d-axis (xad)              [pu]
%     xfc_pu      - field winding leakage reactance (xfc)           [pu]
%
%   OUTPUTS:
%     Ls   - estimated per-phase stator inductance                  [H]
%     info - struct with intermediate values for traceability:
%              info.Zbase_ohm   - base impedance                    [Ohm]
%              info.f_motor_Hz  - motor rated electrical frequency  [Hz]
%              info.Xd_pu       - derived d-axis reactance           [pu]
%              info.Xs_ohm      - stator reactance                  [Ohm]
%
%   METHOD (ENGINEERING ESTIMATE -- NOT AN IEC/IEEE-MANDATED FORMULA):
%
%     This reduces the standard d-axis equivalent circuit (leakage
%     reactance xaDelta in series with the parallel combination of the
%     mutual reactance xad, the field-leakage branch xfc, and the
%     damper-leakage branch) to the two-branch case, valid when the
%     damper branch is absent or negligible (damper resistance/
%     reactance >> xad, xfc -- confirm from the datasheet, e.g. a
%     damperless ring/gearless motor reporting rD, xDc on the order of
%     1e6 pu):
%
%       Xd'    = xaDelta + xad*xfc/(xad+xfc)        [pu]
%       Zbase  = (UM/sqrt(3)) / IM                  [Ohm]
%       f_motor = n_nom * PolePairs / 60            [Hz]
%       Xs     = Xd' * Zbase                        [Ohm]
%       Ls     = Xs / (2*pi*f_motor)                [H]
%
%   ASSUMPTIONS AND LIMITATIONS:
%     - Damper branch (rD, xDc in the full circuit) is open/negligible.
%       If the machine has a significant damper winding, this reduction
%       underestimates Xd'' and this function should not be used;
%       supply a true Xd'' instead via estimate_salient_pole_Ls.m.
%     - xaDelta_pu, xad_pu, xfc_pu are assumed defined at the MOTOR's
%       own rated electrical frequency (from n_nom and PolePairs), NOT
%       the supply/grid frequency -- same caveat as
%       estimate_salient_pole_Ls.m.
%     - The equivalent-circuit reactance definitions themselves follow
%       IEEE 115 / IEC 60034-4 convention; the two-branch reduction and
%       its use as a per-phase Ls for this tool's stator R-L model is
%       an engineering estimate, not a numeric IEC/IEEE requirement.

validateattributes(UM, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'UM');
validateattributes(IM, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'IM');
validateattributes(n_nom, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'n_nom');
validateattributes(PolePairs, {'numeric'}, ...
    {'scalar','positive','finite','integer'}, mfilename, 'PolePairs');
validateattributes(xaDelta_pu, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'xaDelta_pu');
validateattributes(xad_pu, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'xad_pu');
validateattributes(xfc_pu, {'numeric'}, {'scalar','positive','finite'}, ...
    mfilename, 'xfc_pu');

Zbase = (UM/sqrt(3)) / IM;
f_motor = n_nom * PolePairs / 60;

if f_motor <= 0
    error('estimate_ls_from_equivalent_circuit:ZeroMotorFrequency', ...
        ['Computed motor electrical frequency is zero or negative; ', ...
        'check n_nom and PolePairs.']);
end

if (xad_pu + xfc_pu) == 0
    error('estimate_ls_from_equivalent_circuit:ZeroReactanceSum', ...
        'xad_pu + xfc_pu must be nonzero.');
end

Xd_pu = xaDelta_pu + (xad_pu * xfc_pu) / (xad_pu + xfc_pu);
Xs_ohm = Xd_pu * Zbase;
Ls = Xs_ohm / (2*pi*f_motor);

info = struct();
info.Zbase_ohm  = Zbase;
info.f_motor_Hz = f_motor;
info.Xd_pu      = Xd_pu;
info.Xs_ohm     = Xs_ohm;

end
