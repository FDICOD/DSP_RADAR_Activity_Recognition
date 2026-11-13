function s = defaultSettings()
%DEFAULTSETTINGS Default settings for every stage of the pipeline.
%   Change values through dsp.makeSettings(overrides), which rejects unknown keys.

s.seed = 1;

s.data.root = dsp.defaultDataRoot();
s.data.format = 'mat';

% Activity code (the number after the letter A in a file name) to name.
% The data sheet and the authors' example script disagree on codes 4 and 5;
% this is the data sheet's order. It is checked against the data in task 6.4.
s.activity.codeNames = ["walking"; "sitting down"; "standing up"; ...
    "picking up an object"; "drinking"; "falling"];

% Range processing (FMCW front end). Windows: "rect", "hann" or "hamming".
% intervalMetres selects range bins for the Doppler stage when selection is
% "fixed" (the default [3.7 11.3] m is bins 10-30, as in the dataset authors'
% example). With "auto", the bins around the strongest moving return are used:
% those whose energy is at least autoThreshold of the peak, up to autoMaxBins,
% ignoring ranges below autoMinMetres.
s.range.window = 'rect';
s.range.padFactor = 1;
s.range.intervalMetres = [3.7 11.3];
s.range.selection = 'fixed';
s.range.autoMinMetres = 1.0;
s.range.autoThreshold = 0.1;
s.range.autoMaxBins = 41;

% Preprocessing, applied in this order: clutter removal, optional denoising,
% amplitude normalisation. Each step can be switched off ("none").
%   clutter.method: "none", "mean" (subtract each bin's mean over time),
%     "highpass" (mean subtraction plus a Butterworth high-pass along slow time,
%     like the dataset authors' MTI filter; 3.75 Hz at a 1 kHz pulse rate), or
%     "canceller" (two-pulse canceller y[n] = x[n] - x[n-1]).
%   denoise.method: "none" or "lowpass" (Butterworth low-pass along slow time,
%     keeping the Doppler band of human motion).
%   normalize.mode: "none", "segment" (scale each recording to unit RMS over the
%     selected range bins) or "global" (divide by a scale fitted on training
%     recordings only).
s.clutter.method = 'highpass';
s.clutter.cutoffHz = 3.75;
s.clutter.order = 4;
s.denoise.method = 'none';
s.denoise.cutoffHz = 200;
s.denoise.order = 4;
s.normalize.mode = 'none';

% Doppler spectrum (FFT along slow time over the selected range bins).
%   fftSize 0 means the next power of two at or above the number of chirps.
s.doppler.window = 'hann';
s.doppler.fftSize = 0;

% Micro-Doppler spectrogram (our own STFT along slow time). The window is given
% in seconds so it means the same thing at any pulse rate; at 1 kHz, 0.2 s is
% 200 samples, 95% overlap is a hop of 10 samples, and a pad factor of 4 gives an
% FFT of 800 points. dynamicRangeDb and imageSize are for display and for the
% fixed-size images given to classifiers.
s.stft.windowSeconds = 0.2;
s.stft.overlapFraction = 0.95;
s.stft.padFactor = 4;
s.stft.window = 'hamming';
s.stft.dynamicRangeDb = 40;
s.stft.imageSize = [128 128];

% Features (dsp.extractFeatures). Groups: "doppler" (shape of the time-averaged
% velocity spectrum) and "temporal" (how the motion changes over time). Only
% velocities within +/-velocityLimit m/s are used. extentDropDb sets how far below
% the strongest spectrogram value the positive/negative velocity extent is measured.
s.features.groups = ["doppler" "temporal"];
s.features.velocityLimit = 6;
s.features.extentDropDb = 25;

s.split.train = 0.6;
s.split.val = 0.2;
s.split.test = 0.2;
% Each group is an N-by-2 string array of [session folder, subject id] that
% refer to the same person. P08 appears in two February 2019 sessions.
s.split.mergeGroups = {["5 February 2019 UoG Dataset" "P08"; ...
    "6 February 2019 NG Homes Dataset" "P08"]};
end
