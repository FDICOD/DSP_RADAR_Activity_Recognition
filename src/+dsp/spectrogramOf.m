function [sp, sel] = spectrogramOf(rec, s, norm)
%SPECTROGRAMOF Micro-Doppler spectrogram of a recording after the whole front end.
%   [sp, sel] = dsp.spectrogramOf(rec, settings)
%   [sp, sel] = dsp.spectrogramOf(rec, settings, norm)
%   Range FFT, range-bin selection, preprocessing and STFT in one call, without
%   the before-clutter-removal views that dsp.runPipeline also computes.
arguments
    rec (1,1) struct
    s (1,1) struct = dsp.makeSettings()
    norm = []
end
rt = dsp.rangeTime(rec, s);
[pre, sel] = dsp.preprocess(rt, s, norm);
sp = dsp.microDoppler(pre, sel, s);
end
