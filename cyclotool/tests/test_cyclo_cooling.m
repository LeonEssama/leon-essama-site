classdef test_cyclo_cooling < matlab.unittest.TestCase
%TEST_CYCLO_COOLING
% Regression tests for the water-cooling engine
% (calculate_cyclo_water_cooling.m and dependents) against reference
% values extracted directly from the source workbook's own computed
% cells ("Design of Water-Cooling System for Cycloconverters",
% sheet "Calculation of flow & pressure"), glycol = 0%.
%
% Run with:
%   results = runtests('test_cyclo_cooling');
%
% These tests exist specifically to catch the class of regression
% that motivated them: the cooling engine was silently rewritten
% once already (previous "Aktogay workbook" topology, wrong
% component coefficients) with nothing to flag the mismatch. Any
% future change to cyclo_cooling_component_database.m,
% calculate_cyclo_stack_hydraulics.m or calculate_cyclo_cooling_
% hydraulics.m that drifts from the workbook will fail here.
%
% Tolerance: 0.1% relative. The workbook itself has ~0.02-0.05%
% column-to-column numerical noise from its own per-column
% goal-seek (verified independently in Python against these same
% reference cells); 0.1% comfortably separates "matches the
% workbook" from "wrong topology/coefficients".

    properties (Constant)
        RelTol = 1e-3
        FlowVector = [1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2]
    end

    methods (Test)

        function sixPulse(testCase)
            expectedFlow = [80.582472,89.53584,98.489318,107.443008, ...
                116.397216,125.351789,134.306352,143.261568];
            expectedDp   = [101.192229,123.378966,147.617204,173.885065, ...
                202.162846,232.432639,264.678049,298.883982];
            checkType(testCase, "6-pulse", expectedFlow, expectedDp);
        end

        function twelvePulse(testCase)
            expectedFlow = [161.167152,179.074080,196.981478,214.889208, ...
                232.797696,250.706909,268.616712,286.525968];
            expectedDp   = [101.997687,124.333951,148.762867,175.237868, ...
                203.739127,234.248623,266.749854,301.227598];
            checkType(testCase, "12-pulse", expectedFlow, expectedDp);
        end

        function sixPulseFused(testCase)
            expectedFlow = [149.119326,165.687720,182.256307,198.825264, ...
                215.395128,231.965630,248.536116,265.107744];
            expectedDp   = [101.846331,124.178875,148.576825,175.018187, ...
                203.483158,233.953730,266.413410,300.847037];
            checkType(testCase, "6-pulse-fused", expectedFlow, expectedDp);
        end

        function eighteenPulse(testCase)
            expectedFlow = [241.749624,268.609920,295.470797,322.332216, ...
                349.194912,376.058698,402.923064,429.787536];
            expectedDp   = [103.638535,126.370578,151.206134,178.122883, ...
                207.100742,238.121437,271.168226,306.225688];
            checkType(testCase, "18-pulse", expectedFlow, expectedDp);
        end

        function glycolTableMatchesWorkbook(testCase)
            % Calculation of flow & pressure, C120:I121
            pct = [0 10 20 30 40 50 60];
            expectedCp  = [4.1868 4.103064 3.893724 3.726252 3.495978 3.265704 3.098232];
            expectedVis = [1.000 1.032 1.064 1.096 1.128 1.160 1.192];
            for k = 1:numel(pct)
                Fluid = calculate_cyclo_cooling_glycol(pct(k));
                testCase.verifyEqual(Fluid.Cp_kJkgK, expectedCp(k), ...
                    'RelTol', 1e-9);
                testCase.verifyEqual(Fluid.ViscosityCorrection, expectedVis(k), ...
                    'RelTol', 1e-9);
            end
        end

        function branchBalanceIsSymmetric(testCase)
            % Upper and lower branch pressure drops must match at
            % the solved operating point (parallel branches, common
            % rails) to within solver tolerance.
            for q = testCase.FlowVector
                Branch = calculate_cyclo_stack_hydraulics(q);
                testCase.verifyEqual(Branch.DpUpper_kPa, Branch.DpLower_kPa, ...
                    'RelTol', 1e-6);
                testCase.verifyGreaterThan(Branch.QLower_lpm, 0);
            end
        end

        function invalidConverterTypeErrors(testCase)
            CoolingInput = referenceInput(1.8, 0, "not-a-real-type");
            testCase.verifyError( ...
                @() calculate_cyclo_water_cooling(CoolingInput), ...
                'Cyclo:InvalidCoolingConverterType');
        end

        function rerunWithChangedFlowDoesNotError(testCase)
            % Regression guard for the reported GUI symptom: run
            % once, change an input (here: QwKD_lpm), run again.
            % The calculation layer itself must tolerate this even
            % though the bug that prompted this test lived in the
            % GUI's dropdown repopulation, not here.
            r1 = calculate_cyclo_water_cooling(referenceInput(1.8, 0, "12-pulse"));
            r2 = calculate_cyclo_water_cooling(referenceInput(3.2, 20, "18-pulse"));
            testCase.verifyEqual(r1.Status, "PASS");
            testCase.verifyTrue(ismember(r2.Status, ["PASS","CHECK"]));
            testCase.verifyNotEqual(r1.TotalFlow_lpm, r2.TotalFlow_lpm);
        end

    end

end

function checkType(testCase, converterType, expectedFlow, expectedDp)
    flowVec = testCase.FlowVector;
    for k = 1:numel(flowVec)
        CoolingInput = referenceInput(flowVec(k), 0, converterType);
        Cooling = calculate_cyclo_water_cooling(CoolingInput);
        testCase.verifyEqual(Cooling.TotalFlow_lpm, expectedFlow(k), ...
            'RelTol', testCase.RelTol);
        testCase.verifyEqual(Cooling.TotalPressureDrop_kPa, expectedDp(k), ...
            'RelTol', testCase.RelTol);
    end
end

function CoolingInput = referenceInput(QwKD_lpm, glycolPercent, converterType)
    CoolingInput = struct();
    CoolingInput.QwKD_lpm = QwKD_lpm;
    CoolingInput.GlycolPercent = glycolPercent;
    CoolingInput.ConverterType = converterType;
    CoolingInput.ThyristorLoss_kW = 5.7;
    CoolingInput.ResistorLoss_kW = 14.3;
    CoolingInput.ConverterLoss_kW = 210;
    CoolingInput.MaxOutletTemperatureKD_C = 52;
    CoolingInput.MaxOutletTemperatureConverter_C = 60;
end
