function test_harmonic_calculation()
%TEST_HARMONIC_CALCULATION  Regression test against the Atalaya (Sierra
%Azul) 23,000 hp ball-mill drive reference Excel sheet, 12-pulse
%"rating" case (SC(act) = 384 MVA column).
%
%   Confirms unsymmetryCoeff's 0.10 factor for the non-characteristic
%   6-pulse orders (5,7,17,19,29,31,41,43), the korr5 5th-harmonic VBA
%   correction, and the full KI/IL/KU spectrum against the Excel
%   sheet's own printed kin/IL,n/kun values.
%
%   KI_worst/IL_worst ("worst-case" / manufacturer-spec spectrum) are
%   checked against KI/IL divided by their own coeff (the formula the
%   code implements), which was independently confirmed against the
%   reference sheet's own summary column (MAX(...)/IL,1*10, per order
%   5 and 7 checked by hand: this reverses exactly the 0.10 credit
%   while preserving korr5) -- the sheet's screenshot showed only the
%   formulas for that column, not its resulting numbers, so these
%   expected values are derived, not transcribed.
%
%   Tolerances: 0.1% relative on KI%/KU% and on ku25/kuTot (spectrum
%   shape, matched to <0.06% in practice); 0.05% relative on IL,n
%   absolute values, which carry an extra ~0.014% offset traced to the
%   reference sheet's own IL,1 cell not equaling I1S exactly (unlike
%   this function's IL1 = S/(sqrt(3)*Uv0N), which is algebraically
%   forced to equal I1S) -- a known, tiny, unexplained discrepancy in
%   the source sheet, not in this function.

TOL_PCT = 1e-3;   % 0.1% relative, KI/KU/ku25/kuTot
TOL_IL  = 5e-4;   % 0.05% relative, absolute IL,n
fprintf('--- harmonic_calculation regression test (Atalaya, 12-pulse) ---\n');

Input = struct();
Input.PulseNumber = 12;
Input.SC_min = 384e6;

R = struct();
R.dxN     = 0.0972993595541373;
R.uL_used = 1;
R.I1S     = 2209.41451465375;
R.Uv0N    = 3419.52507851723;

H = harmonic_calculation(Input, R);

% [order, kin %, IL,n [A], kun %, KI_worst %, IL_worst [A]] -- columns
% 2-4 from the Excel sheet (columns D/E, SC(act) = 384 MVA, both
% identical); columns 5-6 derived (see file header note).
excel = [ ...
    5,  2.28428121806898,  50.4622323294351,  0.389217153492328, 22.842424, 504.6838; ...
    7,  1.31945943938173,  29.1482801034599,  0.314750539607565, 13.194390, 291.5188; ...
    11, 7.43431761428336,  164.232083026937,  2.78680252572304,   7.434238, 164.2531; ...
    13, 5.77912374884721,  127.667067858401,  2.56022270869084,   5.779083, 127.6839; ...
    17, 0.352089422164098, 7.77803454383816,  0.203973758305499,  3.520905,  77.7914; ...
    19, 0.271394813074236, 5.99540371913268,  0.17572256864468,   2.713977,  59.9630; ...
    23, 1.50255788314518,  33.19312192734,    1.17769124440649,   1.502609,  33.1989; ...
    25, 1.04776401356197,  23.1462355250119,  0.892639057889353,  1.047822,  23.1507; ...
    29, 0.0364260938236834,0.804691644288171, 0.0359983834497948, 0.364323,   8.0494; ...
    31, 0.0115887649430766,0.256008298953269, 0.0122425319708155, 0.115947,   2.5618; ...
    35, 0.232342261356992, 5.13269079122149,  0.277120500839428,  0.232291,   5.1323; ...
    37, 0.343004647869784, 7.57734209517036,  0.432488065832875,  0.342960,   7.5774; ...
    41, 0.0463506409134292,1.02393557846127,  0.0647607693328529, 0.463477,  10.2401; ...
    43, 0.0482379511870964,1.06562829508223,  0.0706853980868647, 0.482359,  10.6573; ...
    47, 0.458134790183799, 10.1206909366418,  0.733776045121836,  0.458131,  10.1220; ...
    49, 0.422646017910681, 9.33670573492204,  0.705740856906495,  0.422649,   9.3381];

assert(isequal(H.HOrder(:), excel(:,1)), ...
    'Harmonic order list does not match the reference sheet.');

for k = 1:size(excel,1)
    h = excel(k,1);
    check(sprintf('h=%2d KI [%%]', h), H.KI(k), excel(k,2), TOL_PCT*excel(k,2));
    check(sprintf('h=%2d IL [A] ', h), H.IL(k), excel(k,3), TOL_IL*excel(k,3));
    check(sprintf('h=%2d KU [%%]', h), H.KU(k), excel(k,4), TOL_PCT*excel(k,4));
    check(sprintf('h=%2d KI_worst [%%]', h), H.KI_worst(k), excel(k,5), TOL_PCT*excel(k,5));
    check(sprintf('h=%2d IL_worst [A] ', h), H.IL_worst(k), excel(k,6), TOL_IL*excel(k,6));
end

check('ku25  [%]', H.ku25,  4.10217154690758, TOL_PCT*4.10217154690758);
check('kuTot [%]', H.kuTot, 4.25896544794397, TOL_PCT*4.25896544794397);

fprintf('All harmonic_calculation tests passed.\n');

end

%% ==========================================================
function check(label, actual, expected, tol)
if abs(actual - expected) > tol
    error('CycloTool:TestFailed', ...
        '%s mismatch: got %.6g, expected %.6g (tol %.3g)', ...
        label, actual, expected, tol);
end
fprintf('  OK    %s: %.6g (expected %.6g)\n', label, actual, expected);
end
