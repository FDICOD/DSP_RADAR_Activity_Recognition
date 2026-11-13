classdef TestCheckDataSizes < matlab.unittest.TestCase
    properties
        Root
    end

    methods (TestMethodSetup)
        function makeFolders(testCase)
            testCase.Root = string(tempname);
            mkdir(fullfile(testCase.Root, 'converted', 'S1'));
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Access = private)
        function writeBytes(testCase, session, name, n)
            fid = fopen(fullfile(testCase.Root, 'converted', session, name), 'w');
            fwrite(fid, zeros(1, n), 'uint8');
            fclose(fid);
        end

        function writeReference(testCase, sessions, files, bytes)
            ref = table(sessions(:), files(:), bytes(:), 'VariableNames', {'session', 'file', 'bytes'});
            writetable(ref, fullfile(testCase.Root, 'converted_sizes.csv'));
        end
    end

    methods (Test)
        function reportsNothingWhenEverythingMatches(testCase)
            testCase.writeBytes('S1', 'a.mat', 10);
            testCase.writeBytes('S1', 'b.mat', 20);
            testCase.writeReference(["S1" "S1"], ["a.mat" "b.mat"], [10 20]);
            bad = check_data_sizes(testCase.Root);
            testCase.verifyEmpty(bad);
        end

        function reportsMissingAndWrongSizeFiles(testCase)
            testCase.writeBytes('S1', 'a.mat', 10);
            testCase.writeBytes('S1', 'c.mat', 7);
            testCase.writeReference(["S1" "S1" "S1"], ["a.mat" "b.mat" "c.mat"], [10 5 9]);
            bad = check_data_sizes(testCase.Root);
            testCase.verifyEqual(height(bad), 2);
            testCase.verifyEqual(bad.file(bad.status == "missing"), "b.mat");
            testCase.verifyEqual(bad.file(bad.status == "wrong size"), "c.mat");
            testCase.verifyEqual(bad.foundBytes(bad.status == "wrong size"), 7);
        end

        function emptyFileCountsAsWrongSize(testCase)
            testCase.writeBytes('S1', 'a.mat', 0);
            testCase.writeReference("S1", "a.mat", 100);
            bad = check_data_sizes(testCase.Root);
            testCase.verifyEqual(bad.status, "wrong size");
        end

        function aMissingSessionFolderMarksItsFilesMissing(testCase)
            testCase.writeReference(["S9" "S9"], ["a.mat" "b.mat"], [1 2]);
            bad = check_data_sizes(testCase.Root);
            testCase.verifyEqual(bad.status, ["missing"; "missing"]);
        end

        function missingReferenceFileGivesAHelpfulError(testCase)
            testCase.verifyError(@() check_data_sizes(testCase.Root), 'check_data_sizes:noReference');
        end
    end
end
