function sel = selectRangeBins(rt, s)
%SELECTRANGEBINS Choose the range bins used for Doppler analysis.
%   sel = dsp.selectRangeBins(rt, settings)
%
%   "fixed": the bins whose range lies in s.range.intervalMetres.
%   "auto":  the contiguous bins around the strongest moving return whose energy
%            is at least s.range.autoThreshold of that peak (at most
%            s.range.autoMaxBins), ignoring ranges below s.range.autoMinMetres.
%            Energy is measured after removing each bin's mean over time, so
%            static returns do not attract the selection.
%
%   sel.bins is a column of row indices into rt.data; sel.mode and
%   sel.rangeMetres ([first last] range of the chosen bins) are recorded for
%   the results.
arguments
    rt (1,1) struct
    s (1,1) struct = dsp.makeSettings()
end
mode = string(s.range.selection);

switch mode
    case "fixed"
        iv = s.range.intervalMetres;
        bins = find(rt.rangeAxis >= iv(1) & rt.rangeAxis <= iv(2));
        if isempty(bins)
            error('dsp:range:noBins', 'No range bins lie between %.2f m and %.2f m (maximum range %.2f m).', ...
                iv(1), iv(2), rt.maxRange);
        end
    case "auto"
        d = rt.data - mean(rt.data, 2);
        energy = mean(abs(d) .^ 2, 2);
        energy(rt.rangeAxis < s.range.autoMinMetres) = 0;
        [peak, k0] = max(energy);
        if peak <= 0
            error('dsp:range:noEnergy', 'No moving return found above %.2f m.', s.range.autoMinMetres);
        end
        threshold = peak * s.range.autoThreshold;
        lo = k0;
        hi = k0;
        nb = numel(energy);
        while lo > 1 && energy(lo-1) >= threshold && (hi - lo + 1) < s.range.autoMaxBins
            lo = lo - 1;
        end
        while hi < nb && energy(hi+1) >= threshold && (hi - lo + 1) < s.range.autoMaxBins
            hi = hi + 1;
        end
        bins = (lo:hi)';
    otherwise
        error('dsp:range:unknownSelection', 'Unknown selection mode "%s".', mode);
end

sel.bins = bins;
sel.mode = mode;
sel.rangeMetres = rt.rangeAxis([bins(1) bins(end)])';
end
