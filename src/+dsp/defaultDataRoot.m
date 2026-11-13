function root = defaultDataRoot()
%DEFAULTDATAROOT Folder holding the converted recordings.
%   Uses the local copy made by stage_data (fast, and not affected by cloud-drive
%   read problems) when it is complete, otherwise data/converted in the project.
%   The folder actually used is stored in every run's metadata (settings.data.root).
staged = fullfile(tempdir, 'dsp_data');
if isfile(fullfile(staged, 'READY')) && isfolder(fullfile(staged, 'converted'))
    root = fullfile(staged, 'converted');
else
    root = fullfile(dsp.projectRoot(), 'data', 'converted');
end
end
