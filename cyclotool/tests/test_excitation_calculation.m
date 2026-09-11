function test_excitation_calculation()
%TEST_EXCITATION_CALCULATION  Regression test for excitation_calculation
%against the reference workbook's own example row (user-supplied
%"Excitation_design.xlsx", sheet "Excitation": F32/F33/F35/F36/F38/F39/
%J32/J33/J42/D57/D72 inputs).
%
%   Confirms the six gaps found in the original implementation are now
%   covered: altitude-based current derating (F47/F48), Size+Frequency
%   fan selection (AE7:AL18), a user-adjustable transformer margin
%   (F57, D57) in place of the hardcoded 15%, the converter-side current
%   I1S (F59), the thermal-relay/CT setting (F72) and "Add 280A4" check
%   (F73), and a full parallel recompute for the oversized voltage
%   column (I1S is scale-invariant in UV0 for a fixed If_nom and margin,
%   so both chains land on the same value here -- see the computation
%   below).

TOL = 1e-3;   % 0.1% relative
fprintf('--- excitation_calculation regression test (reference workbook example) ---\n');

Input = struct();
Input.Uf_nom            = 200;
Input.Uf_max             = 300;
Input.If_nom              = 732;
Input.If_max              = 1098;
Input.VoltageVariation    = 10;
Input.Altitude            = 75;     % < 1000 m -> no altitude derating in this example
Input.FanFrequency        = 50;
Input.UL_exc              = 6000;
Input.UV0_Selected        = 300;    % workbook F46 example value (below smallest DCS880 class)
Input.UV0_Oversized       = 330;    % workbook J42 example value
Input.TrafoMarginPercent  = 15;     % workbook D57
Input.CTRatio             = 800;    % workbook D72

E = excitation_calculation(Input);

%% ===== Required excitation voltage (workbook F45, pre-existing formula) =====
check('UV0_calc [VAC]', E.UV0_calc, 314.9846641, TOL*314.9846641);
check('UV0_calc_class [VAC]', E.UV0_calc_class, 380, 1e-9);

%% ===== Altitude derating (workbook F47) -- gap #1 =====
check('AltitudeDerating [%]', E.AltitudeDerating, 100, 1e-9);

%% ===== Transformer margin now an input, not hardcoded 15% -- gap #3 =====
check('SEx [kVA]', E.SEx, 310.7527779, TOL*310.7527779);
check('STr [kVA]', E.STr, 357.3656946, TOL*357.3656946);
check('I1P [A]', E.I1P, 34.38753, TOL*34.38753);

%% ===== I1S, converter-side current -- gap #4 (workbook F59) =====
% Scale-invariant in UV0 for fixed If_nom/margin: I1S = 0.817*If_nom*(1+m)
check('I1S [A]', E.I1S, 687.7506, TOL*687.7506);

%% ===== DCS880 selection: If_max=1098 A -> first Imax>=1098 is 1500 A (H6) =====
check('DCS_Type', E.DCS_Type, 'DCS880-S01-1500-06/07', 0);
check('DCS_Size', E.DCS_Size, 'H6', 0);
check('Imax_Converter [A]', E.Imax_Converter, 1500, 1e-9);
check('Imax_Converter_Derated [A]', E.Imax_Converter_Derated, 1500, 1e-9);
check('DCS_Utilization [%]', E.DCS_Utilization, 100*1098/1500, TOL*(100*1098/1500));

%% ===== Fan selection now matches Size AND Frequency -- gap #2 =====
check('FanType', E.FanType, 'R2E250-RB', 0);
check('FanPower [W]', E.FanPower, 227, 1e-9);
check('FanCurrent [A]', E.FanCurrent, 1.1, 1e-9);
check('FanBlockingCurrent [A]', E.FanBlockingCurrent, 3.1, 1e-9);

%% ===== Thermal relay / CT + 280A4 check -- gap #5 (workbook F72/F73) =====
check('RelaySetting_A [A]', E.RelaySetting_A, 0.821304, TOL*0.821304);
check('Add280A4', E.Add280A4, 'not required', 0);

%% ===== Oversized column: full parallel recompute -- gap #6 =====
check('SEx_Oversized [kVA]', E.SEx_Oversized, 341.8280557, TOL*341.8280557);
check('STr_Oversized [kVA]', E.STr_Oversized, 393.1022641, TOL*393.1022641);
check('I1S_Oversized [A]', E.I1S_Oversized, 687.7506, TOL*687.7506);
check('DCS_Type_Oversized', E.DCS_Type_Oversized, 'DCS880-S01-1500-06/07', 0);

%% ===== Altitude derating above 1000 m (workbook F47 formula, symbolic --
% this example row does not exercise the >=1000 m branch) =============
InputHighAlt = Input;
InputHighAlt.Altitude = 2000;
EHighAlt = excitation_calculation(InputHighAlt);
check('AltitudeDerating @2000m [%]', EHighAlt.AltitudeDerating, -0.01*2000+110, 1e-9);

%% ===== 60 Hz fan selection now available (was missing entirely) =====
Input60 = Input;
Input60.FanFrequency = 60;
E60 = excitation_calculation(Input60);
check('FanPower @60Hz [W]', E60.FanPower, 390, 1e-9);
check('FanCurrent @60Hz [A]', E60.FanCurrent, 1.7, 1e-9);

fprintf('All excitation_calculation tests passed.\n');

end

%% ==========================================================
function check(label, actual, expected, tol)
if ischar(actual) || isstring(actual)
    if ~strcmp(actual, expected)
        error('CycloTool:TestFailed', '%s mismatch: got ''%s'', expected ''%s''', ...
            label, char(actual), char(expected));
    end
else
    if abs(actual - expected) > tol
        error('CycloTool:TestFailed', ...
            '%s mismatch: got %.6g, expected %.6g (tol %.3g)', ...
            label, actual, expected, tol);
    end
end
fprintf('  OK    %s\n', label);
end
