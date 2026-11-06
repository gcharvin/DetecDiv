function analysisLayoutTest(previewPath)
%ANALYSISLAYOUTTEST Concurrent inspectors, native Close and saved geometry.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanFolder = onCleanup(@()rmdir(folder,'s'));
file = fullfile(folder,'layout.json'); hiddenFile = fullfile(folder,'hidden.json');
startup = detecdivui.startupGuard('begin'); %#ok<NASGU>
host = launch(file); cleanHost = onCleanup(@()safeDelete(host));
objectsFigure = host.widgetFigure('Objects'); dataFigure = host.widgetFigure('Data');
control = uilabel(objectsFigure,'Text','Retained object selection','Tag','retained-object-control');
assert(~host.isWidgetVisible('Objects') && ~host.isWidgetVisible('Data'));
initial = host.snapshot(); legacy = initial; legacy.widgets = rmfield(legacy.widgets,'objects');
writeJSON(fullfile(folder,'legacy.json'),legacy);
assert(host.restoreLayout(fullfile(folder,'legacy.json')) && ~host.isWidgetVisible('Objects'));
assertGeometry(host.App.DocumentLayout,initial.layout.documentLayout);

% Opening either inspector splits only its anchor tile. Existing custom
% column widths, Projects and the other inspector remain in place.
custom = detecdivui.WorkspaceLayout.geometry(host.App.DocumentLayout);
custom.columnWeights = [.25 .50 .25]; host.App.DocumentLayout = custom;
waitUntil(@()max(abs(reshape(host.App.DocumentLayout.columnWeights,1,[])-[.25 .50 .25]))<.002);
before = host.snapshot();
before = before.layout.documentLayout;
host.openObjects(); first = host.snapshot(); first = first.layout.documentLayout;
assert(host.Widgets.display.Showing && host.Widgets.objects.Showing, ...
    'Objects must appear alongside the actual Display controls.');
assertBelow(first,'workspace_display','workspace_objects');
assertSameBounds(first,before,'workspace_projects'); assertSameBounds(first,before,'workspace_image');
assert(max(abs(first.columnWeights(:)-before.columnWeights(:)))<.002);
host.openData(); arranged = host.snapshot(); arranged = arranged.layout.documentLayout;
assertBelow(arranged,'workspace_image','workspace_data');
assertSameBounds(arranged,first,'workspace_objects'); assertSameBounds(arranged,first,'workspace_display');
assertSameBounds(arranged,before,'workspace_projects');
assert(host.isWidgetVisible('Display') && host.isWidgetVisible('Objects') && host.isWidgetVisible('Data'));
assert(host.Widgets.display.Showing && host.Widgets.objects.Showing && host.Widgets.data.Showing, ...
    'Opening Data hid another inspector behind a different tab.');
host.saveLayout(file);

% Native Close is vetoed and hiding runs on the next event turn, retaining
% the FigureDocument, figure and all controls for reopening through View.
assert(host.Widgets.objects.Closable);
host.Widgets.objects.close(); waitUntil(@()~host.isWidgetVisible('Objects'));
assert(isvalid(host.Widgets.objects) && isvalid(objectsFigure) && isvalid(control));
host.openObjects(); assert(isequal(control,findall(objectsFigure,'Tag','retained-object-control')));
assertGeometry(host.App.DocumentLayout,arranged);
close(dataFigure); waitUntil(@()~host.isWidgetVisible('Data')); assert(isvalid(dataFigure));
host.openData(); assertGeometry(host.App.DocumentLayout,arranged);
host.setDocked('Data',false); host.Widgets.data.WindowBounds = [150 150 650 320];
waitUntil(@()host.Widgets.data.Opened && ~host.isDocked('Data'));
host.snapshot(); bounds = host.Widgets.data.WindowBounds;
host.Widgets.data.close();
waitUntil(@()~host.isWidgetVisible('Data'));
assert(~host.isWidgetVisible('Data'),'Native Close did not hide the floating document.');
assert(~host.isDocked('Data'),'Hiding a floating document changed its docking state.');
host.openData(); assert(~host.isDocked('Data') && isvalid(dataFigure));
assert(max(abs(host.Widgets.data.WindowBounds-bounds))<5, ...
    sprintf('Floating bounds changed from %s to %s.',mat2str(bounds),mat2str(host.Widgets.data.WindowBounds)));

% A hidden inspector keeps its placement across a new host as well. Older
% layout records gain Objects invisibly rather than resetting their grid.
assert(host.restoreLayout(file)); host.closeWidget('Objects'); host.saveLayout(hiddenFile);
again = launch(hiddenFile); cleanAgain = onCleanup(@()safeDelete(again));
assert(~again.isWidgetVisible('Objects') && again.isWidgetVisible('Data'));
again.openObjects(); assertGeometry(again.App.DocumentLayout,arranged);
if ~isempty(previewPath), again.show(); again.capture(previewPath); end
assert(again.App.close(),'Widget close vetoes must not veto approved whole-app closure.');
disp('Analysis layout test passed: concurrent Objects/Display, Data below Image, custom geometry, native close/reopen, floating close, hidden placement persistence, legacy migration and whole-app closure.');
end

function host = launch(file)
host = detecdivui.DockingHost(file,false);
view = host.menu([],'View');
for name = {'Projects','Image','Display','Pipeline','Objects','Data'}, host.widgetMenu(view,name{1}); end
host.addDockMenus(view); host.start('off');
host.show();
menus = timerfindall('Tag','DetecDivDockMenu'); if ~isempty(menus), stop(menus); end
end
function assertBelow(layout,top,bottom)
a = bounds(layout,top); b = bounds(layout,bottom);
assert(abs(a(1)-b(1))<.002 && abs(a(3)-b(3))<.002 && abs(a(2)+a(4)-b(2))<.002);
assert(a(4)>0 && b(4)>0);
end
function assertSameBounds(a,b,id)
assert(max(abs(bounds(a,id)-bounds(b,id)))<.002,['Unrelated tile moved: ' id]);
end
function assertGeometry(a,b)
for name = {'projects','image','display','pipeline','objects','data'}
    id = ['workspace_' name{1}];
    if isempty(detecdivui.WorkspaceLayout.tile(b,id)), continue; end
    assertSameBounds(a,b,id);
end
end
function value = bounds(layout,id)
tile = detecdivui.WorkspaceLayout.tile(layout,id); assert(~isempty(tile),['Missing document: ' id]);
[rows,columns] = find(layout.tileCoverage==tile);
x = reshape(layout.columnWeights,1,[]); x = x/sum(x);
y = reshape(layout.rowWeights,1,[]); y = y/sum(y);
value = [sum(x(1:min(columns)-1)) sum(y(1:min(rows)-1)) ...
    sum(x(min(columns):max(columns))) sum(y(min(rows):max(rows)))];
end
function writeJSON(file,value)
fid = fopen(file,'w'); assert(fid>=0); clean = onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(value));
end
function safeDelete(value)
if ~isempty(value) && isvalid(value), delete(value); end
end
function waitUntil(condition)
started = tic;
while ~condition()
    assert(toc(started)<12,'The native layout update did not settle.'); pause(.05); drawnow;
end
end
