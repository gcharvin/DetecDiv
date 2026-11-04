function lazyImageTest(previewPath)
%LAZYIMAGETEST No startup I/O, explicit reads and real path-helper relinking.
if nargin < 1, previewPath = ''; end
workspaceName = 'ddUiLazyProject';
assert(~evalin('base',sprintf('exist(''%s'',''var'')',workspaceName)));
assert(~isappdata(0,'DetecDivLazyTestReads') && ~isappdata(0,'DetecDivLazyTestPrefs'));
folder = tempname; mkdir(folder);
fixtures = fullfile(folder,'prefs-fixture'); mkdir(fixtures);
cleanupFolder = onCleanup(@()cleanupTest(folder,fixtures,workspaceName));
% Isolate relink preferences. Shortcut preferences are legitimate UI reads;
% count path-helper access independently from the viewer's shortcut setup.
writeFile(fullfile(fixtures,'detecdiv_prefs_load.m'),sprintf([ ...
    'function p=detecdiv_prefs_load()\n' ...
    'stack=dbstack;\n' ...
    'if ~any(strcmp({stack.name},''detecdiv_prefs_get_shortcuts''))\n' ...
    'setappdata(0,''DetecDivLazyTestReads'',getappdata(0,''DetecDivLazyTestReads'')+1);\n' ...
    'end\n' ...
    'p=getappdata(0,''DetecDivLazyTestPrefs'');\nend\n']));
writeFile(fullfile(fixtures,'detecdiv_prefs_save.m'),sprintf([ ...
    'function detecdiv_prefs_save(p)\n' ...
    'setappdata(0,''DetecDivLazyTestPrefs'',p);\nend\n']));
setappdata(0,'DetecDivLazyTestReads',0);
setappdata(0,'DetecDivLazyTestPrefs',struct('paths',struct('rawPathHistory',{{}})));
addpath(fixtures,'-begin'); clear detecdiv_prefs_load detecdiv_prefs_save;
rawRoot = fullfile(folder,'raw'); sourceFolder = fullfile(rawRoot,'Pos0'); mkdir(sourceFolder);
pixels = uint16(reshape(1:120,10,12));
imwrite(pixels,fullfile(sourceFolder,'frame1.tif'));
project = shallow(); project.io.file = 'On-demand project';
project.fov.id = 'Pos0'; project.fov.channel = {'Phase'};
project.fov.frames = 1; project.fov.interval = 1;
missing = fullfile(folder,'missing','raw','Pos0'); project.fov.srcpath = {missing};
listing = dir(fullfile(sourceFolder,'*.tif')); listing.folder = missing;
project.fov.srclist = {listing};
zone = roi('Stored ROI',[1 1 12 10]); zone.path = folder;
zone.image = pixels+10; zone.channelid = 1; zone.display.channel = {'Phase'};
assert(zone.save([],false)); zone.image = [];
project.fov.roi = zone;
assignin('base',workspaceName,project);
output = evalc('viewer = detecdiv_ui([],''DiscoverWorkspace'',true,''Visible'',''on'',''LayoutFile'','''',''AutoSaveLayout'',false);');
closeViewer = onCleanup(@()delete(viewer));
viewer.addProject(project); % Focus this fixture even when other workspace projects exist.
drawnow; pause(.3);
ax = findall(viewer.Figure,'Tag','image-view');
assert(isempty(findall(ax,'Type','image')) && isempty(zone.image));
assert(getappdata(0,'DetecDivLazyTestReads') == 0);
assert(~contains(output,'[readImage]') && ~contains(output,'[paths]'));
assert(isempty(viewer.DisplayModel.Layers));
viewer.Host.findCommand('Fit Image').invoke();
assert(isempty(viewer.DisplayModel.Layers));
% Actual toolbar action must stop before the legacy automatic-root search.
load = findall(viewer.Figure,'Tag','load-image'); %#ok<NASGU> Used by evalc below.
output = evalc('load.ButtonPushedFcn(load,[]);');
assert(getappdata(0,'DetecDivLazyTestReads') == 0);
assert(~contains(output,'[readImage]') && ~contains(output,'[paths]'));
status = findall(viewer.Figure,'Tag','status');
relink = findall(viewer.Figure,'Tag','relink-raw-data');
assert(contains(status.Text,'Relink Raw Data') && strcmp(relink.Visible,'on'));
assert(strcmp(project.fov.srcpath{1},missing));
if ~isempty(previewPath), drawnow; pause(.3); viewer.Host.capture(previewPath); end
report = viewer.relinkRawData(rawRoot); % Real existing helper, explicit root.
assert(~isempty(report) && all([report.ok]));
assert(strcmp(project.fov.srcpath{1},sourceFolder));
assert(isequal(imagePixels(ax),pixels));
assert(strcmp(relink.Visible,'off'));
% Returning to a project node clears pixels without initiating a read.
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
tree.SelectedNodes = findall(tree,'Tag','project-node'); tree.SelectionChangedFcn(tree,[]);
assert(isempty(findall(ax,'Type','image')));
reads = getappdata(0,'DetecDivLazyTestReads');
% Restoring an ROI context during metadata refresh must not load its H5.
viewer.Session.selectZone(1); viewer.refreshWorkspace();
assert(isempty(zone.image) && getappdata(0,'DetecDivLazyTestReads') == reads);
viewer.relinkRawData(rawRoot); % Relinking a pending view must not load H5.
assert(isempty(zone.image) && isempty(findall(ax,'Type','image')));
project.fov.srcpath = {missing}; % Stored ROI review works with offline raw data.
viewer.loadCurrentImage();
assert(isequal(imagePixels(ax),pixels+10));
assert(~isempty(zone.image));
stack = shallow(); stack.fov.id = 'Stack'; stack.fov.isMultiTiff = true;
stack.fov.channel = {'Phase','Shared TIFF'}; stack.fov.frames = [1 1]; stack.fov.interval = [1 1];
stack.fov.tiffSource = {fullfile(sourceFolder,'frame1.tif'),''}; stack.fov.pageMap = {1,1};
session = detecdivui.Session(stack);
assert(isequal(session.readPlane(1,2),pixels));
disp('Lazy image test passed: no startup reads/search, missing-source action, real relink and on-demand H5.');
end
function writeFile(file,content)
fid = fopen(file,'w'); cleanup = onCleanup(@()fclose(fid)); fprintf(fid,'%s',content);
end
function cleanupTest(folder,fixtures,workspaceName)
rmpath(fixtures); clear detecdiv_prefs_load detecdiv_prefs_save;
evalin('base',['clear ' workspaceName]);
for key = {'DetecDivLazyTestReads','DetecDivLazyTestPrefs'}
    if isappdata(0,key{1}), rmappdata(0,key{1}); end
end
rmdir(folder,'s');
end
function pixels = imagePixels(ax)
h = findall(ax,'Type','image'); assert(isscalar(h)); pixels = h.CData;
end
