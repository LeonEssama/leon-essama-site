function Fluid = calculate_cyclo_cooling_glycol( ...
    GlycolPercent)

%CALCULATE_CYCLO_COOLING_GLYCOL
% Ethylene glycol / water cooling properties.
%
% Source:
%   "Design of Water-Cooling System for Cycloconverters" workbook,
%   sheet "Calculation of flow & pressure", rows 119-121.
%
%   Correction vs. the previous version: this function's data table
%   was mislabeled "Source: Aktogay cooling workbook" -- the table
%   values themselves already match the reference workbook exactly
%   (verified cell-by-cell against C120:I120 and C121:I121), only the
%   source label was wrong. No numeric change.
%
%   Thermic capacity cp is tabulated at 0/10/20/30/40/50/60% glycol
%   and linearly interpolated between points (this function's own
%   choice, agreed as the preferred approach over the workbook's
%   exact-match-only lookup, since it gives a continuous, physically
%   reasonable curve rather than step changes at intermediate glycol
%   percentages). The viscosity correction factor is linear across
%   the whole 0-60% range by construction in the workbook itself
%   (single slope from the 0% and 50% reference points), so
%   interpolating it changes nothing relative to the workbook.

arguments
    GlycolPercent (1,1) double
end

%% Workbook data (Calculation of flow & pressure, C120:I121)

glycolTable = [ ...
     0
    10
    20
    30
    40
    50
    60];

cpTable = [ ...
    4.1868
    4.103064
    3.893724
    3.726252
    3.495978
    3.265704
    3.098232];

viscosityTable = [ ...
    1.000
    1.032
    1.064
    1.096
    1.128
    1.160
    1.192];

%% Limits

assert( ...
    GlycolPercent >= 0 && ...
    GlycolPercent <= 60, ...
    'Glycol percentage must be between 0 and 60.');

%% Interpolation

Fluid.GlycolPercent = ...
    GlycolPercent;

Fluid.Cp_kJkgK = ...
    interp1( ...
        glycolTable, ...
        cpTable, ...
        GlycolPercent, ...
        'linear');

Fluid.Cp_JkgK = ...
    Fluid.Cp_kJkgK * 1000;

Fluid.ViscosityCorrection = ...
    interp1( ...
        glycolTable, ...
        viscosityTable, ...
        GlycolPercent, ...
        'linear');

Fluid.Source = ...
    "Design of Water-Cooling System for Cycloconverters workbook";

end
