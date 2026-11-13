classdef TestStft < matlab.unittest.TestCase
    properties (Constant)
        Prf = 1000
        Carrier = 5.8e9
    end

    methods (Access = private)
        function x = randomSignal(~, rows, n)
            rng(5);
            x = randn(rows, n) + 1j * randn(rows, n);
        end

        function [mag, freq, time] = reference(~, x, sp, prf)
            % MATLAB's spectrogram with our window, overlap and FFT size. Its
            % two-sided output starts at 0 Hz; fftshift reorders it to run from
            % -prf/2 like ours. (Its 'centered' option puts the Nyquist bin at
            % +prf/2 instead, one bin later than fftshift, with identical values.)
            w = dsp.makeWindow(sp.window, sp.windowLength);
            [ref, f, time] = spectrogram(x(:), w, sp.overlap, sp.nfft, prf, 'twosided');
            mag = abs(fftshift(ref, 1));
            freq = fftshift(f(:));
            freq(freq >= prf / 2) = freq(freq >= prf / 2) - prf;
            time = time(:);
        end
    end

    methods (Test)
        function outputSizeFollowsTheParameters(testCase)
            s = dsp.makeSettings(struct('stft', struct('overlapFraction', 0.5)));
            sp = dsp.stft(testCase.randomSignal(2, 1000), testCase.Prf, testCase.Carrier, s);
            % 0.2 s at 1 kHz = 200 samples, hop 100, FFT 4 x 200 = 800, 9 frames
            testCase.verifyEqual(sp.windowLength, 200);
            testCase.verifyEqual(sp.hop, 100);
            testCase.verifyEqual(sp.nfft, 800);
            testCase.verifySize(sp.mag, [800 9]);
            testCase.verifySize(sp.freq, [800 1]);
            testCase.verifyEqual(sp.time(1), 0.1, 'AbsTol', 1e-12);
            testCase.verifyEqual(diff(sp.time), 0.1 * ones(1, 8), 'AbsTol', 1e-12);
            testCase.verifyEqual(sp.freqResolution, 5);
            testCase.verifyEqual(sp.timeStep, 0.1, 'AbsTol', 1e-12);
            testCase.verifyEqual(sp.binWidth, 1.25);
        end

        function defaultSettingsGiveTheAuthorsParameters(testCase)
            sp = dsp.stft(testCase.randomSignal(1, 1000), testCase.Prf, testCase.Carrier, dsp.makeSettings());
            testCase.verifyEqual(sp.windowLength, 200);
            testCase.verifyEqual(sp.overlap, 190);
            testCase.verifyEqual(sp.hop, 10);
            testCase.verifyEqual(sp.nfft, 800);
            testCase.verifySize(sp.mag, [800 81]);
        end

        function chirpRidgeFollowsTheInstantaneousFrequency(testCase)
            n = 2000;
            t = (0:n-1) / testCase.Prf;
            f0 = 50;
            rate = 50;                                         % Hz per second
            x = exp(1j * 2 * pi * (f0 * t + rate * t .^ 2 / 2));
            sp = dsp.stft(x, testCase.Prf, testCase.Carrier, dsp.makeSettings());
            [~, i] = max(sp.mag, [], 1);
            ridge = reshape(sp.freq(i), 1, []);
            expected = f0 + rate * sp.time;
            testCase.verifyLessThanOrEqual(max(abs(ridge - expected)), sp.binWidth);
        end

        function binsAreCombinedByAddingMagnitudes(testCase)
            x = testCase.randomSignal(3, 800);
            s = dsp.makeSettings();
            all3 = dsp.stft(x, testCase.Prf, testCase.Carrier, s);
            parts = dsp.stft(x(1, :), testCase.Prf, testCase.Carrier, s).mag + ...
                    dsp.stft(x(2, :), testCase.Prf, testCase.Carrier, s).mag + ...
                    dsp.stft(x(3, :), testCase.Prf, testCase.Carrier, s).mag;
            testCase.verifyEqual(all3.mag, parts, 'RelTol', 1e-12);
            testCase.verifyEqual(all3.numBins, 3);
        end

        function overlapNotSmallerThanTheWindowIsRejected(testCase)
            s = dsp.makeSettings(struct('stft', struct('overlapFraction', 0.999)));
            testCase.verifyError(@() dsp.stft(testCase.randomSignal(1, 1000), testCase.Prf, testCase.Carrier, s), ...
                'dsp:stft:invalidOverlap');
        end

        function dataShorterThanTheWindowIsRejected(testCase)
            testCase.verifyError(@() dsp.stft(testCase.randomSignal(1, 100), testCase.Prf, testCase.Carrier, dsp.makeSettings()), ...
                'dsp:stft:tooShort');
        end

        function windowShorterThanTwoSamplesIsRejected(testCase)
            testCase.verifyError(@() dsp.stft(testCase.randomSignal(1, 50), 5, testCase.Carrier, dsp.makeSettings()), ...
                'dsp:stft:windowTooShort');
        end

        function invalidStftSettingsAreRejected(testCase)
            bad = {struct('overlapFraction', 1), struct('padFactor', 0), struct('windowSeconds', -1), ...
                   struct('imageSize', [1 5]), struct('window', 'blackman')};
            for k = 1:numel(bad)
                testCase.verifyError(@() dsp.makeSettings(struct('stft', bad{k})), 'dsp:settings:invalidValue');
            end
        end

        function matchesMatlabSpectrogramOnAnalyticSignals(testCase)
            x = testCase.randomSignal(1, 1500);
            sp = dsp.stft(x, testCase.Prf, testCase.Carrier, dsp.makeSettings());
            [mag, freq, time] = testCase.reference(x, sp, testCase.Prf);
            testCase.verifySize(sp.mag, size(mag));
            testCase.verifyEqual(sp.mag, mag, 'AbsTol', 1e-9 * max(mag(:)));
            testCase.verifyEqual(sp.freq(:), freq, 'AbsTol', 1e-9);
            testCase.verifyEqual(sp.time(:), time, 'AbsTol', 1e-9);
        end

        function matchesMatlabSpectrogramOnAChirp(testCase)
            n = 2000;
            t = (0:n-1) / testCase.Prf;
            x = exp(1j * 2 * pi * (50 * t + 25 * t .^ 2));
            s = dsp.makeSettings(struct('stft', struct('window', 'hann', 'overlapFraction', 0.75)));
            sp = dsp.stft(x, testCase.Prf, testCase.Carrier, s);
            mag = testCase.reference(x, sp, testCase.Prf);
            testCase.verifyEqual(sp.mag, mag, 'AbsTol', 1e-9 * max(mag(:)));
        end

        function matchesMatlabSpectrogramOnARealRecording(testCase)
            s = dsp.makeSettings();
            testCase.assumeTrue(isfolder(s.data.root), 'Converted data not found in data/converted.');
            T = dsp.listRecordings(s);
            T = T(T.included, :);
            testCase.assumeNotEmpty(T, 'No converted recordings found.');

            % the first recording of two different sessions
            for k = [find(T.session == "5 February 2019 UoG Dataset", 1), find(T.session == "1 December 2017 Dataset", 1)]
                try
                    rec = dsp.readConverted(T.file(k));
                catch err
                    testCase.assumeFail("Data file unreadable on this drive: " + err.message);
                end
                rt = dsp.rangeTime(rec, s);
                [pre, sel] = dsp.preprocess(rt, s);
                row = pre.data(sel.bins(1), :);
                sp = dsp.stft(row, pre.prf, pre.carrierHz, s);
                mag = testCase.reference(row, sp, pre.prf);
                testCase.verifyEqual(sp.mag, mag, 'AbsTol', 1e-9 * max(mag(:)), T.name(k));
            end
        end

        function microDopplerUsesTheSelectedBins(testCase)
            x = testCase.randomSignal(10, 800);
            pre = struct('data', x, 'prf', testCase.Prf, 'carrierHz', testCase.Carrier);
            sel = struct('bins', (3:5)', 'rangeMetres', [1.1 1.9]);
            s = dsp.makeSettings();
            sp = dsp.microDoppler(pre, sel, s);
            direct = dsp.stft(x(3:5, :), testCase.Prf, testCase.Carrier, s);
            testCase.verifyEqual(sp.mag, direct.mag);
            testCase.verifyEqual(sp.bins, (3:5)');
            testCase.verifyEqual(sp.rangeMetres, [1.1 1.9]);
            testCase.verifyEqual(sp.numBins, 3);
        end

        function resampledImagesHaveTheSameShapeAndRange(testCase)
            x = testCase.randomSignal(3, 3000);
            short = dsp.stft(x, testCase.Prf, testCase.Carrier, dsp.makeSettings());
            longer = dsp.stft(x, testCase.Prf, testCase.Carrier, ...
                dsp.makeSettings(struct('stft', struct('windowSeconds', 0.4))));
            testCase.verifyNotEqual(size(short.dB), size(longer.dB));
            a = dsp.resampleSpectrogram(short.dB, [64 48], 40);
            b = dsp.resampleSpectrogram(longer.dB, [64 48], 40);
            testCase.verifySize(a, [64 48]);
            testCase.verifySize(b, [64 48]);
            for img = {a, b}
                testCase.verifyGreaterThanOrEqual(min(img{1}(:)), 0);
                testCase.verifyLessThanOrEqual(max(img{1}(:)), 1);
            end
        end

        function resamplingTinyInputIsRejected(testCase)
            testCase.verifyError(@() dsp.resampleSpectrogram(ones(1, 5), [8 8], 40), 'dsp:resample:tooSmall');
        end

        function plotUsesVelocityWhenAvailable(testCase)
            sp = dsp.stft(testCase.randomSignal(1, 800), testCase.Prf, testCase.Carrier, dsp.makeSettings());
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            ax = axes(f);
            dsp.plotSpectrogram(sp, Axes=ax, Title="demo");
            testCase.verifyEqual(string(ax.XLabel.String), "Time (s)");
            testCase.verifyEqual(string(ax.YLabel.String), "Velocity (m/s)");
            testCase.verifyEqual(string(ax.Title.String), "demo");
        end

        function plotFallsBackToHertz(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('dsp:velocity:unavailable'));
            sp = dsp.stft(testCase.randomSignal(1, 800), testCase.Prf, NaN, dsp.makeSettings());
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            ax = axes(f);
            dsp.plotSpectrogram(sp, Axes=ax);
            testCase.verifyEqual(string(ax.YLabel.String), "Doppler (Hz)");
        end
    end
end
