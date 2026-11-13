function img = resampleSpectrogram(dB, targetSize, dynamicRangeDb, referenceDb)
%RESAMPLESPECTROGRAM Fixed-size image with a fixed value range from a spectrogram in dB.
%   img = dsp.resampleSpectrogram(dB, [rows cols], dynamicRangeDb)
%   img = dsp.resampleSpectrogram(dB, [rows cols], dynamicRangeDb, referenceDb)
%
%   Values are limited to the top dynamicRangeDb below referenceDb (default: the
%   image's own maximum) and scaled to 0..1, then resampled to targetSize by
%   linear interpolation. Spectrograms made with different window lengths, and
%   so with different sizes, therefore come out with identical shape and range.
%   Pass the same referenceDb to keep absolute levels comparable across images.
arguments
    dB (:,:) double
    targetSize (1,2) double {mustBePositive, mustBeInteger}
    dynamicRangeDb (1,1) double {mustBePositive}
    referenceDb double = []
end
[h, w] = size(dB);
if h < 2 || w < 2
    error('dsp:resample:tooSmall', 'A spectrogram of size %d-by-%d is too small to resample.', h, w);
end
if isempty(referenceDb)
    referenceDb = max(dB(:));
end
lo = referenceDb - dynamicRangeDb;
X = (min(max(dB, lo), referenceDb) - lo) / dynamicRangeDb;

xq = linspace(1, w, targetSize(2));
yq = linspace(1, h, targetSize(1))';
img = interp2(1:w, 1:h, X, xq, yq, 'linear');
end
