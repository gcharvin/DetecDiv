function imageAxesTest()
%IMAGEAXESTEST Deleted native interaction state is repaired before plotting.
fig = uifigure('Visible','off'); cleanup = onCleanup(@()deleteIfValid(fig));
grid = uigridlayout(fig,[2 2]);
menu = uicontextmenu(fig); uimenu(menu,'Text','Image context');
ax = uiaxes(grid,'Toolbar',[],'Tag','image-axes-healthy');
initialized = detecdivui.ImageAxes.initialize(ax);
assert(initialized == ax && isvalid(ax.InteractionContainer));
assertToolbar(ax);

% Reproduce MATLAB's exact stale-handle listener failure. Real UIAxes can
% automatically clear a deleted native container to []; the fixture deletes
% it between MATLAB's nonempty/property checks and its listener creation.
broken = uiaxes(grid,'Color',[.07 .09 .11],'Tag','image-axes-broken');
broken.ContextMenu = menu; broken.XTick = []; broken.YTick = [];
broken.XLim = [2 12]; broken.YLim = [3 14]; broken.UserData = struct('source','metadata');
broken.Layout.Row = 2; broken.Layout.Column = [1 2]; broken.Units = 'pixels';
interaction = broken.InteractionContainer;
stale = detecdivui.testsupport.StaleAxes(interaction);
strategy = matlab.ui.axestoolbar.internal.AxesBasedModeStrategy();
cleanStrategy = onCleanup(@()deleteIfValid(strategy));
failed = false;
try
    strategy.createInteractionModeListener(stale,ax.Toolbar);
catch err
    names = string({err.stack.name});
    failed = any(contains(names,'AxesBasedModeStrategy') & contains(names,'createInteractionModeListener')) && ...
        (contains(lower(err.identifier),'invalidhandle') || contains(lower(err.message),'invalid or deleted object'));
end
assert(failed,'The reported deleted interaction-container failure was not reproduced.');
clear cleanStrategy;
assert(isempty(broken.InteractionContainer) || ~isvalid(broken.InteractionContainer));
recovered = detecdivui.ImageAxes.initialize(broken);
assert(~isgraphics(broken) && isgraphics(recovered) && recovered.Parent == grid);
assert(strcmp(recovered.Tag,'image-axes-broken') && isequal(recovered.Color,[.07 .09 .11]));
assert(recovered.ContextMenu == menu && isempty(recovered.XTick) && isempty(recovered.YTick));
assert(isequal(recovered.XLim,[2 12]) && isequal(recovered.YLim,[3 14]));
assert(recovered.Layout.Row == 2 && isequal(recovered.Layout.Column,[1 2]));
assert(strcmp(recovered.Units,'pixels') && strcmp(recovered.UserData.source,'metadata'));
assertToolbar(recovered);

% The real toolbar callbacks must still enable the native exploration modes.
imagesc(recovered,magic(8)); drawnow nocallbacks;
toolbar = recovered.Toolbar;
pan = findall(toolbar,'Tag','pan'); zoom = findall(toolbar,'Tag','zoom');
pan.ValueChangedFcn(pan,struct('Axes',recovered,'Value','on'));
assert(strcmp(recovered.InteractionContainer.CurrentMode,'pan'));
zoom.ValueChangedFcn(zoom,struct('Axes',recovered,'Value','on'));
assert(strcmp(recovered.InteractionContainer.CurrentMode,'zoom'));
zoom.ValueChangedFcn(zoom,struct('Axes',recovered,'Value','off'));
assert(strcmp(recovered.InteractionContainer.CurrentMode,'none'));

% Existing pixels are never deleted/recreated to repair a toolbar.
pixels = findall(recovered,'Type','image'); data = pixels.CData;
try
    detecdivui.ImageAxes.initialize(recovered);
    error('detecdivui:TestExpectedError','Plotted axes were accepted for reconstruction.');
catch err
    assert(strcmp(err.identifier,'detecdivui:ImageAxesNotEmpty'));
end
assert(isgraphics(recovered) && isequal(pixels.CData,data));

% An explicit public CreateFcn supplies a repeated fault. The helper
% gets one replacement attempt, removes both failed empty axes and reports
% the first error with the replacement failure attached.
created = 0;
before = numel(findall(grid,'Type','axes'));
fault = uiaxes(grid,'Toolbar',[],'Tag','image-axes-repeat','CreateFcn',@deleteInteraction);
assert(created == 1,'UIAxes did not execute the explicit axes CreateFcn fault.');
try
    detecdivui.ImageAxes.initialize(fault);
    error('detecdivui:TestExpectedError','The repeated native-state failure was accepted.');
catch err
    assert(strcmp(err.identifier,'detecdivui:ImageAxesInteraction') && ~isempty(err.cause));
end
assert(created == 2 && ~isgraphics(fault));
assert(numel(findall(grid,'Type','axes')) == before);
disp('Image axes test passed: exact native listener failure, bounded empty-axis recovery, preserved metadata/layout, live zoom/pan, protected pixels and repeated-failure cleanup.');

    function deleteInteraction(source,~)
        if strcmp(source.Tag,'image-axes-repeat')
            created = created+1; delete(source.InteractionContainer);
        end
    end
end

function assertToolbar(ax)
toolbar = ax.Toolbar;
assert(isscalar(toolbar) && isvalid(toolbar) && strcmp(toolbar.Visible,'on'));
% R2026a combines zoom-in/out in its default "zoom" toggle.
for tag = {'pan','zoom','restoreview'}
    assert(isscalar(findall(toolbar,'Tag',tag{1})),'Missing native toolbar action: %s',tag{1});
end
end

function deleteIfValid(value)
if ~isempty(value) && isvalid(value), delete(value); end
end
