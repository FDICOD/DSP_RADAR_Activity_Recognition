function [best, grid] = tuneClassifier(method, Xtrain, ytrain, Xval, yval, seed)
%TUNECLASSIFIER Choose a classifier's hyperparameters using validation data only.
%   [params, grid] = dsp.tuneClassifier("svm", Xtr, ytr, Xval, yval, seed)
%
%   Each candidate is trained on the training set and scored by macro-F1 on the
%   validation set (the test set is never used here). Candidates:
%     svm     C = 0.1, 1, 10, 100
%     knn     k = 1, 3, 5, 9, 15
%     forest  200 trees, minimum leaf size 1, 3, 5
%   grid lists every candidate with its validation macro-F1 and accuracy; the first
%   candidate with the highest macro-F1 is returned as params.
arguments
    method (1,1) string
    Xtrain (:,:) double
    ytrain (:,1) double
    Xval (:,:) double
    yval (:,1) double
    seed (1,1) double = 1
end
switch lower(method)
    case "svm"
        cand = arrayfun(@(c) struct('C', c), [0.1 1 10 100]);
    case "knn"
        cand = arrayfun(@(k) struct('k', k), [1 3 5 9 15]);
    case "forest"
        cand = arrayfun(@(l) struct('cycles', 200, 'leaf', l), [1 3 5]);
    otherwise
        error('dsp:tune:unknownMethod', 'Unknown method "%s"; use "svm", "knn" or "forest".', method);
end

previous = warning('off', 'dsp:metrics:noPredictions');
cleaner = onCleanup(@() warning(previous));

classes = unique([ytrain; yval]);
n = numel(cand);
macroF1 = zeros(n, 1);
accuracy = zeros(n, 1);
text = strings(n, 1);
for i = 1:n
    model = dsp.trainClassifier(Xtrain, ytrain, method, cand(i), seed);
    m = dsp.classificationMetrics(yval, dsp.predictClassifier(model, Xval), classes);
    macroF1(i) = m.macroF1;
    accuracy(i) = m.accuracy;
    text(i) = dsp.describeParams(cand(i));
end
[~, pick] = max(macroF1);
best = cand(pick);
grid = table(text, macroF1, accuracy, 'VariableNames', {'params', 'valMacroF1', 'valAccuracy'});
end
