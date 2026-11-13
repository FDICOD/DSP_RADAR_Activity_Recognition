classdef TestStageData < matlab.unittest.TestCase
    properties
        Base
        Source
        Reference
        Target
    end

    methods (TestMethodSetup)
        function makeFolders(testCase)
            testCase.Base = string(tempname);
            testCase.Source = fullfile(testCase.Base, 'src');
            testCase.Target = fullfile(testCase.Base, 'staged');
            testCase.Reference = fullfile(testCase.Base, 'sizes.csv');
            mkdir(fullfile(testCase.Source, 'S1'));
            testCase.addTeardown(@() rmdir(testCase.Base, 's'));
            testCase.write('S1', 'a.mat', 10);
            testCase.write('S1', 'b.mat', 20);
            ref = table(["S1"; "S1"], ["a.mat"; "b.mat"], [10; 20], 'VariableNames', {'session', 'file', 'bytes'});
            writetable(ref, testCase.Reference);
        end
    end

    methods (Access = private)
        function write(testCase, session, name, n)
            fid = fopen(fullfile(testCase.Source, session, name), 'w');
            fwrite(fid, zeros(1, n), 'uint8');
            fclose(fid);
        end

        function failed = stageAll(testCase)
            failed = stage_data(Source=testCase.Source, Reference=testCase.Reference, ...
                Target=testCase.Target, Attempts=1);
        end
    end

    methods (Test)
        function copiesEveryFileAndMarksReady(testCase)
            failed = testCase.stageAll();
            testCase.verifyEmpty(failed);
            testCase.verifyTrue(isfile(fullfile(testCase.Target, 'READY')));
            testCase.verifyEqual(dir(fullfile(testCase.Target, 'converted', 'S1', 'b.mat')).bytes, 20);
        end

        function secondRunSkipsFilesAlreadyThere(testCase)
            testCase.stageAll();
            stamp = dir(fullfile(testCase.Target, 'converted', 'S1', 'a.mat')).datenum;
            pause(1.1);
            testCase.stageAll();
            testCase.verifyEqual(dir(fullfile(testCase.Target, 'converted', 'S1', 'a.mat')).datenum, stamp);
            testCase.verifyTrue(isfile(fullfile(testCase.Target, 'READY')));
        end

        function aWrongSizeFileIsReplaced(testCase)
            testCase.stageAll();
            fid = fopen(fullfile(testCase.Target, 'converted', 'S1', 'a.mat'), 'w');
            fwrite(fid, zeros(1, 3), 'uint8');
            fclose(fid);
            failed = testCase.stageAll();
            testCase.verifyEmpty(failed);
            testCase.verifyEqual(dir(fullfile(testCase.Target, 'converted', 'S1', 'a.mat')).bytes, 10);
        end

        function aFileThatCannotBeCopiedPreventsTheReadyMarker(testCase)
            delete(fullfile(testCase.Source, 'S1', 'b.mat'));
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('MATLAB:COPYFILE:SourceDoesNotExist'));
            failed = testCase.stageAll();
            testCase.verifyEqual(failed.file, "b.mat");
            testCase.verifyFalse(isfile(fullfile(testCase.Target, 'READY')));
        end

        function anOldReadyMarkerIsRemovedBeforeCopying(testCase)
            testCase.stageAll();
            delete(fullfile(testCase.Source, 'S1', 'b.mat'));
            delete(fullfile(testCase.Target, 'converted', 'S1', 'b.mat'));
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('MATLAB:COPYFILE:SourceDoesNotExist'));
            testCase.stageAll();
            testCase.verifyFalse(isfile(fullfile(testCase.Target, 'READY')));
        end

        function missingReferenceGivesAHelpfulError(testCase)
            testCase.verifyError(@() stage_data(Source=testCase.Source, ...
                Reference=fullfile(testCase.Base, 'nope.csv'), Target=testCase.Target), 'stage_data:noReference');
        end

        function defaultRootIsAFolderPath(testCase)
            root = dsp.defaultDataRoot();
            testCase.verifyTrue(endsWith(string(root), "converted"));
        end
    end
end
