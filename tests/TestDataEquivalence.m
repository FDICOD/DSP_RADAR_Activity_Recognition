classdef TestDataEquivalence < matlab.unittest.TestCase
    % The text loader (dsp.readDat) and the converted-file loader
    % (dsp.readConverted) must give identical samples.
    %   1. convertedRecordingsSurviveATextRoundTrip rebuilds the original text format
    %      from real converted recordings, so it needs only data/converted.
    %   2. The sample tests compare the two original sample files in data/samples.
    %      They are skipped (not failed) when those files are missing or damaged.

    methods (Access = private)
        function files = intactSamples(~)
            folder = fullfile(dsp.projectRoot(), 'data', 'samples', 'dat');
            files = dir(fullfile(folder, '*.dat'));
            keep = false(size(files));
            for k = 1:numel(files)
                fid = fopen(fullfile(files(k).folder, files(k).name), 'r');
                head = fread(fid, 200, '*char')';
                fclose(fid);
                keep(k) = nnz(head == newline) >= 4;
            end
            files = files(keep);
        end

        function writeText(~, file, S)
            % the original layout: four header lines, then I+Qi per line, CRLF endings
            fid = fopen(file, 'w');
            fprintf(fid, '%.6f\r\n%.6f\r\n%d\r\n%.6f\r\n', S.fc, S.Tc_ms, S.nts, S.bw);
            fprintf(fid, '%d%+di\r\n', [double(S.I(:)) double(S.Q(:))]');
            fclose(fid);
        end
    end

    methods (Test)
        function convertedRecordingsSurviveATextRoundTrip(testCase)
            s = dsp.makeSettings();
            testCase.assumeTrue(isfolder(s.data.root), 'Converted data not found in data/converted.');
            T = dsp.listRecordings(s);
            T = T(T.included, :);
            testCase.assumeNotEmpty(T, 'No converted recordings found.');

            % one recording from each of two sessions (including a 100 MHz file)
            rows = [find(T.session == "5 February 2019 UoG Dataset", 1), ...
                    find(T.session == "7 March 2019 West Cumbria Dataset", 1)];
            for k = rows
                try
                    S = load(T.file(k), 'I', 'Q', 'fc', 'Tc_ms', 'nts', 'bw');
                catch err
                    testCase.assumeFail("Data file unreadable on this drive: " + err.message);
                end
                textFile = string(tempname) + ".dat";
                testCase.addTeardown(@() delete(textFile));
                testCase.writeText(textFile, S);
                testCase.verifyEqual(dsp.readDat(textFile), dsp.readConverted(T.file(k)), T.name(k));
            end
        end

        function textAndConvertedSamplesAreIdentical(testCase)
            files = testCase.intactSamples();
            testCase.assumeNotEmpty(files, ...
                'Sample .dat files in data/samples/dat are missing or damaged; re-upload them.');
            for k = 1:numel(files)
                [~, stem] = fileparts(files(k).name);
                matFile = fullfile(dsp.projectRoot(), 'data', 'samples', 'mat', stem + ".mat");
                testCase.assumeTrue(isfile(matFile), "Missing converted sample " + stem);
                try
                    fromMat = dsp.readConverted(matFile);
                catch err
                    testCase.assumeFail("Converted sample " + stem + " is damaged: " + err.message);
                end
                fromText = dsp.readDat(fullfile(files(k).folder, files(k).name));
                testCase.verifyEqual(fromMat, fromText, "Loaders differ for " + stem);
            end
        end

        function sampleRecordingsHaveTheExpectedHeader(testCase)
            files = testCase.intactSamples();
            testCase.assumeNotEmpty(files, ...
                'Sample .dat files in data/samples/dat are missing or damaged; re-upload them.');
            for k = 1:numel(files)
                rec = dsp.readDat(fullfile(files(k).folder, files(k).name));
                testCase.verifyEqual(rec.carrierHz, 5.8e9);
                testCase.verifyEqual(rec.samplesPerChirp, 128);
                testCase.verifyEqual(rec.bandwidthHz, 4e8);
                testCase.verifyEqual(rec.prf, 1000, 'AbsTol', 1e-6);
                testCase.verifyEqual(rec.droppedSamples, 0);
                testCase.verifyTrue(ismember(rec.numChirps, [5000 10000 20000]));
            end
        end
    end
end
