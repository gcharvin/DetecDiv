function restored = score_restoreMaskInteraction(app)
%SCORE_RESTOREMASKINTERACTION Re-arm mask selection after MATLAB tools run.
% Pan temporarily owns the figure mouse callbacks.  In particular, turning
% pan off can restore the callback snapshot taken when pan was enabled,
% thereby replacing Score's mask callback with an empty/stale value.  Keep
% this recovery in one public helper so every interaction boundary applies
% the same cleanup.

restored = false;
try
    if ~score_isEditMode(app) || ~isprop(app, 'ImageFigure') || ...
            isempty(app.ImageFigure) || ~isgraphics(app.ImageFigure)
        return;
    end

    fig = app.ImageFigure;
    if localPanIsEnabled(fig)
        % Pan legitimately owns the callbacks until the user turns it off.
        return;
    end

    % A mouse-up outside the figure, or an exception in a nested painting
    % callback, may leave these callbacks installed indefinitely.
    fig.WindowButtonMotionFcn = '';
    fig.WindowButtonUpFcn = '';
    fig.WindowButtonDownFcn = ...
        @(src,event) score_paintOverlay(src,event,app);
    fig.Pointer = 'arrow';
    if exist('iptPointerManager', 'file') == 2
        iptPointerManager(fig, 'enable');
    end
    restored = true;
catch ME
    warning('score:MaskInteractionRecovery', ...
        'Could not restore mask selection callbacks: %s', ME.message);
end
end

function tf = localPanIsEnabled(fig)
tf = false;
try
    panMode = pan(fig);
    tf = strcmpi(char(string(panMode.Enable)), 'on');
catch
end
end
