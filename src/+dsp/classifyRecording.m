function r = classifyRecording(bundle, rec)
%CLASSIFYRECORDING Activity prediction for one raw recording, using a saved model bundle.
%   r = dsp.classifyRecording(bundle, rec) runs the whole pipeline (range FFT, bin
%   selection, preprocessing, STFT, features) with the settings stored in the
%   bundle, then the classifier.
%   Fields: code, name, confidence, scores (class probabilities), classes, features.
arguments
    bundle (1,1) struct
    rec (1,1) struct
end
sp = dsp.spectrogramOf(rec, bundle.settings);
x = dsp.extractFeatures(sp, bundle.settings);
[code, confidence, scores] = dsp.predictClassifier(bundle.model, x);
r.code = code;
r.name = bundle.activityNames(code);
r.confidence = confidence;
r.scores = scores;
r.classes = bundle.model.classes';
r.features = x;
end
