classdef TestPreprocessing < matlab.unittest.TestCase
    methods (Access = private)
        function rt = oneBin(~, signal)
            % Range-time data with a single range bin holding the given slow-time signal.
            rt = struct('data', signal(:).', 'rangeAxis', 5, 'maxRange', 5, 'prf', 1000);
        end

        function rt = fakeScene(~)
            % 60 bins, 3000 chirps at 1 kHz: static clutter, a moving target in bins
            % 15-25 (5.6-9.0 m) with a 100 Hz Doppler tone, and weak noise.
            nb = 60; nc = 3000;
            rng(7);
            t = (0:nc-1) / 1000;
            data = 0.01 * (randn(nb, nc) + 1j * randn(nb, nc));
            data(8, :) = data(8, :) + 50;
            data(15:25, :) = data(15:25, :) + 2 * exp(1j * 2 * pi * 100 * t);
            rt = struct('data', data, 'rangeAxis', (0:nb-1)' * 0.375, 'maxRange', 59 * 0.375, 'prf', 1000);
        end

        function s = withSettings(~, varargin)
            % withSettings("clutter", "method", "mean", ...) style helper: group, field, value triples
            s = dsp.makeSettings();
            for k = 1:3:numel(varargin)
                s.(varargin{k}).(varargin{k+1}) = varargin{k+2};
            end
        end
    end

    methods (Test)
        function noneLeavesDataUnchanged(testCase)
            rt = testCase.fakeScene();
            out = dsp.removeClutter(rt, testCase.withSettings("clutter", "method", "none"));
            testCase.verifyEqual(out.data, rt.data);
        end

        function allMethodsKeepTheArraySize(testCase)
            rt = testCase.fakeScene();
            for m = ["none" "mean" "highpass" "canceller"]
                out = dsp.removeClutter(rt, testCase.withSettings("clutter", "method", m));
                testCase.verifySize(out.data, size(rt.data), m);
            end
        end

        function constantOffsetIsRemoved(testCase)
            rt = testCase.oneBin(5 * ones(1, 2000));
            for m = ["mean" "highpass" "canceller"]
                out = dsp.removeClutter(rt, testCase.withSettings("clutter", "method", m));
                testCase.verifyLessThan(max(abs(out.data)), 1e-9, m);
            end
        end

        function offsetPeakAtZeroDopplerIsGreatlyReduced(testCase)
            t = (0:2999) / 1000;
            x = 5 + exp(1j * 2 * pi * 100 * t);
            rt = testCase.oneBin(x);
            out = dsp.removeClutter(rt, testCase.withSettings("clutter", "method", "highpass"));
            before = abs(sum(x));
            after = abs(sum(out.data));
            testCase.verifyLessThan(after / before, 1e-2);
            testCase.verifyLessThan(abs(mean(out.data)), 1e-2);
        end

        function movingToneKeepsItsFrequencyAndPower(testCase)
            t = (0:2999) / 1000;
            x = 5 + exp(1j * 2 * pi * 100 * t);       % offset plus a 100 Hz tone
            rt = testCase.oneBin(x);
            out = dsp.removeClutter(rt, testCase.withSettings("clutter", "method", "highpass"));
            y = out.data(1001:end);                    % skip the start-up transient
            testCase.verifyEqual(mean(abs(y) .^ 2), 1, 'RelTol', 0.02);
            spectrum = abs(fft(out.data));
            [~, k] = max(spectrum);
            testCase.verifyEqual(k - 1, 300);          % 100 Hz at 1 kHz over 3000 samples
        end

        function highpassCutoffAbovePulseRateFails(testCase)
            rt = testCase.fakeScene();
            s = testCase.withSettings("clutter", "cutoffHz", 600);
            testCase.verifyError(@() dsp.removeClutter(rt, s), 'dsp:clutter:badCutoff');
        end

        function denoiseNoneIsExactlyUnchanged(testCase)
            rt = testCase.fakeScene();
            out = dsp.denoiseSlowTime(rt, testCase.withSettings("denoise", "method", "none"));
            testCase.verifyEqual(out.data, rt.data);
        end

        function lowpassKeepsInBandAndRemovesOutOfBand(testCase)
            t = (0:2999) / 1000;
            inBand = testCase.oneBin(exp(1j * 2 * pi * 100 * t));
            outBand = testCase.oneBin(exp(1j * 2 * pi * 400 * t));
            s = testCase.withSettings("denoise", "method", "lowpass");
            a = dsp.denoiseSlowTime(inBand, s);
            b = dsp.denoiseSlowTime(outBand, s);
            testCase.verifyEqual(mean(abs(a.data(1001:end)) .^ 2), 1, 'RelTol', 0.05);
            testCase.verifyLessThan(mean(abs(b.data(1001:end)) .^ 2), 0.01);
        end

        function lowpassCutoffAbovePulseRateFails(testCase)
            rt = testCase.fakeScene();
            s = testCase.withSettings("denoise", "method", "lowpass", "denoise", "cutoffHz", 600);
            testCase.verifyError(@() dsp.denoiseSlowTime(rt, s), 'dsp:denoise:badCutoff');
        end

        function segmentNormalisationGivesUnitRms(testCase)
            rt = testCase.fakeScene();
            s = testCase.withSettings("normalize", "mode", "segment");
            [out, sel] = dsp.preprocess(rt, s);
            testCase.verifyEqual(dsp.segmentRms(out, sel.bins), 1, 'RelTol', 1e-9);
            testCase.verifyEqual(out.steps.normalize, "segment");
        end

        function globalNormalisationUsesTheFittedScale(testCase)
            rt = testCase.fakeScene();
            plain = dsp.preprocess(rt, testCase.withSettings());
            s = testCase.withSettings("normalize", "mode", "global");
            norm = dsp.fitNormalizer([1; 2; 3; 10]);
            testCase.verifyEqual(norm.scale, 2.5);
            out = dsp.preprocess(rt, s, norm);
            testCase.verifyEqual(out.data, plain.data / 2.5, 'AbsTol', 1e-12);
        end

        function globalNormalisationNeedsAFittedNormalizer(testCase)
            rt = testCase.fakeScene();
            s = testCase.withSettings("normalize", "mode", "global");
            testCase.verifyError(@() dsp.preprocess(rt, s), 'dsp:normalize:notFitted');
        end

        function fittedScaleDependsOnlyOnTheTrainingValues(testCase)
            train = [0.9; 1.1; 1.0; 1.2];
            a = dsp.fitNormalizer(train);
            % Validation and test values are never passed to the fit, so
            % whatever they are, the fit cannot change.
            b = dsp.fitNormalizer(train);
            testCase.verifyEqual(a, b);
            testCase.verifyEqual(a.scale, median(train));
            testCase.verifyEqual(a.count, 4);
        end

        function pipelineSwitchesAreIndependent(testCase)
            rt = testCase.fakeScene();
            base = testCase.withSettings();                      % clutter only
            withLowpass = testCase.withSettings("denoise", "method", "lowpass");
            clutterOnly = dsp.removeClutter(rt, base);
            a = dsp.preprocess(rt, base);
            b = dsp.preprocess(rt, withLowpass);
            % denoise "none" adds nothing beyond clutter removal
            testCase.verifyEqual(a.data, clutterOnly.data);
            % switching denoise on changes the data but not the other steps
            testCase.verifyNotEqual(b.data, a.data);
            testCase.verifyEqual(b.steps.clutter, a.steps.clutter);
            testCase.verifyEqual(b.steps.normalize, a.steps.normalize);
            testCase.verifyEqual(b.selection.bins, a.selection.bins);
        end

        function preprocessingRecordsWhatItDid(testCase)
            rt = testCase.fakeScene();
            [out, sel] = dsp.preprocess(rt, testCase.withSettings());
            testCase.verifyEqual(out.steps.clutter, "highpass");
            testCase.verifyEqual(out.steps.denoise, "none");
            testCase.verifyEqual(out.steps.normalize, "none");
            testCase.verifyEqual(out.steps.scale, 1);
            testCase.verifyEqual(sel.bins, (find(rt.rangeAxis >= 3.7 & rt.rangeAxis <= 11.3)));
            testCase.verifyGreaterThan(out.rmsSelected, 0);
        end

        function staticClutterBinsCarryNoEnergyAfterRemoval(testCase)
            rt = testCase.fakeScene();
            out = dsp.preprocess(rt, testCase.withSettings());
            staticBin = rms(abs(out.data(8, 1001:end)));
            movingBin = rms(abs(out.data(20, 1001:end)));
            testCase.verifyLessThan(staticBin, 0.05);
            testCase.verifyGreaterThan(movingBin, 1.5);
        end

        function invalidPreprocessingSettingsAreRejected(testCase)
            testCase.verifyError(@() dsp.makeSettings(struct('clutter', struct('method', 'median'))), ...
                'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('denoise', struct('method', 'wavelet'))), ...
                'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('normalize', struct('mode', 'zscore'))), ...
                'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('clutter', struct('order', 0))), ...
                'dsp:settings:invalidValue');
        end
    end
end
