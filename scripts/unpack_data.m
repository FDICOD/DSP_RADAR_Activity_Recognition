function unpack_data()
% UNPACK_DATA Unzip the uploaded session zips into data/converted.
%   Put the *_Dataset.zip files in the project's data folder first, then run this.
%   Existing session folders are overwritten. Delete the zips afterwards to free
%   MATLAB Drive space if needed.

dataDir = fullfile(dsp.projectRoot(), 'data');
target = fullfile(dataDir, 'converted');
if ~isfolder(target)
    mkdir(target);
end

zips = dir(fullfile(dataDir, '*.zip'));
if isempty(zips)
    error('unpack_data:noZips', 'No .zip files found in %s. Upload the session zips there first.', dataDir);
end

for k = 1:numel(zips)
    fprintf('Unpacking %s (%d of %d)...\n', zips(k).name, k, numel(zips));
    unzip(fullfile(zips(k).folder, zips(k).name), target);
end

sessions = dir(target);
sessions = sessions([sessions.isdir] & ~startsWith({sessions.name}, '.'));
for k = 1:numel(sessions)
    n = numel(dir(fullfile(target, sessions(k).name, '*.mat')));
    fprintf('  %-40s %4d files\n', sessions(k).name, n);
end
end
