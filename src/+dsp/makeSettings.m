function s = makeSettings(overrides)
%MAKESETTINGS Default settings with validated overrides.
%   s = dsp.makeSettings() returns the defaults.
%   s = dsp.makeSettings(struct('seed', 7)) overrides one value.
%   Unknown field names raise dsp:settings:unknownField; invalid values raise
%   dsp:settings:invalidValue.
arguments
    overrides (1,1) struct = struct()
end
s = dsp.defaultSettings();
s = mergeInto(s, overrides, "");
validate(s);
end

function base = mergeInto(base, over, prefix)
names = fieldnames(over);
for k = 1:numel(names)
    name = names{k};
    path = prefix + name;
    if ~isfield(base, name)
        error('dsp:settings:unknownField', 'Unknown setting "%s".', path);
    end
    if isstruct(base.(name)) && isscalar(base.(name)) && isstruct(over.(name))
        base.(name) = mergeInto(base.(name), over.(name), path + ".");
    else
        base.(name) = over.(name);
    end
end
end

function validate(s)
bad = @(msg) error('dsp:settings:invalidValue', '%s', msg);

if ~(isnumeric(s.seed) && isscalar(s.seed) && s.seed >= 0 && s.seed == round(s.seed) && s.seed < 2^32)
    bad('seed must be a non-negative integer below 2^32.');
end
if ~((ischar(s.data.root) || isstring(s.data.root)) && isscalar(string(s.data.root)))
    bad('data.root must be a text value.');
end
if ~(ischar(s.data.format) || isstring(s.data.format)) || ~ismember(string(s.data.format), ["mat" "dat"])
    bad('data.format must be "mat" or "dat".');
end
if ~isstring(s.activity.codeNames) || isempty(s.activity.codeNames)
    bad('activity.codeNames must be a non-empty string array.');
end
r = s.range;
if ~(ischar(r.window) || isstring(r.window)) || ~ismember(string(r.window), ["rect" "hann" "hamming"])
    bad('range.window must be "rect", "hann" or "hamming".');
end
if ~(isnumeric(r.padFactor) && isscalar(r.padFactor) && r.padFactor >= 1 && r.padFactor == round(r.padFactor))
    bad('range.padFactor must be a positive integer.');
end
if ~(isnumeric(r.intervalMetres) && numel(r.intervalMetres) == 2 && r.intervalMetres(1) >= 0 ...
        && r.intervalMetres(2) > r.intervalMetres(1))
    bad('range.intervalMetres must be [low high] in metres with 0 <= low < high.');
end
if ~(ischar(r.selection) || isstring(r.selection)) || ~ismember(string(r.selection), ["fixed" "auto"])
    bad('range.selection must be "fixed" or "auto".');
end
if ~(isnumeric(r.autoMinMetres) && isscalar(r.autoMinMetres) && r.autoMinMetres >= 0)
    bad('range.autoMinMetres must be a non-negative number.');
end
if ~(isnumeric(r.autoThreshold) && isscalar(r.autoThreshold) && r.autoThreshold > 0 && r.autoThreshold <= 1)
    bad('range.autoThreshold must be in (0, 1].');
end
if ~(isnumeric(r.autoMaxBins) && isscalar(r.autoMaxBins) && r.autoMaxBins >= 1 && r.autoMaxBins == round(r.autoMaxBins))
    bad('range.autoMaxBins must be a positive integer.');
end
c = s.clutter;
if ~(ischar(c.method) || isstring(c.method)) || ~ismember(string(c.method), ["none" "mean" "highpass" "canceller"])
    bad('clutter.method must be "none", "mean", "highpass" or "canceller".');
end
d = s.denoise;
if ~(ischar(d.method) || isstring(d.method)) || ~ismember(string(d.method), ["none" "lowpass"])
    bad('denoise.method must be "none" or "lowpass".');
end
for filt = {c, d}
    g = filt{1};
    if ~(isnumeric(g.cutoffHz) && isscalar(g.cutoffHz) && g.cutoffHz > 0)
        bad('Filter cutoffHz must be a positive number.');
    end
    if ~(isnumeric(g.order) && isscalar(g.order) && g.order >= 1 && g.order <= 10 && g.order == round(g.order))
        bad('Filter order must be an integer from 1 to 10.');
    end
end
if ~(ischar(s.normalize.mode) || isstring(s.normalize.mode)) || ~ismember(string(s.normalize.mode), ["none" "segment" "global"])
    bad('normalize.mode must be "none", "segment" or "global".');
end
if ~(ischar(s.doppler.window) || isstring(s.doppler.window)) || ~ismember(string(s.doppler.window), ["rect" "hann" "hamming"])
    bad('doppler.window must be "rect", "hann" or "hamming".');
end
if ~(isnumeric(s.doppler.fftSize) && isscalar(s.doppler.fftSize) && s.doppler.fftSize >= 0 && s.doppler.fftSize == round(s.doppler.fftSize))
    bad('doppler.fftSize must be 0 or a positive integer.');
end
st = s.stft;
if ~(isnumeric(st.windowSeconds) && isscalar(st.windowSeconds) && st.windowSeconds > 0)
    bad('stft.windowSeconds must be a positive number.');
end
if ~(isnumeric(st.overlapFraction) && isscalar(st.overlapFraction) && st.overlapFraction >= 0 && st.overlapFraction < 1)
    bad('stft.overlapFraction must be at least 0 and below 1.');
end
if ~(isnumeric(st.padFactor) && isscalar(st.padFactor) && st.padFactor >= 1 && st.padFactor == round(st.padFactor))
    bad('stft.padFactor must be a positive integer (the FFT size is padFactor times the window length).');
end
if ~(ischar(st.window) || isstring(st.window)) || ~ismember(string(st.window), ["rect" "hann" "hamming"])
    bad('stft.window must be "rect", "hann" or "hamming".');
end
if ~(isnumeric(st.dynamicRangeDb) && isscalar(st.dynamicRangeDb) && st.dynamicRangeDb > 0)
    bad('stft.dynamicRangeDb must be a positive number.');
end
if ~(isnumeric(st.imageSize) && numel(st.imageSize) == 2 && all(st.imageSize >= 2) && all(st.imageSize == round(st.imageSize)))
    bad('stft.imageSize must be [rows columns] with each at least 2.');
end
g = s.features;
if ~isstring(g.groups) || isempty(g.groups) || ~all(ismember(g.groups, ["doppler" "temporal"])) ...
        || numel(unique(g.groups)) ~= numel(g.groups)
    bad('features.groups must be a non-empty string array of distinct names from "doppler" and "temporal".');
end
if ~(isnumeric(g.velocityLimit) && isscalar(g.velocityLimit) && g.velocityLimit > 0)
    bad('features.velocityLimit must be a positive number (m/s).');
end
if ~(isnumeric(g.extentDropDb) && isscalar(g.extentDropDb) && g.extentDropDb > 0)
    bad('features.extentDropDb must be a positive number (dB).');
end
f = [s.split.train s.split.val s.split.test];
if ~isnumeric(f) || any(~isfinite(f)) || any(f <= 0) || abs(sum(f) - 1) > 1e-9
    bad('split.train, split.val and split.test must be positive and sum to 1.');
end
if ~iscell(s.split.mergeGroups)
    bad('split.mergeGroups must be a cell array.');
end
for k = 1:numel(s.split.mergeGroups)
    g = s.split.mergeGroups{k};
    if ~isstring(g) || size(g, 2) ~= 2 || size(g, 1) < 2
        bad('Each split.mergeGroups entry must be an N-by-2 string array with N >= 2.');
    end
end
end
