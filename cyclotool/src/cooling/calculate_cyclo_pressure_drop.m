function Dp_kPa = ...
    calculate_cyclo_pressure_drop( ...
    Flow_lpm, ...
    a, ...
    c)

%CALCULATE_CYCLO_PRESSURE_DROP
%
% Dp = c * q^a
%
% Flow_lpm : flow [l/min]
% a        : exponent
% c        : coefficient
%
% Output:
% Dp[l_kPa   : pressure drop Pa]

arguments

    Flow_lpm (1,1) double
    a        (1,1) double
    c        (1,1) double

end

assert( ...
    Flow_lpm >= 0, ...
    'Flow must be non-negative.');

Dp_kPa = ...
    c * Flow_lpm^a;

end