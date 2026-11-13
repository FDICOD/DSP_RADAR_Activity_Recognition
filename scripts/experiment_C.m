function results = experiment_C(opts)
% EXPERIMENT_C STFT window length and overlap: resolution, robustness to noise and run time.
%   experiment_C
%   experiment_C(PerClass=8, Windows=[0.1 0.2 0.4 0.8], Overlaps=[0.5 0.75 0.95])
%
%   Every window/overlap pair is applied to the same seeded, class-balanced
%   sample of VALIDATION recordings, with the default preprocessing. Reported per
%   configuration: Doppler and velocity resolution (prf / window), time step,
%   number of frames, STFT run time, and robustness to noise = correlation of the
%   noisy spectrogram with the same configuration's clean spectrogram (at the given
%   input SNR values). The window sets a trade-off: longer windows resolve speed
%   finely but blur changes in time.
%   Writes results/experiments/C_*.csv and C_tradeoff.png.
arguments
    opts.PerClass (1,1) double = 4
    opts.Seed (1,1) double = 1
    opts.Windows (1,:) double = [0.1 0.2 0.4 0.8]
    opts.Overlaps (1,:) double = [0.5 0.75 0.95]
    opts.SnrList (1,:) double = [10 0]
    opts.Split (1,1) string = "val"
end

base = dsp.makeSettings();
base.seed = opts.Seed;
T = dsp.splitByPerson(dsp.listRecordings(base), base);
pick = dsp.pickRecordings(T, opts.Split, opts.PerClass, opts.Seed);

[W, O] = ndgrid(opts.Windows, opts.Overlaps);
W = W(:); O = O(:);
nc = numel(W);
levels = [Inf opts.SnrList];
nl = numel(levels);
nr = height(pick);

robust = nan(nr, nc, nl);       % level 1 (clean) is 1 by definition
runtime = nan(nr, nc);
freqRes = nan(1, nc); velRes = nan(1, nc); step = nan(1, nc); frames = nan(nr, nc);

for i = 1:nr
    rec = dsp.readConverted(pick.file(i));
    clean = cell(1, nc);
    for l = 1:nl
        if isinf(levels(l))
            recL = rec;
        else
            recL = dsp.addNoise(rec, levels(l), opts.Seed + i);
        end
        [pre, sel] = dsp.preprocessRecording(recL, base);
        for c = 1:nc
            sc = base;
            sc.stft.windowSeconds = W(c);
            sc.stft.overlapFraction = O(c);
            t0 = tic;
            sp = dsp.microDoppler(pre, sel, sc);
            if l == 1
                runtime(i, c) = toc(t0);
                clean{c} = sp;
                freqRes(c) = sp.freqResolution;
                velRes(c) = sp.freqResolution * pre.wavelength / 2;
                step(c) = sp.timeStep;
                frames(i, c) = size(sp.mag, 2);
            end
            d = dsp.spectrogramDegradation(clean{c}, sp, base.stft.dynamicRangeDb);
            robust(i, c, l) = d.correlation;
        end
    end
    fprintf('C: %d of %d  %s (%s)\n', i, nr, pick.name(i), pick.activity(i));
end

summary = table(W, O, freqRes', velRes', step', mean(frames, 1)', mean(runtime, 1)', ...
    'VariableNames', {'windowSeconds', 'overlapFraction', 'dopplerResolutionHz', ...
    'velocityResolution', 'timeStepSeconds', 'meanFrames', 'meanRuntimeSeconds'});
for l = 2:nl
    summary.("corr_" + string(levels(l)) + "dB") = squeeze(mean(robust(:, :, l), 1))';
end

outDir = fullfile(dsp.projectRoot(), 'results', 'experiments');
if ~isfolder(outDir)
    mkdir(outDir);
end
writetable(summary, fullfile(outDir, 'C_summary.csv'));
dsp.writeRunMetadata(string(fullfile(outDir, 'C_run')), base, ...
    struct('experiment', "C", 'recordings', nr, 'perClass', opts.PerClass, 'split', opts.Split, ...
    'windows', opts.Windows, 'overlaps', opts.Overlaps, 'snrList', opts.SnrList));

f = dsp.newFigure("figure", [100 100 1500 460], false);
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact');
lastLevel = nl;
ax = nexttile(tl);
hold(ax, 'on');
for o = opts.Overlaps
    sel = O == o;
    plot(ax, W(sel), summary.("corr_" + string(levels(lastLevel)) + "dB")(sel), '-o', 'LineWidth', 1.5, ...
        'DisplayName', sprintf('overlap %g%%', 100 * o));
end
hold(ax, 'off');
xlabel(ax, 'Window length (s)');
ylabel(ax, sprintf('Correlation with clean at %g dB', levels(lastLevel)));
title(ax, 'Robustness to noise');
legend(ax, 'Location', 'best');
grid(ax, 'on');
ax = nexttile(tl);
first = O == opts.Overlaps(1);
plot(ax, W(first), summary.velocityResolution(first), '-o', 'LineWidth', 1.5);
xlabel(ax, 'Window length (s)');
ylabel(ax, 'Velocity resolution (m/s)');
title(ax, 'Resolution (finer is lower)');
grid(ax, 'on');
ax = nexttile(tl);
hold(ax, 'on');
for o = opts.Overlaps
    sel = O == o;
    plot(ax, W(sel), summary.meanRuntimeSeconds(sel), '-o', 'LineWidth', 1.5, 'DisplayName', sprintf('overlap %g%%', 100 * o));
end
hold(ax, 'off');
xlabel(ax, 'Window length (s)');
ylabel(ax, 'STFT time per recording (s)');
title(ax, 'Cost');
legend(ax, 'Location', 'best');
grid(ax, 'on');
title(tl, sprintf('Experiment C: %d %s recordings, seed %d', nr, opts.Split, opts.Seed));
dsp.saveFigure(f, string(fullfile(outDir, 'C_tradeoff.png')));
close(f);

disp(summary);
results = summary;
end
