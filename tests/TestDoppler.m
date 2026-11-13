classdef TestDoppler < matlab.unittest.TestCase
    properties (Constant)
        Prf = 1000
        Carrier = 5.8e9
    end

    methods (Test)
        function positiveToneIsLocatedWithinOneBin(testCase)
            t = (0:999) / testCase.Prf;
            sp = dsp.dopplerSpectrum(exp(1j * 2 * pi * 100 * t), testCase.Prf, testCase.Carrier, dsp.makeSettings());
            [~, i] = max(sp.mag);
            testCase.verifyLessThanOrEqual(abs(sp.freq(i) - 100), sp.binWidth);
            testCase.verifyGreaterThan(sp.freq(i), 0);
        end

        function negativeToneHasNegativeFrequency(testCase)
            t = (0:999) / testCase.Prf;
            sp = dsp.dopplerSpectrum(exp(-1j * 2 * pi * 100 * t), testCase.Prf, testCase.Carrier, dsp.makeSettings());
            [~, i] = max(sp.mag);
            testCase.verifyLessThanOrEqual(abs(sp.freq(i) + 100), sp.binWidth);
            testCase.verifyLessThan(sp.freq(i), 0);
        end

        function frequencyAxisIsCentredOnZero(testCase)
            sp = dsp.dopplerSpectrum(ones(1, 1000), testCase.Prf, testCase.Carrier, dsp.makeSettings());
            testCase.verifyEqual(sp.nfft, 1024);                      % next power of two above 1000
            testCase.verifyEqual(sp.freq(1), -testCase.Prf / 2);
            testCase.verifyEqual(sp.freq(513), 0);
            testCase.verifyEqual(sp.freq(end), testCase.Prf / 2 - sp.binWidth, 'AbsTol', 1e-9);
            testCase.verifySize(sp.mag, [1024 1]);
        end

        function binsAreCombinedNonCoherently(testCase)
            t = (0:999) / testCase.Prf;
            x = exp(1j * 2 * pi * 100 * t);
            one = dsp.dopplerSpectrum(x, testCase.Prf, testCase.Carrier, dsp.makeSettings());
            two = dsp.dopplerSpectrum([x; x], testCase.Prf, testCase.Carrier, dsp.makeSettings());
            testCase.verifyEqual(two.mag, 2 * one.mag, 'RelTol', 1e-12);
            testCase.verifyEqual(two.numBins, 2);
        end

        function matchesANaiveDft(testCase)
            x = [1+2j, -3, 0.5j, 4, 2-1j, -1, 0, 3j];
            s = dsp.makeSettings(struct('doppler', struct('window', 'rect', 'fftSize', 8)));
            sp = dsp.dopplerSpectrum(x, testCase.Prf, testCase.Carrier, s);
            n = 0:7;
            k = (0:7)';
            X = exp(-1j * 2 * pi * k * n / 8) * x(:);
            testCase.verifyEqual(sp.mag, fftshift(abs(X)), 'AbsTol', 1e-12);
        end

        function tooSmallFftSizeIsRejected(testCase)
            s = dsp.makeSettings(struct('doppler', struct('fftSize', 8)));
            testCase.verifyError(@() dsp.dopplerSpectrum(ones(1, 16), testCase.Prf, testCase.Carrier, s), ...
                'dsp:doppler:fftTooSmall');
        end

        function velocityIsFrequencyTimesHalfWavelength(testCase)
            [v, ok] = dsp.velocityAxis(100, testCase.Carrier);
            testCase.verifyTrue(ok);
            testCase.verifyEqual(v, 100 * (299792458 / 5.8e9) / 2, 'RelTol', 1e-12);
            % lambda is about 5.17 cm, so 100 Hz is about 2.58 m/s
            testCase.verifyEqual(v, 2.584, 'AbsTol', 1e-3);
        end

        function spectrumCarriesTheVelocityAxis(testCase)
            sp = dsp.dopplerSpectrum(ones(1, 1000), testCase.Prf, testCase.Carrier, dsp.makeSettings());
            testCase.verifyTrue(sp.velocityAvailable);
            testCase.verifyEqual(sp.velocity, sp.freq * (299792458 / 5.8e9) / 2, 'RelTol', 1e-12);
        end

        function missingCarrierGivesAWarning(testCase)
            testCase.verifyWarning(@() dsp.velocityAxis(100, NaN), 'dsp:velocity:unavailable');
        end

        function missingCarrierReportsVelocityUnavailable(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('dsp:velocity:unavailable'));
            [v, ok] = dsp.velocityAxis(100, []);
            testCase.verifyFalse(ok);
            testCase.verifyEmpty(v);
            sp = dsp.dopplerSpectrum(ones(1, 64), testCase.Prf, NaN, dsp.makeSettings());
            testCase.verifyFalse(sp.velocityAvailable);
            testCase.verifyEqual(size(sp.freq, 1), sp.nfft);
        end
    end
end
