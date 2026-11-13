function show_preprocessing(opts)
% SHOW_PREPROCESSING Before/after clutter removal for one recording per activity.
%   show_preprocessing
%   show_preprocessing(Session="4 July 2018 Dataset", Subject="P60")
%   Row 1: range-time map before. Row 2: after, on the same colour scale as row 1.
%   Row 3: Doppler spectrum of the selected bins, before and after, on one axes.
%   Saves results/figures/preprocessing_by_activity.png.
arguments
    opts.Show (1,1) logical = true
    opts.Session (1,1) string = "5 February 2019 UoG Dataset"
    opts.Subject (1,1) string = "P01"
    opts.Repetition (1,1) double = 1
    opts.DynamicRangeDb (1,1) double = 70
end

s = dsp.makeSettings();
T = dsp.listRecordings(s);
T = T(T.included & T.session == opts.Session & T.subject == opts.Subject, :);
if isempty(T)
    error('show_preprocessing:noData', 'No recordings for %s in session "%s".', opts.Subject, opts.Session);
end

n = numel(s.activity.codeNames);
res = cell(1, n);
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
    res{c} = dsp.runPipeline(dsp.readConverted(pick.file(1)), s);
    names(c) = pick.name(1);
end

f = dsp.newFigure("figure", [20 20 2000 1100], opts.Show);
tl = tiledlayout(f, 3, 6, 'TileSpacing', 'compact');
for c = 1:n
    r = res{c};
    ax1 = nexttile(tl, c);
    ax2 = nexttile(tl, 6 + c);
    ax3 = nexttile(tl, 12 + c);
    if isempty(r)
        title(ax1, sprintf('%s: no recording', s.activity.codeNames(c)));
        continue
    end
    top = 20 * log10(max(abs(r.rt.data(:))));
    dsp.plotRangeTime(r.rt, Axes=ax1, ReferenceDb=top, DynamicRangeDb=opts.DynamicRangeDb, ...
        Title=sprintf('%s: before', s.activity.codeNames(c)));
    dsp.plotRangeTime(r.pre, Axes=ax2, ReferenceDb=top, DynamicRangeDb=opts.DynamicRangeDb, ...
        Title="after (" + r.pre.steps.clutter + ")");
    ref = max(r.dopBefore.mag);
    dsp.plotDopplerSpectrum(r.dopBefore, Axes=ax3, DisplayName="before", ReferenceMag=ref);
    hold(ax3, 'on');
    dsp.plotDopplerSpectrum(r.dopAfter, Axes=ax3, DisplayName="after", ReferenceMag=ref);
    hold(ax3, 'off');
    ylim(ax3, [-100 5]);
    if c == 1
        legend(ax3, 'Location', 'south');
    end
end
title(tl, sprintf('Clutter removal, %s, %s (rows 1-2 share a colour scale per column)', opts.Subject, opts.Session));

outDir = fullfile(dsp.projectRoot(), 'results', 'figures');
if ~isfolder(outDir)
    mkdir(outDir);
end
outFile = fullfile(outDir, 'preprocessing_by_activity.png');
dsp.saveFigure(f, string(outFile), 120);
if ~opts.Show
    close(f);
end
end
