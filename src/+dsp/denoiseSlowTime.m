function rt = denoiseSlowTime(rt, s)
%DENOISESLOWTIME Optional low-pass filtering along slow time.
%   rt = dsp.denoiseSlowTime(rt, settings)
%
%   Human motion at 5.8 GHz produces Doppler frequencies of a few hundred Hz at
%   most (f_D = 2v/lambda, about 39 Hz per m/s), so noise outside that band can
%   be removed. With s.denoise.method = "none" the data is returned unchanged;
%   with "lowpass" a causal Butterworth low-pass of order s.denoise.order at
%   s.denoise.cutoffHz is applied to every range bin. Whether it helps is
%   measured, not assumed (Experiment B).
arguments
    rt (1,1) struct
    s (1,1) struct = dsp.makeSettings()
end
method = string(s.denoise.method);

switch method
    case "none"
    case "lowpass"
        wn = s.denoise.cutoffHz / (rt.prf / 2);
        if wn <= 0 || wn >= 1
            error('dsp:denoise:badCutoff', ...
                'Low-pass cutoff %.2f Hz must be between 0 and half the pulse rate (%.1f Hz).', ...
                s.denoise.cutoffHz, rt.prf / 2);
        end
        [b, a] = butter(s.denoise.order, wn, 'low');
        rt.data = filter(b, a, rt.data, [], 2);
    otherwise
        error('dsp:denoise:unknownMethod', 'Unknown denoise method "%s".', method);
end
rt.denoiseMethod = method;
end
