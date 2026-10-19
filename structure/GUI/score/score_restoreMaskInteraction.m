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
    if localPanIsEnabled(app,fig)
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

function tf = localPanIsEnabled(app,fig)
tf = false;
% Browser-based Pan in R2026a can be active while the legacy pan(fig)
% accessor reports off. Score's own toggle must take precedence so mouse
% recovery does not try to replace callbacks still owned by that mode.
try
    if isprop(app,'PanButton') && ~isempty(app.PanButton) && ...
            isvalid(app.PanButton) && app.PanButton.Value
        tf = true;
        return;
    end
catch
end
try
    panMode = pan(fig);
    tf = strcmpi(char(string(panMode.Enable)), 'on');
catch
end
end
