function bad = check_data_sizes(dataRoot)
% CHECK_DATA_SIZES Quick check that every converted file is present and the right size.
%   bad = check_data_sizes
%   Compares the size on disk of every file under data/converted with the size it
%   should have (data/converted_sizes.csv, made from the original converted files).
%   It only lists folders, so it takes seconds. A missing, truncated or empty file
%   means MATLAB Drive has not finished syncing it or has damaged it: re-upload the
%   zip of that session and run unpack_data.
arguments
    dataRoot (1,1) string = string(fullfile(dsp.projectRoot(), 'data'))
end

refFile = fullfile(dataRoot, 'converted_sizes.csv');
if ~isfile(refFile)
    error('check_data_sizes:noReference', ...
        'Reference sizes not found: %s. Upload converted_sizes.csv into the data folder.', refFile);
end
ref = readtable(refFile, 'FileType', 'text', 'Delimiter', ',', 'TextType', 'string');

status = strings(height(ref), 1);
found = zeros(height(ref), 1);
for session = unique(ref.session)'
    d = dir(fullfile(dataRoot, 'converted', session));
    names = string({d.name});
    bytes = [d.bytes];
    for r = find(ref.session == session)'
        i = find(names == ref.file(r), 1);
        if isempty(i)
            status(r) = "missing";
        else
            found(r) = bytes(i);
            if bytes(i) == ref.bytes(r)
                status(r) = "ok";
            else
                status(r) = "wrong size";
            end
        end
    end
end

report = table(ref.session, ref.file, ref.bytes, found, status, ...
    'VariableNames', {'session', 'file', 'expectedBytes', 'foundBytes', 'status'});
bad = report(report.status ~= "ok", :);
fprintf('%d of %d converted files have the right size.\n', nnz(report.status == "ok"), height(report));
if isempty(bad)
    fprintf('No missing or damaged files.\n');
else
    fprintf('Problem files (%d):\n', height(bad));
    disp(bad(1:min(25, height(bad)), :));
    fprintf('Sessions to re-upload: %s\n', strjoin(unique(bad.session), '; '));
end
end
