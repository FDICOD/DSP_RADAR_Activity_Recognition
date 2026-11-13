function F = featureTable(T, s, opts)
%FEATURETABLE Feature vectors for every included recording, with a restartable cache.
%   F = dsp.featureTable(T, settings)
%   F = dsp.featureTable(T, settings, CacheFile="results/cache/features.mat")
%   F = dsp.featureTable(T, settings, SnrDb=5, NoiseSeed=1)
%
%   T is the recording table with a split column (dsp.splitByPerson). For each
%   included recording with a split: read it, optionally add noise to the raw
%   samples, run the whole front end (dsp.spectrogramOf) and extract features.
%   A recording that cannot be processed is recorded as failed and the others
%   continue, so one unreadable file never stops a long run.
%
%   With CacheFile, finished recordings are saved every SaveEvery recordings and
%   at the end, and a later call with the SAME settings (range, preprocessing,
%   STFT, features, SNR and noise seed) reuses them. An interrupted run (for
%   example a MATLAB Online session timing out) therefore resumes where it
%   stopped, and a cache made with different settings is ignored. Noise for
%   recording r uses seed NoiseSeed + r, so it does not depend on which other
%   recordings are processed.
%
%   Fields of F: X (recordings-by-features, NaN for failed), names, row (index
%   into T), ids ("session/name"), ok, message.
arguments
    T table
    s (1,1) struct
    opts.SnrDb (1,1) double = Inf
    opts.NoiseSeed (1,1) double = 1
    opts.CacheFile (1,1) string = ""
    opts.SaveEvery (1,1) double = 50
    opts.Verbose (1,1) logical = true
end

rows = find(T.included & T.split ~= "");
n = numel(rows);
ids = T.session(rows) + "/" + T.name(rows);
key = cacheKey(s, opts);
X = [];
names = strings(1, 0);
ok = false(n, 1);
message = strings(n, 1);

if opts.CacheFile ~= "" && isfile(opts.CacheFile)
    C = load(opts.CacheFile);
    if isfield(C, 'key') && string(C.key) == key
        [found, loc] = ismember(ids, string(C.ids));
        if any(found)
            names = string(C.names);
            X = nan(n, numel(names));
            X(found, :) = C.X(loc(found), :);
            ok(found) = true;
            if opts.Verbose
                fprintf('Features: %d of %d recordings found in the cache.\n', nnz(found), n);
            end
        end
    elseif opts.Verbose
        fprintf('Features: the cache was made with different settings and is ignored.\n');
    end
end

todo = find(~ok)';
for j = 1:numel(todo)
    k = todo(j);
    r = rows(k);
    try
        rec = dsp.readConverted(T.file(r));
        if isfinite(opts.SnrDb)
            rec = dsp.addNoise(rec, opts.SnrDb, opts.NoiseSeed + r);
        end
        sp = dsp.spectrogramOf(rec, s);
        [x, nm] = dsp.extractFeatures(sp, s);
        if isempty(X)
            X = nan(n, numel(x));
            names = nm;
        end
        X(k, :) = x;
        ok(k) = true;
    catch err
        message(k) = string(err.message);
    end
    if opts.Verbose && mod(j, 100) == 0
        fprintf('Features: %d of %d recordings processed (%d failed so far).\n', j, numel(todo), nnz(~ok(todo(1:j))));
    end
    if opts.CacheFile ~= "" && mod(j, opts.SaveEvery) == 0
        saveCache(opts.CacheFile, key, ids, names, X, ok);
    end
end
if isempty(X)
    X = nan(n, 0);
end
if opts.CacheFile ~= ""
    saveCache(opts.CacheFile, key, ids, names, X, ok);
end

F.X = X;
F.names = names;
F.row = rows;
F.ids = ids;
F.ok = ok;
F.message = message;
if opts.Verbose && any(~ok)
    fprintf('Features: %d recordings failed; first reason: %s\n', nnz(~ok), message(find(~ok, 1)));
end
end

function key = cacheKey(s, opts)
k = struct('version', 1, 'range', s.range, 'clutter', s.clutter, 'denoise', s.denoise, ...
    'normalize', s.normalize, 'stft', s.stft, 'features', s.features, ...
    'snr', sprintf('%g', opts.SnrDb), 'noiseSeed', opts.NoiseSeed);
key = string(jsonencode(k));
end

function saveCache(file, key, ids, names, X, ok)
C.key = key;
C.ids = ids(ok);
C.names = names;
C.X = X(ok, :);
folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder)
    mkdir(folder);
end
save(file, '-struct', 'C');
end
