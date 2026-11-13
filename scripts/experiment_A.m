function results = experiment_A(varargin)
% EXPERIMENT_A Baseline: the whole pipeline with an SVM on the DSP features.
%   experiment_A                 % validation split only
%   experiment_A('UseTest', true)  % final run, scores the test split once
%   See run_classification for the outputs.
results = run_classification('Methods', "svm", 'Name', "A", varargin{:});
end
