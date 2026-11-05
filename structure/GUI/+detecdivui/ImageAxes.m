classdef ImageAxes
    % Initialize image toolbars only after their native host is ready.
    methods (Static)
        function ax = initialize(ax)
            assert(isscalar(ax) && isa(ax,'matlab.ui.control.UIAxes') && isgraphics(ax), ...
                'detecdivui:ImageAxes','A live scalar UIAxes is required.');
            assert(isempty(ax.Children),'detecdivui:ImageAxesNotEmpty', ...
                'Initialize the image axes before plotting data.');
            state = detecdivui.ImageAxes.capture(ax); firstError = [];
            for attempt = 1:2
                try
                    assert(detecdivui.ImageAxes.validInteraction(ax), ...
                        'detecdivui:ImageAxesInteraction','The image axes interaction container is invalid.');
                    % Explicit creation avoids the lazy ax.Toolbar getter.
                    toolbar = axtoolbar(ax,'default'); toolbar.Visible = 'on';
                    return;
                catch err
                    if isgraphics(ax) && ~isempty(ax.Children)
                        rethrow(err);
                    end
                    if attempt == 2 && ~isempty(firstError)
                        failure = addCause(firstError,err);
                        try
                            if isgraphics(ax), delete(ax); end
                        catch cleanupError
                            failure = addCause(failure,cleanupError);
                        end
                        rethrow(failure);
                    end
                    if ~detecdivui.ImageAxes.interactionFailure(err) || ~isgraphics(ax)
                        if isgraphics(ax)
                            try
                                delete(ax);
                            catch cleanupError
                                err = addCause(err,cleanupError);
                            end
                        end
                        rethrow(err);
                    end
                    firstError = err;
                    try
                        delete(ax);
                        ax = detecdivui.ImageAxes.recreate(state);
                    catch replacementError
                        rethrow(addCause(firstError,replacementError));
                    end
                end
            end
        end
    end
    methods (Static, Access = private)
        function state = capture(ax)
            state = struct('Parent',ax.Parent,'Units',ax.Units,'Position',ax.Position, ...
                'Grid',false,'Row',[],'Column',[],'Properties',struct());
            if isprop(ax.Layout,'Row') && isprop(ax.Layout,'Column')
                state.Grid = true; state.Row = ax.Layout.Row; state.Column = ax.Layout.Column;
            end
            names = {'Tag','Color','ContextMenu','CreateFcn','XTick','YTick','XLim','YLim','ZLim', ...
                'XDir','YDir','ZDir','Visible','UserData', ...
                'XTickMode','YTickMode','XLimMode','YLimMode','ZLimMode'};
            for k = 1:numel(names), state.Properties.(names{k}) = ax.(names{k}); end
        end
        function ax = recreate(state)
            ax = uiaxes(state.Parent,'Toolbar',[],'Tag',state.Properties.Tag,'CreateFcn',state.Properties.CreateFcn);
            try
                ax.Units = state.Units;
                if state.Grid
                    ax.Layout.Row = state.Row; ax.Layout.Column = state.Column;
                else
                    ax.Position = state.Position;
                end
                for key = fieldnames(state.Properties)'
                    ax.(key{1}) = state.Properties.(key{1});
                end
            catch err
                try
                    if isgraphics(ax), delete(ax); end
                catch cleanupError
                    err = addCause(err,cleanupError);
                end
                rethrow(err);
            end
        end
        function valid = validInteraction(ax)
            valid = true;
            if isprop(ax,'InteractionContainer')
                interaction = ax.InteractionContainer;
                valid = isscalar(interaction) && isa(interaction,'handle') && isvalid(interaction);
            end
        end
        function matches = interactionFailure(err)
            if strcmp(err.identifier,'detecdivui:ImageAxesInteraction'), matches = true; return; end
            names = string({err.stack.name});
            listener = any(contains(names,'AxesBasedModeStrategy') & contains(names,'createInteractionModeListener'));
            invalid = contains(lower(err.identifier),'invalidhandle') || contains(lower(err.message),'invalid or deleted object');
            matches = listener && invalid;
        end
    end
end
