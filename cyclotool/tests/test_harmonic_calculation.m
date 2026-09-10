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

% [order, kin %, IL,n [A], kun %] from the Excel sheet (columns D/E,
% SC(act) = 384 MVA, both identical)
excel = [ ...
    5,  2.28428121806898,  50.4622323294351,  0.389217153492328; ...
    7,  1.31945943938173,  29.1482801034599,  0.314750539607565; ...
    11, 7.43431761428336,  164.232083026937,  2.78680252572304;  ...
    13, 5.77912374884721,  127.667067858401,  2.56022270869084;  ...
    17, 0.352089422164098, 7.77803454383816,  0.203973758305499; ...
    19, 0.271394813074236, 5.99540371913268,  0.17572256864468;  ...
    23, 1.50255788314518,  33.19312192734,    1.17769124440649;  ...
    25, 1.04776401356197,  23.1462355250119,  0.892639057889353; ...
    29, 0.0364260938236834,0.804691644288171, 0.0359983834497948;...
    31, 0.0115887649430766,0.256008298953269, 0.0122425319708155;...
    35, 0.232342261356992, 5.13269079122149,  0.277120500839428; ...
    37, 0.343004647869784, 7.57734209517036,  0.432488065832875; ...
    41, 0.0463506409134292,1.02393557846127,  0.0647607693328529;...
    43, 0.0482379511870964,1.06562829508223,  0.0706853980868647;...
    47, 0.458134790183799, 10.1206909366418,  0.733776045121836; ...
    49, 0.422646017910681, 9.33670573492204,  0.705740856906495];

assert(isequal(H.HOrder(:), excel(:,1)), ...
    'Harmonic order list does not match the reference sheet.');

for k = 1:size(excel,1)
    h = excel(k,1);
    check(sprintf('h=%2d KI [%%]', h), H.KI(k), excel(k,2), TOL_PCT*excel(k,2));
    check(sprintf('h=%2d IL [A] ', h), H.IL(k), excel(k,3), TOL_IL*excel(k,3));
    check(sprintf('h=%2d KU [%%]', h), H.KU(k), excel(k,4), TOL_PCT*excel(k,4));
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
