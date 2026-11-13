function file = writeRunMetadata(runDir, s, extra)
%WRITERUNMETADATA Save settings, seed and software versions as metadata.json.
%   file = dsp.writeRunMetadata(runDir, settings) creates runDir if needed and
%   returns the path of the metadata.json it wrote. extra is an optional struct
%   of additional values to store (for example the STFT window length).
arguments
    runDir (1,1) string
    s (1,1) struct
    extra (1,1) struct = struct()
end
if ~isfolder(runDir)
    mkdir(runDir);
end

v = ver; %#ok<VERUSE>
wanted = ["MATLAB" "Signal Processing Toolbox" "Statistics and Machine Learning Toolbox" "Deep Learning Toolbox"];
tb = struct('name', {}, 'version', {});
for k = 1:numel(wanted)
    idx = find(strcmp({v.Name}, wanted(k)), 1);
    if ~isempty(idx)
        tb(end+1) = struct('name', wanted(k), 'version', string(v(idx).Version)); %#ok<AGROW>
    end
end

meta.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
meta.seed = s.seed;
meta.matlabRelease = string(version('-release'));
meta.matlabVersion = string(version);
meta.computer = string(computer);
meta.toolboxes = tb;
meta.settings = s;
meta.extra = extra;

file = fullfile(runDir, 'metadata.json');
fid = fopen(file, 'w');
if fid < 0
    error('dsp:writeRunMetadata:cannotWrite', 'Cannot write %s.', file);
end
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true));
end
