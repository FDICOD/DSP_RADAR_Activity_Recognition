classdef TestPipeline < matlab.unittest.TestCase
    methods (Access = private)
        function rec = syntheticScene(~)
            % A strong static reflector at range bin 22 (8.2 m) and a person-like mover
            % at bin 16 (6.0 m) with a 100 Hz Doppler, 3 s at a 1 kHz pulse rate.
            nts = 128; nc = 3000; prf = 1000;
            n = (0:nts-1)';
            m = 0:nc-1;
            static = 5 * exp(1j * 2 * pi * 22 * n / nts) .* ones(1, nc);
            mover = exp(1j * 2 * pi * 16 * n / nts) .* exp(1j * 2 * pi * 100 * m / prf);
            x = static + mover;
            rec = dsp.makeRecording(5.8e9, 1, nts, 4e8, real(x(:)), imag(x(:)));
        end
    end

    methods (Test)
        function allStagesArePresent(testCase)
            r = dsp.runPipeline(testCase.syntheticScene(), dsp.makeSettings());
            for f = ["rt" "pre" "sel" "dopBefore" "dopAfter" "spBefore" "spAfter" "settings"]
                testCase.verifyTrue(isfield(r, f), "missing " + f);
            end
            testCase.verifyEqual(r.sel.bins, (11:31)');
            testCase.verifyEqual(r.spAfter.bins, r.sel.bins);
            testCase.verifyEqual(size(r.spBefore.mag), size(r.spAfter.mag));
            testCase.verifyEqual(r.pre.steps.clutter, "highpass");
        end

        function clutterRemovalReducesTheZeroDopplerLine(testCase)
            r = dsp.runPipeline(testCase.syntheticScene(), dsp.makeSettings());
            [~, i0] = min(abs(r.dopBefore.freq));
            testCase.verifyEqual(r.dopBefore.freq(i0), 0);
            testCase.verifyLessThan(r.dopAfter.mag(i0) / r.dopBefore.mag(i0), 0.01);
        end

        function clutterRemovalKeepsTheMovingTarget(testCase)
            r = dsp.runPipeline(testCase.syntheticScene(), dsp.makeSettings());
            away = abs(r.dopBefore.freq) > 50;
            [peakBefore, i] = max(r.dopBefore.mag .* away);
            testCase.verifyLessThanOrEqual(abs(abs(r.dopBefore.freq(i)) - 100), r.dopBefore.binWidth);
            peakAfter = max(r.dopAfter.mag .* away);
            testCase.verifyEqual(peakAfter / peakBefore, 1, 'AbsTol', 0.15);
        end

        function spectrogramZeroDopplerRowIsReducedToo(testCase)
            r = dsp.runPipeline(testCase.syntheticScene(), dsp.makeSettings());
            [~, i0] = min(abs(r.spBefore.freq));
            before = mean(r.spBefore.mag(i0, :));
            after = mean(r.spAfter.mag(i0, :));
            testCase.verifyLessThan(after / before, 0.05);
        end

        function pipelineIsDeterministic(testCase)
            rec = testCase.syntheticScene();
            a = dsp.runPipeline(rec, dsp.makeSettings());
            b = dsp.runPipeline(rec, dsp.makeSettings());
            testCase.verifyEqual(a.spAfter.mag, b.spAfter.mag);
            testCase.verifyEqual(a.sel.bins, b.sel.bins);
        end

        function dopplerSpectrumPlotHasLabelledAxes(testCase)
            r = dsp.runPipeline(testCase.syntheticScene(), dsp.makeSettings());
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            ax = axes(f);
            ref = max(r.dopBefore.mag);
            dsp.plotDopplerSpectrum(r.dopBefore, Axes=ax, DisplayName="before", ReferenceMag=ref);
            hold(ax, 'on');
            dsp.plotDopplerSpectrum(r.dopAfter, Axes=ax, DisplayName="after", ReferenceMag=ref, Title="spectra");
            hold(ax, 'off');
            testCase.verifyEqual(string(ax.XLabel.String), "Velocity (m/s)");
            testCase.verifyEqual(string(ax.YLabel.String), "Magnitude (dB)");
            testCase.verifyEqual(string(ax.Title.String), "spectra");
            testCase.verifyEqual(numel(ax.Children), 2);
            % the strongest point of the reference spectrum is 0 dB
            testCase.verifyEqual(max(ax.Children(2).YData), 0, 'AbsTol', 1e-9);
        end

        function rangeTimePlotsCanShareAColourScale(testCase)
            r = dsp.runPipeline(testCase.syntheticScene(), dsp.makeSettings());
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            ax1 = subplot(1, 2, 1);
            ax2 = subplot(1, 2, 2);
            top = 20 * log10(max(abs(r.rt.data(:))));
            dsp.plotRangeTime(r.rt, Axes=ax1, ReferenceDb=top, DynamicRangeDb=70);
            dsp.plotRangeTime(r.pre, Axes=ax2, ReferenceDb=top, DynamicRangeDb=70);
            testCase.verifyEqual(ax1.CLim, ax2.CLim);
            testCase.verifyEqual(ax1.CLim, [top - 70, top], 'AbsTol', 1e-9);
        end

        function spectrogramPlotsCanShareAColourScale(testCase)
            r = dsp.runPipeline(testCase.syntheticScene(), dsp.makeSettings());
            f = figure('Visible', 'off');
            testCase.addTeardown(@() close(f));
            ax1 = subplot(1, 2, 1);
            ax2 = subplot(1, 2, 2);
            top = max(r.spBefore.dB(:));
            dsp.plotSpectrogram(r.spBefore, Axes=ax1, ReferenceDb=top, DynamicRangeDb=60);
            dsp.plotSpectrogram(r.spAfter, Axes=ax2, ReferenceDb=top, DynamicRangeDb=60);
            testCase.verifyEqual(ax1.CLim, ax2.CLim);
        end
    end
end
