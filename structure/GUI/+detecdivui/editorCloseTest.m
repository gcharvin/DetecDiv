function editorCloseTest()
%EDITORCLOSETEST Native clean X-close destroys figures before widget disposal.
project = shallow(); project.fov.id = 'Position';
r = roi('Close',[1 1 8 8]); r.image = zeros(8,8,2,2,'uint16');
r.image(2:5,2:5,2,:) = 1; r.channelid = [1 2];
r.display.channel = {'BF','Mask'}; r.display.indexed = [false true];
r.display.intensity = [1 1 1;0 0 0];
[model,~] = cellModel.fromLegacy(r); r.cellModel = model; r.cellModelInfo.loaded = true;
project.fov.roi = r;
for mode = 1:2
    viewer = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false, ...
        'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
    cleanup = onCleanup(@()delete(viewer));
    tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
    tree.SelectedNodes = findall(tree,'Tag','roi-node'); tree.SelectionChangedFcn(tree,[]);
    if mode == 1, viewer.openTracksTool(); else, viewer.openContourTool(); end
    lastwarn(''); viewer.Host.App.close(); drawnow; pause(.2); drawnow;
    [message,~] = lastwarn;
    assert(~isvalid(viewer),'A clean annotation window did not close.');
    assert(isempty(message),'Closing the annotation window raised a warning: %s',message);
    clear cleanup;
end
assert(isempty(timerfindall('Tag','DetecDivDockMenu')));
disp('Editor close test passed: native clean Tracks/Contours X-close without destructor warnings or leaked menu timers.');
end
