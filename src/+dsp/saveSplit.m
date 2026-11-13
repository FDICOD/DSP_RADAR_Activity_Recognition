function saveSplit(T, file)
%SAVESPLIT Write the person-to-split assignment as CSV so it can be reused.
file = char(file);
use = T.included & T.split ~= "";
[persons, firstRow] = unique(T.person(use));
splitOf = T.split(use);
A = table(persons, splitOf(firstRow), 'VariableNames', {'person', 'split'});
folder = fileparts(file);
if ~isempty(folder) && ~isfolder(folder)
    mkdir(folder);
end
writetable(A, file, 'FileType', 'text', 'Delimiter', ',');
end
