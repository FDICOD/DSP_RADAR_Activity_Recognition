function results = experiment_D(varargin)
% EXPERIMENT_D Classifier comparison: SVM, k-NN and random forest on identical splits and features.
%   experiment_D                 % validation split only
%   experiment_D('UseTest', true)  % final run, scores the test split once per method
%   Each method is tuned on the validation split only. See run_classification.
results = run_classification('Methods', ["svm" "knn" "forest"], 'Name', "D", varargin{:});
end
