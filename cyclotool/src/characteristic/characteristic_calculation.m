function C = characteristic_calculation(Input)
%CHARACTERISTIC_CALCULATION  Speed/voltage/current operating characteristics.
%
%   C = characteristic_calculation(Input)
%
%   Builds the 4-point corner characteristics (n_min, transition speed,
%   n_nom, n_max) for motor voltage and current at nominal and reduced
%   (u_L min) line voltage, plus continuous curves over the full speed
%   range for plotting.
%
%   Calculation logic is unchanged from the original; the per-sample
%   for-loops building the continuous curves have been vectorized with
%   logical indexing (identical piecewise-linear math, no loop).

if Input.n_nom == 0
    error('characteristic_calculation:ZeroNnom', 'Input.n_nom must be nonzero.');
end

C = struct();

%% Corner points
C.Speed = [Input.n_min; Input.u_L * Input.n_nom; Input.n_nom; Input.n_max];
C.Frequency = C.Speed * Input.PolePairs / 60;

%% Motor voltage at the corner points
C.UM_nom = [ ...
    Input.UM * Input.n_min / Input.n_nom; ...
    Input.UM * Input.u_L; ...
    Input.UM; ...
    Input.UM];
C.UM_uLmin = [ ...
    Input.UM * Input.n_min / Input.n_nom; ...
    Input.UM * Input.u_L; ...
    Input.UM * Input.u_L; ...
    Input.UM * Input.u_L];

%% Motor current at the corner points
C.IM_nom = Input.IM * ones(4, 1);
C.IM_uLmin = [Input.IM; Input.IM; Input.IM/Input.u_L; Input.IM/Input.u_L];

%% Overload current at the corner points
C.IM_ovld_nom   = Input.overload * C.IM_nom;
C.IM_ovld_uLmin = Input.overload * C.IM_uLmin;

%% -------------------------------------------------
% Continuous curves over the full speed range
%% -------------------------------------------------
C.nCurve = linspace(Input.n_min, Input.n_max, 200);
nTransition = Input.u_L * Input.n_nom;

%% Voltage curve (uL = 1): ramps to UM at n_nom, then flat
belowNom = C.nCurve <= Input.n_nom;
C.UM_curve = Input.UM * ones(size(C.nCurve));
C.UM_curve(belowNom) = Input.UM * C.nCurve(belowNom) / Input.n_nom;

%% Voltage curve (uL min): ramps to UM*u_L at the transition speed, then flat
belowTransition = C.nCurve <= nTransition;
C.UM_uL_curve = Input.UM * Input.u_L * ones(size(C.nCurve));
C.UM_uL_curve(belowTransition) = ...
    Input.UM * C.nCurve(belowTransition) / Input.n_nom;

%% Current curve (uL = 1): constant
C.IM_curve = Input.IM * ones(size(C.nCurve));

%% Current curve (uL min): constant, then linear ramp, then constant
C.IM_uL_curve = (Input.IM/Input.u_L) * ones(size(C.nCurve));
C.IM_uL_curve(belowTransition) = Input.IM;

rampRegion = ~belowTransition & (C.nCurve <= Input.n_nom);
if Input.n_nom ~= nTransition
    frac = (C.nCurve(rampRegion) - nTransition) / (Input.n_nom - nTransition);
    C.IM_uL_curve(rampRegion) = Input.IM + frac * (Input.IM/Input.u_L - Input.IM);
end

C.IM_ovld_curve    = Input.overload * C.IM_curve;
C.IM_ovld_uL_curve = Input.overload * C.IM_uL_curve;

end
