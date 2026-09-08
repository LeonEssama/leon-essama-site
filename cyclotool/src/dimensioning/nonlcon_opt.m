function [c,ceq] = nonlcon_opt(x,Input)

Input.u_r = x(1);
Input.exT = x(2);

try
    R = calculate(Input);
    c = [];
    %----------------------------------------
    % IkN <= 99.5% IKS0
    %----------------------------------------
    c(end+1) = R.IkN ...
         - Input.IkN_Factor*Input.Thy.IKS0;
    %----------------------------------------
    % kN >= user minimum
    %----------------------------------------
    c(end+1) = Input.kN_min - R.k_N;
    %----------------------------------------
    % STN >= Psh/3
    %----------------------------------------
    c(end+1) = R.Psh/3 - R.STN;
    ceq = [];
catch
    c = 1e6;
    ceq = [];
end
end