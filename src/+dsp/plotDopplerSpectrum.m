function ax = plotDopplerSpectrum(sp, opts)
%PLOTDOPPLERSPECTRUM Plot a Doppler spectrum in dB relative to a reference magnitude.
%   dsp.plotDopplerSpectrum(sp, Axes=ax, DisplayName="before", ReferenceMag=max(sp.mag))
%
%   The horizontal axis is velocity in m/s when available, otherwise Doppler in
%   Hz. Plot several spectra on one axes with hold on, giving them the same
%   ReferenceMag so their levels can be compared.
arguments
    sp (1,1) struct
    opts.Axes = []
    opts.DisplayName (1,1) string = ""
    opts.ReferenceMag double = []
    opts.Title (1,1) string = ""
end
if isempty(opts.Axes)
    ax = gca;
else
    ax = opts.Axes;
end
if isempty(opts.ReferenceMag)
    ref = max(sp.mag);
else
    ref = opts.ReferenceMag;
end

if sp.velocityAvailable
    x = sp.velocity;
    xLabel = 'Velocity (m/s)';
else
    x = sp.freq;
    xLabel = 'Doppler (Hz)';
end
y = 20 * log10(max(sp.mag, eps) / ref);
if strlength(opts.DisplayName) > 0
    plot(ax, x, y, 'DisplayName', opts.DisplayName, 'LineWidth', 1);
else
    plot(ax, x, y, 'LineWidth', 1);
end
grid(ax, 'on');
xlabel(ax, xLabel);
ylabel(ax, 'Magnitude (dB)');
if strlength(opts.Title) > 0
    title(ax, opts.Title);
end
end
