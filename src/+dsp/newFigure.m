function f = newFigure(name, position, show)
%NEWFIGURE Create a figure that is shown on screen, or hidden for saving only.
%   f = dsp.newFigure("Range-time", [100 100 1400 520], true)
%   Hidden figures (show = false) are drawn off screen, so they can be saved as
%   images without opening a window. This avoids blank floating windows in some
%   MATLAB Online sessions. Close hidden figures after saving them.
arguments
    name (1,1) string
    position (1,4) double
    show (1,1) logical = true
end
if show
    f = figure('Name', name, 'Position', position);
else
    f = figure('Name', name, 'Position', position, 'Visible', 'off');
end
end
