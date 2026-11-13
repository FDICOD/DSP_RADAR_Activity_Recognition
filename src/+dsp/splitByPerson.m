function T = splitByPerson(T, s)
%SPLITBYPERSON Assign every person to train, val or test and add a split column.
%   T is the table from dsp.listRecordings. All recordings of one person get the
%   same split, so no person appears in two splits. People are placed greedily
%   (rare-class holders first), each time choosing the split whose class counts move
%   closest to their targets, so every class is spread across the splits in the
%   configured proportions as far as the data allows. The result depends only on
%   the data and s.seed. Excluded recordings get split "".
%
%   Warns with id dsp:split:missingClass if a class is absent from a split.
arguments
    T table
    s (1,1) struct = dsp.makeSettings()
end

names = ["train"; "val"; "test"];
frac = [s.split.train; s.split.val; s.split.test];

inc = T.included;
persons = unique(T.person(inc));
nP = numel(persons);
if nP < 3
    error('dsp:split:tooFewPeople', ...
        'Need at least 3 people to make train, val and test splits; found %d.', nP);
end

classes = unique(T.activityCode(inc));
classes = classes(:)';
nC = numel(classes);

counts = zeros(nP, nC);
for p = 1:nP
    rowsOfPerson = inc & T.person == persons(p);
    for c = 1:nC
        counts(p, c) = sum(rowsOfPerson & T.activityCode == classes(c));
    end
end
total = sum(counts, 1);
target = frac * total;

stream = RandStream('mt19937ar', 'Seed', s.seed);
order = randperm(stream, nP);
rarity = sum(counts ./ max(total, 1), 2);
[~, byRarity] = sort(rarity(order), 'descend');
order = order(byRarity);
order = order(:)';

current = zeros(3, nC);
assignment = zeros(nP, 1);
for p = order
    bestCost = Inf;
    bestSplit = 1;
    for k = 1:3
        t = max(target(k, :), 1);
        cost = sum(((current(k, :) + counts(p, :) - t) .^ 2 - (current(k, :) - t) .^ 2) ./ t);
        if cost < bestCost
            bestCost = cost;
            bestSplit = k;
        end
    end
    assignment(p) = bestSplit;
    current(bestSplit, :) = current(bestSplit, :) + counts(p, :);
end

for k = 1:3
    if ~any(assignment == k)
        error('dsp:split:emptySplit', 'The %s split received no people; use more people or other fractions.', names(k));
    end
end

T.split = strings(height(T), 1);
[found, loc] = ismember(T.person, persons);
use = found & inc;
T.split(use) = names(assignment(loc(use)));

for c = 1:nC
    for k = 1:3
        if current(k, c) == 0
            warning('dsp:split:missingClass', 'Activity code %d has no recordings in the %s split.', ...
                classes(c), names(k));
        end
    end
end
end
