classdef TestNoise < matlab.unittest.TestCase
    methods (Access = private)
        function rec = offsetNoiseRecording(~)
            % 500 chirps of 128 samples: random beat signal on a constant ADC offset
            rng(11);
            n = 128 * 500;
            rec = dsp.makeRecording(5.8e9, 1, 128, 4e8, 2000 + 100 * randn(n, 1), 2100 + 80 * randn(n, 1));
        end

        function rec = syntheticScene(~)
            % static reflector (bin 22) and a 100 Hz mover (bin 16) on an ADC offset
            nts = 128; nc = 3000; prf = 1000;
            n = (0:nts-1)';
            m = 0:nc-1;
            x = 5 * exp(1j * 2 * pi * 22 * n / nts) .* ones(1, nc) ...
                + exp(1j * 2 * pi * 16 * n / nts) .* exp(1j * 2 * pi * 100 * m / prf) + (2000 + 2000j);
            rec = dsp.makeRecording(5.8e9, 1, nts, 4e8, real(x(:)), imag(x(:)));
        end
    end

    methods (Test)
        function achievesTheRequestedSnr(testCase)
            rec = testCase.offsetNoiseRecording();
            ps = mean(abs(rec.iq - mean(rec.iq)) .^ 2);
            for snr = [20 10 5 0]
                noisy = dsp.addNoise(rec, snr, 3);
                added = noisy.iq - rec.iq;
                measured = 10 * log10(ps / mean(abs(added) .^ 2));
                testCase.verifyEqual(measured, snr, 'AbsTol', 0.1, sprintf('SNR %g dB', snr));
            end
        end

        function noiseIsSplitEquallyBetweenIAndQ(testCase)
            rec = testCase.offsetNoiseRecording();
            added = dsp.addNoise(rec, 10, 4).iq - rec.iq;
            testCase.verifyEqual(var(real(added)), var(imag(added)), 'RelTol', 0.05);
            testCase.verifyLessThan(abs(mean(added)), 0.05 * std(real(added)));
        end

        function sameSeedGivesTheSameNoise(testCase)
            rec = testCase.offsetNoiseRecording();
            a = dsp.addNoise(rec, 5, 7);
            b = dsp.addNoise(rec, 5, 7);
            c = dsp.addNoise(rec, 5, 8);
            testCase.verifyEqual(a.iq, b.iq);
            testCase.verifyNotEqual(a.iq, c.iq);
        end

        function infiniteSnrLeavesTheSignalUnchanged(testCase)
            rec = testCase.offsetNoiseRecording();
            out = dsp.addNoise(rec, Inf, 1);
            testCase.verifyEqual(out.iq, rec.iq);
        end

        function globalRandomStateIsUntouched(testCase)
            rec = testCase.offsetNoiseRecording();
            rng(42);
            expected = rand(1, 3);
            rng(42);
            dsp.addNoise(rec, 5, 1);
            testCase.verifyEqual(rand(1, 3), expected);
        end

        function everythingElseInTheRecordingIsKept(testCase)
            rec = testCase.offsetNoiseRecording();
            noisy = dsp.addNoise(rec, 5, 1);
            for f = ["carrierHz" "chirpDuration" "samplesPerChirp" "bandwidthHz" "numChirps" "prf"]
                testCase.verifyEqual(noisy.(f), rec.(f), f);
            end
            testCase.verifySize(noisy.iq, size(rec.iq));
            testCase.verifyEqual(noisy.noise.snrDb, 5);
            testCase.verifyEqual(noisy.noise.seed, 1);
        end

        function silentRecordingIsRejected(testCase)
            rec = dsp.makeRecording(5.8e9, 1, 128, 4e8, 2000 * ones(1280, 1), 2000 * ones(1280, 1));
            testCase.verifyError(@() dsp.addNoise(rec, 10, 1), 'dsp:noise:noSignal');
        end

        function invalidSnrIsRejected(testCase)
            rec = testCase.offsetNoiseRecording();
            testCase.verifyError(@() dsp.addNoise(rec, NaN, 1), 'dsp:noise:badSnr');
            testCase.verifyError(@() dsp.addNoise(rec, -Inf, 1), 'dsp:noise:badSnr');
        end

        function noiseReachesTheRangeProcessingStage(testCase)
            rec = testCase.syntheticScene();
            s = dsp.makeSettings();
            clean = dsp.rangeTime(rec, s);
            noisy = dsp.rangeTime(dsp.addNoise(rec, 10, 1), s);
            farBin = 60;                                   % no target there
            testCase.verifyGreaterThan(mean(abs(noisy.data(farBin, :)) .^ 2), ...
                1e6 * mean(abs(clean.data(farBin, :)) .^ 2) + 1);
        end

        function identicalSpectrogramsHaveNoDegradation(testCase)
            sp = dsp.spectrogramOf(testCase.syntheticScene(), dsp.makeSettings());
            d = dsp.spectrogramDegradation(sp, sp, 40);
            testCase.verifyEqual(d.correlation, 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(d.nrmse, 0, 'AbsTol', 1e-12);
        end

        function degradationOfDifferentSizesIsRejected(testCase)
            a = struct('dB', zeros(10, 10));
            b = struct('dB', zeros(10, 12));
            testCase.verifyError(@() dsp.spectrogramDegradation(a, b, 40), 'dsp:degradation:sizeMismatch');
        end

        function degradationGrowsAsSnrFalls(testCase)
            T = dsp.snrSweep(testCase.syntheticScene(), [20 10 5 0], dsp.makeSettings(), 1, 3);
            testCase.verifyEqual(T.snrDb', [20 10 5 0]);
            testCase.verifyTrue(all(diff(T.correlation) < 0), 'correlation should fall as SNR falls');
            testCase.verifyTrue(all(diff(T.nrmse) > 0), 'nrmse should rise as SNR falls');
            testCase.verifyGreaterThan(T.correlation(1), 0.6);
            testCase.verifyLessThan(T.correlation(end), T.correlation(1));
        end
    end
end
