function bundle = loadModel(file)
%LOADMODEL Load a bundle written by dsp.saveModel.
file = char(file);
if ~isfile(file)
    error('dsp:loadModel:notFound', 'Model file not found: %s', file);
end
S = load(file, 'bundle');
if ~isfield(S, 'bundle')
    error('dsp:loadModel:badFile', 'File %s is not a saved model bundle.', file);
end
bundle = S.bundle;
end
