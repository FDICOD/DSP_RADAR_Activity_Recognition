function r = demo_pipeline(opts)
% DEMO_PIPELINE Show every signal-processing stage on one real recording.
%   demo_pipeline
%   demo_pipeline(Session="4 July 2018 Dataset", Name="4P60A04R1")
%   demo_pipeline(Save=true)          % also writes PNGs to results/figures
%   demo_pipeline(Save=true, Show=false)   % only writes the PNGs; no windows are opened
%
%   Figures, in pipeline order:
%     1  raw I/Q beat signal
%     2  range-time map before and after clutter removal (same colour scale)
%     3  Doppler spectrum before and after clutter removal (same axes)
%     4  micro-Doppler spectrogram before and after clutter removal (same scale)
%     5  summary: settings used, true label, and the prediction stage
%        (reported as unavailable until a classifier has been trained)
%     6  (only with SnrDb) clean and noisy spectrograms side by side on one scale
%   demo_pipeline(SnrDb=5) adds white noise at 5 dB input SNR (seeded, so it is
%   repeatable) before any processing and shows how much the spectrogram changes.
%   Returns the result struct of dsp.runPipeline.
arguments
    opts.Session (1,1) string = "5 February 2019 UoG Dataset"
    opts.Name (1,1) string = "1P01A01R01"
    opts.DynamicRangeDb (1,1) double = 70
    opts.VelocityLimit (1,1) double = 6
    opts.Save (1,1) logical = false
    opts.Show (1,1) logical = true
    opts.SnrDb (1,1) double = Inf
    opts.Seed (1,1) double = 1
end

s = dsp.makeSettings();
T = dsp.listRecordings(s);
row = T(T.session == opts.Session & T.name == opts.Name & T.included, :);
if isempty(row)
    error('demo_pipeline:notFound', 'No included recording "%s" in session "%s" under %s.', ...
        opts.Name, opts.Session, s.data.root);
end
rec = dsp.readConverted(row.file(1));
r = dsp.runPipeline(rec, s);
label = row.activity(1);
who = sprintf('%s, true activity: %s', row.name(1), label);

outDir = fullfile(dsp.projectRoot(), 'results', 'figures');
if opts.Save && ~isfolder(outDir)
    mkdir(outDir);
end
if ~opts.Show && ~opts.Save
    error('demo_pipeline:nothingToDo', 'With Show=false, set Save=true, otherwise the figures would be lost.');
end
saveFig = @(f, k) maybeSave(f, opts.Save, opts.Show, string(fullfile(outDir, sprintf('demo_%s_%d.png', row.name(1), k))));

% 1. raw I/Q
f1 = dsp.newFigure('1 Raw I/Q', [100 100 1100 450], opts.Show);
nShow = 5 * rec.samplesPerChirp;
tms = (0:nShow-1)' / r.rt.fs * 1000;
plot(tms, real(rec.iq(1:nShow)), tms, imag(rec.iq(1:nShow)));
xlabel('Time (ms)');
ylabel('ADC counts');
legend('I', 'Q');
grid on;
title(sprintf('1. Raw I/Q beat signal, first 5 chirps (%s)', who));
saveFig(f1, 1);

% 2. range-time before and after clutter removal, one colour scale
f2 = dsp.newFigure('2 Range-time', [100 100 1400 520], opts.Show);
tl2 = tiledlayout(f2, 1, 2, 'TileSpacing', 'compact');
topRaw = 20 * log10(max(abs(r.rt.data(:))));
ax = nexttile;
dsp.plotRangeTime(r.rt, Axes=ax, ReferenceDb=topRaw, DynamicRangeDb=opts.DynamicRangeDb, ...
    Title="Before clutter removal");
markBins(ax, r.sel.rangeMetres);
ax = nexttile;
dsp.plotRangeTime(r.pre, Axes=ax, ReferenceDb=topRaw, DynamicRangeDb=opts.DynamicRangeDb, ...
    Title="After clutter removal (" + r.pre.steps.clutter + ")");
markBins(ax, r.sel.rangeMetres);
title(tl2, sprintf('2. Range-time map, same colour scale; dashed lines = range bins used (%s)', who));
saveFig(f2, 2);

% 3. Doppler spectrum before and after
f3 = dsp.newFigure('3 Doppler spectrum', [100 100 1100 500], opts.Show);
ax = axes(f3);
ref = max(r.dopBefore.mag);
dsp.plotDopplerSpectrum(r.dopBefore, Axes=ax, DisplayName="before clutter removal", ReferenceMag=ref);
hold(ax, 'on');
dsp.plotDopplerSpectrum(r.dopAfter, Axes=ax, DisplayName="after clutter removal", ReferenceMag=ref);
hold(ax, 'off');
legend(ax, 'Location', 'northeast');
ylim(ax, [-100 5]);
title(ax, sprintf('3. Doppler spectrum of the selected range bins (%s)', who));
saveFig(f3, 3);

% 4. spectrogram before and after, one colour scale
f4 = dsp.newFigure('4 Spectrogram', [100 100 1400 520], opts.Show);
tl4 = tiledlayout(f4, 1, 2, 'TileSpacing', 'compact');
topSp = max(r.spBefore.dB(:));
ax = nexttile;
dsp.plotSpectrogram(r.spBefore, Axes=ax, ReferenceDb=topSp, DynamicRangeDb=opts.DynamicRangeDb, ...
    Title="Before clutter removal");
limitVelocity(ax, r.spBefore, opts.VelocityLimit);
ax = nexttile;
dsp.plotSpectrogram(r.spAfter, Axes=ax, ReferenceDb=topSp, DynamicRangeDb=opts.DynamicRangeDb, ...
    Title="After clutter removal");
limitVelocity(ax, r.spAfter, opts.VelocityLimit);
title(tl4, sprintf('4. Micro-Doppler spectrogram, same colour scale (%s)', who));
saveFig(f4, 4);

% 5. summary and prediction stage
f5 = dsp.newFigure('5 Summary', [100 100 1100 450], opts.Show);
ax = axes(f5, 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1]);
sp = r.spAfter;
lines = [ ...
    "Recording: " + row.name(1) + "   (" + row.session(1) + ")"; ...
    "True activity: " + label; ...
    sprintf("Range bins used: %d to %d (%.1f to %.1f m), selection: %s", r.sel.bins(1), r.sel.bins(end), ...
        r.sel.rangeMetres(1), r.sel.rangeMetres(2), r.sel.mode); ...
    "Clutter removal: " + r.pre.steps.clutter + ";  denoise: " + r.pre.steps.denoise + ";  normalise: " + r.pre.steps.normalize; ...
    sprintf("STFT: %.2f s window (%d samples), overlap %d samples, FFT %d points, %s window", ...
        s.stft.windowSeconds, sp.windowLength, sp.overlap, sp.nfft, sp.window); ...
    sprintf("Resolution: %.1f Hz in Doppler (%.2f m/s), %.3f s time step", sp.freqResolution, ...
        sp.freqResolution * rec.wavelength / 2, sp.timeStep); ...
    ""; ...
    "Features and activity prediction: not available yet (classifier not trained)."];
text(ax, 0.02, 0.95, lines, 'VerticalAlignment', 'top', 'FontSize', 14, 'Interpreter', 'none');
title(ax, '5. Summary', 'Visible', 'on');
saveFig(f5, 5);

% 6. clean versus noisy
if isfinite(opts.SnrDb)
    noisyRec = dsp.addNoise(rec, opts.SnrDb, opts.Seed);
    spNoisy = dsp.spectrogramOf(noisyRec, s);
    deg = dsp.spectrogramDegradation(r.spAfter, spNoisy, s.stft.dynamicRangeDb);
    f6 = dsp.newFigure('6 Clean vs noisy', [100 100 1400 520], opts.Show);
    tl6 = tiledlayout(f6, 1, 2, 'TileSpacing', 'compact');
    top = max(r.spAfter.dB(:));
    ax = nexttile;
    dsp.plotSpectrogram(r.spAfter, Axes=ax, ReferenceDb=top, DynamicRangeDb=opts.DynamicRangeDb, Title="Clean");
    limitVelocity(ax, r.spAfter, opts.VelocityLimit);
    ax = nexttile;
    dsp.plotSpectrogram(spNoisy, Axes=ax, ReferenceDb=top, DynamicRangeDb=opts.DynamicRangeDb, ...
        Title=sprintf('Input SNR %g dB (correlation with clean %.2f)', opts.SnrDb, deg.correlation));
    limitVelocity(ax, spNoisy, opts.VelocityLimit);
    title(tl6, sprintf('6. Clean vs noisy spectrogram, same colour scale (%s)', who));
    saveFig(f6, 6);
    fprintf('Input SNR %g dB: spectrogram correlation %.3f, nrmse %.3f\n', opts.SnrDb, deg.correlation, deg.nrmse);
end
end

function markBins(ax, rangeMetres)
hold(ax, 'on');
xl = xlim(ax);
for y = rangeMetres
    plot(ax, xl, [y y], 'w--', 'LineWidth', 1.5);
end
hold(ax, 'off');
end

function limitVelocity(ax, sp, limit)
if sp.velocityAvailable
    ylim(ax, [-limit limit]);
end
end

function maybeSave(fig, doSave, show, file)
if doSave
    dsp.saveFigure(fig, file);
end
if ~show && isgraphics(fig)
    close(fig);
end
end
