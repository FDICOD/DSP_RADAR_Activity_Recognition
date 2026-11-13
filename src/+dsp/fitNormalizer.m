function norm = fitNormalizer(trainRms)
%FITNORMALIZER Fit the global amplitude scale from training recordings only.
%   norm = dsp.fitNormalizer(trainRms) where trainRms holds out.rmsSelected of
%   every TRAINING recording (preprocessed with normalize.mode = "none"). The
%   scale is their median. Validation and test recordings must never be passed
%   here: they are scaled with the stored value, which keeps them from
%   influencing the preprocessing.
arguments
    trainRms (:,1) double {mustBePositive, mustBeFinite}
end
if isempty(trainRms)
    error('dsp:normalize:noTrainingData', 'At least one training RMS value is needed.');
end
norm.scale = median(trainRms);
norm.count = numel(trainRms);
end
