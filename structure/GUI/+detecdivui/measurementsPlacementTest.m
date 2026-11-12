function measurementsPlacementTest()
%MEASUREMENTSPLACEMENTTEST Tabbed default and one-time old-layout migration.
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
startup=detecdivui.startupGuard('begin'); %#ok<NASGU>
h=detecdivui.DockingHost('',false); cleanup=onCleanup(@()delete(h)); h.start('on');
initial=h.snapshot(); original=initial.layout.documentLayout;
h.openMeasurements(); assertRight(h);
current=h.App.DocumentLayout;
assert(isequal(current.tileCoverage,original.tileCoverage)&&isequal(current.rowWeights,original.rowWeights));
h.closeWidget('Measurements'); h.openMeasurements(); assertRight(h);

% Reproduce the old automatic split, with the user's separate Annotations
% pane between Image and Measurements. Only Measurements changes group.
[old,changed]=detecdivui.WorkspaceLayout.below(original,'workspace_image','workspace_measurements',.6); assert(changed);
[old,changed]=detecdivui.WorkspaceLayout.below(old,'workspace_image','workspace_objects',.6); assert(changed);
legacy=h.snapshot(); legacy=rmfield(legacy,'measurementsLayoutVersion'); legacy.hiddenLayouts=struct();
legacy.layout.documentLayout=old; legacy.widgets.measurements.visible=true; legacy.widgets.measurements.placed=true;
legacy.widgets.objects.visible=true; legacy.widgets.objects.placed=true;
file=fullfile(folder,'legacy.json'); write(file,legacy); assert(h.restoreLayout(file),h.LastLayoutError); assertRight(h);
layout=h.App.DocumentLayout;
assert(detecdivui.WorkspaceLayout.isBelowImage(layout,'workspace_objects'),'Annotations moved with Measurements.');
assert(~detecdivui.WorkspaceLayout.isBelowImage(layout,'workspace_measurements'));
assertNoEmptyTiles(layout);

% Hidden old defaults must not return to the former split when reopened.
h.closeWidget('Measurements'); hidden=h.snapshot(); hidden=rmfield(hidden,'measurementsLayoutVersion');
layout=hidden.layout.documentLayout;
[old,changed]=detecdivui.WorkspaceLayout.below(layout,'workspace_image','workspace_measurements',.6); assert(changed);
hidden.hiddenLayouts.measurements=struct('visible',old,'hidden',layout);
hidden.widgets.measurements.placed=true;
write(file,hidden); assert(h.restoreLayout(file)&&~h.isWidgetVisible('Measurements'));
h.openMeasurements(); assertRight(h); assertNoEmptyTiles(h.App.DocumentLayout);

% After migration, a deliberately saved custom position is user-owned.
h.resetLayout(); h.openMeasurements();
manual=detecdivui.WorkspaceLayout.tabWith(h.App.DocumentLayout,'workspace_image','workspace_measurements');
[manual,changed]=detecdivui.WorkspaceLayout.below(manual,'workspace_image','workspace_measurements',.6); assert(changed);
h.App.DocumentLayout=manual;
custom=h.snapshot(); custom.hiddenLayouts=struct();
assert(detecdivui.WorkspaceLayout.isBelowImage(custom.layout.documentLayout,'workspace_measurements'));
write(file,custom); assert(h.restoreLayout(file),h.LastLayoutError);
assert(detecdivui.WorkspaceLayout.isBelowImage(h.App.DocumentLayout,'workspace_measurements'));
h.openMeasurements(); assert(detecdivui.WorkspaceLayout.isBelowImage(h.App.DocumentLayout,'workspace_measurements'));
h.closeWidget('Measurements'); h.openMeasurements();
assert(detecdivui.WorkspaceLayout.isBelowImage(h.App.DocumentLayout,'workspace_measurements'));

h.setDocked('Measurements',false); floating=h.snapshot();
floating=rmfield(floating,'measurementsLayoutVersion'); write(file,floating);
assert(h.restoreLayout(file)); h.openMeasurements();
assert(~h.isDocked('Measurements')&&h.Widgets.measurements.Showing,'A saved floating widget was redocked automatically.');
disp('Measurements placement passed: right tab group, unchanged image area, legacy visible/hidden split migration, retained Annotations, custom positions and floating windows.');
end
function assertRight(h)
layout=h.App.DocumentLayout;
assert(detecdivui.WorkspaceLayout.tile(layout,'workspace_measurements')== ...
    detecdivui.WorkspaceLayout.tile(layout,'workspace_display'));
assert(h.Widgets.measurements.Showing);
end
function assertNoEmptyTiles(layout)
for k=unique(layout.tileCoverage(:))'
    assert(~isempty(layout.tileOccupancy(k).children),'Migration left an empty workspace tile.');
end
end
function write(path,value)
fid=fopen(path,'w'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(value));
end
