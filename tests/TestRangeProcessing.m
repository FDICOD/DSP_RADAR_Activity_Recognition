classdef TestRangeProcessing < matlab.unittest.TestCase
    properties (Constant)
        C = 299792458
    end

    methods (Access = private)
        function rec = toneRecording(~, cyclesPerChirp, numChirps)
            % Beat tone with cyclesPerChirp cycles in every 128-sample chirp.
            nts = 128;
            x = repmat(exp(1j * 2 * pi * cyclesPerChirp * (0:nts-1)' / nts), numChirps, 1);
            rec = dsp.makeRecording(5.8e9, 1, nts, 4e8, real(x), imag(x));
        end
    end

    methods (Test)
        function reshapeGivesFastTimeByChirp(testCase)
            rec = dsp.makeRecording(5.8e9, 1, 128, 4e8, (1:128*5)', zeros(128*5, 1));
            X = dsp.reshapeChirps(rec);
            testCase.verifyEqual(size(X), [128 5]);
            testCase.verifyEqual(real(X(:, 2)), (129:256)');
            testCase.verifyEqual(rec.prf, 1000, 'AbsTol', 1e-9);
        end

        function targetRangeIsLocatedWithinOneBin(testCase)
            k0 = 20;
            rt = dsp.rangeTime(testCase.toneRecording(k0, 50), dsp.makeSettings());
            [~, k] = max(mean(abs(rt.data), 2));
            expected = k0 * testCase.C / (2 * 4e8);
            testCase.verifyEqual(k, k0 + 1);
            testCase.verifyLessThanOrEqual(abs(rt.rangeAxis(k) - expected), rt.binSpacing);
            testCase.verifyEqual(rt.rangeAxis(k), expected, 'RelTol', 1e-12);
        end

        function rectangularWindowPeakEqualsChirpLength(testCase)
            rt = dsp.rangeTime(testCase.toneRecording(20, 10), dsp.makeSettings());
            testCase.verifyEqual(max(abs(rt.data(:, 1))), 128, 'RelTol', 1e-9);
        end

        function binSpacingIsTheoreticalResolution(testCase)
            rec = testCase.toneRecording(20, 10);
            rt = dsp.rangeTime(rec, dsp.makeSettings());
            testCase.verifyEqual(rt.binSpacing, testCase.C / (2 * 4e8), 'RelTol', 1e-12);
            testCase.verifyEqual(rt.rangeAxis(2) - rt.rangeAxis(1), rt.binSpacing, 'RelTol', 1e-9);
            testCase.verifyEqual(size(rt.data, 1), 64);
            testCase.verifyEqual(rt.maxRange, 63 * rt.binSpacing, 'RelTol', 1e-12);
        end

        function hundredMegahertzFilesHaveCoarserRangeBins(testCase)
            % 60 West Cumbria files have a 100 MHz bandwidth in their header.
            nts = 128;
            x = repmat(exp(1j * 2 * pi * 3 * (0:nts-1)' / nts), 20, 1);
            rec = dsp.makeRecording(5.8e9, 1, nts, 1e8, real(x), imag(x));
            rt = dsp.rangeTime(rec, dsp.makeSettings());
            testCase.verifyEqual(rt.binSpacing, testCase.C / (2 * 1e8), 'RelTol', 1e-12);
            [~, k] = max(mean(abs(rt.data), 2));
            testCase.verifyEqual(rt.rangeAxis(k), 3 * testCase.C / (2 * 1e8), 'RelTol', 1e-12);
            % the same 3.7-11.3 m interval holds only 5 bins here (4.5, 6.0, 7.5, 9.0, 10.5 m)
            sel = dsp.selectRangeBins(rt, dsp.makeSettings());
            testCase.verifyEqual(sel.bins, (4:8)');
        end

        function zeroPaddingDividesTheBinSpacing(testCase)
            s = dsp.makeSettings(struct('range', struct('padFactor', 4)));
            rt = dsp.rangeTime(testCase.toneRecording(20, 10), s);
            testCase.verifyEqual(rt.binSpacing, testCase.C / (2 * 4e8) / 4, 'RelTol', 1e-12);
            testCase.verifyEqual(size(rt.data, 1), 256);
            [~, k] = max(abs(rt.data(:, 1)));
            testCase.verifyEqual(k, 81);
            testCase.verifyEqual(rt.rangeAxis(k), 20 * testCase.C / (2 * 4e8), 'RelTol', 1e-12);
        end

        function timeAxisFollowsTheChirpDuration(testCase)
            rt = dsp.rangeTime(testCase.toneRecording(20, 10), dsp.makeSettings());
            testCase.verifyEqual(rt.timeAxis, (0:9) * 1e-3, 'AbsTol', 1e-15);
        end

        function fixedSelectionUsesTheConfiguredInterval(testCase)
            rt = dsp.rangeTime(testCase.toneRecording(20, 10), dsp.makeSettings());
            sel = dsp.selectRangeBins(rt, dsp.makeSettings());
            % default [3.7 11.3] m is range bins 10..30 (0-based), rows 11..31
            testCase.verifyEqual(sel.bins, (11:31)');
            testCase.verifyEqual(sel.mode, "fixed");
            testCase.verifyEqual(sel.rangeMetres, rt.rangeAxis([11 31])');
        end

        function fixedSelectionWithNothingInRangeFails(testCase)
            rt = dsp.rangeTime(testCase.toneRecording(20, 10), dsp.makeSettings());
            s = dsp.makeSettings(struct('range', struct('intervalMetres', [40 50])));
            testCase.verifyError(@() dsp.selectRangeBins(rt, s), 'dsp:range:noBins');
        end

        function automaticSelectionFindsTheMovingTarget(testCase)
            nb = 100; nc = 2000;
            rng(3);
            noise = 1e-3 * (randn(nb, nc) + 1j * randn(nb, nc));
            t = (0:nc-1) / 1000;
            doppler = exp(1j * 2 * pi * 50 * t);        % 100 whole cycles: zero mean
            data = noise;
            data(5, :) = data(5, :) + 100;               % strong static reflector
            data(39:41, :) = data(39:41, :) + [0.5; 1; 0.5] * doppler;
            rt = struct('data', data, 'rangeAxis', (0:nb-1)' * 0.375, 'maxRange', 99 * 0.375);

            s = dsp.makeSettings(struct('range', struct('selection', 'auto')));
            sel = dsp.selectRangeBins(rt, s);
            testCase.verifyEqual(sel.mode, "auto");
            testCase.verifyEqual(sel.bins, (39:41)');
            testCase.verifyTrue(ismember(40, sel.bins));
            testCase.verifyFalse(ismember(80, sel.bins));
            testCase.verifyFalse(ismember(5, sel.bins));
        end

        function automaticSelectionRespectsTheMaximumWidth(testCase)
            nb = 60; nc = 1000;
            t = (0:nc-1) / 1000;
            data = zeros(nb, nc);
            data(20:40, :) = repmat(exp(1j * 2 * pi * 50 * t), 21, 1);
            rt = struct('data', data, 'rangeAxis', (0:nb-1)' * 0.375, 'maxRange', 59 * 0.375);
            s = dsp.makeSettings(struct('range', struct('selection', 'auto', 'autoMaxBins', 5)));
            sel = dsp.selectRangeBins(rt, s);
            testCase.verifyEqual(numel(sel.bins), 5);
        end

        function plotHasLabelledAxes(testCase)
            rt = dsp.rangeTime(testCase.toneRecording(20, 30), dsp.makeSettings());
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            ax = axes(f);
            dsp.plotRangeTime(rt, Axes=ax, RemoveStatic=true, Title="test map");
            testCase.verifyEqual(string(ax.XLabel.String), "Time (s)");
            testCase.verifyEqual(string(ax.YLabel.String), "Range (m)");
            testCase.verifyEqual(string(ax.Title.String), "test map");
        end

        function invalidRangeSettingsAreRejected(testCase)
            testCase.verifyError(@() dsp.makeSettings(struct('range', struct('window', 'blackman'))), ...
                'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('range', struct('padFactor', 0))), ...
                'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('range', struct('intervalMetres', [5 2]))), ...
                'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('range', struct('selection', 'best'))), ...
                'dsp:settings:invalidValue');
        end
    end
end
