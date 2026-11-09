function startupTest()
%STARTUPTEST Relaunch and failed construction keep existing viewers/data intact.
% Faults use an isolated temporary copy of Viewer. Production classes and
% global graphics defaults are never edited or given fault-injection hooks.
folder = tempname; mkdir(folder);
resources = containers.Map('KeyType','char','ValueType','any');
state = containers.Map('KeyType','char','ValueType','any');
state('mode') = 'none'; state('created') = 0; state('poisoned') = 0; state('guarded') = false;
fixtureRoot = fullfile(folder,'fixture'); mkdir(fixtureRoot);
cleanup = onCleanup(@()cleanAll(resources,folder,fixtureRoot));
fixture = createFixture(fixtureRoot);
fault = @(ax,phase)injectFault(ax,phase,state);

project = shallow(); project.io.file = 'Startup regression'; project.io.path = folder;
project.fov.id = 'Position'; project.fov.channel = {'Phase'}; project.fov.frames = 1;
project.fov.srcpath = {'Z:\unavailable-startup-source'};
project.fov.roi = roi('Cells',[1 1 12 12]); pixels = uint16(magic(12));
project.fov.roi.image = pixels; project.fov.roi.display.channel = {'Phase'};
originalROI = project.fov.roi;
layout = fullfile(folder,'layout.json');

old = launch(project,'',false); resources('old') = old;
old.Session.selectZone(1); old.loadCurrentImage();
oldAxes = old.roiAxes(); oldAxes.XLim = [2 8]; oldAxes.YLim = [3 9];
old.Host.saveLayout(layout);
% Whitespace is valid JSON but ensures any unwanted auto-save changes bytes,
% even when the failed new window would otherwise save the same geometry.
writeText(layout,[newline fileread(layout) newline]); layoutBytes = readBytes(layout);
assertToolbar(oldAxes);
before = snapshotResources();

state('mode') = 'once'; state('created') = 0; state('poisoned') = 0; state('guarded') = false;
recovered = feval(fixture,project,'off',layout,false,'','','',fault); resources('recovered') = recovered;
assert(state('poisoned') == 1, ...
    'The fixture did not exercise the deleted interaction-container fault.');
assert(state('guarded'),'Image axes were constructed outside the startup menu-dispatch guard.');
assert(state('created') <= 2,'Recovery exceeded its bounded empty-axes retry.');
assertToolbar(recovered.roiAxes());
assert(~detecdivui.startupGuard('active'));
assertOldViewer();
delete(recovered); resources.remove('recovered');
waitUntil(@()noNewResources(before));

% Every new candidate is poisoned. Startup must fail, release all of its UI
% resources/guard and preserve the existing saved layout and old viewer.
state('mode') = 'always'; state('created') = 0; state('poisoned') = 0;
failed = false;
try
    unexpected = feval(fixture,project,'off',layout,true,'','','',fault); resources('unexpected') = unexpected;
catch err
    failed = true;
    assert(contains(lower(getReport(err,'basic','hyperlinks','off')),'interaction') || ...
        contains(lower(err.message),'invalid') || contains(lower(err.message),'deleted'),err.message);
end
assert(failed && state('poisoned') == 2,'Repeated interaction faults did not fail after two attempts.');
assert(~detecdivui.startupGuard('active'),'A failed toolbar initialization left startup dispatch suspended.');
waitUntil(@()noNewResources(before));
assert(isequal(readBytes(layout),layoutBytes),'Failed toolbar startup overwrote the saved layout.');
assertOldViewer();

% A failure before Host.start must also dispose a partially built host. The
% fixture deletes the first empty axes before the constructor configures it.
state('mode') = 'delete'; state('created') = 0; state('poisoned') = 0;
failed = false;
try
    unexpected = feval(fixture,project,'off',layout,true,'','','',fault); resources('unexpected') = unexpected;
catch
    failed = true;
end
assert(failed && state('poisoned') == 1,'The early-construction failure was not exercised.');
assert(~detecdivui.startupGuard('active'),'Early constructor failure retained the startup guard.');
waitUntil(@()noNewResources(before));
assert(isequal(readBytes(layout),layoutBytes),'Early startup failure overwrote the saved layout.');
assertOldViewer();

% An ordinary production launch needs no fixture or modified graphics default.
again = launch(project,layout,false); resources('again') = again;
assert(isKey(resources,'again'));
assertToolbar(again.roiAxes()); assertOldViewer();
assert(~detecdivui.startupGuard('active'));
assert(isequal(project.fov.roi,originalROI) && isequal(originalROI.image,pixels));
assert(isempty(project.processing.pipelineRun) && isempty(dir(fullfile(folder,'**','*.h5'))));
clear cleanup;
disp('Startup test passed: existing viewer preserved, deleted-container recovery, bounded failure cleanup, saved-layout protection, released startup guard and ordinary relaunch.');

    function assertOldViewer()
        assert(isvalid(old) && isequal(old.roiAxes(),oldAxes) && isgraphics(oldAxes));
        image = findall(oldAxes,'Type','image');
        assert(isscalar(image) && isequal(image.CData,pixels));
        assert(isequal(oldAxes.XLim,[2 8]) && isequal(oldAxes.YLim,[3 9]));
        assert(old.Session.Project == project && old.Session.Position == 1 && old.Session.Zone == 1);
        assertToolbar(oldAxes);
    end
end

function viewer = launch(project,layout,autoSave)
viewer = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false,'LayoutFile',layout, ...
    'AutoSaveLayout',autoSave,'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
end

function injectFault(ax,phase,state)
if ~isgraphics(ax) || ~strcmp(ax.Tag,'image-view') || ~isempty(ax.Children), return; end
state('guarded') = state('guarded') || detecdivui.startupGuard('active');
mode = state('mode');
if strcmp(phase,'created')
    state('created') = state('created')+1;
    if strcmp(mode,'delete')
        delete(ax); state('poisoned') = state('poisoned')+1;
        assert(state('poisoned') > 0);
    end
elseif strcmp(phase,'ready')
    % UIAxes ignores inherited root CreateFcn defaults in this build, but an
    % explicit constructor CreateFcn runs. ImageAxes must preserve that
    % callback when rebuilding the still-empty axes, so a repeat fault also
    % tests its actual bounded recreation path.
    ax.CreateFcn = @(replacement,event)poisonReplacement(replacement,event,state);
    poisonContainer(ax,state);
end
end

function poisonReplacement(ax,~,state)
state('created') = state('created')+1;
poisonContainer(ax,state);
end

function poisonContainer(ax,state)
mode = state('mode');
if strcmp(mode,'none') || strcmp(mode,'once') && state('poisoned') > 0, return; end
assert(isgraphics(ax) && isempty(ax.Children) && isprop(ax,'InteractionContainer') && ...
    ~isempty(ax.InteractionContainer),'The empty-axes regression target is unavailable.');
delete(ax.InteractionContainer);
state('poisoned') = state('poisoned')+1;
assert(state('poisoned') > 0);
end

function constructor = createFixture(root)
[~,suffix] = fileparts(fileparts(root)); package = matlab.lang.makeValidName(['ddStartupFixture_' suffix]);
packageFolder = fullfile(root,['+' package]); mkdir(packageFolder);
sourceFolder = fileparts(mfilename('fullpath'));
source = fileread(fullfile(sourceFolder,'Viewer.m'));
source = strrep(source,sprintf('\r\n'),newline);
signature = regexp(source,'        function obj = Viewer\([^\n]*\)','match','once');
assert(~isempty(signature),'Viewer constructor signature changed.');
extended = [signature(1:end-1) ',fault)']; source = strrep(source,signature,extended);
created = '            obj.ImageAxes = obj.Axes;';
ready = '            obj.Axes = detecdivui.ImageAxes.initialize(obj.Axes); obj.ImageAxes = obj.Axes;';
assert(isscalar(strfind(source,created)) && isscalar(strfind(source,ready)), ...
    'Viewer startup fault-injection anchors changed.');
source = strrep(source,created,[created newline '            fault(obj.Axes,''created'');']);
source = strrep(source,ready,['            fault(obj.Axes,''ready'');' newline ready]);
file = fullfile(packageFolder,'Viewer.m'); fid = fopen(file,'w');
assert(fid >= 0,'Could not create isolated startup fixture.');
fwrite(fid,unicode2native(source,'UTF-8'),'uint8'); fclose(fid);
copyfile(fullfile(sourceFolder,'imageKeyboard.html'),fullfile(packageFolder,'imageKeyboard.html'));
addpath(root,'-begin'); rehash;
constructor = [package '.Viewer'];
end

function assertToolbar(ax)
assert(isgraphics(ax)); toolbar = ax.Toolbar;
assert(isscalar(toolbar) && isvalid(toolbar) && strcmp(toolbar.Visible,'on'));
for tag = {'pan','zoom','restoreview'}
    assert(isscalar(findall(toolbar,'Tag',tag{1})), ...
        'The default image toolbar lost %s.',tag{1});
end
assert(isvalid(ax.InteractionContainer));
end

function snapshot = snapshotResources()
snapshot.figures = findall(groot,'Type','figure');
snapshot.timers = ownedTimers(); snapshot.windows = ownedWindows();
end

function yes = noNewResources(before)
figures = findall(groot,'Type','figure'); timers = ownedTimers(); windows = ownedWindows();
yes = all(ismember(figures,before.figures)) && all(ismember(timers,before.timers)) && ...
    all(ismember(windows,before.windows));
end

function timers = ownedTimers()
timers = timerfindall;
if isempty(timers), return; end
tags = {'DetecDivDockMenu','DetecDivPipelineFollow','DetecDivLiveDisplay','DetecDivWidgetClose'};
timers = timers(ismember({timers.Tag},tags));
end

function paths = ownedWindows()
paths = strings(0,1); windows = matlab.internal.webwindowmanager.instance.windowList;
for k = 1:numel(windows)
    if ~isvalid(windows(k)), continue; end
    path = string(windows(k).URL);
    if contains(path,'id=DetecDivUI_'), paths(end+1,1) = path; end %#ok<AGROW>
end
end

function waitUntil(condition)
started = tic;
while ~condition()
    assert(toc(started) < 15,'detecdivui:StartupCleanup','Startup resources were not released.');
    drawnow; pause(.03);
end
end

function bytes = readBytes(file)
fid = fopen(file,'rb'); assert(fid >= 0); cleanup = onCleanup(@()fclose(fid));
bytes = fread(fid,Inf,'*uint8');
end

function writeText(file,text)
fid = fopen(file,'w','n','UTF-8'); assert(fid >= 0); cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s',text);
end

function cleanAll(resources,folder,fixtureRoot)
teardown = detecdivui.startupGuard('begin'); %#ok<NASGU>
for key = {'unexpected','again','recovered','old'}
    if isKey(resources,key{1})
        object = resources(key{1});
        if ~isempty(object) && isvalid(object)
            fprintf('Startup cleanup: deleting %s viewer.\n',key{1}); delete(object);
        end
    end
end
disp('Startup cleanup: removing fixture.');
rmpath(fixtureRoot);
if isfolder(folder), rmdir(folder,'s'); end
end
