function T = listRecordings(s)
%LISTRECORDINGS Catalogue every recording under s.data.root without loading samples.
%   T = dsp.listRecordings(settings) scans each session folder for files with the
%   configured extension and returns one row per file with variables:
%     session, file, name, subject, person, activityCode, activity,
%     repetition, included, reason
%   person identifies a person as "session|subject" after applying
%   s.split.mergeGroups. Files that do not match the naming pattern, have
%   inconsistent digits, or have an unknown activity code get included = false
%   and a reason, and are listed rather than silently dropped.
arguments
    s (1,1) struct = dsp.makeSettings()
end

root = string(s.data.root);
if ~isfolder(root)
    error('dsp:listRecordings:noData', ...
        ['Dataset folder not found: %s\n' ...
         'Download and convert the Glasgow data first (see README.md, section "Data").'], root);
end
ext = "." + string(s.data.format);
codeNames = s.activity.codeNames(:);

entries = dir(root);
entries = entries([entries.isdir]);
sessionNames = string({entries.name});
sessionNames = sort(sessionNames(~startsWith(sessionNames, ".")));

rows = {};
for si = 1:numel(sessionNames)
    session = sessionNames(si);
    files = dir(fullfile(root, session, "*" + ext));
    files = files(~[files.isdir]);
    fileNames = sort(string({files.name}));
    fileNames = fileNames(~startsWith(fileNames, "."));
    for fi = 1:numel(fileNames)
        info = dsp.parseFileName(fileNames(fi));
        included = info.valid;
        reason = info.reason;
        activity = "";
        if info.valid
            code = info.activityCode;
            if code >= 1 && code <= numel(codeNames) && code == round(code)
                activity = codeNames(code);
            else
                included = false;
                reason = "unknown_activity_code";
            end
        end
        rows{end+1} = struct( ... %#ok<AGROW>
            'session', session, ...
            'file', string(fullfile(root, session, fileNames(fi))), ...
            'name', info.stem, ...
            'subject', info.subject, ...
            'person', session + "|" + info.subject, ...
            'activityCode', info.activityCode, ...
            'activity', activity, ...
            'repetition', info.repetition, ...
            'included', included, ...
            'reason', reason);
    end
end

if isempty(rows)
    T = table('Size', [0 10], ...
        'VariableTypes', ["string" "string" "string" "string" "string" "double" "string" "double" "logical" "string"], ...
        'VariableNames', ["session" "file" "name" "subject" "person" "activityCode" "activity" "repetition" "included" "reason"]);
    return
end

T = struct2table(vertcat(rows{:}));
T.person = mergePeople(T.person, s.split.mergeGroups);
end

function person = mergePeople(person, groups)
for k = 1:numel(groups)
    g = groups{k};
    keys = g(:, 1) + "|" + g(:, 2);
    person(ismember(person, keys(2:end))) = keys(1);
end
end
