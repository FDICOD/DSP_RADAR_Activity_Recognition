function rec = readDat(path)
%READDAT Read one original Glasgow text recording (.dat).
%   The file has four header lines (carrier frequency in Hz, chirp duration in
%   ms, samples per chirp, bandwidth in Hz) followed by one sample per line
%   written as I+Qi, for example 1812+1897i.
path = char(path);
if ~isfile(path)
    error('dsp:readDat:fileNotFound', 'File not found: %s', path);
end

txt = fileread(path);
nl = find(txt == newline, 4);
if numel(nl) < 4
    error('dsp:readDat:badHeader', 'File %s has fewer than four header lines.', path);
end
head = sscanf(txt(1:nl(4)), '%f');
if numel(head) ~= 4
    error('dsp:readDat:badHeader', 'The first four lines of %s are not four numbers.', path);
end

body = txt(nl(4)+1:end);
body(body == 'i') = ' ';
vals = sscanf(body, '%f');
if mod(numel(vals), 2) ~= 0
    error('dsp:readDat:oddValueCount', 'File %s has an odd number of sample values.', path);
end

rec = dsp.makeRecording(head(1), head(2), head(3), head(4), vals(1:2:end), vals(2:2:end));
end
