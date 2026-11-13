function sp = microDoppler(pre, sel, s)
%MICRODOPPLER Micro-Doppler spectrogram of preprocessed range-time data.
%   sp = dsp.microDoppler(pre, sel, settings) where pre comes from dsp.preprocess
%   and sel from dsp.selectRangeBins. The spectrogram is computed over the
%   selected range bins; their numbers and range are recorded in sp.
arguments
    pre (1,1) struct
    sel (1,1) struct
    s (1,1) struct = dsp.makeSettings()
end
sp = dsp.stft(pre.data(sel.bins, :), pre.prf, pre.carrierHz, s);
sp.bins = sel.bins;
sp.rangeMetres = sel.rangeMetres;
end
