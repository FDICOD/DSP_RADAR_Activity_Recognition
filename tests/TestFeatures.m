classdef TestFeatures < matlab.unittest.TestCase
    methods (Access = private)
        function sp = ridge(~, centreFcn, sigma, energyFcn, nT, dt)
            % Gaussian ridge of power exp(-(v-c)^2/sigma^2) times energyFcn(t):
            % the power distribution over velocity has standard deviation sigma/sqrt(2).
            v = linspace(-6, 6, 241)';
            t = (0:nT-1) * dt;
            mag = zeros(numel(v), nT);
            for k = 1:nT
                mag(:, k) = sqrt(energyFcn(t(k))) * exp(-(v - centreFcn(t(k))) .^ 2 / (2 * sigma ^ 2));
            end
            sp = struct('mag', mag, 'velocity', v, 'velocityAvailable', true, 'timeStep', dt, 'time', t);
        end

        function f = named(~, x, names)
            f = cell2struct(num2cell(x), cellstr(names), 2);
        end
    end

    methods (Test)
        function namesMatchValuesAndAreUniqueAndFinite(testCase)
            sp = testCase.ridge(@(t) 1, 0.5, @(t) 1, 200, 0.01);
            [x, names] = dsp.extractFeatures(sp, dsp.makeSettings());
            testCase.verifySize(x, [1 18]);
            testCase.verifyEqual(numel(names), numel(x));
            testCase.verifyEqual(numel(unique(names)), numel(names));
            testCase.verifyTrue(all(isfinite(x)));
        end

        function constantRidgeGivesItsKnownStatistics(testCase)
            sp = testCase.ridge(@(t) 1, 0.5, @(t) 1, 200, 0.01);
            [x, names] = dsp.extractFeatures(sp, dsp.makeSettings());
            f = testCase.named(x, names);
            testCase.verifyEqual(f.dopCentroid, 1, 'AbsTol', 1e-6);
            testCase.verifyEqual(f.dopSpread, 0.5 / sqrt(2), 'AbsTol', 1e-3);
            testCase.verifyEqual(f.dopSkew, 0, 'AbsTol', 1e-3);
            testCase.verifyEqual(f.dopPeakVelocity, 1, 'AbsTol', 1e-9);
            testCase.verifyEqual(f.dopV95, 1.6, 'AbsTol', 0.06);
            testCase.verifyEqual(f.tCentroidMean, 1, 'AbsTol', 1e-6);
            testCase.verifyEqual(f.tCentroidStd, 0, 'AbsTol', 1e-9);
            testCase.verifyEqual(f.tCentroidRange, 0, 'AbsTol', 1e-9);
            testCase.verifyEqual(f.tSpreadMean, 0.5 / sqrt(2), 'AbsTol', 1e-3);
            testCase.verifyEqual(f.tActiveFraction, 1);
            testCase.verifyEqual(f.tEnergyCentre, 0.5, 'AbsTol', 1e-9);
        end

        function fasterMotionHasLargerSpreadSpeedAndExtent(testCase)
            slow = testCase.ridge(@(t) 0.5, 0.3, @(t) 1, 200, 0.01);
            fast = testCase.ridge(@(t) 3.0, 0.8, @(t) 1, 200, 0.01);
            [xs, names] = dsp.extractFeatures(slow, dsp.makeSettings());
            xf = dsp.extractFeatures(fast, dsp.makeSettings());
            a = testCase.named(xs, names);
            b = testCase.named(xf, names);
            testCase.verifyGreaterThan(b.dopSpread, a.dopSpread);
            testCase.verifyGreaterThan(b.dopV95, a.dopV95);
            testCase.verifyGreaterThan(b.dopPosExtent, a.dopPosExtent);
        end

        function directionShowsInTheSignedFeatures(testCase)
            away = testCase.ridge(@(t) -2, 0.5, @(t) 1, 200, 0.01);
            [x, names] = dsp.extractFeatures(away, dsp.makeSettings());
            f = testCase.named(x, names);
            testCase.verifyLessThan(f.dopCentroid, 0);
            testCase.verifyEqual(f.dopPeakVelocity, -2, 'AbsTol', 1e-9);
            testCase.verifyEqual(f.dopNegExtent, 3.15, 'AbsTol', 0.1);
            testCase.verifyEqual(f.dopPosExtent, 0);
            testCase.verifyLessThan(f.tCentroidMean, 0);
        end

        function periodicEnvelopeIsDetectedAndAHumpIsNot(testCase)
            periodic = testCase.ridge(@(t) 1, 0.5, @(t) 1 + 0.8 * sin(2 * pi * 2 * t), 300, 0.01);
            hump = testCase.ridge(@(t) 1, 0.5, @(t) exp(-((t - 1.5) / 0.4) ^ 2), 300, 0.01);
            flat = testCase.ridge(@(t) 1, 0.5, @(t) 1, 300, 0.01);
            [x, names] = dsp.extractFeatures(periodic, dsp.makeSettings());
            p = testCase.named(x, names).tPeriodicity;
            h = testCase.named(dsp.extractFeatures(hump, dsp.makeSettings()), names).tPeriodicity;
            c = testCase.named(dsp.extractFeatures(flat, dsp.makeSettings()), names).tPeriodicity;
            testCase.verifyGreaterThan(p, 0.6);
            testCase.verifyEqual(h, 0, 'AbsTol', 0.1);
            testCase.verifyEqual(c, 0);
        end

        function burstTimingFeaturesLocateTheBurst(testCase)
            early = testCase.ridge(@(t) 1, 0.5, @(t) exp(-((t - 0.5) / 0.2) ^ 2), 300, 0.01);
            late = testCase.ridge(@(t) 1, 0.5, @(t) exp(-((t - 2.5) / 0.2) ^ 2), 300, 0.01);
            [xe, names] = dsp.extractFeatures(early, dsp.makeSettings());
            xl = dsp.extractFeatures(late, dsp.makeSettings());
            testCase.verifyLessThan(testCase.named(xe, names).tEnergyCentre, 0.3);
            testCase.verifyGreaterThan(testCase.named(xl, names).tEnergyCentre, 0.7);
            testCase.verifyLessThan(testCase.named(xe, names).tActiveFraction, 0.4);
        end

        function amplitudeScaleDoesNotMatter(testCase)
            sp = testCase.ridge(@(t) 1.5, 0.6, @(t) 1 + 0.5 * sin(2 * pi * 1.2 * t), 300, 0.01);
            big = sp;
            big.mag = 1000 * sp.mag;
            testCase.verifyEqual(dsp.extractFeatures(big, dsp.makeSettings()), ...
                dsp.extractFeatures(sp, dsp.makeSettings()), 'AbsTol', 1e-9);
        end

        function groupsCanBeSelected(testCase)
            sp = testCase.ridge(@(t) 1, 0.5, @(t) 1, 200, 0.01);
            sD = dsp.makeSettings(struct('features', struct('groups', "doppler")));
            sT = dsp.makeSettings(struct('features', struct('groups', "temporal")));
            [xd, nd] = dsp.extractFeatures(sp, sD);
            [xt, nt] = dsp.extractFeatures(sp, sT);
            testCase.verifySize(xd, [1 8]);
            testCase.verifyTrue(all(startsWith(nd, "dop")));
            testCase.verifySize(xt, [1 10]);
            testCase.verifyTrue(all(startsWith(nt, "t")));
        end

        function silentSpectrogramGivesFiniteZeros(testCase)
            sp = testCase.ridge(@(t) 1, 0.5, @(t) 1, 100, 0.01);
            sp.mag = zeros(size(sp.mag));
            [x, names, info] = dsp.extractFeatures(sp, dsp.makeSettings());
            testCase.verifyTrue(info.silent);
            testCase.verifyEqual(x, zeros(1, numel(names)));
        end

        function singleFrameSpectrogramStillWorks(testCase)
            sp = testCase.ridge(@(t) 1, 0.5, @(t) 1, 1, 0.01);
            [x, ~, info] = dsp.extractFeatures(sp, dsp.makeSettings());
            testCase.verifyFalse(info.silent);
            testCase.verifyTrue(all(isfinite(x)));
        end

        function invalidInputsAreRejected(testCase)
            sp = testCase.ridge(@(t) 1, 0.5, @(t) 1, 100, 0.01);
            noVel = sp;
            noVel.velocityAvailable = false;
            testCase.verifyError(@() dsp.extractFeatures(noVel, dsp.makeSettings()), 'dsp:features:noVelocity');
            narrow = dsp.makeSettings(struct('features', struct('velocityLimit', 0.01)));
            testCase.verifyError(@() dsp.extractFeatures(sp, narrow), 'dsp:features:bandTooNarrow');
            testCase.verifyError(@() dsp.makeSettings(struct('features', struct('groups', "spectral"))), ...
                'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('features', struct('groups', strings(1, 0)))), ...
                'dsp:settings:invalidValue');
            testCase.verifyError(@() dsp.makeSettings(struct('features', struct('velocityLimit', -1))), ...
                'dsp:settings:invalidValue');
        end

        function aToneInTheRealPipelineHasTheRightVelocity(testCase)
            prf = 1000;
            t = (0:2999) / prf;
            data = exp(1j * 2 * pi * 100 * t);
            s = dsp.makeSettings();
            sp = dsp.stft(data, prf, 5.8e9, s);
            [x, names] = dsp.extractFeatures(sp, s);
            f = testCase.named(x, names);
            expected = 100 * (299792458 / 5.8e9) / 2;
            testCase.verifyEqual(f.dopPeakVelocity, expected, 'AbsTol', 0.05);
            testCase.verifyEqual(f.dopCentroid, expected, 'AbsTol', 0.1);
            testCase.verifyLessThan(f.dopSpread, 0.2);
            testCase.verifyTrue(all(isfinite(x)));
        end

        function featuresAreDeterministic(testCase)
            sp = testCase.ridge(@(t) 1.5, 0.6, @(t) 1 + 0.5 * sin(2 * pi * 1.2 * t), 300, 0.01);
            testCase.verifyEqual(dsp.extractFeatures(sp, dsp.makeSettings()), ...
                dsp.extractFeatures(sp, dsp.makeSettings()));
        end
    end
end
