function J = objective_fun_opt(x,Input)

Input.u_r = x(1);
Input.exT = x(2);

try
    R = calculate(Input);
    J = ((R.Uv0N - Input.Uv0N_target) ...
        / Input.Uv0N_target)^2;
    if ~isfinite(J)
        J = 1e6;
    end
catch
    J = 1e6;
end
end