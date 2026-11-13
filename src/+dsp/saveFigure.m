function ok = saveFigure(fig, file, resolution)
%SAVEFIGURE Save a figure as an image, with a fallback and clear diagnostics.
%   ok = dsp.saveFigure(fig, file)
%   ok = dsp.saveFigure(fig, file, resolution)
%
%   Waits for the figure to finish drawing, creates the folder if needed and
%   saves with exportgraphics. If fig is not a valid figure (some MATLAB Online
%   sessions lose figure handles), the most recently created open figure is saved
%   instead and a warning says so. If nothing can be saved, ok is false and the
%   warning dsp:saveFigure:failed explains what was found.
arguments
    fig
    file (1,1) string
    resolution (1,1) double {mustBePositive} = 150
end
folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder)
    mkdir(folder);
end
drawnow;
ok = false;

if isscalar(fig) && isgraphics(fig, 'figure')
    try
        exportgraphics(fig, file, 'Resolution', resolution);
        ok = true;
    catch err
        warning('dsp:saveFigure:exportFailed', 'Could not save %s: %s', file, err.message);
    end
end

if ~ok
    open = findall(0, 'Type', 'figure');
    if ~isempty(open)
        try
            exportgraphics(open(1), file, 'Resolution', resolution);
            ok = true;
            warning('dsp:saveFigure:usedNewest', ...
                'The figure handle was not valid, so the newest open figure was saved as %s.', file);
        catch
        end
    end
end

if ok
    fprintf('Saved %s\n', file);
else
    warning('dsp:saveFigure:failed', ...
        'Could not save %s (handle class %s, %d open figures).', file, class(fig), numel(findall(0, 'Type', 'figure')));
end
end
