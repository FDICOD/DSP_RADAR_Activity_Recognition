classdef TestSettings < matlab.unittest.TestCase
    methods (Test)
        function defaultsAreValid(testCase)
            s = dsp.makeSettings();
            testCase.verifyEqual(s.seed, 1);
            testCase.verifyEqual(string(s.data.format), "mat");
            testCase.verifyEqual(numel(s.activity.codeNames), 6);
        end

        function overrideIsApplied(testCase)
            s = dsp.makeSettings(struct('seed', 7, 'split', struct('train', 0.5, 'val', 0.25, 'test', 0.25)));
            testCase.verifyEqual(s.seed, 7);
            testCase.verifyEqual(s.split.train, 0.5);
            testCase.verifyEqual(s.split.val, 0.25);
        end

        function unknownTopLevelKeyIsRejected(testCase)
            testCase.verifyError(@() dsp.makeSettings(struct('sede', 1)), 'dsp:settings:unknownField');
        end

        function unknownNestedKeyIsRejected(testCase)
            testCase.verifyError(@() dsp.makeSettings(struct('split', struct('trian', 0.5))), ...
                'dsp:settings:unknownField');
        end

        function invalidSeedIsRejected(testCase)
            testCase.verifyError(@() dsp.makeSettings(struct('seed', -1)), 'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('seed', 1.5)), 'dsp:settings:invalidValue');
        end

        function invalidFractionsAreRejected(testCase)
            testCase.verifyError(@() dsp.makeSettings(struct('split', struct('train', 0.9))), ...
                'dsp:settings:invalidValue');
        end

        function invalidFormatIsRejected(testCase)
            testCase.verifyError(@() dsp.makeSettings(struct('data', struct('format', 'csv'))), ...
                'dsp:settings:invalidValue');
        end

        function sameSeedGivesSameRandomNumbers(testCase)
            dsp.setSeed(5);
            a = rand(1, 8);
            dsp.setSeed(5);
            b = rand(1, 8);
            testCase.verifyEqual(a, b);
        end

        function differentSeedsGiveDifferentNumbers(testCase)
            dsp.setSeed(5);
            a = rand(1, 8);
            dsp.setSeed(6);
            b = rand(1, 8);
            testCase.verifyNotEqual(a, b);
        end

        function metadataFileHasRequiredFields(testCase)
            runDir = string(tempname);
            cleaner = onCleanup(@() rmdir(runDir, 's'));
            s = dsp.makeSettings(struct('seed', 3));
            file = dsp.writeRunMetadata(runDir, s, struct('note', "unit test"));
            testCase.verifyTrue(isfile(file));
            m = jsondecode(fileread(file));
            for f = ["timestamp" "seed" "matlabRelease" "matlabVersion" "computer" "toolboxes" "settings" "extra"]
                testCase.verifyTrue(isfield(m, f), "missing field " + f);
            end
            testCase.verifyEqual(m.seed, 3);
            testCase.verifyEqual(numel(m.settings.activity.codeNames), 6);
            testCase.verifyTrue(any(strcmp({m.toolboxes.name}, 'Signal Processing Toolbox')));
        end
    end
end
