function [x, names, info] = extractFeatures(sp, s)
%EXTRACTFEATURES Feature vector from a micro-Doppler spectrogram.
%   [x, names, info] = dsp.extractFeatures(sp, settings)
%
%   sp comes from dsp.stft or dsp.microDoppler (it needs a velocity axis). Only
%   velocities within +/- s.features.velocityLimit are used, and power is
%   magnitude squared. x is a row vector and names a matching string row.
%   Every feature is a ratio, a shape measure or a velocity, so none depends on
%   the absolute signal level, and none depends on how long the recording is
%   (the recordings are 5, 10 or 20 s long).
%
%   Group "doppler" (the time-averaged power over velocity P(v)):
%     dopCentroid      mean velocity (m/s); sign shows the direction of motion
%     dopSpread        standard deviation of velocity (m/s)
%     dopSkew          asymmetry of P(v) (0 = symmetric)
%     dopPeakVelocity  velocity of the largest value of P(v) (m/s)
%     dopEntropy       spectral entropy of P(v), 0..1 (1 = flat)
%     dopV95           speed below which 95% of the power lies (m/s)
%     dopPosExtent     largest positive velocity within s.features.extentDropDb of
%                      the spectrogram's strongest value (m/s, 0 if none)
%     dopNegExtent     the same for negative velocity (reported as a positive number)
%   Group "temporal" (frame by frame; "active" frames have at least 5% of the
%   strongest frame's energy):
%     tCentroidMean, tCentroidStd, tCentroidRange   velocity centroid over active
%                      frames: mean, standard deviation, 5-95% range (m/s)
%     tSpreadMean, tSpreadStd                       per-frame velocity spread (m/s)
%     tEnergyStdDb     standard deviation of the frame energy in dB re the maximum
%     tActiveFraction  share of frames with at least 10% of the maximum energy
%     tEnergyCentre    energy-weighted mean time as a fraction of the recording (0..1)
%     tEnergySpread    energy-weighted standard deviation of time (fraction)
%     tPeriodicity     highest local maximum of the energy envelope's
%                      autocorrelation at lags of 0.25-1.5 s (0 if none), a gait
%                      or limb-swing measure
%
%   A spectrogram with no energy gives all zeros and info.silent = true. All
%   values are finite. Spectrograms of other recordings must use the same settings
%   to be comparable.
arguments
    sp (1,1) struct
    s (1,1) struct = dsp.makeSettings()
end
if ~sp.velocityAvailable
    error('dsp:features:noVelocity', 'The spectrogram has no velocity axis (carrier frequency unknown).');
end
groups = string(s.features.groups);
if ~all(ismember(groups, ["doppler" "temporal"]))
    bad = groups(~ismember(groups, ["doppler" "temporal"]));
    error('dsp:features:unknownGroup', 'Unknown feature group "%s".', bad(1));
end

band = abs(sp.velocity(:)) <= s.features.velocityLimit;
if nnz(band) < 3
    error('dsp:features:bandTooNarrow', 'Fewer than three velocity bins lie within +/-%g m/s.', s.features.velocityLimit);
end
v = sp.velocity(band);
p = sp.mag(band, :) .^ 2;

dopNames = ["dopCentroid" "dopSpread" "dopSkew" "dopPeakVelocity" "dopEntropy" "dopV95" "dopPosExtent" "dopNegExtent"];
tmpNames = ["tCentroidMean" "tCentroidStd" "tCentroidRange" "tSpreadMean" "tSpreadStd" ...
    "tEnergyStdDb" "tActiveFraction" "tEnergyCentre" "tEnergySpread" "tPeriodicity"];

names = strings(1, 0);
if any(groups == "doppler")
    names = [names dopNames];
end
if any(groups == "temporal")
    names = [names tmpNames];
end

info.silent = ~(sum(p(:)) > 0);
info.groups = groups;
if info.silent
    x = zeros(1, numel(names));
    return
end

x = zeros(1, 0);
if any(groups == "doppler")
    x = [x dopplerFeatures(v, p, s.features.extentDropDb)];
end
if any(groups == "temporal")
    x = [x temporalFeatures(v, p, sp.timeStep)];
end
x(~isfinite(x)) = 0;
end

function f = dopplerFeatures(v, p, dropDb)
P = mean(p, 2);
q = P / sum(P);
c = sum(v .* q);
spread = sqrt(sum((v - c) .^ 2 .* q));
if spread > eps
    skew = sum(((v - c) / spread) .^ 3 .* q);
else
    skew = 0;
end
[~, i] = max(P);
peakVelocity = v(i);
nz = q > 0;
entropy = -sum(q(nz) .* log2(q(nz))) / log2(numel(q));

[speed, order] = sort(abs(v));
cum = cumsum(q(order));
v95 = speed(find(cum >= 0.95, 1));

rowMax = max(p, [], 2);
db = 10 * log10(max(rowMax, realmin));
above = db >= max(db) - dropDb;
posExtent = 0;
negExtent = 0;
if any(above & v > 0)
    posExtent = max(v(above & v > 0));
end
if any(above & v < 0)
    negExtent = -min(v(above & v < 0));
end
f = [c spread skew peakVelocity entropy v95 posExtent negExtent];
end

function f = temporalFeatures(v, p, timeStep)
nT = size(p, 2);
e = sum(p, 1)';                                  % frame energy
emax = max(e);
active = e >= 0.05 * emax;

safe = max(e, realmin)';
centroid = (v' * p) ./ safe;                     % per-frame velocity centroid
spreadFrame = sqrt(max((v .^ 2)' * p ./ safe - centroid .^ 2, 0));
cA = centroid(active)';
bA = spreadFrame(active)';

if numel(cA) > 1
    cStd = std(cA);
    bStd = std(bA);
else
    cStd = 0;
    bStd = 0;
end
cRange = quant(cA, 0.95) - quant(cA, 0.05);
energyStdDb = 0;
if nnz(active) > 1
    energyStdDb = std(10 * log10(e(active) / emax));
end
activeFraction = mean(e >= 0.1 * emax);

if nT > 1
    tn = (0:nT-1)' / (nT - 1);
else
    tn = 0;
end
centre = sum(tn .* e) / sum(e);
tSpread = sqrt(sum((tn - centre) .^ 2 .* e) / sum(e));

f = [mean(cA) cStd cRange mean(bA) bStd energyStdDb activeFraction centre tSpread periodicity(e, timeStep)];
end

function r = periodicity(e, dt)
y = e(:) - mean(e);
den = sum(y .^ 2);
n = numel(y);
r = 0;
if den <= 0 || ~(dt > 0)
    return
end
kmin = max(1, round(0.25 / dt));
kmax = min(round(1.5 / dt), floor(n / 2));
if kmax <= kmin + 1
    return
end
acf = zeros(kmax + 1, 1);
for k = 0:kmax
    acf(k + 1) = sum(y(1:n-k) .* y(1+k:n)) / den;
end
for k = kmin:kmax-1
    if acf(k + 1) > acf(k) && acf(k + 1) >= acf(k + 2)
        r = max(r, acf(k + 1));
    end
end
r = max(r, 0);
end

function q = quant(x, prob)
x = sort(x(:));
n = numel(x);
if n == 1
    q = x;
    return
end
pos = 1 + (n - 1) * prob;
lo = floor(pos);
hi = ceil(pos);
q = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
