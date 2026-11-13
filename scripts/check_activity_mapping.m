function result = check_activity_mapping(opts)
% CHECK_ACTIVITY_MAPPING Which of codes 4 and 5 is "picking up an object" and which is "drinking"?
%   check_activity_mapping
%   check_activity_mapping(MaxPairs=200, Seed=1)
%
%   The dataset's data sheet says code 4 = picking up an object and code 5 =
%   drinking, but the authors' example script says the opposite. Bending to pick
%   up an object moves the whole torso and should reach higher velocities than
%   lifting a cup to the mouth. For people who did both activities in the same
%   repetition, this compares the velocity extent (95% power speed, rms velocity)
%   of code 4 against code 5 after the full front end. If code 4 is wider in most
%   pairs, the data sheet is right.
%   Writes results/mapping_check/pairs.csv and summary.txt.
arguments
    opts.MaxPairs (1,1) double = 200
    opts.Seed (1,1) double = 1
end

s = dsp.makeSettings();
T = dsp.listRecordings(s);
T = T(T.included & ismember(T.activityCode, [4 5]), :);
T.key = T.session + "|" + T.subject + "|" + string(T.repetition);

keys4 = T.key(T.activityCode == 4);
keys5 = T.key(T.activityCode == 5);
common = intersect(keys4, keys5);
if isempty(common)
    error('check_activity_mapping:noPairs', 'No person has both activity 4 and activity 5 in the same repetition.');
end
rs = RandStream('mt19937ar', 'Seed', opts.Seed);
common = common(randperm(rs, numel(common), min(opts.MaxPairs, numel(common))));
n = numel(common);

v95 = zeros(n, 2);
vRms = zeros(n, 2);
for k = 1:n
    for c = 1:2
        code = 3 + c;
        row = T(T.key == common(k) & T.activityCode == code, :);
        rec = dsp.readConverted(row.file(1));
        rt = dsp.rangeTime(rec, s);
        [pre, sel] = dsp.preprocess(rt, s);
        dop = dsp.dopplerSpectrum(pre.data(sel.bins, :), pre.prf, pre.carrierHz, s);
        e = dsp.velocityExtent(dop);
        v95(k, c) = e.v95;
        vRms(k, c) = e.vRms;
    end
end

pairs = table(common, v95(:, 1), v95(:, 2), vRms(:, 1), vRms(:, 2), ...
    'VariableNames', {'key', 'v95_code4', 'v95_code5', 'vRms_code4', 'vRms_code5'});

wide4 = mean(v95(:, 1) > v95(:, 2));
wideRms4 = mean(vRms(:, 1) > vRms(:, 2));
if wide4 >= 0.8
    verdict = "Code 4 is the wider activity in most pairs: this supports the data sheet (4 = picking up an object, 5 = drinking).";
elseif wide4 <= 0.2
    verdict = "Code 5 is the wider activity in most pairs: this supports the authors' script (4 = drinking, 5 = picking up an object). Swap the two names in dsp.defaultSettings.";
else
    verdict = "Inconclusive: neither code is clearly wider. Keep the data sheet mapping and say so in the report.";
end

lines = [ ...
    sprintf("Pairs compared: %d (same session, subject and repetition)", n); ...
    sprintf("Median v95 [m/s]:  code 4 = %.2f,  code 5 = %.2f", median(v95(:, 1)), median(v95(:, 2))); ...
    sprintf("Median vRms [m/s]: code 4 = %.2f,  code 5 = %.2f", median(vRms(:, 1)), median(vRms(:, 2))); ...
    sprintf("Code 4 wider than code 5 by v95:  %.0f%% of pairs", 100 * wide4); ...
    sprintf("Code 4 wider than code 5 by vRms: %.0f%% of pairs", 100 * wideRms4); ...
    "Verdict: " + verdict];
disp(strjoin(lines, newline));

outDir = fullfile(dsp.projectRoot(), 'results', 'mapping_check');
if ~isfolder(outDir)
    mkdir(outDir);
end
writetable(pairs, fullfile(outDir, 'pairs.csv'));
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', strjoin(lines, newline));
fclose(fid);

result = struct('pairs', pairs, 'fractionCode4Wider', wide4, 'verdict', verdict);
end
