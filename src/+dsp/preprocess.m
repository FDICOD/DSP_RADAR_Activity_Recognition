function [out, sel] = preprocess(rt, s, norm)
%PREPROCESS Run the configured preprocessing steps on range-time data.
%   [out, sel] = dsp.preprocess(rt, settings)
%   [out, sel] = dsp.preprocess(rt, settings, norm)   % norm from dsp.fitNormalizer
%
%   Steps, always in this order, each switchable in the settings:
%     1. range-bin selection        (s.range)    on the unprocessed data
%     2. clutter removal            (s.clutter)
%     3. optional slow-time denoise (s.denoise)
%     4. amplitude normalisation    (s.normalize)
%   There is no randomness, so two settings that differ in one switch give
%   results that differ only through that step.
%
%   out is rt with processed data plus: rmsSelected (RMS of the selected bins
%   before normalisation, used to fit a global scale on training data),
%   selection, and steps (the methods used and the scale applied).
arguments
    rt (1,1) struct
    s (1,1) struct = dsp.makeSettings()
    norm = []
end
sel = dsp.selectRangeBins(rt, s);

out = dsp.removeClutter(rt, s);
out = dsp.denoiseSlowTime(out, s);
out.rmsSelected = dsp.segmentRms(out, sel.bins);

mode = string(s.normalize.mode);
switch mode
    case "none"
        scale = 1;
    case "segment"
        if out.rmsSelected <= 0
            error('dsp:normalize:silent', 'Cannot normalise a recording with zero amplitude in the selected bins.');
        end
        scale = 1 / out.rmsSelected;
    case "global"
        if isempty(norm) || ~isfield(norm, 'scale')
            error('dsp:normalize:notFitted', ...
                'normalize.mode is "global" but no fitted normalizer was given; use dsp.fitNormalizer on training data.');
        end
        scale = 1 / norm.scale;
    otherwise
        error('dsp:normalize:unknownMode', 'Unknown normalize mode "%s".', mode);
end
out.data = out.data * scale;

out.selection = sel;
out.steps = struct('clutter', string(s.clutter.method), 'denoise', string(s.denoise.method), ...
    'normalize', mode, 'scale', scale);
end
