classdef TestRecordingIO < matlab.unittest.TestCase
    properties
        Dir
    end

    methods (TestMethodSetup)
        function makeTempFolder(testCase)
            testCase.Dir = string(tempname);
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Access = private)
        function path = writeText(testCase, name, header, iVals, qVals, eol)
            % Write a fabricated recording in the original text layout.
            path = fullfile(testCase.Dir, name);
            fid = fopen(path, 'w');
            for k = 1:numel(header)
                fprintf(fid, '%s%s', header{k}, eol);
            end
            for k = 1:numel(iVals)
                if qVals(k) >= 0
                    fprintf(fid, '%d+%di%s', iVals(k), qVals(k), eol);
                else
                    fprintf(fid, '%d-%di%s', iVals(k), -qVals(k), eol);
                end
            end
            fclose(fid);
        end
    end

    methods (Test)
        function readsHeaderAndSamples(testCase)
            iv = (10:10:100)';
            qv = [-1 2 -3 4 -5 6 -7 8 -9 10]';
            path = testCase.writeText('a.dat', {'5800000000.000000', '1.000000', '4', '400000000.000000'}, ...
                iv, qv, sprintf('\r\n'));
            rec = dsp.readDat(path);
            testCase.verifyEqual(rec.carrierHz, 5.8e9);
            testCase.verifyEqual(rec.chirpDuration, 1e-3, 'AbsTol', 1e-15);
            testCase.verifyEqual(rec.samplesPerChirp, 4);
            testCase.verifyEqual(rec.bandwidthHz, 4e8);
            testCase.verifyEqual(rec.prf, 1000, 'AbsTol', 1e-9);
            testCase.verifyEqual(rec.wavelength, 299792458 / 5.8e9, 'RelTol', 1e-12);
            % 10 samples with 4 per chirp: 2 whole chirps kept, 2 samples dropped
            testCase.verifyEqual(rec.numChirps, 2);
            testCase.verifyEqual(rec.droppedSamples, 2);
            testCase.verifyEqual(rec.iq, complex(iv(1:8), qv(1:8)));
        end

        function worksWithUnixLineEndings(testCase)
            path = testCase.writeText('b.dat', {'5800000000.000000', '1.000000', '2', '400000000.000000'}, ...
                [5; 6; 7; 8], [1; 2; 3; 4], newline);
            rec = dsp.readDat(path);
            testCase.verifyEqual(rec.numChirps, 2);
            testCase.verifyEqual(rec.droppedSamples, 0);
            testCase.verifyEqual(rec.iq, complex([5; 6; 7; 8], [1; 2; 3; 4]));
        end

        function missingTextFileFails(testCase)
            testCase.verifyError(@() dsp.readDat(fullfile(testCase.Dir, 'nope.dat')), 'dsp:readDat:fileNotFound');
        end

        function shortHeaderFails(testCase)
            path = fullfile(testCase.Dir, 'c.dat');
            fid = fopen(path, 'w');
            fprintf(fid, '5800000000.000000\r\n1.000000\r\n');
            fclose(fid);
            testCase.verifyError(@() dsp.readDat(path), 'dsp:readDat:badHeader');
        end

        function oddNumberOfValuesFails(testCase)
            path = fullfile(testCase.Dir, 'd.dat');
            fid = fopen(path, 'w');
            fprintf(fid, '5800000000.000000\r\n1.000000\r\n2\r\n400000000.000000\r\n10+5i\r\n7\r\n');
            fclose(fid);
            testCase.verifyError(@() dsp.readDat(path), 'dsp:readDat:oddValueCount');
        end

        function convertedFileMatchesTextFile(testCase)
            iv = uint16([1200; 35000; 40; 65535; 2000; 3000; 4000; 5000]);
            qv = uint16([1300; 100; 2; 7; 2100; 3100; 4100; 5100]);
            textPath = testCase.writeText('e.dat', {'5800000000.000000', '1.000000', '4', '400000000.000000'}, ...
                double(iv), double(qv), sprintf('\r\n'));
            matPath = fullfile(testCase.Dir, 'e.mat');
            I = iv; Q = qv; fc = 5.8e9; Tc_ms = 1; nts = 4; bw = 4e8; %#ok<NASGU>
            save(matPath, 'I', 'Q', 'fc', 'Tc_ms', 'nts', 'bw');
            testCase.verifyEqual(dsp.readConverted(matPath), dsp.readDat(textPath));
        end

        function convertedFileMissingFieldFails(testCase)
            matPath = fullfile(testCase.Dir, 'f.mat');
            I = uint16([1; 2; 3; 4]); Q = uint16([1; 2; 3; 4]); %#ok<NASGU>
            save(matPath, 'I', 'Q');
            testCase.verifyError(@() dsp.readConverted(matPath), 'dsp:readConverted:missingField');
        end

        function unreadableConvertedFileGivesAHelpfulError(testCase)
            path = fullfile(testCase.Dir, 'junk.mat');
            fid = fopen(path, 'w');
            fprintf(fid, 'this is not a MAT-file');
            fclose(fid);
            try
                dsp.readConverted(path);
                testCase.verifyFail('Expected an error for a file that is not a MAT-file.');
            catch err
                testCase.verifyEqual(err.identifier, 'dsp:readConverted:unreadable');
                testCase.verifySubstring(err.message, 'junk.mat');
                testCase.verifySubstring(err.message, '22 bytes');
                testCase.verifySubstring(err.message, 'this is not a MAT-f');
            end
        end

        function headerReaderReportsLength(testCase)
            matPath = fullfile(testCase.Dir, 'g.mat');
            I = uint16(1:2000)'; Q = uint16(1:2000)'; fc = 5.8e9; Tc_ms = 1; nts = 128; bw = 4e8; %#ok<NASGU>
            save(matPath, 'I', 'Q', 'fc', 'Tc_ms', 'nts', 'bw');
            h = dsp.readConvertedHeader(matPath);
            testCase.verifyEqual(h.numSamples, 2000);
            testCase.verifyEqual(h.samplesPerChirp, 128);
            % 2000 / 128 = 15 whole chirps of 1 ms
            testCase.verifyEqual(h.durationSeconds, 0.015, 'AbsTol', 1e-12);
        end
    end
end
