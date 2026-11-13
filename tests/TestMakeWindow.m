classdef TestMakeWindow < matlab.unittest.TestCase
    methods (Test)
        function rectangularIsAllOnes(testCase)
            testCase.verifyEqual(dsp.makeWindow("rect", 5), ones(5, 1));
        end

        function periodicHannHasKnownValues(testCase)
            testCase.verifyEqual(dsp.makeWindow("hann", 4), [0; 0.5; 1; 0.5], 'AbsTol', 1e-12);
        end

        function periodicHammingHasKnownValues(testCase)
            testCase.verifyEqual(dsp.makeWindow("hamming", 4), [0.08; 0.54; 1; 0.54], 'AbsTol', 1e-12);
        end

        function resultIsAColumnOfTheRequestedLength(testCase)
            testCase.verifySize(dsp.makeWindow("hann", 128), [128 1]);
        end

        function unknownWindowFails(testCase)
            testCase.verifyError(@() dsp.makeWindow("kaiser", 8), 'dsp:makeWindow:unknownWindow');
        end
    end
end
