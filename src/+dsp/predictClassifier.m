function [yhat, confidence, scores] = predictClassifier(model, X)
%PREDICTCLASSIFIER Predicted activity code, confidence and class scores.
%   [yhat, confidence, scores] = dsp.predictClassifier(model, X)
%   X is recordings-by-features, built with the same feature settings as the
%   training data. scores holds one class probability per column (the order of
%   model.classes); confidence is the largest of them. The interface is the same
%   for every method, so experiments do not depend on the classifier type.
arguments
    model (1,1) struct
    X (:,:) double
end
if size(X, 2) ~= numel(model.mu)
    error('dsp:predict:featureCount', 'The model expects %d features but X has %d.', numel(model.mu), size(X, 2));
end
if any(~isfinite(X(:)))
    error('dsp:predict:nonFinite', 'The features contain NaN or Inf.');
end
Z = (X - model.mu) ./ model.sd;

switch model.method
    case "svm"
        [yhat, ~, ~, scores] = predict(model.mdl, Z);
    case "knn"
        [yhat, scores] = predict(model.mdl, Z);
    case "forest"
        [yhat, scores] = predict(model.mdl, Z);
    otherwise
        error('dsp:predict:unknownMethod', 'Unknown method "%s".', model.method);
end
confidence = max(scores, [], 2);
end
