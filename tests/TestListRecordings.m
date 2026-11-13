classdef TestListRecordings < matlab.unittest.TestCase
    properties
        Root
        Settings
    end

    methods (TestMethodSetup)
        function makeFakeDataset(testCase)
            testCase.Root = string(tempname);
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));

            layout = struct( ...
                'SessionA', {{'1P01A01R1.mat', '2P01A02R1.mat', '1P08A01R1.mat', ...
                              '3P03A02R1.mat', '4P30A04R3 (2).mat', '._1P02A01R1.mat'}}, ...
                'SessionB', {{'1P01A01R1.mat', '6P08A06R1.mat', '9P09A09R1.mat'}});
            sessions = fieldnames(layout);
            for k = 1:numel(sessions)
                folder = fullfile(testCase.Root, sessions{k});
                mkdir(folder);
                names = layout.(sessions{k});
                for j = 1:numel(names)
                    fclose(fopen(fullfile(folder, names{j}), 'w'));
                end
            end

            s = dsp.makeSettings();
            s.data.root = testCase.Root;
            s.data.format = 'mat';
            s.split.mergeGroups = {["SessionA" "P08"; "SessionB" "P08"]};
            testCase.Settings = s;
        end
    end

    methods (Test)
        function listsEveryFileExceptHiddenOnes(testCase)
            T = dsp.listRecordings(testCase.Settings);
            % 5 visible files in SessionA, 3 in SessionB; the "._" file is skipped
            testCase.verifyEqual(height(T), 8);
            testCase.verifyEqual(unique(T.session)', ["SessionA" "SessionB"]);
        end

        function includedAndExcludedAreSeparated(testCase)
            T = dsp.listRecordings(testCase.Settings);
            testCase.verifyEqual(sum(T.included), 5);
            reasons = T.reason(~T.included);
            testCase.verifyEqual(sort(reasons)', sort(["inconsistent_digits" "name_not_matching" "unknown_activity_code"]));
        end

        function activityNamesFollowTheMapping(testCase)
            T = dsp.listRecordings(testCase.Settings);
            row = T(T.name == "6P08A06R1", :);
            testCase.verifyEqual(row.activity, "falling");
            testCase.verifyEqual(row.activityCode, 6);
        end

        function changingTheMappingChangesNames(testCase)
            s = testCase.Settings;
            s.activity.codeNames = ["a"; "b"; "c"; "d"; "e"; "f"];
            T = dsp.listRecordings(s);
            row = T(T.name == "6P08A06R1", :);
            testCase.verifyEqual(row.activity, "f");
        end

        function samePersonInTwoSessionsIsMerged(testCase)
            T = dsp.listRecordings(testCase.Settings);
            a = T.person(T.session == "SessionA" & T.subject == "P08");
            b = T.person(T.session == "SessionB" & T.subject == "P08");
            testCase.verifyEqual(a, b);
        end

        function reusedIdentifierWithoutMergeIsDifferentPeople(testCase)
            T = dsp.listRecordings(testCase.Settings);
            a = T.person(T.session == "SessionA" & T.subject == "P01" & T.activityCode == 1);
            b = T.person(T.session == "SessionB" & T.subject == "P01");
            testCase.verifyNotEqual(a, b);
        end

        function missingDataFolderGivesHelpfulError(testCase)
            s = testCase.Settings;
            s.data.root = fullfile(testCase.Root, 'does_not_exist');
            testCase.verifyError(@() dsp.listRecordings(s), 'dsp:listRecordings:noData');
        end

        function summaryIsWrittenForConvertedFiles(testCase)
            % Give the fake files real content so headers can be read.
            files = dir(fullfile(testCase.Root, '**', '*.mat'));
            for k = 1:numel(files)
                I = uint16(1:256)'; Q = uint16(1:256)'; fc = 5.8e9; Tc_ms = 1; nts = 128; bw = 4e8; %#ok<NASGU>
                save(fullfile(files(k).folder, files(k).name), 'I', 'Q', 'fc', 'Tc_ms', 'nts', 'bw');
            end
            T = dsp.listRecordings(testCase.Settings);
            out = fullfile(testCase.Root, 'out', 'summary.txt');
            text = dsp.writeDatasetSummary(T, testCase.Settings, string(out));
            testCase.verifyTrue(isfile(out));
            testCase.verifyTrue(contains(text, "Excluded files (3)"));
            testCase.verifyTrue(contains(text, "inconsistent_digits"));
            testCase.verifyTrue(contains(text, "5.8e+09, 1, 128, 4e+08 : 5 files"));
        end
    end
end
