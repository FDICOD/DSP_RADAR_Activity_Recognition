classdef TestClassifiers < matlab.unittest.TestCase
    properties (TestParameter)
        method = {"svm", "knn", "forest"}
    end

    methods (Access = private)
        function [X, y] = clusters(~, perClass, seed)
            % three well-separated classes in four features
            rng(seed);
            centres = [0 0 0 0; 5 0 5 0; 0 5 0 5];
            X = zeros(0, 4);
            y = zeros(0, 1);
            for c = 1:3
                X = [X; centres(c, :) + randn(perClass, 4)]; %#ok<AGROW>
                y = [y; c * ones(perClass, 1)]; %#ok<AGROW>
            end
        end

        function p = quickParams(~, method)
            switch method
                case "svm", p = struct('C', 10);
                case "knn", p = struct('k', 3);
                otherwise, p = struct('cycles', 50, 'leaf', 1);
            end
        end

        function rec = mover(~, f, seed)
            % a moving target (f Hz Doppler) plus a strong static reflector and weak noise
            rng(seed);
            nts = 128; nc = 1500;
            n = (0:nts-1)'; m = 0:nc-1;
            x = exp(1j * 2 * pi * 16 * n / nts) .* exp(1j * 2 * pi * f * m / 1000) ...
                + 0.05 * (randn(nts, nc) + 1j * randn(nts, nc)) + 3 * exp(1j * 2 * pi * 22 * n / nts);
            rec = dsp.makeRecording(5.8e9, 1, nts, 4e8, real(x(:)), imag(x(:)));
        end
    end

    methods (Test)
        function everyMethodSeparatesEasyClasses(testCase, method)
            [Xtr, ytr] = testCase.clusters(40, 1);
            [Xte, yte] = testCase.clusters(30, 2);
            model = dsp.trainClassifier(Xtr, ytr, method, testCase.quickParams(method), 1);
            [yhat, conf, scores] = dsp.predictClassifier(model, Xte);
            testCase.verifyGreaterThan(mean(yhat == yte), 0.95);
            testCase.verifySize(scores, [numel(yte) 3]);
            testCase.verifyGreaterThanOrEqual(min(conf), 0);
            testCase.verifyLessThanOrEqual(max(conf), 1 + 1e-9);
            testCase.verifyEqual(sum(scores, 2), ones(numel(yte), 1), 'AbsTol', 1e-6);
            testCase.verifyEqual(conf, max(scores, [], 2));
        end

        function trainingIsReproducibleForTheSameSeed(testCase, method)
            [X, y] = testCase.clusters(30, 3);
            [Xte, ~] = testCase.clusters(20, 4);
            a = dsp.trainClassifier(X, y, method, testCase.quickParams(method), 7);
            b = dsp.trainClassifier(X, y, method, testCase.quickParams(method), 7);
            testCase.verifyEqual(dsp.predictClassifier(a, Xte), dsp.predictClassifier(b, Xte));
        end

        function standardisationUsesOnlyTheTrainingData(testCase)
            [X, y] = testCase.clusters(30, 5);
            model = dsp.trainClassifier(X, y, "knn", struct('k', 3), 1);
            testCase.verifyEqual(model.mu, mean(X, 1), 'AbsTol', 1e-12);
            testCase.verifyEqual(model.sd, std(X, 0, 1), 'AbsTol', 1e-12);
            testCase.verifyEqual(model.trainCounts, [30; 30; 30]);
        end

        function aConstantFeatureDoesNotBreakStandardisation(testCase)
            [X, y] = testCase.clusters(30, 6);
            X(:, 2) = 3;
            model = dsp.trainClassifier(X, y, "knn", struct('k', 3), 1);
            testCase.verifyEqual(model.sd(2), 1);
            yhat = dsp.predictClassifier(model, X);
            testCase.verifyGreaterThan(mean(yhat == y), 0.95);
        end

        function badInputsAreRejected(testCase)
            [X, y] = testCase.clusters(10, 1);
            testCase.verifyError(@() dsp.trainClassifier(X, y, "tree", struct(), 1), 'dsp:train:unknownMethod');
            testCase.verifyError(@() dsp.trainClassifier(X, y(1:5), "knn", struct(), 1), 'dsp:train:sizeMismatch');
            testCase.verifyError(@() dsp.trainClassifier(X, ones(30, 1), "knn", struct(), 1), 'dsp:train:oneClass');
            bad = X;
            bad(1) = NaN;
            testCase.verifyError(@() dsp.trainClassifier(bad, y, "knn", struct(), 1), 'dsp:train:nonFinite');
            model = dsp.trainClassifier(X, y, "knn", struct('k', 3), 1);
            testCase.verifyError(@() dsp.predictClassifier(model, X(:, 1:3)), 'dsp:predict:featureCount');
        end

        function tuningPicksTheBestValidationCandidate(testCase, method)
            [Xtr, ytr] = testCase.clusters(25, 1);
            [Xva, yva] = testCase.clusters(15, 2);
            [best, grid] = dsp.tuneClassifier(method, Xtr, ytr, Xva, yva, 1);
            testCase.verifyGreaterThanOrEqual(height(grid), 3);
            [top, i] = max(grid.valMacroF1);
            testCase.verifyEqual(dsp.describeParams(best), grid.params(i));
            testCase.verifyGreaterThan(top, 0.9);
        end

        function tuningNeverTouchesTestData(testCase)
            % the signature has no test inputs; unknown methods are refused
            [X, y] = testCase.clusters(10, 1);
            testCase.verifyError(@() dsp.tuneClassifier("tree", X, y, X, y, 1), 'dsp:tune:unknownMethod');
        end

        function savedModelReloadsAndPredictsIdentically(testCase, method)
            [X, y] = testCase.clusters(30, 8);
            s = dsp.makeSettings();
            model = dsp.trainClassifier(X, y, method, testCase.quickParams(method), 1);
            file = string(tempname) + ".mat";
            testCase.addTeardown(@() delete(file));
            dsp.saveModel(model, s, file);
            bundle = dsp.loadModel(file);
            testCase.verifyEqual(bundle.settings, s);
            testCase.verifyEqual(numel(bundle.featureNames), 18);
            testCase.verifyEqual(bundle.activityNames, string(s.activity.codeNames));
            [Xte, ~] = testCase.clusters(10, 9);
            testCase.verifyEqual(dsp.predictClassifier(bundle.model, Xte), dsp.predictClassifier(model, Xte));
        end

        function loadingAMissingOrWrongFileFails(testCase)
            testCase.verifyError(@() dsp.loadModel(string(tempname) + ".mat"), 'dsp:loadModel:notFound');
            file = string(tempname) + ".mat";
            testCase.addTeardown(@() delete(file));
            x = 1; %#ok<NASGU>
            save(file, 'x');
            testCase.verifyError(@() dsp.loadModel(file), 'dsp:loadModel:badFile');
        end

        function aRecordingIsClassifiedFromRawSamplesToLabel(testCase)
            s = dsp.makeSettings();
            freqs = {40, 200};
            X = zeros(0, 18);
            y = zeros(0, 1);
            for c = 1:2
                for i = 1:8
                    rec = testCase.mover(freqs{c} + 4 * (i - 4), 100 * c + i);
                    X(end+1, :) = dsp.extractFeatures(dsp.spectrogramOf(rec, s), s); %#ok<AGROW>
                    y(end+1, 1) = c; %#ok<AGROW>
                end
            end
            model = dsp.trainClassifier(X, y, "knn", struct('k', 3), 1);
            file = string(tempname) + ".mat";
            testCase.addTeardown(@() delete(file));
            dsp.saveModel(model, s, file);
            bundle = dsp.loadModel(file);

            slow = dsp.classifyRecording(bundle, testCase.mover(42, 901));
            fast = dsp.classifyRecording(bundle, testCase.mover(195, 902));
            testCase.verifyEqual(slow.code, 1);
            testCase.verifyEqual(slow.name, "walking");
            testCase.verifyEqual(fast.code, 2);
            testCase.verifyEqual(fast.name, "sitting down");
            testCase.verifyGreaterThan(fast.confidence, 0.5);
            testCase.verifySize(fast.features, [1 18]);
        end

        function aGlobalNormalizerCannotBeSavedWithoutItsFit(testCase)
            [X, y] = testCase.clusters(10, 1);
            model = dsp.trainClassifier(X, y, "knn", struct('k', 3), 1);
            s = dsp.makeSettings(struct('normalize', struct('mode', 'global')));
            testCase.verifyError(@() dsp.saveModel(model, s, string(tempname) + ".mat"), 'dsp:saveModel:globalNormalizer');
        end
    end
end
