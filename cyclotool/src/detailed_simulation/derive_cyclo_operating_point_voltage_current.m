function [UM_op, IM_op, uL_op, fieldWeakening] = ...
    derive_cyclo_operating_point_voltage_current(Input, Speed, voltageCaseIndex)
%DERIVE_CYCLO_OPERATING_POINT_VOLTAGE_CURRENT  Per-point motor voltage
%and current for one named speed x voltage-case operating point.
%
%   [UM_op, IM_op, uL_op, fieldWeakening] = ...
%       derive_cyclo_operating_point_voltage_current(Input, Speed, voltageCaseIndex)
%
%   Reuses the SAME field-weakening formula already established in
%   CycloGUI_v2_0/generateNetzMatrix for the Netzbelastung operating
%   matrix -- reproduced here, not reinvented, so
%   run_cyclo_operating_point_sweep.m's detailed-simulation operating
%   points stay consistent with the rest of the tool (Netzbelastung/
%   Losses/Characteristic all already use this same construction).
%
%   voltageCaseIndex: 1 = uLmin (Input.u_L), 2 = uL=1, 3 = uLmax
%   (2-Input.u_L).
%
%   Below base speed (Speed < Input.n_nom): constant V/Hz --
%     UM_op = Input.UM * Speed/Input.n_nom, independent of voltageCaseIndex.
%   At or above base speed (Speed >= Input.n_nom): field weakening --
%     UM_op = Input.UM*Input.u_L on the uLmin case, else Input.UM (voltage
%     held at or below rated rather than continuing to rise with speed).
%   Current is scaled by 1/uL_op on the uLmin case (at any speed, not
%   only in field weakening -- this represents the grid undervoltage
%   scenario the uLmin case models, current rising to hold shaft power
%   roughly constant), else unscaled: IM_op = Input.IM * iM.

arguments
    Input (1,1) struct
    Speed (1,1) double {mustBePositive, mustBeFinite}
    voltageCaseIndex (1,1) double {mustBeMember(voltageCaseIndex, [1 2 3])}
end

switch voltageCaseIndex
    case 1
        uL_op = Input.u_L;
    case 2
        uL_op = 1.0;
    case 3
        uL_op = 2 - Input.u_L;
end

fieldWeakening = Speed >= Input.n_nom;

if ~fieldWeakening
    UM_op = Input.UM * Speed / Input.n_nom;
else
    if voltageCaseIndex == 1
        UM_op = Input.UM * Input.u_L;
    else
        UM_op = Input.UM;
    end
end

if voltageCaseIndex == 1
    iM = 1 / uL_op;
else
    iM = 1.0;
end
IM_op = Input.IM * iM;

end
