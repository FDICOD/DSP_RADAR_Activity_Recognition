function rec = addNoise(rec, snrDb, seed)
%ADDNOISE Add complex white Gaussian noise to the raw samples at a target input SNR.
%   noisy = dsp.addNoise(rec, snrDb, seed)
%
%   Signal power is the power of the recording after removing its mean, which is
%   the constant ADC offset: Ps = mean(|x - mean(x)|^2). It includes the static
%   returns, so this is an SNR at the radar input, before any processing gain from
%   the range FFT or STFT, and the SNR of the moving person alone is lower. Noise
%   has power Ps / 10^(snrDb/10), split equally between I and Q.
%
%   The noise comes from its own random stream seeded with seed, so the same
%   recording, SNR and seed always give the same noisy recording and the global
%   random state is untouched. snrDb = Inf returns the recording unchanged.
%   Noise is added BEFORE range processing, clutter removal and the STFT, so the
%   whole pipeline is exercised by it; labels are not affected.
arguments
    rec (1,1) struct
    snrDb (1,1) double
    seed (1,1) double {mustBeNonnegative, mustBeInteger}
end
if isnan(snrDb) || snrDb == -Inf
    error('dsp:noise:badSnr', 'The SNR must be a number in dB, or Inf for no noise.');
end
x = rec.iq;
signalPower = mean(abs(x - mean(x)) .^ 2);
if signalPower <= 0
    error('dsp:noise:noSignal', 'The recording has no signal power above its constant offset.');
end
noisePower = signalPower / 10 ^ (snrDb / 10);

if isfinite(snrDb)
    stream = RandStream('mt19937ar', 'Seed', seed);
    noise = sqrt(noisePower / 2) * complex(randn(stream, numel(x), 1), randn(stream, numel(x), 1));
    rec.iq = x + noise;
end
rec.noise = struct('snrDb', snrDb, 'seed', seed, 'signalPower', signalPower, 'noisePower', noisePower);
end
