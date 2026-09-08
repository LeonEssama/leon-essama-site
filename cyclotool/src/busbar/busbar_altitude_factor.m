function [k5, src, rule] = busbar_altitude_factor(alt, location)
%BUSBAR_ALTITUDE_FACTOR  Altitude derating k5, BBC Schaltanlagen-Handbuch Tab. 13-14.
%
%   [k5, src, rule] = busbar_altitude_factor(alt, location)
%
%   alt       site altitude above sea level [m]
%   location  'indoor' | 'outdoor'
%
%   k5        derating factor [-]
%   src       human-readable provenance
%   rule      machine-readable classification: 'below_table' | 'table' |
%             'interpolated' | 'extrapolated'
%
%   Tabelle 13-14 ('Belastungsminderung in Hoehen ab 1000 m'):
%       1000 m -> 1.00 indoor / 0.98 outdoor
%       2000 m -> 0.99        / 0.94
%       3000 m -> 0.96        / 0.89
%       4000 m -> 0.90        / 0.83
%   Below 1000 m there is no reduction. Linear interpolation is used
%   between tabulated altitudes.
%
%   ABOVE 4000 m the table ends. No IEC/IEEE requirement found for this
%   item: IEC 61439-1 makes conditions above 2000 m subject to agreement
%   between manufacturer and user rather than publishing a curve. This
%   function LINEARLY EXTRAPOLATES from the last two rows and warns. That
%   is an ENGINEERING ESTIMATE. Supply an agreed k5 explicitly instead.
%
%   The table footnote also notes larger reductions above 60 deg latitude
%   or in particularly dusty air. That is NOT applied automatically.
%
%   WHY THIS IS ITS OWN FUNCTION
%     k5 depends only on altitude and location, both of which are constant
%     across a busbar check. Resolving it once per run rather than once
%     per section keeps the extrapolation warning to a single message
%     instead of one per section per surface finish.
%
%   NOT EXECUTED: statically reviewed only, no MATLAB runtime was
%   available when this was written.

arguments
    alt      (1,1) double {mustBeNonnegative, mustBeFinite}
    location (1,:) char {mustBeMember(location, {'indoor','outdoor'})} = 'indoor'
end

ALT_KM = [1 2 3 4];                  % [1000 m]
K_IN   = [1.00 0.99 0.96 0.90];      % indoor
K_OUT  = [0.98 0.94 0.89 0.83];      % outdoor

if strcmpi(location, 'indoor')
    kTab = K_IN;
else
    kTab = K_OUT;
end

a = alt / 1000;   % [1000 m]

if a < ALT_KM(1)
    k5   = 1;
    src  = sprintf('Tab. 13-14: %g m is below 1000 m, no reduction', alt);
    rule = 'below_table';

elseif a <= ALT_KM(end)
    k5 = interp1(ALT_KM, kTab, a, 'linear');
    if any(abs(a - ALT_KM) < eps(4))
        src  = sprintf('Tab. 13-14 (%s), tabulated row at %g m', location, alt);
        rule = 'table';
    else
        src  = sprintf('Tab. 13-14 (%s), linear interpolation at %g m', ...
            location, alt);
        rule = 'interpolated';
    end

else
    slope = (kTab(end) - kTab(end-1)) / (ALT_KM(end) - ALT_KM(end-1));
    k5    = max(kTab(end) + slope * (a - ALT_KM(end)), 0);
    src   = sprintf(['ENGINEERING ESTIMATE: linear extrapolation of ' ...
                     'Tab. 13-14 (%s) beyond 4000 m to %g m'], location, alt);
    rule  = 'extrapolated';
    warning('busbar_k_factors:AltitudeExtrapolated', ...
        ['Altitude %g m exceeds the last row of Tab. 13-14 (4000 m). ' ...
         'k5 = %.4f is a linear extrapolation, not a tabulated or ' ...
         'standardised value. Agree a figure with the manufacturer per ' ...
         'IEC 61439-1 and enter it as an explicit k5.'], alt, k5);
end

end
