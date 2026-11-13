function results = run_classification(opts)
% RUN_CLASSIFICATION Features, tuning on validation, evaluation and saved models.
%   run_classification                                   % SVM, validation only
%   run_classification(Methods=["svm" "knn" "forest"])
%   run_classification(UseTest=true)                     % final run: also score the test split
%
%   Pipeline: features for every included recording (cached, restartable) ->
%   standardise on the training set -> choose hyperparameters by macro-F1 on the
%   VALIDATION split -> train on the training split -> score validation (and, only
%   with UseTest=true, the test split, once per method). Writes to results/classification:
%     <Name>_summary.csv   one row per method and split: accuracy, macro P/R/F1, timings
%     <Name>_perclass.csv  precision, recall, F1 and support per activity
%     <Name>_confusion_<method>_<split>.csv
%     <Name>_tuning_<method>.csv
%   and saves each model bundle to results/models/<Name>_<method>.mat.
%   Day-to-day work should use UseTest=false so the test split is not tuned on.
arguments
    opts.Methods (1,:) string = "svm"
    opts.Seed (1,1) double = 1
    opts.UseTest (1,1) logical = false
    opts.SaveModel (1,1) logical = true
    opts.Name (1,1) string = "A"
end

s = dsp.makeSettings();
s.seed = opts.Seed;
dsp.setSeed(opts.Seed);
T = dsp.splitByPerson(dsp.listRecordings(s), s);

root = dsp.projectRoot();
outDir = fullfile(root, 'results', 'classification');
modelDir = fullfile(root, 'results', 'models');
cacheFile = string(fullfile(root, 'results', 'cache', 'features_clean.mat'));
for d = {outDir, modelDir}
    if ~isfolder(d{1})
        mkdir(d{1});
    end
end

tFeat = tic;
F = dsp.featureTable(T, s, CacheFile=cacheFile);
featureSeconds = toc(tFeat);
good = F.ok;
if ~any(good)
    error('run_classification:noFeatures', 'No recording could be processed; first reason: %s', F.message(1));
end
if any(~good)
    warning('run_classification:failedRecordings', '%d recordings failed and are left out.', nnz(~good));
end
rows = F.row(good);
X = F.X(good, :);
y = T.activityCode(rows);
split = T.split(rows);
classes = unique(y);
classNames = string(s.activity.codeNames(classes));

Xtr = X(split == "train", :);  ytr = y(split == "train");
Xva = X(split == "val", :);    yva = y(split == "val");
Xte = X(split == "test", :);   yte = y(split == "test");
fprintf('Recordings: train %d, val %d, test %d; %d features. Feature time %.0f s.\n', ...
    numel(ytr), numel(yva), numel(yte), size(X, 2), featureSeconds);

summaryParts = {};
perClassParts = {};
for method = opts.Methods
    fprintf('--- %s ---\n', method);
    tTune = tic;
    [params, grid] = dsp.tuneClassifier(method, Xtr, ytr, Xva, yva, opts.Seed);
    tuneSeconds = toc(tTune);
    writetable(grid, fullfile(outDir, sprintf('%s_tuning_%s.csv', opts.Name, method)));
    fprintf('Chosen on validation: %s\n', dsp.describeParams(params));

    tTrain = tic;
    model = dsp.trainClassifier(Xtr, ytr, method, params, opts.Seed);
    trainSeconds = toc(tTrain);

    evalSets = {"val", Xva, yva};
    if opts.UseTest
        evalSets(2, :) = {"test", Xte, yte};
    end
    for e = 1:size(evalSets, 1)
        name = evalSets{e, 1};
        tPred = tic;
        yhat = dsp.predictClassifier(model, evalSets{e, 2});
        predictMs = 1000 * toc(tPred) / numel(yhat);
        m = dsp.classificationMetrics(evalSets{e, 3}, yhat, classes);
        fprintf('%s %s: accuracy %.3f, macro-F1 %.3f\n', method, name, m.accuracy, m.macroF1);

        summaryParts{end+1} = table(opts.Name, method, name, string(dsp.describeParams(params)), numel(yhat), ...
            m.accuracy, m.macroPrecision, m.macroRecall, m.macroF1, trainSeconds, tuneSeconds, predictMs, ...
            'VariableNames', {'experiment', 'method', 'split', 'params', 'recordings', 'accuracy', ...
            'macroPrecision', 'macroRecall', 'macroF1', 'trainSeconds', 'tuneSeconds', 'predictMsPerRecording'}); %#ok<AGROW>
        perClassParts{end+1} = table(repmat(method, numel(classes), 1), repmat(name, numel(classes), 1), ...
            classNames(:), m.precision, m.recall, m.f1, m.support, ...
            'VariableNames', {'method', 'split', 'activity', 'precision', 'recall', 'f1', 'support'}); %#ok<AGROW>
        cmTable = array2table(m.confusion, 'VariableNames', cellstr("pred_" + replace(classNames(:)', " ", "_")), ...
            'RowNames', cellstr("true_" + replace(classNames(:), " ", "_")));
        writetable(cmTable, fullfile(outDir, sprintf('%s_confusion_%s_%s.csv', opts.Name, method, name)), 'WriteRowNames', true);
    end

    if opts.SaveModel
        dsp.saveModel(model, s, string(fullfile(modelDir, sprintf('%s_%s.mat', opts.Name, method))));
    end
end

summary = vertcat(summaryParts{:});
perClass = vertcat(perClassParts{:});
writetable(summary, fullfile(outDir, sprintf('%s_summary.csv', opts.Name)));
writetable(perClass, fullfile(outDir, sprintf('%s_perclass.csv', opts.Name)));
dsp.writeRunMetadata(string(fullfile(outDir, sprintf('%s_run', opts.Name))), s, ...
    struct('experiment', opts.Name, 'methods', opts.Methods, 'useTest', opts.UseTest, ...
    'recordings', struct('train', numel(ytr), 'val', numel(yva), 'test', numel(yte))));
disp(summary(:, {'method', 'split', 'params', 'accuracy', 'macroF1', 'trainSeconds', 'predictMsPerRecording'}));
disp(perClass(perClass.split == "val", :));
results = struct('summary', summary, 'perClass', perClass);
end
