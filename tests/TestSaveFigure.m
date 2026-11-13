classdef TestSaveFigure < matlab.unittest.TestCase
    methods (Test)
        function savesAValidFigure(testCase)
            file = string(tempname) + ".png";
            testCase.addTeardown(@() delete(file));
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            plot(axes(f), 1:5);
            ok = dsp.saveFigure(f, file);
            testCase.verifyTrue(ok);
            testCase.verifyTrue(isfile(file));
            testCase.verifyGreaterThan(dir(file).bytes, 0);
        end

        function createsTheFolder(testCase)
            folder = string(tempname);
            file = fullfile(folder, "sub", "a.png");
            testCase.addTeardown(@() rmdir(folder, 's'));
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            plot(axes(f), 1:5);
            testCase.verifyTrue(dsp.saveFigure(f, file));
            testCase.verifyTrue(isfile(file));
        end

        function usesTheNewestFigureWhenTheHandleIsInvalid(testCase)
            file = string(tempname) + ".png";
            testCase.addTeardown(@() delete(file));
            gone = figure('Visible', 'off');
            close(gone);
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            plot(axes(f), 1:5);
            testCase.verifyWarning(@() dsp.saveFigure(gone, file), 'dsp:saveFigure:usedNewest');
            testCase.verifyTrue(isfile(file));
        end

        function reportsFailureWhenTheFileCannotBeWritten(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'dsp:saveFigure:exportFailed', 'dsp:saveFigure:failed'}));
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            plot(axes(f), 1:5);
            ok = dsp.saveFigure(f, string(tempname) + ".notanimageformat");
            testCase.verifyFalse(ok);
        end
    end
end
