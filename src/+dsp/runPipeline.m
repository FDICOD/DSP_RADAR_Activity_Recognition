function r = runPipeline(rec, s, norm)
%RUNPIPELINE Every signal-processing stage for one recording, with before/after views.
%   r = dsp.runPipeline(rec, settings)
%   r = dsp.runPipeline(rec, settings, norm)   % norm from dsp.fitNormalizer
%
%   Stages: range FFT, range-bin selection, preprocessing (clutter removal,
%   optional denoise, normalisation), Doppler spectrum and micro-Doppler
%   spectrogram. The Doppler spectrum and spectrogram are computed twice, on the
%   range-time data before and after preprocessing, so the effect of clutter
%   removal can be shown on the same bins.
%
%   Fields: rt (range-time data before preprocessing), pre (after), sel (range
%   bins used), dopBefore, dopAfter, spBefore, spAfter, settings.
arguments
    rec (1,1) struct
    s (1,1) struct = dsp.makeSettings()
    norm = []
end
r.rt = dsp.rangeTime(rec, s);
[r.pre, r.sel] = dsp.preprocess(r.rt, s, norm);
r.dopBefore = dsp.dopplerSpectrum(r.rt.data(r.sel.bins, :), r.rt.prf, r.rt.carrierHz, s);
r.dopAfter = dsp.dopplerSpectrum(r.pre.data(r.sel.bins, :), r.pre.prf, r.pre.carrierHz, s);
r.spBefore = dsp.microDoppler(r.rt, r.sel, s);
r.spAfter = dsp.microDoppler(r.pre, r.sel, s);
r.settings = s;
end
