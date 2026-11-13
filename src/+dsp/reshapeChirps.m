function X = reshapeChirps(rec)
%RESHAPECHIRPS Arrange samples as fast time (rows) by chirp (columns).
%   The recording stores the beat signal of one chirp after another, so column k
%   holds the samplesPerChirp samples of chirp k. The pulse repetition frequency
%   is rec.prf (1 / chirp duration).
X = reshape(rec.iq, rec.samplesPerChirp, rec.numChirps);
end
