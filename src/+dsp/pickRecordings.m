function pick = pickRecordings(T, split, perClass, seed)
%PICKRECORDINGS A reproducible sample of recordings from one split, balanced over activities.
%   pick = dsp.pickRecordings(T, "val", 5, seed)
%   T is the table from dsp.splitByPerson. For each activity code present in the
%   split, up to perClass included recordings are drawn at random (seeded,
%   without touching the global random state). Used by experiments that tune on
%   the validation split.
arguments
    T table
    split (1,1) string
    perClass (1,1) double {mustBePositive, mustBeInteger}
    seed (1,1) double {mustBeNonnegative, mustBeInteger}
end
rows = T.included & T.split == split;
if ~any(rows)
    error('dsp:pick:noRecordings', 'No included recordings in the "%s" split.', split);
end
stream = RandStream('mt19937ar', 'Seed', seed);
codes = unique(T.activityCode(rows));
chosen = false(height(T), 1);
for c = codes'
    idx = find(rows & T.activityCode == c);
    take = idx(randperm(stream, numel(idx), min(perClass, numel(idx))));
    chosen(take) = true;
end
pick = T(chosen, :);
end
