classdef TestMetrics < matlab.unittest.TestCase
    methods (Test)
        function matchesAHandComputedExample(testCase)
            yTrue = [1 1 1 2 2 3 3 3 3]';
            yPred = [1 1 2 2 3 3 3 3 1]';
            m = dsp.classificationMetrics(yTrue, yPred, [1 2 3]');
            testCase.verifyEqual(m.confusion, [2 1 0; 0 1 1; 1 0 3]);
            testCase.verifyEqual(m.accuracy, 6 / 9, 'AbsTol', 1e-12);
            testCase.verifyEqual(m.precision, [2/3; 1/2; 3/4], 'AbsTol', 1e-12);
            testCase.verifyEqual(m.recall, [2/3; 1/2; 3/4], 'AbsTol', 1e-12);
            testCase.verifyEqual(m.f1, [2/3; 1/2; 3/4], 'AbsTol', 1e-12);
            testCase.verifyEqual(m.macroF1, (2/3 + 1/2 + 3/4) / 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(m.support, [3; 2; 4]);
        end

        function perClassValuesSumConsistentlyWithTheConfusionMatrix(testCase)
            rng(2);
            yTrue = randi(4, 200, 1);
            yPred = randi(4, 200, 1);
            m = dsp.classificationMetrics(yTrue, yPred, (1:4)');
            testCase.verifyEqual(sum(m.confusion(:)), 200);
            testCase.verifyEqual(sum(m.support), 200);
            testCase.verifyEqual(m.recall, diag(m.confusion) ./ sum(m.confusion, 2), 'AbsTol', 1e-12);
            testCase.verifyEqual(m.precision, diag(m.confusion) ./ sum(m.confusion, 1)', 'AbsTol', 1e-12);
            testCase.verifyEqual(m.accuracy, sum(yTrue == yPred) / 200, 'AbsTol', 1e-12);
        end

        function aClassThatIsNeverPredictedHasZeroPrecisionAndAWarning(testCase)
            yTrue = [1 2 2]';
            yPred = [1 1 1]';
            testCase.verifyWarning(@() dsp.classificationMetrics(yTrue, yPred, [1 2]'), 'dsp:metrics:noPredictions');
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('dsp:metrics:noPredictions'));
            m = dsp.classificationMetrics(yTrue, yPred, [1 2]');
            testCase.verifyEqual(m.precision, [1/3; 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(m.recall, [1; 0]);
            testCase.verifyEqual(m.f1, [0.5; 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(m.macroF1, 0.25, 'AbsTol', 1e-12);
            testCase.verifyEqual(m.accuracy, 1/3, 'AbsTol', 1e-12);
        end

        function aClassAbsentFromTheTruthIsLeftOutOfTheMacroAverages(testCase)
            m = dsp.classificationMetrics([1 1 2]', [1 2 2]', [1 2 3]');
            testCase.verifyEqual(m.support, [2; 1; 0]);
            testCase.verifyEqual(m.macroF1, 2/3, 'AbsTol', 1e-12);
            testCase.verifyEqual(m.macroRecall, mean([0.5 1]), 'AbsTol', 1e-12);
            testCase.verifySize(m.confusion, [3 3]);
        end

        function perfectPredictionsGiveOnes(testCase)
            y = [1 2 3 1 2 3]';
            m = dsp.classificationMetrics(y, y);
            testCase.verifyEqual(m.accuracy, 1);
            testCase.verifyEqual(m.macroF1, 1);
            testCase.verifyEqual(m.confusion, 2 * eye(3));
        end

        function badInputsAreRejected(testCase)
            testCase.verifyError(@() dsp.classificationMetrics([], []), 'dsp:metrics:empty');
            testCase.verifyError(@() dsp.classificationMetrics([1 2]', [1]'), 'dsp:metrics:sizeMismatch');
            testCase.verifyError(@() dsp.classificationMetrics([1 2]', [1 5]', [1 2]'), 'dsp:metrics:unknownLabel');
        end

        function balancedWeightsGiveEveryClassTheSameTotal(testCase)
            y = [ones(100, 1); 2 * ones(10, 1); 3 * ones(40, 1)];
            w = dsp.balancedWeights(y);
            totals = arrayfun(@(c) sum(w(y == c)), 1:3);
            testCase.verifyEqual(totals, repmat(150 / 3, 1, 3), 'AbsTol', 1e-9);
            testCase.verifyEqual(sum(w), numel(y), 'AbsTol', 1e-9);
        end

        function paramsAreDescribedAsText(testCase)
            testCase.verifyEqual(dsp.describeParams(struct('C', 10)), "C=10");
            testCase.verifyEqual(dsp.describeParams(struct('cycles', 200, 'leaf', 3)), "cycles=200, leaf=3");
            testCase.verifyEqual(dsp.describeParams(struct()), "default");
        end
    end
end
