% Adds the project source folders to the MATLAB path.
% Run once per session from the project root (MATLAB runs this automatically
% when started in this folder).
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'tests'));
clear root
