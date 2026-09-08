function mustHaveFields(S, fieldNames, callerName)
%MUSTHAVEFIELDS  Assert that a struct contains a set of required fields.
%
%   mustHaveFields(S, fieldNames, callerName) throws a clear, actionable
%   error if any field in the cell array FIELDNAMES is missing from the
%   struct S. Used at the top of the dimensioning functions to fail fast
%   with a useful message instead of a cryptic "undefined field" error
%   deep inside a formula.
%
%   Inputs:
%       S          - struct to check (typically the Input struct)
%       fieldNames - cell array of required field name strings
%       callerName - name of the calling function, for the error message
%
%   This function does not alter any calculation; it only validates
%   presence of inputs before they are used.

missing = fieldNames(~isfield(S, fieldNames));
if ~isempty(missing)
    error('%s:MissingFields', ...
        '%s: missing required input field(s): %s', ...
        callerName, strjoin(missing, ', '));
end
end
