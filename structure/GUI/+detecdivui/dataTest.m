function dataTest(previewPath)
%DATATEST Score plots, immutable snapshots, frame navigation and saved layouts.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); clean = onCleanup(@()rmdir(folder,'s'));
r = roi('Data',[1 1 12 12]); r.path = folder;
r.image = ones(12,12,1,4,'uint16'); r.channelid = 1; r.display.channel = {'BF'};
values = table((1:4)',categorical({'A';'B';'A';'B'}), ...
    {[1 2];[3 4];[5 6];[7 8]},["G1";"S";"G1";"S"], ...
    'VariableNames',{'Signal','State','Vector','Words'});
ds = dataseries(values,{},'groupid','Measurements'); r.data = ds;
ds.plotProperties{1,6} = 'Intensity'; ds.groupProperties = {'Intensity','Image','auto','auto'};
other = roi('Empty',[1 1 12 12]); other.path = folder;
other.image = r.image; other.channelid = 1; other.display.channel = {'BF'};
p = shallow(); p.io.file = 'Data test'; p.fov.id = 'Position'; p.fov.roi = [r other];
file = fullfile(folder,'layout.json');
v = detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false, ...
    'LayoutFile',file,'AutoSaveLayout',false,'RecentProjectsFile','');
cleanup = onCleanup(@()safeDelete(v));
stop(timerfindall('Tag','DetecDivDockMenu'));
assert(~v.Host.isWidgetVisible('Data') && isempty(v.Data.Series));
legacy = v.Host.snapshot(); legacy.widgets = rmfield(legacy.widgets,'data');
fid = fopen(fullfile(folder,'legacy.json'),'w'); fprintf(fid,'%s',jsonencode(legacy)); fclose(fid);
assert(v.Host.restoreLayout(fullfile(folder,'legacy.json')) && ~v.Host.isWidgetVisible('Data'));
tree = findall(v.widgetFigure('Projects'),'Tag','projects-tree'); choose(tree,1);
v.Host.findCommand('Data').invoke();
assert(v.Host.isWidgetVisible('Data') && isempty(v.Data.Series));
assert(v.Host.App.DocumentLayout.gridDimensions.h==2);
v.Data.loadData(); assert(isscalar(v.Data.Series) && v.Data.Series{1}~=ds);
status = findall(v.widgetFigure('Data'),'Tag','data-status');
assert(contains(status.Text,'4 rows'),status.Text);
marker = findall(v.Data.Axes,'Tag','data-frame-marker'); assert(isscalar(marker) && marker.Value==1);
v.Data.navigate(3); assert(v.annotationFrame()==3 && marker.Value==3);
slider = findall(v.Figure,'Tag','time-slider'); slider.Value = 2; slider.ValueChangedFcn(slider,[]);
assert(marker.Value==2);
variable = findall(v.widgetFigure('Data'),'Tag','data-variable');
variable.Value = 'State'; variable.ValueChangedFcn(variable,[]);
assert(isequal(string(v.Data.Axes.YTickLabel),["A";"B"]),status.Text);
variable.Value = 'Words'; variable.ValueChangedFcn(variable,[]);
assert(isequal(string(v.Data.Axes.YTickLabel),["G1";"S"]),status.Text);
group = findall(v.widgetFigure('Data'),'Tag','data-group');
group.Value = 'Intensity'; group.ValueChangedFcn(group,[]);
assert(isscalar(findall(v.Data.Axes,'Type','image')),status.Text);
v.Data.navigate(3); assert(v.annotationFrame()==3);
variable.Value = 'Vector'; variable.ValueChangedFcn(variable,[]);
curves = findall(v.Data.Axes,'Type','line'); assert(numel(curves)==4,status.Text);
drawnow;
assert(v.Data.Axes.YLim(2)>=8 && v.Data.Axes.YLim(1)<=1,mat2str(v.Data.Axes.YLim));
assert(v.Data.Axes.XLim(2)>=4);
assert(strcmp(v.Data.Axes.YDir,'normal'));
units = findall(v.widgetFigure('Data'),'Tag','data-time-units'); units.Value = 'Minutes';
interval = findall(v.widgetFigure('Data'),'Tag','data-interval'); interval.Value = 2.5;
units.ValueChangedFcn(units,[]); v.Data.navigate(10); assert(v.annotationFrame()==4);
assert(isequal(ds.data,values) && isequal(r.data,ds) && all(r.image(:)==1));
if ~isempty(previewPath), v.Host.capture(previewPath); end
% Non-temporal data must never navigate the image or show a frame marker.
ds.type = 'generation'; v.Data.loadData(); v.Data.navigate(1);
assert(v.annotationFrame()==4 && isempty(findall(v.Data.Axes,'Tag','data-frame-marker')));
ds.type = 'temporal'; ds.data = values(1,:); v.Data.loadData();
assert(contains(status.Text,'1 rows'),status.Text);
% Switching targets clears snapshots immediately; never retains another ROI's curves.
choose(tree,2); assert(isempty(v.Data.Series) && isempty(findall(v.Data.Axes,'Type','line')));
v.Data.loadData(); assert(strcmp(status.Text,'No dataseries'),status.Text);
% Disk-backed series load into a scratch ROI, without populating live caches.
r.data = ds; r.save('data'); r.data = dataseries(); choose(tree,1); v.Data.loadData();
assert(isscalar(v.Data.Series) && isempty(r.data.data));
v.Host.setDocked('Data',false); v.Host.saveLayout();
assert(~v.Host.isDocked('Data')); v.Host.setDocked('Data',true);
assert(v.Host.restoreLayout(file) && ~v.Host.isDocked('Data') && v.Host.isWidgetVisible('Data'));
v.Host.setDocked('Data',true); v.closeProject(1); assert(isempty(v.Data.Series));
disp('Data test passed: Score types, immutable cached/disk snapshots, frame synchronization, context clearing, float/redock and old/new layouts.');
end
function choose(tree,index)
nodes = findall(tree,'Tag','roi-node'); node = nodes(arrayfun(@(n)n.UserData.roi==index,nodes));
tree.SelectedNodes = node; tree.SelectionChangedFcn(tree,[]);
end
function safeDelete(viewer)
if isvalid(viewer), delete(viewer); end
end
