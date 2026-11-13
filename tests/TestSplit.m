classdef TestSplit < matlab.unittest.TestCase
    methods (Access = private)
        function T = fakeTable(~, nPeople, nFallPeople)
            % nPeople people, each with 3 recordings of activities 1-5;
            % the first nFallPeople also have 3 recordings of activity 6.
            person = strings(0, 1);
            code = zeros(0, 1);
            for p = 1:nPeople
                codes = 1:5;
                if p <= nFallPeople
                    codes = 1:6;
                end
                for c = codes
                    for r = 1:3
                        person(end+1, 1) = "S|P" + string(p); %#ok<AGROW>
                        code(end+1, 1) = c; %#ok<AGROW>
                    end
                end
            end
            names = ["walking"; "sitting down"; "standing up"; "picking up an object"; "drinking"; "falling"];
            T = table(person, code, names(code), true(numel(code), 1), ...
                'VariableNames', {'person', 'activityCode', 'activity', 'included'});
        end
    end

    methods (Test)
        function noPersonSpansSplits(testCase)
            T = dsp.splitByPerson(testCase.fakeTable(40, 16), dsp.makeSettings());
            for p = unique(T.person)'
                testCase.verifyEqual(numel(unique(T.split(T.person == p))), 1, p);
            end
        end

        function everySplitIsUsedAndHasEveryClass(testCase)
            T = dsp.splitByPerson(testCase.fakeTable(40, 16), dsp.makeSettings());
            S = dsp.splitSummary(T);
            testCase.verifyEqual(height(S), 6);
            testCase.verifyTrue(all(S.train > 0) && all(S.val > 0) && all(S.test > 0));
            testCase.verifyEqual(sum(S.total), height(T));
        end

        function splitSizesAreCloseToTheFractions(testCase)
            T = dsp.splitByPerson(testCase.fakeTable(40, 40), dsp.makeSettings());
            share = [sum(T.split == "train") sum(T.split == "val") sum(T.split == "test")] / height(T);
            testCase.verifyEqual(share, [0.6 0.2 0.2], 'AbsTol', 0.1);
        end

        function sameSeedGivesSameSplit(testCase)
            base = testCase.fakeTable(40, 16);
            s = dsp.makeSettings(struct('seed', 11));
            a = dsp.splitByPerson(base, s);
            b = dsp.splitByPerson(base, s);
            testCase.verifyEqual(a.split, b.split);
        end

        function tooFewPeopleFails(testCase)
            testCase.verifyError(@() dsp.splitByPerson(testCase.fakeTable(2, 2), dsp.makeSettings()), ...
                'dsp:split:tooFewPeople');
        end

        function rareClassMissingFromASplitIsReported(testCase)
            base = testCase.fakeTable(30, 1);
            testCase.verifyWarning(@() dsp.splitByPerson(base, dsp.makeSettings()), 'dsp:split:missingClass');
        end

        function excludedRecordingsGetNoSplit(testCase)
            base = testCase.fakeTable(30, 10);
            base.included(1:3) = false;
            T = dsp.splitByPerson(base, dsp.makeSettings());
            testCase.verifyEqual(T.split(~T.included), strings(3, 1));
        end

        function savedSplitRoundTrips(testCase)
            T = dsp.splitByPerson(testCase.fakeTable(40, 16), dsp.makeSettings());
            file = string(tempname) + ".csv";
            testCase.addTeardown(@() delete(file));
            dsp.saveSplit(T, file);
            back = T;
            back.split = strings(height(T), 1);
            back = dsp.loadSplit(back, file);
            testCase.verifyEqual(back.split, T.split);
        end

        function unknownPersonInSavedSplitFails(testCase)
            T = dsp.splitByPerson(testCase.fakeTable(40, 16), dsp.makeSettings());
            file = string(tempname) + ".csv";
            testCase.addTeardown(@() delete(file));
            dsp.saveSplit(T, file);
            other = T;
            other.person(1) = "S|NEW";
            testCase.verifyError(@() dsp.loadSplit(other, file), 'dsp:split:unknownPerson');
        end
    end
end
