function show_class_gallery(opts)
% SHOW_CLASS_GALLERY One micro-Doppler spectrogram per activity on common axes.
%   show_class_gallery
%   show_class_gallery(Session="4 July 2018 Dataset", Subject="P60")
%   Uses the same person and repetition for every activity, the same colour scale
%   (the strongest value over all six) and the same time and velocity limits, so
%   the six signatures can be compared directly. Saves
%   results/figures/class_gallery.png.
arguments
    opts.Show (1,1) logical = true
    opts.Session (1,1) string = "5 February 2019 UoG Dataset"
    opts.Subject (1,1) string = "P01"
    opts.Repetition (1,1) double = 1
    opts.DynamicRangeDb (1,1) double = 50
    opts.MaxSeconds (1,1) double = 5
    opts.VelocityLimit (1,1) double = 6
end

s = dsp.makeSettings();
T = dsp.listRecordings(s);
T = T(T.included & T.session == opts.Session & T.subject == opts.Subject, :);
if isempty(T)
    error('show_class_gallery:noData', 'No recordings for %s in session "%s".', opts.Subject, opts.Session);
end

n = numel(s.activity.codeNames);
spec = cell(1, n);
names = strings(1, n);
for c = 1:n
    rows = T(T.activityCode == c, :);
    if isempty(rows)
        continue
    end
    pick = rows(rows.repetition == opts.Repetition, :);
    if isempty(pick)
        pick = rows(1, :);
    end
    r = dsp.runPipeline(dsp.readConverted(pick.file(1)), s);
    spec{c} = r.spAfter;
    names(c) = pick.name(1);
end

have = ~cellfun(@isempty, spec);
ref = max(cellfun(@(x) max(x.dB(:)), spec(have)));

f = dsp.newFigure("figure", [100 100 1500 800], opts.Show);
tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact');
for c = 1:n
    ax = nexttile;
    if ~have(c)
        title(ax, sprintf('%s: no recording', s.activity.codeNames(c)));
        continue
    end
    dsp.plotSpectrogram(spec{c}, Axes=ax, ReferenceDb=ref, DynamicRangeDb=opts.DynamicRangeDb, ...
        Title=sprintf('%s (%s)', s.activity.codeNames(c), names(c)));
    xlim(ax, [0 opts.MaxSeconds]);
    if spec{c}.velocityAvailable
        ylim(ax, [-opts.VelocityLimit opts.VelocityLimit]);
    end
end
title(tl, sprintf('Micro-Doppler signatures, %s, %s (one colour scale)', opts.Subject, opts.Session));

outDir = fullfile(dsp.projectRoot(), 'results', 'figures');
if ~isfolder(outDir)
    mkdir(outDir);
end
outFile = fullfile(outDir, 'class_gallery.png');
dsp.saveFigure(f, string(outFile));
if ~opts.Show
    close(f);
end
end
