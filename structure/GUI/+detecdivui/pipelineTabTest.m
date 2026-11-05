function pipelineTabTest()
%PIPELINETABTEST Persistent pipeline browser, graph and draft across docking.
resources = containers.Map('KeyType','char','ValueType','any');
cleanup = onCleanup(@()cleanAll(resources));
project = shallow(); project.io.file = 'Pipeline browsing'; project.fov.id = 'Position';
template = pipeline(); template.strid = 'Workspace pipeline';
template.nodes = struct('id','grid','name','Define ROIs','type','roiGrid','pkg','roiGrid', ...
    'func','roiGrid.process','enabled',true,'params',roiGrid.setparam());
original = template.nodes;
baseNames = evalin('base','who');
projectName = matlab.lang.makeUniqueStrings('ddUiBrowserProject',baseNames,namelengthmax);
templateName = matlab.lang.makeUniqueStrings('ddUiBrowserPipeline',[baseNames;{projectName}],namelengthmax);
assignin('base',projectName,project); assignin('base',templateName,template);
cleanPublished = onCleanup(@()evalin('base',['clear ' projectName ' ' templateName]));

first = launch(); resources('first') = first;
selectFromLibrary(first);
widget = first.Pipeline; axes = widget.CompactGraph.Axes;
settings = widget.Setup.values(); settings.runId = 'Retained draft'; settings.frames = '1:2';
widget.Draft.configure(settings); widget.Draft.set('grid','referenceFrame',2); widget.refresh();
savedSettings = widget.Draft.Settings; savedOverrides = widget.Draft.Overrides;
widget.showLibrary(); widget.selectDraft(); checkFirst();
first.Host.setDocked('Pipeline',false); selectFromLibrary(first); checkFirst();
first.Host.setDocked('Pipeline',true); selectFromLibrary(first); checkFirst();
widget.rebindCallbacks(); selectFromLibrary(first); checkFirst();

% Launch another native viewer while the first still owns live callbacks.
% Each viewer keeps its draft although both reference the same source object.
second = launch(); resources('second') = second; selectFromLibrary(second);
other = second.Pipeline.Setup.values(); other.runId = 'Independent draft';
second.Pipeline.Draft.configure(other); second.Pipeline.refresh();
selectFromLibrary(first); checkFirst();
assert(strcmp(second.Pipeline.Draft.Settings.runId,'Independent draft'));
assert(isequaln(template.nodes,original) && isempty(project.processing.pipelineRun));
assert(isKey(resources,'second'));
disp('Pipeline browser test passed: tree and graph without nested tabs, single-click selection, retained drafts, detach/redock and two viewers.');

    function checkFirst()
        assert(widget.CompactGraph.Axes == axes && widget.Template == template);
        assert(isequaln(widget.Draft.Settings,savedSettings) && isequaln(widget.Draft.Overrides,savedOverrides));
        assert(isequaln(template.nodes,original));
    end
    function viewer = launch()
        % Keep an existing test viewer's native menu poll out of CEF startup.
        stopMenus();
        viewer = detecdiv_ui([],'Visible','off','DiscoverWorkspace',true,'LayoutFile','', ...
            'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
        stopMenus();
    end
    function selectFromLibrary(viewer)
        assert(~any(strcmp({viewer.WorkspaceObjects.kind},'pipeline')));
        viewer.Pipeline.showLibrary();
        figure = viewer.widgetFigure('Pipeline');
        tree = findall(figure,'Tag','pipeline-library'); assert(isscalar(tree));
        graph = viewer.Pipeline.CompactGraph.Axes;
        browserPanel = findall(figure,'Tag','pipeline-library-panel');
        graphPanel = findall(figure,'Tag','pipeline-graph-panel');
        assert(isscalar(browserPanel) && isscalar(graphPanel));
        assert(isequal(findall(browserPanel,'Tag','pipeline-library'),tree));
        assert(isequal(findall(graphPanel,'Tag',graph.Tag),graph));
        assert(strcmp(browserPanel.Visible,'on') && strcmp(graphPanel.Visible,'on'));
        assert(isempty(ancestor(tree,'uitab')) && isempty(ancestor(graph,'uitab')));
        assert(isempty(findall(figure,'Tag','pipeline-template')));
        assert(isempty(findall(figure,'Tag','pipeline-run-picker')));
        picker = findall(viewer.Pipeline.SettingsFigure,'Tag','pipeline-run-picker');
        assert(isscalar(picker));
        nodes = findall(tree,'Type','uitreenode'); selected = [];
        for k = 1:numel(nodes)
            data = nodes(k).UserData;
            if isstruct(data) && isfield(data,'kind') && strcmp(data.kind,'open') && isequal(data.template,template)
                selected = nodes(k); break;
            end
        end
        assert(~isempty(selected),'The workspace pipeline was not listed in its browser.');
        tree.SelectedNodes = selected;
        detecdivui.Callback.call(tree.SelectionChangedFcn,tree,struct('SelectedNodes',selected));
        assert(viewer.Pipeline.Template == template);
        assert(strcmp(picker.Value,'draft'));
        assert(viewer.Pipeline.CompactGraph.Axes == graph);
    end
end

function stopMenus()
menus = timerfindall('Tag','DetecDivDockMenu');
if ~isempty(menus), stop(menus); end
end

function cleanAll(resources)
for name = {'second','first'}
    if isKey(resources,name{1})
        viewer = resources(name{1});
        if ~isempty(viewer) && isvalid(viewer), delete(viewer); end
    end
end
end
