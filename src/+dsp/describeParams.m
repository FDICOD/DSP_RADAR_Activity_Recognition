function text = describeParams(params)
%DESCRIBEPARAMS One-line text for a classifier's parameters, for example "C=10".
names = fieldnames(params);
parts = strings(1, numel(names));
for k = 1:numel(names)
    parts(k) = string(names{k}) + "=" + string(params.(names{k}));
end
if isempty(parts)
    text = "default";
else
    text = strjoin(parts, ", ");
end
end
