function T = snrSweep(rec, snrList, s, seed, repeats)
%SNRSWEEP Spectrogram degradation of one recording at several input SNR values.
%   T = dsp.snrSweep(rec, [20 10 5 0], settings, seed, repeats)
%
%   For each SNR, noise is added to the raw samples (dsp.addNoise), the full
%   front end is run, and the spectrogram is compared with the clean one
%   (dsp.spectrogramDegradation) using s.stft.dynamicRangeDb. With repeats > 1 the
%   noise is drawn with seeds seed, seed+1, ... and the results averaged.
%   T has columns snrDb, correlation and nrmse.
arguments
    rec (1,1) struct
    snrList (1,:) double
    s (1,1) struct = dsp.makeSettings()
    seed (1,1) double {mustBeNonnegative, mustBeInteger} = 1
    repeats (1,1) double {mustBePositive, mustBeInteger} = 1
end
clean = dsp.spectrogramOf(rec, s);
n = numel(snrList);
corr = zeros(n, 1);
nrmse = zeros(n, 1);
for k = 1:n
    c = zeros(repeats, 1);
    e = zeros(repeats, 1);
    for r = 1:repeats
        noisy = dsp.spectrogramOf(dsp.addNoise(rec, snrList(k), seed + r - 1), s);
        d = dsp.spectrogramDegradation(clean, noisy, s.stft.dynamicRangeDb);
        c(r) = d.correlation;
        e(r) = d.nrmse;
    end
    corr(k) = mean(c);
    nrmse(k) = mean(e);
end
T = table(snrList(:), corr, nrmse, 'VariableNames', {'snrDb', 'correlation', 'nrmse'});
end
