function m = classificationMetrics(yTrue, yPred, classes)
%CLASSIFICATIONMETRICS Accuracy, per-class and macro precision/recall/F1, confusion matrix.
%   m = dsp.classificationMetrics(yTrue, yPred)
%   m = dsp.classificationMetrics(yTrue, yPred, classes)   % fix the class list
%
%   confusion(i, j) counts recordings of true class classes(i) predicted as
%   classes(j). Precision of a class that is never predicted is 0 (warning
%   dsp:metrics:noPredictions); recall of a class absent from yTrue is not
%   defined, so the macro averages cover only the classes present in yTrue.
%   macroRecall is the balanced accuracy.
arguments
    yTrue (:,1) double
    yPred (:,1) double
    classes (:,1) double = unique([yTrue; yPred])
end
if isempty(yTrue)
    error('dsp:metrics:empty', 'There are no labels to evaluate.');
end
if numel(yTrue) ~= numel(yPred)
    error('dsp:metrics:sizeMismatch', 'yTrue has %d labels but yPred has %d.', numel(yTrue), numel(yPred));
end
[~, ti] = ismember(yTrue, classes);
[~, pj] = ismember(yPred, classes);
if any(ti == 0) || any(pj == 0)
    error('dsp:metrics:unknownLabel', 'A label is not in the class list.');
end

K = numel(classes);
cm = accumarray([ti pj], 1, [K K]);
support = sum(cm, 2);
predicted = sum(cm, 1)';
tp = diag(cm);

has = support > 0;
predictedAny = predicted > 0;
recall = zeros(K, 1);
precision = zeros(K, 1);
recall(has) = tp(has) ./ support(has);
precision(predictedAny) = tp(predictedAny) ./ predicted(predictedAny);

never = has & ~predictedAny;
if any(never)
    warning('dsp:metrics:noPredictions', ...
        'Class %s was never predicted; its precision is reported as 0.', strjoin(string(classes(never))', ', '));
end

f1 = zeros(K, 1);
d = precision + recall;
f1(d > 0) = 2 * precision(d > 0) .* recall(d > 0) ./ d(d > 0);

m.classes = classes;
m.confusion = cm;
m.support = support;
m.precision = precision;
m.recall = recall;
m.f1 = f1;
m.accuracy = trace(cm) / sum(cm(:));
m.macroPrecision = mean(precision(has));
m.macroRecall = mean(recall(has));
m.macroF1 = mean(f1(has));
end
