function run_all_tests()
%RUN_ALL_TESTS  Entry point for the CycloTool cooling-engine test
% suite. Run from the tests/ folder (or with it and the cooling
% source folder both on path):
%
%   run_all_tests
%
% Non-zero exit if any test fails -- suitable for CI.

results = runtests('test_cyclo_cooling');
disp(table(results));

if any([results.Failed])
    error('CycloTool:TestsFailed', ...
        '%d of %d cooling-engine tests failed.', ...
        sum([results.Failed]), numel(results));
end

fprintf('All %d cooling-engine tests passed.\n', numel(results));

end
