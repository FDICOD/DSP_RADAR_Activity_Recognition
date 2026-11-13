function show_range_time(opts)
% SHOW_RANGE_TIME Range-time map of one real recording per activity.
%   show_range_time                                  % February 2019 laboratory session
%   show_range_time(Session="4 July 2018 Dataset")
%   show_range_time(Show=false)                      % only save the PNG, open no window
%   Static returns are removed by mean subtraction so the moving person is visible.
%   Saves results/figures/range_time_by_activity.png.

arguments
    opts.Session (1,1) string = "5 February 2019 UoG Dataset"
    opts.Show (1,1) logical = true
end
sessionName = opts.Session;

s = dsp.makeSettings();
T = dsp.listRecordings(s);
T = T(T.included & T.session == sessionName, :);
if isempty(T)
    error('show_range_time:noData', 'No included recordings found for session "%s" under %s.', ...
        sessionName, s.data.root);
end

f = dsp.newFigure("figure", [100 100 1500 800], opts.Show);
tl = tiledlayout(2, 3, 'TileSpacing', 'compact');
for code = 1:numel(s.activity.codeNames)
    rows = T(T.activityCode == code, :);
    nexttile;
    if isempty(rows)
        title(sprintf('%s: no recording', s.activity.codeNames(code)));
        continue
    end
    rec = dsp.readConverted(rows.file(1));
    rt = dsp.rangeTime(rec, s);
    dsp.plotRangeTime(rt, RemoveStatic=true, ...
        Title=sprintf('%s (%s)', rows.activity(1), rows.name(1)));
end
title(tl, "Range-time maps, static returns removed (" + sessionName + ")");

outDir = fullfile(dsp.projectRoot(), 'results', 'figures');
if ~isfolder(outDir)
    mkdir(outDir);
end
outFile = fullfile(outDir, 'range_time_by_activity.png');
dsp.saveFigure(f, string(outFile));
if ~opts.Show
    close(f);
end
end
