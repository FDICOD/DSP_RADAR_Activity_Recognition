function h = readConvertedHeader(path)
%READCONVERTEDHEADER Header values and length of a converted recording, without loading samples.
path = char(path);
S = load(path, 'fc', 'Tc_ms', 'nts', 'bw');
w = whos('-file', path, 'I');
if isempty(w)
    error('dsp:readConvertedHeader:missingField', 'File %s is missing field I.', path);
end
h.carrierHz = double(S.fc);
h.chirpDurationMs = double(S.Tc_ms);
h.samplesPerChirp = double(S.nts);
h.bandwidthHz = double(S.bw);
h.numSamples = w.size(1);
h.durationSeconds = floor(h.numSamples / h.samplesPerChirp) * h.chirpDurationMs / 1000;
end
