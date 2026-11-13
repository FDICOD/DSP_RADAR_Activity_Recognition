function [v, available] = velocityAxis(freqHz, carrierHz)
%VELOCITYAXIS Convert Doppler frequency to radial velocity, v = f_D * lambda / 2.
%   [v, available] = dsp.velocityAxis(freqHz, carrierHz)
%   lambda = c / carrierHz (0.0517 m at 5.8 GHz). Positive Doppler gives positive
%   velocity by this formula; the sign convention of the hardware is not assumed.
%   If carrierHz is missing or not positive, v is empty, available is false and
%   the warning dsp:velocity:unavailable is raised; callers should then show Hz.
c = 299792458;
if isempty(carrierHz) || ~isscalar(carrierHz) || ~isfinite(carrierHz) || carrierHz <= 0
    v = [];
    available = false;
    warning('dsp:velocity:unavailable', ...
        'No valid carrier frequency: velocity is unavailable and only Doppler frequency is returned.');
    return
end
wavelength = c / carrierHz;
v = freqHz * wavelength / 2;
available = true;
end
