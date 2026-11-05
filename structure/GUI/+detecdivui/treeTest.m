function treeTest()
%TREETEST Populate the browser after native visible peers have been created.
names = {'ddUiTreeProjectA','ddUiTreeProjectB','ddUiTreePipeline'};
for k = 1:numel(names)
    assert(~evalin('base',sprintf('exist(''%s'',''var'')',names{k})));
end
cleanup = onCleanup(@()evalin('base',['clear ' strjoin(names,' ')]));
project = shallow(); project.io.file = 'Tree experiment A';
for f = 1:4
    project.fov(f) = fov(); project.fov(f).id = sprintf('Position %d',f);
    for r = 1:160
        project.fov(f).roi(r) = roi(sprintf('Trap %d_%d',f,r),[r r 8 8]);
    end
end
second = shallow(); second.io.file = 'Tree experiment B'; second.fov.id = 'Second position';
second.fov.roi = roi('Second trap',[1 1 8 8]);
project.fov(4).roi(160).image = uint16(ones(8));
template = pipelineConstruct(); template.strid = 'Tree template';
assignin('base',names{1},project); assignin('base',names{2},second);
assignin('base',names{3},template);
viewer = detecdiv_ui([],'DiscoverWorkspace',true,'Visible','on', ...
    'LayoutFile','','AutoSaveLayout',false,'RecentPipelinesFile','');
closeViewer = onCleanup(@()delete(viewer));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
assert(numel(findall(tree,'Tag','roi-node')) == 641);
drawnow; pause(.5);
viewer.refreshWorkspace(); % Rebuild again with a live, visible native tree.
nodes = findall(tree,'Tag','roi-node');
assert(numel(nodes) == 641);
assert(all(arrayfun(@(node)isempty(node.NodeData) && isstruct(node.UserData),nodes)));
target = nodes(arrayfun(@(node)node.UserData.project == 1 && ...
    node.UserData.fov == 4 && node.UserData.roi == 160,nodes));
tree.SelectedNodes = target; tree.SelectionChangedFcn(tree,[]);
assert(viewer.Session.Position == 4 && viewer.Session.Zone == 160);
disp('Visible tree test passed: workspace import, 641 ROIs, live rebuild and selection.');
end
