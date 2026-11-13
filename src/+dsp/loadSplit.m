function T = loadSplit(T, file)
%LOADSPLIT Apply a saved person-to-split assignment to a recording table.
file = char(file);
A = readtable(file, 'FileType', 'text', 'Delimiter', ',', 'TextType', 'string');
savedPersons = string(A.person);
savedSplits = string(A.split);

T.split = strings(height(T), 1);
idx = find(T.included);
[found, loc] = ismember(T.person(idx), savedPersons);
if ~all(found)
    unknown = T.person(idx(~found));
    error('dsp:split:unknownPerson', 'Person %s is not in the saved split %s.', unknown(1), file);
end
T.split(idx) = savedSplits(loc);
end
