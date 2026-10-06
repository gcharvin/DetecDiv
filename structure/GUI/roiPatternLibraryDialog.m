classdef roiPatternLibraryDialog < handle
    % Compact popup: selecting for a run and publishing a preset are separate.
    properties
        UIFigure
        Result struct = struct()
        Action char = 'cancel'
    end
    properties (Access = private)
        Folder char = ''
        Params struct = struct()
        Entries struct = struct([])
        Selected double = 1
        Cards = gobjects(0)
        Gallery
        UseButton
        ReplaceButton
        SaveButton
        ReadOnly logical = false
    end
    methods
        function app = roiPatternLibraryDialog(folder, params, nodeId, canEdit, readOnly)
            if nargin < 5, readOnly = false; end
            app.Folder = char(string(folder)); app.Params = params;
            app.ReadOnly = readOnly;
            library = pipelineRoiPatternLibrary('load',folder); app.Entries = library.entries;
            app.UIFigure = uifigure('Name',['Pattern for run: ' char(string(nodeId))], ...
                'Position',[150 150 850 620], 'CloseRequestFcn',@(~,~)app.finish('cancel'));
            grid = uigridlayout(app.UIFigure,[5 1]);
            grid.RowHeight = {32,40,'1x',36,36}; grid.Padding = [12 12 12 12];
            uilabel(grid,'Text','Choose a pattern for this run. Create / test opens the image editor.', ...
                'FontWeight','bold');
            settings = sprintf('Detection: channel %s | frame %s | threshold %s. Source details are shown on each thumbnail.', ...
                app.textField(params,'channel'),app.textField(params,'referenceFrame'),app.textField(params,'threshold'));
            uilabel(grid,'Text',settings,'WordWrap','on','Interpreter','none');
            app.Gallery = uigridlayout(grid,[1 3]); app.Gallery.Layout.Row = 3;
            app.Gallery.ColumnWidth = {'1x','1x','1x'}; app.Gallery.Scrollable = 'on';
            tools = uigridlayout(grid,[1 3]); tools.Layout.Row = 4;
            tools.ColumnWidth = {'1x','1x','1x'}; tools.Padding = [0 0 0 0];
            edit = uibutton(tools,'Text','Create / test on data...', 'Tag','PatternLibraryEdit', ...
                'ButtonPushedFcn',@(~,~)app.finish('edit'));
            edit.Enable = app.onOff(canEdit && ~readOnly);
            app.SaveButton = uibutton(tools,'Text','Save current as new...', 'Tag','PatternLibrarySave', ...
                'ButtonPushedFcn',@(~,~)app.saveNew());
            app.ReplaceButton = uibutton(tools,'Text','Replace selected preset...', 'Tag','PatternLibraryReplace', ...
                'ButtonPushedFcn',@(~,~)app.replaceSelected());
            buttons = uigridlayout(grid,[1 3]); buttons.Layout.Row = 5;
            buttons.ColumnWidth = {'1x',110,150}; buttons.Padding = [0 0 0 0];
            uilabel(buttons,'Text','Library changes apply to future choices; each run keeps its own copy.', ...
                'WordWrap','on','FontColor',[.35 .35 .35]);
            uibutton(buttons,'Text','Cancel','Tag','PatternLibraryCancel', ...
                'ButtonPushedFcn',@(~,~)app.finish('cancel'));
            app.UseButton = uibutton(buttons,'Text','Use for this run','Tag','PatternLibraryUse', ...
                'ButtonPushedFcn',@(~,~)app.finish('use'));
            if readOnly, app.UseButton.Text = 'Close review'; end
            app.rebuild();
        end
        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure), delete(app.UIFigure); end
        end
    end
    methods (Access = private)
        function rebuild(app)
            delete(app.Gallery.Children);
            n = numel(app.Entries)+1; app.Cards = gobjects(1,n);
            app.Gallery.RowHeight = repmat({220},1,ceil(n/3));
            for i = 1:n
                if i == 1
                    p = app.currentPattern(); name = 'Current run pattern';
                    if isfield(app.Params,'patternPreset') && isfield(app.Params.patternPreset,'name')
                        name = sprintf('Current run: %s (revision %d)',app.Params.patternPreset.name,app.Params.patternPreset.revision);
                    end
                else
                    entry = app.Entries(i-1); p = entry.pattern;
                    name = sprintf('%s (revision %d)',entry.name,entry.revision);
                end
                card = uipanel(app.Gallery,'BorderType','line');
                card.Layout.Row = ceil(i/3); card.Layout.Column = mod(i-1,3)+1;
                app.Cards(i) = card;
                g = uigridlayout(card,[3 1]); g.RowHeight = {'1x',48,30}; g.Padding = [6 6 6 6];
                ax = uiaxes(g); ax.Layout.Row = 1; ax.XTick = []; ax.YTick = []; ax.Toolbar.Visible = 'off';
                ax.Interactions = []; ax.ButtonDownFcn = @(~,~)app.select(i);
                if app.hasImage(p)
                    h = imagesc(ax,double(p.image)); colormap(ax,gray(256)); axis(ax,'image'); axis(ax,'off');
                    h.ButtonDownFcn = @(~,~)app.select(i);
                    sizeText = sprintf('%d x %d px',size(p.image,2),size(p.image,1));
                else
                    sizeText = 'No image patch yet';
                    text(ax,.5,.5,'Draw a pattern first','HorizontalAlignment','center'); axis(ax,'off');
                end
                details = sprintf('%s | %s | frame %s\n%s',sizeText,app.textField(p,'fovId'), ...
                    app.textField(p,'referenceFrame'),app.textField(p,'channel'));
                source = uilabel(g,'Text',details,'WordWrap','on','Interpreter','none');
                if isfield(p,'sourcePath'), source.Tooltip = char(string(p.sourcePath)); end
                uibutton(g,'Text',name,'Tag',sprintf('PatternChoice%d',i), ...
                    'Tooltip',name,'ButtonPushedFcn',@(~,~)app.select(i));
            end
            app.select(min(app.Selected,n));
            app.SaveButton.Enable = app.onOff(~app.ReadOnly && ~isempty(app.Folder) && isfolder(app.Folder) && app.hasImage(app.currentPattern()));
            app.SaveButton.Tooltip = 'Save the current run motif under a new name. Existing names require an explicit replacement.';
            app.ReplaceButton.Tooltip = 'Replace the selected library preset with the current run motif, after confirmation.';
        end
        function select(app,i)
            app.Selected = i;
            for j = 1:numel(app.Cards)
                app.Cards(j).BackgroundColor = [.94 .94 .94];
                app.Cards(j).Children.BackgroundColor = [.94 .94 .94];
                app.Cards(j).Title = '';
            end
            app.Cards(i).BackgroundColor = [.75 .87 1];
            app.Cards(i).Children.BackgroundColor = [.75 .87 1];
            app.Cards(i).Title = 'Selected for this run';
            if app.ReadOnly, app.Cards(i).Title = 'Preview'; end
            p = app.currentPattern(); if i > 1, p = app.Entries(i-1).pattern; end
            app.UseButton.Enable = app.onOff(app.ReadOnly || app.hasImage(p));
            app.ReplaceButton.Enable = app.onOff(~app.ReadOnly && i > 1 && app.hasImage(app.currentPattern()));
        end
        function p = currentPattern(app)
            p = struct();
            if isfield(app.Params,'pattern') && isstruct(app.Params.pattern) && ~isempty(app.Params.pattern)
                p = app.Params.pattern(1);
            elseif isfield(app.Params,'patternList') && ~isempty(app.Params.patternList)
                idx = 1;
                if isfield(app.Params,'activePatternIndex') && ~isempty(app.Params.activePatternIndex)
                    idx = min(max(1,round(app.Params.activePatternIndex)),numel(app.Params.patternList));
                end
                p = app.Params.patternList(idx);
            end
        end
        function saveNew(app)
            if app.ReadOnly, return; end
            answer = inputdlg('Name for the current run pattern:','Save new pattern',1,{'Pattern'});
            if isempty(answer), return; end
            try
                entry = pipelineRoiPatternLibrary('save',app.Folder,answer{1},app.currentPattern());
                app.Params = pipelineApplyRoiPatternPreset(app.Params,entry);
                library = pipelineRoiPatternLibrary('load',app.Folder); app.Entries = library.entries;
                app.Selected = 1; app.rebuild();
            catch ME
                uialert(app.UIFigure,ME.message,'Save pattern');
            end
        end
        function replaceSelected(app)
            if app.ReadOnly, return; end
            if app.Selected < 2, return; end
            old = app.Entries(app.Selected-1);
            msg = sprintf('Replace "%s" revision %d with the current run motif?\nThis creates revision %d.',old.name,old.revision,old.revision+1);
            choice = uiconfirm(app.UIFigure,msg,'Replace library pattern', ...
                'Options',{'Replace','Cancel'},'DefaultOption','Cancel','CancelOption','Cancel');
            if ~strcmp(choice,'Replace'), return; end
            try
                entry = pipelineRoiPatternLibrary('save',app.Folder,old.name,app.currentPattern(),old.id,old.revision);
                app.Params = pipelineApplyRoiPatternPreset(app.Params,entry);
                library = pipelineRoiPatternLibrary('load',app.Folder); app.Entries = library.entries;
                app.Selected = 1; app.rebuild();
            catch ME
                uialert(app.UIFigure,ME.message,'Replace pattern');
            end
        end
        function finish(app,action)
            if app.ReadOnly, action = 'cancel'; end
            app.Action = action;
            app.Result = app.Params;
            if ~strcmp(action,'cancel') && app.Selected > 1
                app.Result = pipelineApplyRoiPatternPreset(app.Params,app.Entries(app.Selected-1));
            end
            app.UIFigure.Visible = 'off'; uiresume(app.UIFigure);
        end
    end
    methods (Static, Access = private)
        function tf = hasImage(p)
            tf = isstruct(p) && isfield(p,'image') && isnumeric(p.image) && ~isempty(p.image) && ismatrix(p.image);
        end
        function s = textField(p,key)
            s = '-';
            if isfield(p,key) && ~isempty(p.(key)), s = char(join(string(p.(key)),', ')); end
        end
        function s = onOff(tf)
            s = 'off'; if tf, s = 'on'; end
        end
    end
end
