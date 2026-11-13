function f = motionFraction(sp, velocityCut)
%MOTIONFRACTION Share of a spectrogram's energy that lies away from zero velocity.
%   f = dsp.motionFraction(sp, 0.15) where sp comes from dsp.stft or dsp.microDoppler.
%   Energy is magnitude squared; "motion" is |velocity| above velocityCut (m/s).
%   Static returns sit at zero velocity, so a spectrogram dominated by them has a
%   small fraction and one showing the moving person has a large one.
arguments
    sp (1,1) struct
    velocityCut (1,1) double {mustBeNonnegative}
end
if ~sp.velocityAvailable
    error('dsp:motion:noVelocity', 'The spectrogram has no velocity axis.');
end
p = sp.mag .^ 2;
total = sum(p(:));
if total <= 0
    error('dsp:motion:noPower', 'The spectrogram has no energy.');
end
away = abs(sp.velocity(:)) > velocityCut;
f = sum(p(away, :), 'all') / total;
end
