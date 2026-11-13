classdef TestExperimentHelpers < matlab.unittest.TestCase
    methods (Access = private)
        function T = fakeTable(~)
            % 12 people x 6 activities x 2 repetitions, split 8/2/2 people
            person = strings(0, 1); code = zeros(0, 1); split = strings(0, 1);
            splits = ["train" "train" "train" "train" "train" "train" "train" "train" "val" "val" "test" "test"];
            for p = 1:12
                for c = 1:6
                    for r = 1:2
                        person(end+1, 1) = "S|P" + string(p); %#ok<AGROW>
                        code(end+1, 1) = c; %#ok<AGROW>
                        split(end+1, 1) = splits(p); %#ok<AGROW>
                    end
                end
            end
            T = table(person, code, split, true(numel(code), 1), (1:numel(code))', ...
                'VariableNames', {'person', 'activityCode', 'split', 'included', 'id'});
        end
    end

    methods (Test)
        function pickIsBalancedAndFromTheRequestedSplit(testCase)
            T = testCase.fakeTable();
            pick = dsp.pickRecordings(T, "val", 3, 1);
            testCase.verifyTrue(all(pick.split == "val"));
            for c = 1:6
                testCase.verifyEqual(sum(pick.activityCode == c), 3);
            end
            testCase.verifyEqual(height(pick), 18);
        end

        function pickTakesEverythingWhenFewerAreAvailable(testCase)
            T = testCase.fakeTable();                       % val has 2 people x 2 reps = 4 per class
            pick = dsp.pickRecordings(T, "val", 10, 1);
            testCase.verifyEqual(height(pick), 24);
        end

        function pickIsReproducibleAndLeavesTheGlobalRandomStateAlone(testCase)
            T = testCase.fakeTable();
            a = dsp.pickRecordings(T, "train", 4, 7);
            b = dsp.pickRecordings(T, "train", 4, 7);
            c = dsp.pickRecordings(T, "train", 4, 8);
            testCase.verifyEqual(a.id, b.id);
            testCase.verifyNotEqual(a.id, c.id);
            rng(5); expected = rand;
            rng(5); dsp.pickRecordings(T, "train", 4, 7);
            testCase.verifyEqual(rand, expected);
        end

        function pickIgnoresExcludedRecordings(testCase)
            T = testCase.fakeTable();
            T.included(T.activityCode == 6) = false;
            pick = dsp.pickRecordings(T, "val", 3, 1);
            testCase.verifyFalse(any(pick.activityCode == 6));
        end

        function pickFailsOnAnEmptySplit(testCase)
            testCase.verifyError(@() dsp.pickRecordings(testCase.fakeTable(), "nope", 3, 1), 'dsp:pick:noRecordings');
        end

        function motionFractionSeparatesStaticFromMoving(testCase)
            vel = (-3:3)';
            staticOnly = struct('mag', [0 0 0 5 0 0 0]' * ones(1, 4), 'velocity', vel, 'velocityAvailable', true);
            movingOnly = struct('mag', [0 0 2 0 2 0 0]' * ones(1, 4), 'velocity', vel, 'velocityAvailable', true);
            mixed = struct('mag', [0 0 3 4 0 0 0]' * ones(1, 4), 'velocity', vel, 'velocityAvailable', true);
            testCase.verifyEqual(dsp.motionFraction(staticOnly, 0.5), 0);
            testCase.verifyEqual(dsp.motionFraction(movingOnly, 0.5), 1);
            % powers 9 (at -1) and 16 (at 0): motion share 9/25
            testCase.verifyEqual(dsp.motionFraction(mixed, 0.5), 9 / 25, 'AbsTol', 1e-12);
        end

        function motionFractionNeedsVelocityAndEnergy(testCase)
            noVel = struct('mag', ones(3, 3), 'velocity', [], 'velocityAvailable', false);
            testCase.verifyError(@() dsp.motionFraction(noVel, 0.1), 'dsp:motion:noVelocity');
            zero = struct('mag', zeros(3, 3), 'velocity', (-1:1)', 'velocityAvailable', true);
            testCase.verifyError(@() dsp.motionFraction(zero, 0.1), 'dsp:motion:noPower');
        end

        function clutterRemovalRaisesTheMotionFraction(testCase)
            nts = 128; nc = 3000;
            n = (0:nts-1)'; m = 0:nc-1;
            x = 5 * exp(1j * 2 * pi * 22 * n / nts) .* ones(1, nc) ...
                + exp(1j * 2 * pi * 16 * n / nts) .* exp(1j * 2 * pi * 100 * m / 1000);
            rec = dsp.makeRecording(5.8e9, 1, nts, 4e8, real(x(:)), imag(x(:)));
            sOff = dsp.makeSettings(struct('clutter', struct('method', 'none')));
            sOn = dsp.makeSettings();
            off = dsp.motionFraction(dsp.spectrogramOf(rec, sOff), 0.15);
            on = dsp.motionFraction(dsp.spectrogramOf(rec, sOn), 0.15);
            testCase.verifyLessThan(off, 0.1);
            testCase.verifyGreaterThan(on, 0.9);
        end

        function preprocessRecordingMatchesSpectrogramOf(testCase)
            nts = 128; nc = 1500;
            n = (0:nts-1)'; m = 0:nc-1;
            x = exp(1j * 2 * pi * 16 * n / nts) .* exp(1j * 2 * pi * 80 * m / 1000) + 0.1;
            rec = dsp.makeRecording(5.8e9, 1, nts, 4e8, real(x(:)), imag(x(:)));
            s = dsp.makeSettings();
            [pre, sel] = dsp.preprocessRecording(rec, s);
            sp = dsp.microDoppler(pre, sel, s);
            testCase.verifyEqual(sp.mag, dsp.spectrogramOf(rec, s).mag);
        end
    end
end
