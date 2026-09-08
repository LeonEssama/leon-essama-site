function R = cyclo_dimensioning(Input)
%CYCLO_DIMENSIONING  Cycloconverter dimensioning main entry point.
%
%   R = cyclo_dimensioning(Input) optimizes the free voltage-margin
%   parameter(s) (u_r, and exT when not fixed) so that calculate(Input)
%   meets its target Uv0N as closely as possible, then runs the final
%   dimensioning, checks the result against the STN/3 thermal limit, and
%   assembles the full results struct (margins, optimizer diagnostics,
%   input echo and PASS/FAIL status) expected by CycloGUI.
%
%   Input structure: from CycloGUI (see calculate.m / objective_fun_*
%   for the required fields).
%   Output structure: R, containing all results (all field names are
%   unchanged from the original so existing GUI code keeps working).
%
%   Changes vs. the original:
%     - The thyristor-class feasibility check (target Uv0N vs. the
%       maximum achievable Uv0 for the selected thyristor class) now
%       runs FIRST, before the nonlinear solve. It depends only on
%       Input fields, not on the optimization result, so checking it
%       first avoids running the full lsqnonlin optimization (and
%       calculate()) when the thyristor class is already known to be
%       too low, and avoids returning a partially-populated R.
%     - Two redundant duplicate-value assignments (N_SerieN/R.N_SerieN,
%       and R.u_r assigned twice) have been removed; the final values
%       are identical to the original.
%     - The end-of-function debug disp()/fprintf() calls have been
%       removed.
%     - The lsqnonlin call is now wrapped in try/catch for a clearer
%       error message if the solver itself fails.

%% ----------------------------------------------------------
% Early feasibility check: can this thyristor class reach the
% target Uv0 at all, independent of the optimization result?
%% ----------------------------------------------------------
N_SerieN = Input.PulseNumber/6;
DeltaUL  = 1 + (1 - Input.u_L);
Uv0Max   = (N_SerieN * Input.Thy.UDRM) / (2 * sqrt(2) * DeltaUL);

if Input.Uv0N_target > Uv0Max
    uialert(Input.MainFigure, ...
        sprintf(['Target Uv0 = %.0f V\n\n' ...
        'Maximum possible Uv0 = %.0f V\n\n' ...
        'Selected thyristor class: %s\n\n' ...
        'Please select a higher thyristor voltage class.'], ...
        Input.Uv0N_target, Uv0Max, Input.Thy.Type), ...
        'Thyristor Class Too Low');
    R = struct();
    return;
end

%% ----------------------------------------------------------
% Initial guess / bounds
%% ----------------------------------------------------------
if strcmpi(Input.exTMode, 'Fixed')
    x0 = 1.06;
    lb = 1.06;
    ub = 1.2;
else
    x0 = [1.005 0.04];
    lb = [1.005 0.04];
    ub = [1.3  0.25];
end

%% ----------------------------------------------------------
% Optimization options
%% ----------------------------------------------------------
options = optimoptions('fmincon', ...
    'Algorithm','sqp', ...
    'Display','off', ...
    'MaxIterations',1000, ...
    'MaxFunctionEvaluations',10000, ...
    'ConstraintTolerance',1e-6, ...
    'OptimalityTolerance',1e-8, ...
    'StepTolerance',1e-8);
%% ----------------------------------------------------------
% Solver
%% ----------------------------------------------------------
try
    if strcmpi(Input.exTMode,'Fixed')
        [x,fval,exitflag,output] = fmincon( ...
            @(x)objective_fun_fixed(x,Input), ...
            x0, ...
            [],[],[],[], ...
            lb, ...
            ub, ...
            [], ...
            options);
        residual = fval;
        resnorm  = fval;
    else
        [x,fval,exitflag,output] = fmincon( ...
            @(x)objective_fun_opt(x,Input), ...
            x0, ...
            [],[],[],[], ...
            lb, ...
            ub, ...
            @(x)nonlcon_opt(x,Input), ...
            options);
        residual = fval;
        resnorm  = fval;
    end
catch solverErr
    error( ...
        'cyclo_dimensioning:SolverFailed', ...
        'Optimization failed:\n\n%s', ...
        solverErr.message);
end

%% ----------------------------------------------------------
% Store optimized variables
%% ----------------------------------------------------------
if strcmpi(Input.exTMode, 'Fixed')
    Input.u_r = x(1);
    Input.exT = Input.exT_user;
else
    Input.u_r = x(1);
    Input.exT = x(2);
end

%% ----------------------------------------------------------
% Final calculation
%% ----------------------------------------------------------
R = calculate(Input);

STN_Limit = R.Psh/3;
if R.STN < STN_Limit
    error('cyclo_dimensioning:STNBelowLimit', ...
        'STN below limit\n\nSTN = %.2f MVA\nLimit = %.2f MVA', ...
        R.STN/1e6, STN_Limit/1e6);
end
R.STN_Limit  = STN_Limit;
R.STN_OK     = true;
R.STr_sizing = R.STN * Input.ReserveFactor;

R.Uv0_Error = 100 * (R.Uv0N - Input.Uv0N_target) / Input.Uv0N_target;
R.IkN_Error = 100 * (R.IkN - Input.Thy.IKS0) / Input.Thy.IKS0;

%% ----------------------------------------------------------
% Optimization information
%% ----------------------------------------------------------
R.u_r      = Input.u_r;
R.exT      = Input.exT;
R.resnorm  = resnorm;
R.residual = residual;
R.exitflag = exitflag;
R.output   = output;

%% ----------------------------------------------------------
% Engineering margins
%% ----------------------------------------------------------
R.kN_Margin      = 100 * (R.k_N - R.kN_min) / R.kN_min;
R.SC_Margin      = 100 * (Input.Thy.IKS0 - R.IkN) / Input.Thy.IKS0;
R.ThermalMargin  = Input.Thy.Tjmax - R.TjMax;
R.RecoveryMargin = (Input.Thy.tq - 350e-6) * 1e6;
R.Uv0Margin      = 100 * (R.Uv0Max - R.Uv0N) / R.Uv0Max;

%% ----------------------------------------------------------
% Number of series thyristors (echoed on R for the GUI)
%% ----------------------------------------------------------
R.N_SerieN = N_SerieN;

%% ----------------------------------------------------------
% Input echo
%% ----------------------------------------------------------
R.ThyristorType = Input.Thy.Type;
R.UDRM = Input.Thy.UDRM;
R.IKS0 = Input.Thy.IKS0;
R.IKS1 = Input.Thy.IKS1;

%% ----------------------------------------------------------
% Overall summary
%% ----------------------------------------------------------
if R.SOA_OK
    R.Status = 'PASS';
else
    R.Status = 'FAIL';
end

end
