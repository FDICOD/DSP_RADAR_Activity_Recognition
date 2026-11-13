function [pre, sel] = preprocessRecording(rec, s, norm)
%PREPROCESSRECORDING Range FFT, bin selection and preprocessing, without the STFT.
%   [pre, sel] = dsp.preprocessRecording(rec, settings)
%   Use this when several STFT settings are tried on the same recording, so the
%   front end is computed once and dsp.microDoppler is called for each setting.
arguments
    rec (1,1) struct
    s (1,1) struct = dsp.makeSettings()
    norm = []
end
[pre, sel] = dsp.preprocess(dsp.rangeTime(rec, s), s, norm);
end
