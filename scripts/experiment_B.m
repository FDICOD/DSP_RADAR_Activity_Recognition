function results = experiment_B(opts)
% EXPERIMENT_B Preprocessing comparison at signal level: clutter removal and range-bin selection.
%   experiment_B
%   experiment_B(PerClass=8, Seed=1)
%
%   Four configurations are compared on a seeded, class-balanced sample of
%   VALIDATION recordings (the test split is never touched):
%     none + fixed, highpass + fixed, none + auto, highpass + auto
%   (clutter removal off/on x range bins from a fixed interval / chosen
%   automatically). For every recording the spectrogram of each configuration is
%   compared, at several input SNR levels, in two ways:
%     fidelity      correlation with the clean spectrogram of the REFERENCE
%                   configuration (highpass + fixed); mixes "this method differs"
%                   with "noise hurt it", so it favours the reference at high SNR
%     selfFidelity  correlation with the same configuration's OWN clean
%                   spectrogram: how much noise alone degrades that method
%   (1 = identical), plus the normalised error. The motion fraction (share of spectrogram
%   energy beyond +/-0.15 m/s) and the number of range bins used are also reported.
%   Noise is added to the raw samples with the same seed in every configuration,
%   so the configurations see identical noise.
%   Writes results/experiments/B_*.csv and B_fidelity.png.
arguments
    opts.PerClass (1,1) double = 4
    opts.Seed (1,1) double = 1
    opts.SnrList (1,:) double = [20 10 5 0]
    opts.Split (1,1) string = "val"
    opts.VelocityCut (1,1) double = 0.15
end

base = dsp.makeSettings();
base.seed = opts.Seed;
T = dsp.splitByPerson(dsp.listRecordings(base), base);
pick = dsp.pickRecordings(T, opts.Split, opts.PerClass, opts.Seed);

names = ["none + fixed"; "highpass + fixed"; "none + auto"; "highpass + auto"];
clutter = ["none" "highpass" "none" "highpass"];
selection = ["fixed" "fixed" "auto" "auto"];
refIdx = 2;
nc = numel(names);
settingsOf = cell(1, nc);
for c = 1:nc
    sc = base;
    sc.clutter.method = char(clutter(c));
    sc.range.selection = char(selection(c));
    settingsOf{c} = sc;
end

levels = [Inf opts.SnrList];          % Inf = clean
nr = height(pick);
nl = numel(levels);
fidelity = nan(nr, nc, nl);
selfFid = nan(nr, nc, nl);
nrmse = nan(nr, nc, nl);
motion = nan(nr, nc);
nbins = nan(nr, nc);

for i = 1:nr
    rec = dsp.readConverted(pick.file(i));
    refClean = dsp.spectrogramOf(rec, settingsOf{refIdx});
    ownClean = cell(1, nc);
    for l = 1:nl
        if isinf(levels(l))
            recL = rec;
        else
            recL = dsp.addNoise(rec, levels(l), opts.Seed + i);
        end
        for c = 1:nc
            [sp, sel] = dsp.spectrogramOf(recL, settingsOf{c});
            d = dsp.spectrogramDegradation(refClean, sp, base.stft.dynamicRangeDb);
            fidelity(i, c, l) = d.correlation;
            nrmse(i, c, l) = d.nrmse;
            if l == 1
                ownClean{c} = sp;
            end
            dSelf = dsp.spectrogramDegradation(ownClean{c}, sp, base.stft.dynamicRangeDb);
            selfFid(i, c, l) = dSelf.correlation;
            if l == 1
                motion(i, c) = dsp.motionFraction(sp, opts.VelocityCut);
                nbins(i, c) = numel(sel.bins);
            end
        end
    end
    fprintf('B: %d of %d  %s (%s)\n', i, nr, pick.name(i), pick.activity(i));
end

% per-recording table
[I, C, L] = ndgrid(1:nr, 1:nc, 1:nl);
raw = table(pick.name(I(:)), pick.activity(I(:)), names(C(:)), reshape(levels(L(:)), [], 1), ...
    fidelity(:), selfFid(:), nrmse(:), ...
    'VariableNames', {'recording', 'activity', 'config', 'snrDb', 'fidelity', 'selfFidelity', 'nrmse'});

% summary per configuration and SNR level
rowsOut = nc * nl;
config = strings(rowsOut, 1); snr = zeros(rowsOut, 1);
meanFid = zeros(rowsOut, 1); sdFid = zeros(rowsOut, 1); meanErr = zeros(rowsOut, 1);
meanSelf = zeros(rowsOut, 1); sdSelf = zeros(rowsOut, 1);
k = 0;
for c = 1:nc
    for l = 1:nl
        k = k + 1;
        f = fidelity(:, c, l);
        config(k) = names(c);
        snr(k) = levels(l);
        meanFid(k) = mean(f);
        sdFid(k) = std(f);
        meanErr(k) = mean(nrmse(:, c, l));
        meanSelf(k) = mean(selfFid(:, c, l));
        sdSelf(k) = std(selfFid(:, c, l));
    end
end
byLevel = table(config, snr, meanFid, sdFid, meanSelf, sdSelf, meanErr, ...
    'VariableNames', {'config', 'snrDb', 'meanFidelity', 'sdFidelity', 'meanSelfFidelity', 'sdSelfFidelity', 'meanNrmse'});
byConfig = table(names, mean(motion, 1)', mean(nbins, 1)', ...
    'VariableNames', {'config', 'motionFraction', 'meanRangeBins'});

outDir = fullfile(dsp.projectRoot(), 'results', 'experiments');
if ~isfolder(outDir)
    mkdir(outDir);
end
writetable(raw, fullfile(outDir, 'B_raw.csv'));
writetable(byLevel, fullfile(outDir, 'B_by_snr.csv'));
writetable(byConfig, fullfile(outDir, 'B_by_config.csv'));
dsp.writeRunMetadata(string(fullfile(outDir, 'B_run')), base, ...
    struct('experiment', "B", 'recordings', nr, 'perClass', opts.PerClass, 'split', opts.Split, ...
    'snrList', opts.SnrList, 'reference', names(refIdx)));

f = dsp.newFigure("figure", [100 100 1800 480], false);
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact');
ax = nexttile(tl);
hold(ax, 'on');
[snrAscending, byAscending] = sort(opts.SnrList);   % noisiest on the left, clean on the right
order = [byAscending + 1, 1];                        % level 1 of the arrays is the clean case
xs = [snrAscending, max(snrAscending) + 10];
for c = 1:nc
    m = arrayfun(@(l) mean(fidelity(:, c, l)), order);
    plot(ax, xs, m, '-o', 'LineWidth', 1.5, 'DisplayName', names(c));
end
hold(ax, 'off');
xticks(ax, xs);
xticklabels(ax, [string(snrAscending), "clean"]);
xlabel(ax, 'Input SNR (dB)');
ylabel(ax, 'Correlation with the reference clean spectrogram');
title(ax, 'Fidelity to the reference clean spectrogram');
legend(ax, 'Location', 'southeast');
grid(ax, 'on');
ax = nexttile(tl);
hold(ax, 'on');
for c = 1:nc
    m = arrayfun(@(l) mean(selfFid(:, c, l)), order);
    plot(ax, xs, m, '-o', 'LineWidth', 1.5, 'DisplayName', names(c));
end
hold(ax, 'off');
xticks(ax, xs);
xticklabels(ax, [string(snrAscending), "clean"]);
xlabel(ax, 'Input SNR (dB)');
ylabel(ax, 'Correlation with the same method''s clean spectrogram');
title(ax, 'Robustness to noise of each method');
grid(ax, 'on');
ax = nexttile(tl);
bar(ax, categorical(names, names), mean(motion, 1));
ylabel(ax, sprintf('Energy beyond +/-%.2f m/s (fraction)', opts.VelocityCut));
title(ax, 'Share of the spectrogram that is motion (clean)');
grid(ax, 'on');
title(tl, sprintf('Experiment B: %d %s recordings, seed %d', nr, opts.Split, opts.Seed));
dsp.saveFigure(f, string(fullfile(outDir, 'B_fidelity.png')));
close(f);

disp(byConfig);
disp(byLevel);
results = struct('raw', raw, 'bySnr', byLevel, 'byConfig', byConfig);
end
