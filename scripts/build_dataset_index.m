function T = build_dataset_index(dataRoot)
% BUILD_DATASET_INDEX Catalogue the recordings, split them by person and write a summary.
%   build_dataset_index                % uses the data folder in the default settings
%   build_dataset_index('/path/to/converted')
%   Writes recordings.csv, split.csv, summary.txt and metadata.json to
%   results/dataset/ and prints the summary.

s = dsp.makeSettings();
if nargin > 0
    s.data.root = dataRoot;
end
dsp.setSeed(s.seed);

T = dsp.listRecordings(s);
T = dsp.splitByPerson(T, s);

outDir = fullfile(dsp.projectRoot(), 'results', 'dataset');
if ~isfolder(outDir)
    mkdir(outDir);
end
writetable(T, fullfile(outDir, 'recordings.csv'));
dsp.saveSplit(T, fullfile(outDir, 'split.csv'));
text = dsp.writeDatasetSummary(T, s, string(fullfile(outDir, 'summary.txt')));
dsp.writeRunMetadata(string(outDir), s);

disp(text);
fprintf('\nWritten to %s\n', outDir);
end
