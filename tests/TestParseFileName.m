classdef TestParseFileName < matlab.unittest.TestCase
    methods (Test)
        function oneDigitRepetition(testCase)
            info = dsp.parseFileName('1P05A01R1.dat');
            testCase.verifyTrue(info.valid);
            testCase.verifyEqual(info.subject, "P05");
            testCase.verifyEqual(info.activityCode, 1);
            testCase.verifyEqual(info.repetition, 1);
        end

        function twoDigitRepetitionAndNoExtension(testCase)
            info = dsp.parseFileName('1P36A01R01');
            testCase.verifyTrue(info.valid);
            testCase.verifyEqual(info.subject, "P36");
            testCase.verifyEqual(info.repetition, 1);
        end

        function convertedExtensionIsAccepted(testCase)
            info = dsp.parseFileName('6P08A06R3.mat');
            testCase.verifyTrue(info.valid);
            testCase.verifyEqual(info.activityCode, 6);
            testCase.verifyEqual(info.subject, "P08");
        end

        function oneDigitActivityField(testCase)
            info = dsp.parseFileName('1P53A1R01.dat');
            testCase.verifyTrue(info.valid);
            testCase.verifyEqual(info.activityCode, 1);
            testCase.verifyEqual(info.subject, "P53");
        end

        function inconsistentDigitsAreFlagged(testCase)
            for name = ["3P03A02R1.dat" "2P34A03R1.dat" "6P01A05R03.dat"]
                info = dsp.parseFileName(name);
                testCase.verifyFalse(info.valid, name);
                testCase.verifyEqual(info.reason, "inconsistent_digits", name);
            end
        end

        function handMadeCopiesAreRejected(testCase)
            for name = ["4P30A04R3 (2).dat" "4P64A04R3 - Copy.dat" "notes.dat"]
                info = dsp.parseFileName(name);
                testCase.verifyFalse(info.valid, name);
                testCase.verifyEqual(info.reason, "name_not_matching", name);
            end
        end
    end
end
