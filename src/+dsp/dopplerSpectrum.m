function sp = dopplerSpectrum(data, prf, carrierHz, s)
%DOPPLERSPECTRUM Magnitude Doppler spectrum from an FFT along slow time.
%   sp = dsp.dopplerSpectrum(data, prf, carrierHz, settings)
%
%   data is range-bins-by-chirps (for example the selected bins of preprocessed
%   range-time data). Each bin is windowed (s.doppler.window), transformed with
%   an FFT of s.doppler.fftSize points (0 = next power of two >= the number of
%   chirps), and the magnitudes are summed over bins, which is non-coherent
%   combination. The axis is centred on 0 Hz and spans -prf/2 to just below
%   +prf/2.
%
%   Fields: freq (Hz, column), mag (column), velocity (m/s, empty when the
%   carrier is unknown), velocityAvailable, nfft, binWidth (Hz), numBins.
arguments
    data (:,:) {mustBeNumeric}
    prf (1,1) double {mustBePositive}
    carrierHz
    s (1,1) struct = dsp.makeSettings()
end
n = size(data, 2);
nfft = s.doppler.fftSize;
if nfft == 0
    nfft = 2 ^ nextpow2(n);
end
if nfft < n
    error('dsp:doppler:fftTooSmall', ...
        'FFT size %d is smaller than the %d chirps in the data; use 0 or a larger size.', nfft, n);
end

w = dsp.makeWindow(string(s.doppler.window), n);
F = fft(data .* w.', nfft, 2);
mag = fftshift(sum(abs(F), 1)).';

k = (-floor(nfft / 2) : ceil(nfft / 2) - 1)';
sp.freq = k * prf / nfft;
sp.mag = mag;
sp.nfft = nfft;
sp.binWidth = prf / nfft;
sp.numBins = size(data, 1);
[sp.velocity, sp.velocityAvailable] = dsp.velocityAxis(sp.freq, carrierHz);
end
