function bad = check_data_integrity()
% CHECK_DATA_INTEGRITY Find converted recordings that cannot be read.
%   bad = check_data_integrity
%   Opens the header of every converted .mat under data/converted (about a minute)
%   and lists files that cannot be read or have an unexpected header. A file that
%   MATLAB Drive has damaged or not finished syncing shows up here; re-upload the
%   zip of its session and run unpack_data to replace it.

s = dsp.makeSettings();
T = dsp.listRecordings(s);
n = height(T);
ok = true(n, 1);
message = strings(n, 1);
for k = 1:n
    try
        h = dsp.readConvertedHeader(T.file(k));
        if h.samplesPerChirp ~= 128 || h.carrierHz ~= 5.8e9 || h.numSamples < 5000
            error('check:header', 'unexpected header (nts %g, fc %g, %d samples)', ...
                h.samplesPerChirp, h.carrierHz, h.numSamples);
        end
    catch err
        ok(k) = false;
        message(k) = string(err.message);
    end
    if mod(k, 250) == 0
        fprintf('  checked %d of %d\n', k, n);
    end
end

bad = T(~ok, {'session', 'name', 'file'});
bad.message = message(~ok);
fprintf('%d of %d converted files are readable.\n', nnz(ok), n);
if isempty(bad)
    fprintf('No damaged files found.\n');
else
    fprintf('Damaged files:\n');
    disp(bad(:, {'session', 'name', 'message'}));
    fprintf('Sessions to re-upload: %s\n', strjoin(unique(bad.session), '; '));
end
end
