function S = splitSummary(T)
%SPLITSUMMARY Number of recordings per activity in each split.
%   S has one row per activity code with columns train, val, test and total.
use = T.included & T.split ~= "";
codes = unique(T.activityCode(use));
codes = codes(:);

counts = zeros(numel(codes), 3);
labels = strings(numel(codes), 1);
splitNames = ["train" "val" "test"];
for c = 1:numel(codes)
    rows = use & T.activityCode == codes(c);
    labels(c) = T.activity(find(rows, 1));
    for k = 1:3
        counts(c, k) = sum(rows & T.split == splitNames(k));
    end
end
S = table(codes, labels, counts(:, 1), counts(:, 2), counts(:, 3), sum(counts, 2), ...
    'VariableNames', {'activityCode', 'activity', 'train', 'val', 'test', 'total'});
end
