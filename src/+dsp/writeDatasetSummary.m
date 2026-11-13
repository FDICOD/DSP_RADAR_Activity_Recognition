function text = writeDatasetSummary(T, s, outFile, includeHeaders)
%WRITEDATASETSUMMARY Describe the dataset and split, and save it as a text file.
%   Lists file counts, excluded files with reasons, people per session,
%   recordings per activity and split, and (for converted .mat files, when
%   includeHeaders is true) the radar parameters and recording lengths found.
arguments
    T table
    s (1,1) struct
    outFile (1,1) string
    includeHeaders (1,1) logical = true
end

fmt = @(varargin) string(sprintf(varargin{:}));
L = strings(1, 0);
L(end+1) = "Dataset summary";
L(end+1) = "Root: " + string(s.data.root);
L(end+1) = "Format: " + string(s.data.format) + " (raw recordings only)";
L(end+1) = fmt("Files found: %d (included %d, excluded %d)", height(T), sum(T.included), sum(~T.included));
L(end+1) = "";

L(end+1) = "Activity-code mapping used:";
for k = 1:numel(s.activity.codeNames)
    L(end+1) = fmt("  %d = %s", k, s.activity.codeNames(k)); %#ok<AGROW>
end
L(end+1) = "";

excluded = T(~T.included, :);
L(end+1) = fmt("Excluded files (%d):", height(excluded));
for k = 1:height(excluded)
    L(end+1) = "  " + excluded.session(k) + " / " + excluded.name(k) + " : " + excluded.reason(k); %#ok<AGROW>
end
L(end+1) = "";

inc = T(T.included, :);
sessions = unique(inc.session);
sessionTable = table(sessions, zeros(numel(sessions), 1), zeros(numel(sessions), 1), ...
    'VariableNames', {'session', 'files', 'people'});
for k = 1:numel(sessions)
    rows = inc.session == sessions(k);
    sessionTable.files(k) = sum(rows);
    sessionTable.people(k) = numel(unique(inc.person(rows)));
end
L(end+1) = "Included recordings per session:";
L = [L, asLines(evalc('disp(sessionTable)'))];
L(end+1) = fmt("People overall (after merging): %d", numel(unique(inc.person)));
L(end+1) = "";

if ismember('split', T.Properties.VariableNames)
    L(end+1) = "Recordings per activity and split:";
    L = [L, asLines(evalc('disp(dsp.splitSummary(T))'))];
    peoplePerSplit = zeros(1, 3);
    splitNames = ["train" "val" "test"];
    for k = 1:3
        peoplePerSplit(k) = numel(unique(inc.person(T.split(T.included) == splitNames(k))));
    end
    L(end+1) = fmt("People per split: train %d, val %d, test %d", peoplePerSplit);
    L(end+1) = "";
end

if includeHeaders && string(s.data.format) == "mat" && height(inc) > 0
    n = height(inc);
    P = zeros(n, 5);
    for k = 1:n
        h = dsp.readConvertedHeader(inc.file(k));
        P(k, :) = [h.carrierHz h.chirpDurationMs h.samplesPerChirp h.bandwidthHz h.durationSeconds];
    end
    [combos, ~, g] = unique(P(:, 1:4), 'rows');
    L(end+1) = "Radar parameters found (carrier Hz, chirp ms, samples per chirp, bandwidth Hz):";
    for k = 1:size(combos, 1)
        L(end+1) = fmt("  %g, %g, %g, %g : %d files", combos(k, :), sum(g == k)); %#ok<AGROW>
    end
    [lens, ~, g2] = unique(P(:, 5));
    L(end+1) = "Recording lengths (seconds):";
    for k = 1:numel(lens)
        L(end+1) = fmt("  %g s : %d files", lens(k), sum(g2 == k)); %#ok<AGROW>
    end
end

text = strjoin(L, newline);
folder = fileparts(outFile);
if strlength(folder) > 0 && ~isfolder(folder)
    mkdir(folder);
end
fid = fopen(outFile, 'w');
if fid < 0
    error('dsp:writeDatasetSummary:cannotWrite', 'Cannot write %s.', outFile);
end
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
end

function lines = asLines(text)
% Split text at line breaks into a row of strings.
lines = reshape(splitlines(string(strtrim(text))), 1, []);
end
