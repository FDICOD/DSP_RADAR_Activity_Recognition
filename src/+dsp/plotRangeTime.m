function ax = plotRangeTime(rt, opts)
%PLOTRANGETIME Show a range-time map (magnitude in dB) with labelled axes.
%   dsp.plotRangeTime(rt)
%   dsp.plotRangeTime(rt, Axes=ax, RemoveStatic=true, DynamicRangeDb=50, Title="walking")
%   dsp.plotRangeTime(rt, ReferenceDb=top)   % same colour scale as another map
%
%   RemoveStatic subtracts each range bin's mean over time first, which hides
%   stationary reflectors so the moving person is visible. (The pipeline's own
%   clutter removal is a separate, later step.)
arguments
    rt (1,1) struct
    opts.Axes = []
    opts.RemoveStatic (1,1) logical = false
    opts.DynamicRangeDb (1,1) double = 50
    opts.Title (1,1) string = ""
    opts.ReferenceDb double = []
end
if isempty(opts.Axes)
    ax = gca;
else
    ax = opts.Axes;
end

d = rt.data;
if opts.RemoveStatic
    d = d - mean(d, 2);
end
db = 20 * log10(abs(d) + eps);

imagesc(ax, rt.timeAxis, rt.rangeAxis, db);
axis(ax, 'xy');
if isempty(opts.ReferenceDb)
    top = max(db(:));
else
    top = opts.ReferenceDb;
end
clim(ax, [top - opts.DynamicRangeDb, top]);
colormap(ax, 'jet');
colorbar(ax);
xlabel(ax, 'Time (s)');
ylabel(ax, 'Range (m)');
if strlength(opts.Title) > 0
    title(ax, opts.Title);
end
end
