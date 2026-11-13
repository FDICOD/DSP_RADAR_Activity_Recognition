classdef TestVelocityExtent < matlab.unittest.TestCase
    methods (Access = private)
        function dop = spectrum(~, v, mag)
            dop = struct('velocity', v(:), 'mag', mag(:), 'velocityAvailable', true);
        end
    end

    methods (Test)
        function singleLineHasThatSpeed(testCase)
            dop = testCase.spectrum([-3 -1 0 1 3], [0 0 0 1 0]);
            e = dsp.velocityExtent(dop);
            testCase.verifyEqual(e.v95, 1);
            testCase.verifyEqual(e.vRms, 1, 'AbsTol', 1e-12);
        end

        function twoSymmetricLinesGiveTheirSpeed(testCase)
            dop = testCase.spectrum([-3 -1 0 1 3], [1 0 0 0 1]);
            e = dsp.velocityExtent(dop);
            testCase.verifyEqual(e.v95, 3);
            testCase.verifyEqual(e.vRms, 3, 'AbsTol', 1e-12);
        end

        function widerSpectrumHasLargerExtent(testCase)
            v = linspace(-6, 6, 1201);
            narrow = dsp.velocityExtent(testCase.spectrum(v, exp(-v .^ 2 / (2 * 0.5 ^ 2))));
            wide = dsp.velocityExtent(testCase.spectrum(v, exp(-v .^ 2 / (2 * 1.5 ^ 2))));
            testCase.verifyGreaterThan(wide.v95, narrow.v95);
            testCase.verifyGreaterThan(wide.vRms, narrow.vRms);
        end

        function gaussianPowerHasTheExpectedRms(testCase)
            % magnitude exp(-v^2 / (2 s^2)) gives power exp(-v^2 / s^2): variance s^2 / 2
            v = linspace(-10, 10, 4001);
            s = 1.2;
            e = dsp.velocityExtent(testCase.spectrum(v, exp(-v .^ 2 / (2 * s ^ 2))));
            testCase.verifyEqual(e.vRms, s / sqrt(2), 'RelTol', 1e-3);
        end

        function missingVelocityAxisIsRejected(testCase)
            dop = struct('velocity', [], 'mag', [1; 2; 3], 'velocityAvailable', false);
            testCase.verifyError(@() dsp.velocityExtent(dop), 'dsp:extent:noVelocity');
        end

        function emptyPowerIsRejected(testCase)
            dop = testCase.spectrum([-1 0 1], [0 0 0]);
            testCase.verifyError(@() dsp.velocityExtent(dop), 'dsp:extent:noPower');
        end

        function aFasterMoverHasALargerExtent(testCase)
            % end to end on synthetic scenes: 60 Hz versus 200 Hz Doppler
            s = dsp.makeSettings();
            ext = zeros(1, 2);
            for k = 1:2
                f = [60 200];
                nts = 128; nc = 3000;
                n = (0:nts-1)'; m = 0:nc-1;
                x = exp(1j * 2 * pi * 16 * n / nts) .* exp(1j * 2 * pi * f(k) * m / 1000);
                rec = dsp.makeRecording(5.8e9, 1, nts, 4e8, real(x(:)), imag(x(:)));
                rt = dsp.rangeTime(rec, s);
                [pre, sel] = dsp.preprocess(rt, s);
                dop = dsp.dopplerSpectrum(pre.data(sel.bins, :), pre.prf, pre.carrierHz, s);
                ext(k) = dsp.velocityExtent(dop).v95;
            end
            testCase.verifyGreaterThan(ext(2), ext(1));
            % 200 Hz at 5.8 GHz is about 5.2 m/s, 60 Hz about 1.55 m/s
            testCase.verifyEqual(ext(2), 200 * (299792458 / 5.8e9) / 2, 'AbsTol', 0.3);
        end
    end
end
