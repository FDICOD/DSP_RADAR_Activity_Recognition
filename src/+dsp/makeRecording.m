function rec = makeRecording(carrierHz, chirpMs, samplesPerChirp, bandwidthHz, iVals, qVals)
%MAKERECORDING Build the recording struct shared by the text and converted loaders.
%   iVals, qVals are the in-phase and quadrature samples (any numeric type).
%   An incomplete trailing chirp is discarded and counted in droppedSamples.
%
%   Fields: iq (complex double column), carrierHz, chirpDuration (s),
%   samplesPerChirp, bandwidthHz, numChirps, droppedSamples, prf (Hz),
%   wavelength (m).
nts = double(samplesPerChirp);
if ~(isscalar(nts) && nts >= 1 && nts == round(nts))
    error('dsp:makeRecording:badHeader', 'Samples per chirp must be a positive integer.');
end
iVals = double(iVals(:));
qVals = double(qVals(:));
if numel(iVals) ~= numel(qVals)
    error('dsp:makeRecording:sizeMismatch', 'I and Q must have the same number of samples.');
end

n = numel(iVals);
numChirps = floor(n / nts);
keep = numChirps * nts;

rec.iq = complex(iVals(1:keep), qVals(1:keep));
rec.carrierHz = double(carrierHz);
rec.chirpDuration = double(chirpMs) / 1000;
rec.samplesPerChirp = nts;
rec.bandwidthHz = double(bandwidthHz);
rec.numChirps = numChirps;
rec.droppedSamples = n - keep;
rec.prf = 1 / rec.chirpDuration;
rec.wavelength = 299792458 / rec.carrierHz;
end
