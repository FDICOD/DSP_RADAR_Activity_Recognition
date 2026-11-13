function info = parseFileName(name)
%PARSEFILENAME Read activity, subject and repetition from a Glasgow file name.
%   Names look like 1P05A01R1 or 1P36A01R01: leading digit, P and subject
%   number, A and activity code, R and repetition. Fields may have one or two
%   digits. The activity is taken from the code after A.
%
%   info.valid is false when the name does not match (info.reason is
%   "name_not_matching", for example hand-made copies named "... (2)") or when
%   the leading digit differs from the activity code ("inconsistent_digits").
[~, stem] = fileparts(char(name));

info = struct('stem', string(stem), 'valid', false, 'reason', "name_not_matching", ...
    'leadingDigit', NaN, 'subject', "", 'activityCode', NaN, 'repetition', NaN);

tok = regexp(stem, '^(\d)P(\d+)A(\d+)R(\d+)$', 'tokens', 'once', 'ignorecase');
if isempty(tok)
    return
end

info.leadingDigit = str2double(tok{1});
info.subject = "P" + string(tok{2});
info.activityCode = str2double(tok{3});
info.repetition = str2double(tok{4});

if info.leadingDigit ~= info.activityCode
    info.reason = "inconsistent_digits";
    return
end
info.valid = true;
info.reason = "ok";
end
