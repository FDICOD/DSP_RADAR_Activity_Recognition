function e = velocityExtent(dop)
%VELOCITYEXTENT How wide a Doppler spectrum is, in velocity.
%   e = dsp.velocityExtent(dop) where dop comes from dsp.dopplerSpectrum.
%   The spectrum's power (magnitude squared) is treated as a distribution over
%   velocity:
%     v95    the speed below which 95% of the power lies (m/s)
%     vRms   the root-mean-square velocity (m/s)
%   Both grow with the speed of the moving parts of the body.
if ~dop.velocityAvailable
    error('dsp:extent:noVelocity', 'The spectrum has no velocity axis (carrier frequency unknown).');
end
v = dop.velocity(:);
p = dop.mag(:) .^ 2;
total = sum(p);
if total <= 0
    error('dsp:extent:noPower', 'The spectrum has no power.');
end

[speed, order] = sort(abs(v));
cum = cumsum(p(order)) / total;
e.v95 = speed(find(cum >= 0.95, 1));
e.vRms = sqrt(sum(p .* v .^ 2) / total);
end
