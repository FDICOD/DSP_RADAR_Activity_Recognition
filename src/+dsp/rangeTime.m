function rt = rangeTime(rec, s)
%RANGETIME Range FFT of every chirp: the range-time data of a recording.
%   rt = dsp.rangeTime(rec, settings)
%
%   Each chirp's beat signal is windowed (s.range.window), zero-padded by
%   s.range.padFactor and Fourier transformed along fast time. Only the
%   non-negative beat frequencies are kept: range R = f_b * c * Tc / (2 * B), so
%   the bin spacing is c / (2 * B * padFactor) (0.375 m for 400 MHz, no padding).
%
%   Fields: data (bins-by-chirps complex), rangeAxis (m, bins-by-1),
%   timeAxis (s, 1-by-chirps), binSpacing (m), maxRange (m), fs (fast-time
%   sampling rate, Hz), nfft, and prf, wavelength, carrierHz copied from rec.
arguments
    rec (1,1) struct
    s (1,1) struct = dsp.makeSettings()
end
c = 299792458;
nts = rec.samplesPerChirp;
nfft = nts * s.range.padFactor;

w = dsp.makeWindow(string(s.range.window), nts);
X = dsp.reshapeChirps(rec) .* w;
F = fft(X, nfft, 1);
nbins = floor(nfft / 2);

fs = nts / rec.chirpDuration;
rt.data = F(1:nbins, :);
rt.binSpacing = c / (2 * rec.bandwidthHz * s.range.padFactor);
rt.rangeAxis = (0:nbins-1)' * rt.binSpacing;
rt.timeAxis = (0:rec.numChirps-1) * rec.chirpDuration;
rt.maxRange = rt.rangeAxis(end);
rt.fs = fs;
rt.nfft = nfft;
rt.prf = rec.prf;
rt.wavelength = rec.wavelength;
rt.carrierHz = rec.carrierHz;
end
