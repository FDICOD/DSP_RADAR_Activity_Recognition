classdef TestFeatureTable < matlab.unittest.TestCase
    properties
        Root
        Settings
        Cache
    end

    methods (TestMethodSetup)
        function makeFakeDataset(testCase)
            testCase.Root = string(tempname);
            mkdir(fullfile(testCase.Root, 'S1'));
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            % two slow movers (activity 1) and two fast movers (activity 2)
            testCase.writeFake('1P01A01R1', 40);
            testCase.writeFake('1P02A01R1', 45);
            testCase.writeFake('2P01A02R1', 190);
            testCase.writeFake('2P02A02R1', 200);
            s = dsp.makeSettings();
            s.data.root = char(testCase.Root);
            s.data.format = 'mat';
            testCase.Settings = s;
            testCase.Cache = fullfile(testCase.Root, 'cache', 'features.mat');
        end
    end

    methods (Access = private)
        function writeFake(testCase, name, f)
            rng(round(f));
            nts = 128; nc = 1000;
            n = (0:nts-1)'; m = 0:nc-1;
            x = exp(1j * 2 * pi * 16 * n / nts) .* exp(1j * 2 * pi * f * m / 1000) ...
                + 0.05 * (randn(nts, nc) + 1j * randn(nts, nc));
            x = x(:);
            I = uint16(2000 + 400 * real(x)); %#ok<NASGU>
            Q = uint16(2000 + 400 * imag(x)); %#ok<NASGU>
            fc = 5.8e9; Tc_ms = 1; bw = 4e8; %#ok<NASGU>
            nts = 128; %#ok<NASGU>
            save(fullfile(testCase.Root, 'S1', name + ".mat"), 'I', 'Q', 'fc', 'Tc_ms', 'nts', 'bw');
        end

        function T = table4(testCase)
            T = dsp.listRecordings(testCase.Settings);
            T.split = ["train"; "train"; "val"; "val"];
        end
    end

    methods (Test)
        function computesFeaturesForEveryRecording(testCase)
            T = testCase.table4();
            F = dsp.featureTable(T, testCase.Settings, Verbose=false);
            testCase.verifyTrue(all(F.ok));
            testCase.verifySize(F.X, [4 18]);
            testCase.verifyEqual(numel(F.names), 18);
            testCase.verifyTrue(all(isfinite(F.X(:))));
            testCase.verifyEqual(F.row, (1:4)');
            % the fast movers have the larger 95%-power speed
            i = find(F.names == "dopV95");
            testCase.verifyGreaterThan(min(F.X(3:4, i)), max(F.X(1:2, i)));
        end

        function recordingsWithoutASplitOrExcludedAreSkipped(testCase)
            T = testCase.table4();
            T.split(2) = "";
            T.included(4) = false;
            F = dsp.featureTable(T, testCase.Settings, Verbose=false);
            testCase.verifyEqual(F.row, [1; 3]);
            testCase.verifySize(F.X, [2 18]);
        end

        function theCacheIsReusedWithoutTheFiles(testCase)
            T = testCase.table4();
            first = dsp.featureTable(T, testCase.Settings, CacheFile=testCase.Cache, Verbose=false);
            rmdir(fullfile(testCase.Root, 'S1'), 's');
            second = dsp.featureTable(T, testCase.Settings, CacheFile=testCase.Cache, Verbose=false);
            testCase.verifyTrue(all(second.ok));
            testCase.verifyEqual(second.X, first.X);
        end

        function aCacheMadeWithOtherSettingsIsIgnored(testCase)
            T = testCase.table4();
            dsp.featureTable(T, testCase.Settings, CacheFile=testCase.Cache, Verbose=false);
            rmdir(fullfile(testCase.Root, 'S1'), 's');
            other = testCase.Settings;
            other.stft.windowSeconds = 0.3;
            F = dsp.featureTable(T, other, CacheFile=testCase.Cache, Verbose=false);
            testCase.verifyFalse(any(F.ok));
            testCase.verifyTrue(all(strlength(F.message) > 0));
            testCase.verifyTrue(all(isnan(F.X(:))) || isempty(F.X));
        end

        function aBrokenFileOnlyAffectsItself(testCase)
            T = testCase.table4();
            fid = fopen(fullfile(testCase.Root, 'S1', '2P01A02R1.mat'), 'w');
            fprintf(fid, 'not a mat file');
            fclose(fid);
            F = dsp.featureTable(T, testCase.Settings, Verbose=false);
            testCase.verifyEqual(find(~F.ok)', 3);
            testCase.verifyTrue(all(isnan(F.X(3, :))));
            testCase.verifyTrue(all(isfinite(F.X([1 2 4], :)), 'all'));
            testCase.verifySubstring(F.message(3), '2P01A02R1.mat');
        end

        function aRunThatStoppedHalfwayResumes(testCase)
            T = testCase.table4();
            % pretend the first run only finished recordings 1 and 2
            half = T;
            half.split(3:4) = "";
            dsp.featureTable(half, testCase.Settings, CacheFile=testCase.Cache, Verbose=false);
            % the full run reuses those two and computes the rest
            F = dsp.featureTable(T, testCase.Settings, CacheFile=testCase.Cache, Verbose=false);
            full = dsp.featureTable(T, testCase.Settings, Verbose=false);
            testCase.verifyTrue(all(F.ok));
            testCase.verifyEqual(F.X, full.X, 'AbsTol', 1e-12);
        end

        function noiseIsRepeatableAndChangesTheFeatures(testCase)
            T = testCase.table4();
            clean = dsp.featureTable(T, testCase.Settings, Verbose=false);
            a = dsp.featureTable(T, testCase.Settings, SnrDb=0, NoiseSeed=3, Verbose=false);
            b = dsp.featureTable(T, testCase.Settings, SnrDb=0, NoiseSeed=3, Verbose=false);
            c = dsp.featureTable(T, testCase.Settings, SnrDb=0, NoiseSeed=4, Verbose=false);
            testCase.verifyEqual(a.X, b.X);
            testCase.verifyNotEqual(a.X, c.X);
            testCase.verifyNotEqual(a.X, clean.X);
        end

        function noiseForOneRecordingDoesNotDependOnTheOthers(testCase)
            T = testCase.table4();
            all4 = dsp.featureTable(T, testCase.Settings, SnrDb=5, NoiseSeed=2, Verbose=false);
            only3 = T;
            only3.split([1 2 4]) = "";
            one = dsp.featureTable(only3, testCase.Settings, SnrDb=5, NoiseSeed=2, Verbose=false);
            testCase.verifyEqual(one.X, all4.X(3, :), 'AbsTol', 1e-12);
        end
    end
end
