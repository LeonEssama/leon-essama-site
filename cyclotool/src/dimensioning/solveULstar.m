function uLstar = solveULstar(targetIL1, Savg, UL)
%SOLVEULSTAR  Solve for the line-voltage ratio u_Lstar meeting a target IL1.
%
%   uLstar = solveULstar(targetIL1, Savg, UL) inverts the apparent-power
%   relationship S = sqrt(3) * UL * uLstar * IL1 to find the u_Lstar
%   value that produces the desired target line current.
%
%   Inputs:
%       targetIL1 - Desired fundamental line current [A]
%       Savg      - Average apparent power [VA]
%       UL        - Line voltage [V]
%
%   Output:
%       uLstar    - Required line-voltage ratio [pu]
%
%   Calculation is unchanged:
%       uLstar = Savg / (sqrt(3) * UL * targetIL1)

if UL == 0 || targetIL1 == 0
    error('solveULstar:InvalidInput', ...
        'UL and targetIL1 must both be nonzero.');
end

uLstar = Savg / (sqrt(3) * UL * targetIL1);

end
