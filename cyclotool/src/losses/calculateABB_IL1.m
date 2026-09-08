function IL1 = calculateABB_IL1(IM, Uv0N, UL)
%CALCULATEABB_IL1  Line current (ABB fixed-formula estimate).
%
%   IL1 = calculateABB_IL1(IM, Uv0N, UL) returns the estimated RMS line
%   current using the ABB empirical coefficient (2.21 * 0.975), scaled by
%   the motor current, converter output voltage and line voltage.
%
%   Inputs:
%       IM   - Motor current [A]
%       Uv0N - Converter no-load voltage [V]
%       UL   - Line voltage [V]
%
%   Output:
%       IL1  - Estimated fundamental line current [A]
%
%   Calculation is unchanged from the original ABB formula:
%       IL1 = 2.21 * 0.975 * IM * Uv0N / UL

if UL == 0
    error('calculateABB_IL1:ZeroLineVoltage', ...
        'UL (line voltage) must be nonzero.');
end

ABB_COEFF = 2.21 * 0.975;   % Empirical ABB line-current coefficient

IL1 = ABB_COEFF * IM * Uv0N / UL;

end
