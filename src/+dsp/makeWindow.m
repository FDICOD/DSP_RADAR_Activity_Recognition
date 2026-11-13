function w = makeWindow(name, n)
%MAKEWINDOW Periodic analysis window as a column vector.
%   name is "rect", "hann" or "hamming". The periodic form (denominator n, not
%   n-1) is the one used for spectral analysis with an n-point FFT.
arguments
    name (1,1) string
    n (1,1) double {mustBePositive, mustBeInteger}
end
k = (0:n-1)';
switch lower(name)
    case "rect"
        w = ones(n, 1);
    case "hann"
        w = 0.5 - 0.5 * cos(2 * pi * k / n);
    case "hamming"
        w = 0.54 - 0.46 * cos(2 * pi * k / n);
    otherwise
        error('dsp:makeWindow:unknownWindow', 'Unknown window "%s".', name);
end
end
