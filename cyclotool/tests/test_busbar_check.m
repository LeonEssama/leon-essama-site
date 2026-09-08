function test_busbar_check()
%TEST_BUSBAR_CHECK  Regression test against Schienenueberpruefung.xlsx.
%
%   Reproduces all 16 rows of the source workbook (8 sections x 2 sheets)
%   and checks the k-factor rules that the workbook cannot exercise.
%
%   Run once after installing the module, and again after any change to
%   BusbarAmpacityTable.m, busbar_k_factors.m or BusbarSectionDefaults.m.
%
%   The two workbook sheets come from DIFFERENT projects, which is why the
%   machine current, frequency and altitude differ between cases 1 and 2.
%
%   TEST DESIGN NOTE
%     Cases 3 and 4 assert on RETURNED VALUES and provenance strings, not
%     on warning identifiers. An earlier version asserted via lastwarn and
%     was wrong twice over: warning('off', id) suppresses the warning
%     entirely so lastwarn is never set, and even when enabled lastwarn
%     holds only the MOST RECENT warning, which busbar_check overwrites
%     with busbar_check:PaintRequired. Asserting on warning plumbing tests
%     MATLAB rather than the calculation.

TOL = 1e-6;
fprintf('--- busbar_check regression test ---\n');

%% ===== Case 1: sheet 'blanke Schienen' (bare) ==========================
% IM = 2720 A, f_motor = 7 Hz, altitude 930 m (below 1000 m -> k5 = 1)
In1 = struct('IM', 2720, 'n_nom', 14, 'PolePairs', 30, ...
             'fL', 50, 'Altitude', 930);
% f_motor = 30 * 14 / 60 = 7.00 Hz, matching workbook cell C14

B1 = busbar_check(In1, 'Location', 'indoor');

check('bare  I_max   [A] ', B1.Bare.I_max_A, ...
    [3520; 3350; 3520; 2991.0714285714284; 2480; 2288; 1776; 2288], TOL);
check('bare  Reserve [pu]', B1.Bare.Reserve_pu, ...
    [1.2941176470588236; 1.2316176470588236; 1.2941176470588236; ...
     1.3468012470988129; 1.1166791474452724; 1.030226568288219; ...
     1.130927292000855;  1.4569603851902908], TOL);

assert(all(B1.Bare.OK), 'Case 1: every bare section should pass at 930 m.');
assert(abs(B1.Currents.f_motor_Hz - 7) < TOL, ...
    'Case 1: f_motor should be 7.00 Hz.');
assert(all(B1.Bare.Band == "< 16 Hz" | B1.Bare.Band == "> 20 Hz"), ...
    'Case 1: no section should land in the frequency band gap.');
fprintf('  PASS  case 1 bands, frequency and pass/fail flags\n');

%% ===== Case 2: sheet 'gestrichene Schienen' (painted) ==================
% IM = 2555.5556 A, f_motor = 6 Hz, altitude 4400 m with the workbook's
% k5 = 0.86 supplied as an explicit override (Tab. 13-14 stops at 4000 m).
In2 = struct('IM', 2555.5555555555557, 'n_nom', 12, 'PolePairs', 30, ...
             'fL', 50, 'Altitude', 4400);
% f_motor = 30 * 12 / 60 = 6.00 Hz, matching workbook cell C14

% busbar_check warns that one section fails bare but passes painted. That
% is the correct result for this project and is asserted below, so the
% warning is silenced here to keep the test output readable.
wState = warning('off', 'busbar_check:PaintRequired');
restoreWarn = onCleanup(@() warning(wState));

B2 = busbar_check(In2, 'Location', 'indoor', 'k5', 0.86);

check('paint I_max   [A] ', B2.Painted.I_max_A, ...
    [3698.86; 3510.8542510121456; 3698.86; 3128.4990347490343; ...
     2451; 2397.68; 1973.7; 2397.68], TOL);
check('paint Reserve [pu]', B2.Painted.Reserve_pu, ...
    [1.4473799999999999; 1.3738125330047526; 1.4473799999999999; ...
     1.4993268839852918; 1.1746368312185667; 1.1490833282236363; ...
     1.337692961308184;  1.6250492270706827], TOL);

assert(all(B2.Painted.OK), 'Case 2: every painted section should pass.');

% Expected bare failure: 'Netzseite Horizontalschiene' (section 6).
%   I_max = 2860 A * k3 0.80 * k5 0.86 = 1967.7 A
%   Reserve = 1967.7 / 2086.60 = 0.9430  -> below 1.0
expectedBareFail = 6;
assert(isequal(find(~B2.Bare.OK), expectedBareFail), ...
    'Case 2: section %d alone should fail bare.', expectedBareFail);
check('case 2 bare fail reserve [pu]', ...
    B2.Bare.Reserve_pu(expectedBareFail), 0.9430066911677487, TOL);
fprintf(['  PASS  case 2: painting is a requirement, not an option ' ...
         '(section %d)\n'], expectedBareFail);

%% ===== Case 3: k5 altitude rule =======================================
% Tab. 13-14 interpolation, and extrapolation beyond its last row.
% Columns: altitude [m], location, expected k5 [-], expected rule code.
% The rule code is machine-readable and stable; the _source string is for
% humans and is deliberately NOT asserted on.
k5cases = { ...
     500, 'indoor',  1.000, 'below_table'
    1000, 'indoor',  1.000, 'table'
    1000, 'outdoor', 0.980, 'table'
    2500, 'indoor',  0.975, 'interpolated'
    4000, 'indoor',  0.900, 'table'
    4400, 'indoor',  0.876, 'extrapolated'
    4400, 'outdoor', 0.806, 'extrapolated'};

wState2 = warning('off', 'busbar_k_factors:AltitudeExtrapolated');
restoreWarn2 = onCleanup(@() warning(wState2));

for i = 1:size(k5cases, 1)
    alt = k5cases{i,1}; loc = k5cases{i,2};
    K = busbar_k_factors('Painted', false, 'nBars', 1, ...
        'Width_mm', 160, 'Thickness_mm', 10, ...
        'Altitude_m', alt, 'Location', loc);
    check(sprintf('k5 %5d m %-7s [-]', alt, loc), K.k5, k5cases{i,3}, TOL);
    assert(strcmp(K.k5_rule, k5cases{i,4}), ...
        'k5 at %g m %s: rule should be "%s", got "%s" (%s).', ...
        alt, loc, k5cases{i,4}, K.k5_rule, K.k5_source);
end
fprintf(['  PASS  k5 rule codes: 1000 m is a tabulated row, not ' ...
         '"below table"\n']);

%% ===== Case 4: k3 arrangement rule ====================================
% Tab. 13-13: 2 bars 50..200 mm -> 0.80 bare / 0.85 painted.
% Single bars and short vertical runs are exempt.
% Columns: painted, nBars, width [mm], orientation, run length [m],
%          expected k3 [-], expected rule code.
k3cases = { ...
    false, 2, 160, 'horizontal', Inf, 0.80, 'table'
    true,  2, 160, 'horizontal', Inf, 0.85, 'table'
    false, 1, 160, 'horizontal', Inf, 1.00, 'single_bar'
    false, 2, 100, 'vertical',   2.0, 1.00, 'vertical_exempt'
    false, 2, 100, 'vertical',   3.0, 0.80, 'table'};

for i = 1:size(k3cases, 1)
    K = busbar_k_factors('Painted', k3cases{i,1}, 'nBars', k3cases{i,2}, ...
        'Width_mm', k3cases{i,3}, 'Thickness_mm', 10, ...
        'Orientation', k3cases{i,4}, 'RunLength_m', k3cases{i,5});
    check(sprintf('k3 %d bar(s) %3d mm %-10s [-]', ...
        k3cases{i,2}, k3cases{i,3}, k3cases{i,4}), K.k3, k3cases{i,6}, TOL);
    assert(strcmp(K.k3_rule, k3cases{i,7}), ...
        'k3 rule should be "%s", got "%s" (%s).', ...
        k3cases{i,7}, K.k3_rule, K.k3_source);
end
fprintf(['  PASS  k3: the 2 m vertical exemption changes the riser ' ...
         'rating by 20%%\n']);

%% ===== Case 5: frequency band gap =====================================
% 18 Hz lies in the undefined 16..20 Hz gap.
In5 = In1;
In5.n_nom = 36;   % f_motor = 30 * 36 / 60 = 18 Hz

try
    busbar_check(In5, 'BandGapRule', 'error');
    error('test_busbar_check:NoGapError', ...
        'BandGapRule ''error'' should have refused to compute at 18 Hz.');
catch err
    assert(strcmp(err.identifier, 'busbar_check:FrequencyBandGap'), ...
        'Expected busbar_check:FrequencyBandGap, got %s.', err.identifier);
end

wState3 = warning('off', 'busbar_check:FrequencyBandGap');
restoreWarn3 = onCleanup(@() warning(wState3));
B5 = busbar_check(In5, 'BandGapRule', 'conservative');
motorRows = B5.Bare.f_Hz == 18;
assert(all(B5.Bare.Band(motorRows) == "> 20 Hz (gap)"), ...
    'Conservative rule should select the lower (> 20 Hz) rating.');
fprintf('  PASS  16..20 Hz gap: errors on demand, else takes the lower rating\n');

fprintf('--- all checks passed ---\n');

end

%% ========================================================================
function check(label, actual, expected, tol)
%CHECK  Assert an actual vector matches the reference to within tol.
a = actual(:); e = expected(:);
assert(numel(a) == numel(e), ...
    '%s: expected %d value(s), got %d.', label, numel(e), numel(a));
d = max(abs(a - e));
if d > tol
    [~, i] = max(abs(a - e));
    error('test_busbar_check:Mismatch', ...
        '%s: element %d differs by %.3g (got %.12g, expected %.12g)', ...
        label, i, d, a(i), e(i));
end
fprintf('  PASS  %s  (max deviation %.2e)\n', label, d);
end
