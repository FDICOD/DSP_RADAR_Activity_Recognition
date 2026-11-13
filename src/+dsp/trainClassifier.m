function model = trainClassifier(X, y, method, params, seed)
%TRAINCLASSIFIER Train a classical classifier on feature vectors.
%   model = dsp.trainClassifier(X, y, "svm",    struct('C', 10), seed)
%   model = dsp.trainClassifier(X, y, "knn",    struct('k', 5), seed)
%   model = dsp.trainClassifier(X, y, "forest", struct('cycles', 200, 'leaf', 3), seed)
%
%   X is recordings-by-features and y the activity codes. Features are
%   standardised with the mean and standard deviation of THIS training set only,
%   and classes are weighted equally (dsp.balancedWeights), so the rare falling
%   class is not ignored. Methods:
%     svm     RBF support vector machine, one-vs-one, posterior probabilities
%     knn     k nearest neighbours
%     forest  bagged decision trees with random feature subsets (random forest)
%   Apply with dsp.predictClassifier. Training is seeded.
arguments
    X (:,:) double
    y (:,1) double
    method (1,1) string
    params (1,1) struct = struct()
    seed (1,1) double = 1
end
if size(X, 1) ~= numel(y)
    error('dsp:train:sizeMismatch', 'X has %d rows but y has %d labels.', size(X, 1), numel(y));
end
if any(~isfinite(X(:)))
    error('dsp:train:nonFinite', 'The training features contain NaN or Inf.');
end
classes = unique(y);
if numel(classes) < 2
    error('dsp:train:oneClass', 'At least two classes are needed to train a classifier.');
end

mu = mean(X, 1);
sd = std(X, 0, 1);
sd(sd < eps) = 1;
Z = (X - mu) ./ sd;
w = dsp.balancedWeights(y);
rng(seed, 'twister');

switch lower(method)
    case "svm"
        C = getParam(params, 'C', 1);
        learner = templateSVM('KernelFunction', 'rbf', 'BoxConstraint', C, ...
            'KernelScale', 'auto', 'Standardize', false);
        mdl = fitcecoc(Z, y, 'Learners', learner, 'Coding', 'onevsone', 'Weights', w, ...
            'FitPosterior', true, 'ClassNames', classes);
    case "knn"
        k = getParam(params, 'k', 5);
        mdl = fitcknn(Z, y, 'NumNeighbors', k, 'Weights', w, 'ClassNames', classes);
    case "forest"
        cycles = getParam(params, 'cycles', 200);
        leaf = getParam(params, 'leaf', 1);
        learner = templateTree('MinLeafSize', leaf, 'NumVariablesToSample', 'auto');
        mdl = fitcensemble(Z, y, 'Method', 'Bag', 'NumLearningCycles', cycles, ...
            'Learners', learner, 'Weights', w, 'ClassNames', classes);
    otherwise
        error('dsp:train:unknownMethod', 'Unknown method "%s"; use "svm", "knn" or "forest".', method);
end

model.method = lower(method);
model.params = params;
model.mu = mu;
model.sd = sd;
model.classes = classes;
model.trainCounts = arrayfun(@(c) nnz(y == c), classes);
model.mdl = mdl;
end

function v = getParam(params, name, default)
if isfield(params, name)
    v = params.(name);
else
    v = default;
end
end
