function sp = stft(data, prf, carrierHz, s)
%STFT Micro-Doppler spectrogram: our own short-time Fourier transform along slow time.
%   sp = dsp.stft(data, prf, carrierHz, settings)
%
%   data is range-bins-by-chirps. Slow time is cut into overlapping frames of
%   L = round(windowSeconds * prf) samples, hopping by L - round(L * overlapFraction)
%   samples. Each frame is multiplied by the analysis window, transformed with an
%   FFT of padFactor * L points, and the magnitudes are summed over range bins
%   (non-coherent combination). Frequency runs from -prf/2 upward in steps of
%   prf / nfft.
%
%   Fields: mag (frequency-by-time, linear), dB (20*log10 of mag), freq (Hz,
%   column), time (frame centres in s, row), velocity (m/s, empty if the carrier is
%   unknown), velocityAvailable, and the resolution figures freqResolution
%   (prf / L, Hz), timeStep (hop / prf, s), binWidth (prf / nfft, Hz), plus
%   windowLength, overlap, hop, nfft, window and numBins.
%
%   Verified against MATLAB's spectrogram (same window, overlap and FFT size):
%   magnitudes agree to 1e-9 of the largest value (tests/TestStft.m). The
%   frequency axis runs from -prf/2 like fftshift; MATLAB's 'centered' option
%   puts the Nyquist bin at +prf/2 instead, one bin later, with the same values.
arguments
    data (:,:) {mustBeNumeric}
    prf (1,1) double {mustBePositive}
    carrierHz
    s (1,1) struct = dsp.makeSettings()
end
c = s.stft;
L = round(c.windowSeconds * prf);
if L < 2
    error('dsp:stft:windowTooShort', 'The window of %.4f s is only %d samples at a pulse rate of %g Hz.', ...
        c.windowSeconds, L, prf);
end
overlap = round(L * c.overlapFraction);
hop = L - overlap;
if hop < 1
    error('dsp:stft:invalidOverlap', ...
        'Overlap of %d samples is not smaller than the window length of %d samples.', overlap, L);
end
nfft = L * c.padFactor;
if nfft < L
    error('dsp:stft:fftTooSmall', 'FFT size %d is smaller than the window length %d.', nfft, L);
end
n = size(data, 2);
if n < L
    error('dsp:stft:tooShort', 'The data has %d chirps, fewer than the window length of %d.', n, L);
end

numFrames = floor((n - L) / hop) + 1;
w = dsp.makeWindow(string(c.window), L);

mag = zeros(nfft, numFrames);
for f = 1:numFrames
    idx = (f - 1) * hop + (1:L);
    F = fft(data(:, idx) .* w.', nfft, 2);
    mag(:, f) = fftshift(sum(abs(F), 1)).';
end

k = (-floor(nfft / 2) : ceil(nfft / 2) - 1)';
sp.mag = mag;
sp.dB = 20 * log10(max(mag, eps));
sp.freq = k * prf / nfft;
sp.time = ((0:numFrames-1) * hop + L / 2) / prf;
[sp.velocity, sp.velocityAvailable] = dsp.velocityAxis(sp.freq, carrierHz);
sp.freqResolution = prf / L;
sp.timeStep = hop / prf;
sp.binWidth = prf / nfft;
sp.windowLength = L;
sp.overlap = overlap;
sp.hop = hop;
sp.nfft = nfft;
sp.window = string(c.window);
sp.numBins = size(data, 1);
end
