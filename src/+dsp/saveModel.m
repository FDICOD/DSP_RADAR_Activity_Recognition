function saveModel(model, settings, file)
%SAVEMODEL Save a trained classifier with everything needed to apply it to a new recording.
%   dsp.saveModel(model, settings, "results/models/A_svm.mat")
%   The bundle holds the model, the range / preprocessing / STFT / feature settings
%   it was trained with, the feature names and the activity names. Load it with
%   dsp.loadModel and apply it to a recording with dsp.classifyRecording.
arguments
    model (1,1) struct
    settings (1,1) struct
    file (1,1) string
end
if string(settings.normalize.mode) == "global"
    error('dsp:saveModel:globalNormalizer', ...
        'Saving a model with normalize.mode "global" needs the fitted normalizer; use "none" or "segment".');
end
[~, featureNames] = dsp.extractFeatures(struct('mag', ones(5, 3), 'velocity', linspace(-1, 1, 5)', ...
    'velocityAvailable', true, 'timeStep', 0.01), settings);
bundle.model = model;
bundle.settings = settings;
bundle.featureNames = featureNames;
bundle.activityNames = string(settings.activity.codeNames);
bundle.created = string(datetime('now'));
folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder)
    mkdir(folder);
end
save(file, 'bundle');
end
