function F = objective_fun_fixed(x, Input)
%OBJECTIVE_FUN_FIXED  lsqnonlin residual vector for the "fixed exT" mode.
%
%   F = objective_fun_fixed(x, Input) sets Input.u_r = x(1) and holds
%   Input.exT fixed at Input.exT_user, runs the full calculate(Input),
%   and returns a 2-element residual vector:
%     F(1) = (Uv0N target error, fraction)
%     F(2) = 20 * (IkN overshoot above Thy.IKS0, fraction, >=0)
%
%   Note the IkN limit here is the full Thy.IKS0 (no 99% margin), unlike
%   objective_fun_opt which allows only up to 99% — this is intentional:
%   in fixed-exT mode there is only one free variable (u_r) so the
%   solver has less room to trade off the two objectives.
%
%   Calculation logic is unchanged from the original.

if Input.Uv0N_target == 0
    error('objective_fun_fixed:ZeroTarget', 'Input.Uv0N_target must be nonzero.');
end

Input.u_r = x(1);
Input.exT = Input.exT_user;

R = calculate(Input);

eUv = (R.Uv0N - Input.Uv0N_target) / Input.Uv0N_target;
eIk = max(0, (R.IkN - Input.Thy.IKS0) / Input.Thy.IKS0);

F = [eUv; 20*eIk];

end
