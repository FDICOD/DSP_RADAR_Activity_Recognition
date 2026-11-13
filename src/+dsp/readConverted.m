function rec = readConverted(path)
%READCONVERTED Read one compact converted recording (.mat).
%   The file holds I and Q (unsigned 16-bit), and the header values fc, Tc_ms,
%   nts and bw, as written by tools/convert_dat_to_mat.py. The result matches
%   dsp.readDat on the original text file.
path = char(path);
if ~isfile(path)
    error('dsp:readConverted:fileNotFound', 'File not found: %s', path);
end

S = [];
attempts = 4;
for attempt = 1:attempts
    try
        S = load(path);
        break
    catch err
        if attempt < attempts
            pause(2 ^ (attempt - 1));   % 1, 2, 4 s: a cloud drive can briefly return an unreadable file
            continue
        end
        info = dir(path);
        fid = fopen(path, 'r');
        head = '';
        if fid > 0
            head = fread(fid, 20, '*char')';
            fclose(fid);
        end
        head = regexprep(head, '[^\x20-\x7E]', '?');
        error('dsp:readConverted:unreadable', ...
            'Cannot read %s as a MAT-file (%d bytes on disk, starts with "%s"; a good file starts with "MATLAB 5.0 MAT-file"): %s', ...
            path, info.bytes, head, err.message);
    end
end
required = {'I', 'Q', 'fc', 'Tc_ms', 'nts', 'bw'};
for k = 1:numel(required)
    if ~isfield(S, required{k})
        error('dsp:readConverted:missingField', 'File %s is missing field %s.', path, required{k});
    end
end
rec = dsp.makeRecording(S.fc, S.Tc_ms, S.nts, S.bw, S.I, S.Q);
end
