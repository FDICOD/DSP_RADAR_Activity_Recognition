function ax = plotSpectrogram(sp, opts)
%PLOTSPECTROGRAM Show a micro-Doppler spectrogram (dB) with labelled axes.
%   dsp.plotSpectrogram(sp)
%   dsp.plotSpectrogram(sp, Axes=ax, Title="walking", DynamicRangeDb=40, ReferenceDb=top)
%
%   The vertical axis is velocity in m/s when it is available, otherwise Doppler
%   in Hz. Pass the same ReferenceDb to several plots to put them on one
%   colour scale.
arguments
    sp (1,1) struct
    opts.Axes = []
    opts.Title (1,1) string = ""
    opts.DynamicRangeDb (1,1) double = 40
    opts.ReferenceDb double = []
end
if isempty(opts.Axes)
    ax = gca;
else
    ax = opts.Axes;
end

if sp.velocityAvailable
    y = sp.velocity;
    yLabel = 'Velocity (m/s)';
else
    y = sp.freq;
    yLabel = 'Doppler (Hz)';
end
imagesc(ax, sp.time, y, sp.dB);
axis(ax, 'xy');
if isempty(opts.ReferenceDb)
    top = max(sp.dB(:));
else
    top = opts.ReferenceDb;
end
clim(ax, [top - opts.DynamicRangeDb, top]);
colormap(ax, 'jet');
colorbar(ax);
xlabel(ax, 'Time (s)');
ylabel(ax, yLabel);
if strlength(opts.Title) > 0
    title(ax, opts.Title);
end
end
