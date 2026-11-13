function failed = stage_data(opts)
% STAGE_DATA Copy the converted recordings to the session's local disk.
%   stage_data
%   Reading 1,750 files straight from MATLAB Drive sometimes fails for single files.
%   This copies data/converted to local storage (tempdir/dsp_data) once per MATLAB
%   Online session, retrying each file and checking its size against
%   data/converted_sizes.csv, and writes a READY marker when every file is correct.
%   After that every script reads the local copy automatically (dsp.defaultDataRoot).
%   Files already copied correctly are skipped, so it can be run again after an
%   interruption. The local copy disappears when the session ends; run stage_data
%   again in the next session (a few minutes). Returns a table of failed files.
arguments
    opts.Source (1,1) string = string(fullfile(dsp.projectRoot(), 'data', 'converted'))
    opts.Reference (1,1) string = string(fullfile(dsp.projectRoot(), 'data', 'converted_sizes.csv'))
    opts.Target (1,1) string = string(fullfile(tempdir, 'dsp_data'))
    opts.Attempts (1,1) double = 4
end

if ~isfile(opts.Reference)
    error('stage_data:noReference', 'Reference sizes not found: %s. Upload converted_sizes.csv into the data folder.', opts.Reference);
end
ref = readtable(opts.Reference, 'FileType', 'text', 'Delimiter', ',', 'TextType', 'string');

marker = fullfile(opts.Target, 'READY');
if isfile(marker)
    delete(marker);          % a partial copy must never be used
end

n = height(ref);
bad = false(n, 1);
reason = strings(n, 1);
copied = 0;
skipped = 0;
for k = 1:n
    dest = fullfile(opts.Target, 'converted', ref.session(k), ref.file(k));
    if sizeOf(dest) == ref.bytes(k)
        skipped = skipped + 1;
    else
        if ~isfolder(fileparts(dest))
            mkdir(fileparts(dest));
        end
        ok = false;
        for attempt = 1:opts.Attempts
            [status, msg] = copyfile(fullfile(opts.Source, ref.session(k), ref.file(k)), dest);
            if status && sizeOf(dest) == ref.bytes(k)
                ok = true;
                break
            end
            reason(k) = string(msg);
            pause(2 ^ (attempt - 1));
        end
        if ok
            copied = copied + 1;
        else
            bad(k) = true;
        end
    end
    if mod(k, 200) == 0
        fprintf('  %d of %d (copied %d, already there %d, failed %d)\n', k, n, copied, skipped, nnz(bad));
    end
end

failed = table(ref.session(bad), ref.file(bad), reason(bad), 'VariableNames', {'session', 'file', 'reason'});
if isempty(failed)
    fid = fopen(marker, 'w');
    fprintf(fid, '%s\n', char(datetime('now')));
    fclose(fid);
    fprintf('Staged %d files (%d copied, %d already there) to %s\n', n, copied, skipped, opts.Target);
    fprintf('All scripts now read the local copy.\n');
else
    fprintf('%d files could not be copied correctly; the local copy is NOT used yet. Run stage_data again.\n', height(failed));
    disp(failed(1:min(10, height(failed)), :));
end
end

function b = sizeOf(file)
d = dir(file);
if isempty(d)
    b = -1;
else
    b = d(1).bytes;
end
end
