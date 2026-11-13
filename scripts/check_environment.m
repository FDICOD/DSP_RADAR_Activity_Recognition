function check_environment()
% CHECK_ENVIRONMENT Record the MATLAB release and installed toolboxes.
%   Writes results/environment.txt and prints it, for report/notes.md.

root = fileparts(fileparts(mfilename('fullpath')));
outDir = fullfile(root, 'results');
if ~isfolder(outDir)
    mkdir(outDir);
end

v = ver; %#ok<VERUSE>
lines = strings(0, 1);
lines(end+1) = "MATLAB release: " + string(version('-release'));
lines(end+1) = "MATLAB version: " + string(version);
lines(end+1) = "Computer: " + string(computer);
lines(end+1) = "";
lines(end+1) = "Products:";
for k = 1:numel(v)
    lines(end+1) = "  " + string(v(k).Name) + "  " + string(v(k).Version); %#ok<AGROW>
end

needed = ["Signal Processing Toolbox", "Statistics and Machine Learning Toolbox"];
lines(end+1) = "";
lines(end+1) = "Required toolboxes:";
for k = 1:numel(needed)
    present = any(strcmp({v.Name}, needed(k)));
    lines(end+1) = "  " + needed(k) + ": " + string(present); %#ok<AGROW>
end

text = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'environment.txt'), 'w');
fprintf(fid, '%s\n', text);
fclose(fid);
disp(text);
end
