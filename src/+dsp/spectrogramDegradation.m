function d = spectrogramDegradation(clean, noisy, dynamicRangeDb)
%SPECTROGRAMDEGRADATION How much noise changes a spectrogram, without any classifier.
%   d = dsp.spectrogramDegradation(clean, noisy, dynamicRangeDb)
%
%   Both spectrograms (from dsp.stft or dsp.microDoppler, same settings and same
%   recording) are limited to the top dynamicRangeDb below the CLEAN spectrogram's
%   maximum, then compared:
%     correlation  Pearson correlation of the two dB maps (1 = identical)
%     nrmse        root-mean-square difference as a fraction of dynamicRangeDb
%                  (0 = identical)
%   Lower correlation and higher nrmse mean more degradation.
arguments
    clean (1,1) struct
    noisy (1,1) struct
    dynamicRangeDb (1,1) double {mustBePositive} = 40
end
if ~isequal(size(clean.dB), size(noisy.dB))
    error('dsp:degradation:sizeMismatch', 'The two spectrograms must have the same size; they were made with different settings.');
end
top = max(clean.dB(:));
lo = top - dynamicRangeDb;
a = min(max(clean.dB(:), lo), top);
b = min(max(noisy.dB(:), lo), top);

c = corrcoef(a, b);
d.correlation = c(1, 2);
d.nrmse = sqrt(mean((a - b) .^ 2)) / dynamicRangeDb;
end
