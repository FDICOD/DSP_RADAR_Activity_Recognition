function rt = removeClutter(rt, s)
%REMOVECLUTTER Suppress DC and static returns along slow time in every range bin.
%   rt = dsp.removeClutter(rt, settings)
%
%   Static reflectors (walls, furniture) give a constant value in a range bin
%   over time, which is a spike at 0 Hz Doppler. Removing it leaves the moving
%   person. The method is s.clutter.method:
%     "none"       data unchanged
%     "mean"       subtract each bin's mean over time
%     "highpass"   mean subtraction, then a causal Butterworth high-pass of order
%                  s.clutter.order at s.clutter.cutoffHz (an MTI filter). The
%                  filter starts from rest, so the first few tens of chirps hold a
%                  short transient.
%     "canceller"  two-pulse canceller y[n] = x[n] - x[n-1], with y[1] = 0. Its
%                  gain 2*sin(pi*f/PRF) is not flat, so it also reshapes the
%                  Doppler spectrum.
%   The number of range bins and chirps is unchanged.
arguments
    rt (1,1) struct
    s (1,1) struct = dsp.makeSettings()
end
method = string(s.clutter.method);
d = rt.data;

switch method
    case "none"
    case "mean"
        d = d - mean(d, 2);
    case "canceller"
        d = [zeros(size(d, 1), 1), diff(d, 1, 2)];
    case "highpass"
        wn = s.clutter.cutoffHz / (rt.prf / 2);
        if wn <= 0 || wn >= 1
            error('dsp:clutter:badCutoff', ...
                'High-pass cutoff %.2f Hz must be between 0 and half the pulse rate (%.1f Hz).', ...
                s.clutter.cutoffHz, rt.prf / 2);
        end
        [b, a] = butter(s.clutter.order, wn, 'high');
        d = d - mean(d, 2);
        d = filter(b, a, d, [], 2);
    otherwise
        error('dsp:clutter:unknownMethod', 'Unknown clutter method "%s".', method);
end

rt.data = d;
rt.clutterMethod = method;
end
