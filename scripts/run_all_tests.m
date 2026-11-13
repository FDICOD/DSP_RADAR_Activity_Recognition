function results = run_all_tests()
% RUN_ALL_TESTS Run every test in the tests folder and write a plain-text log.
%   Writes results/test_log.txt (TAP format, includes failure details) so the
%   output can be pasted or downloaded without screenshots.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'tests'));

outDir = fullfile(root, 'results');
if ~isfolder(outDir)
    mkdir(outDir);
end
logFile = fullfile(outDir, 'test_log.txt');

import matlab.unittest.plugins.TAPPlugin
import matlab.unittest.plugins.ToFile

suite = testsuite(fullfile(root, 'tests'));
runner = testrunner('textoutput');
runner.addPlugin(TAPPlugin.producingVersion13(ToFile(logFile)));
results = runner.run(suite);

disp(table(results));
fprintf('\nPassed: %d  Failed: %d  Incomplete: %d  (of %d)\n', ...
    nnz([results.Passed]), nnz([results.Failed]), nnz([results.Incomplete]), numel(results));
fprintf('Log written to: %s\n', logFile);
end
