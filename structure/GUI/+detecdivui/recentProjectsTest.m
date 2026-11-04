function recentProjectsTest()
%RECENTPROJECTSTEST Classic history compatibility and real recent-menu actions.
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
file = fullfile(folder,'prefs','recentProjects.mat');
history = detecdivui.RecentProjects(file);
for k = 1:12, history.remember(fullfile(folder,sprintf('Missing%d.json',k))); end
assert(numel(history.Paths) == 10 && endsWith(history.Paths(1),'Missing12.json'));
history.remember(fullfile(folder,'Missing11.mat'));
assert(numel(history.Paths) == 10 && endsWith(history.Paths(1),'Missing11.mat'));
history.remember(fullfile(folder,'Missing11.json'));
assert(numel(history.Paths) == 10 && endsWith(history.Paths(1),'Missing11.json'));
loaded = detecdivui.RecentProjects(file); assert(isequal(loaded.Paths,history.Paths));
saved = load(file,'RecentProjects'); assert(isstring(saved.RecentProjects));
% No path existence checks/pruning during history load: unavailable entries stay.
assert(all(contains(loaded.Paths,'Missing')));
history.clear(); assert(isempty(detecdivui.RecentProjects(file).Paths));
project = shallow(); project.io.file = 'Recent project'; project.io.path = folder;
project.fov.id = 'Position'; project.fov.srcpath = {fullfile(folder,'unavailable-raw')};
json = shallowProjectExportLight(project);
legacy = fullfile(folder,'Recent project.mat'); shallowObj = project; save(legacy,'shallowObj');
assert(strcmp(detecdivui.RecentProjects.resolve(legacy),json));
history.remember(fullfile(folder,'missing.json')); history.remember(legacy);
viewer = detecdiv_ui([],'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile',file);
closeViewer = onCleanup(@()delete(viewer));
assert(isempty(viewer.Sessions)); % Recent references never auto-open projects/raw data.
menu = viewer.Host.findCommand('Recent Projects'); assert(strcmp(menu.Enable,'on'));
assert(numel(menu.Children) == 3 && contains(menu.Children{1}.Text,'Recent project.mat'));
viewer.Host.menuScript(sprintf('document.querySelector(''[data-command="%s"]'').click()',menu.Children{1}.Id));
started = tic;
while isempty(viewer.Sessions)
    assert(toc(started) < 15,'Recent menu action did not open the project.'); pause(.05); drawnow;
end
assert(isscalar(viewer.Sessions) && viewer.Session.Zone == 0);
assert(endsWith(viewer.RecentProjects.Paths(1),'.json'));
assert(isempty(findall(viewer.Figure,'Type','image')) && isempty(viewer.ROIs));
active = viewer.Session.Project; active.fov.id = 'Unsaved position';
menu.Children{1}.invoke();
assert(isequal(viewer.Session.Project,active) && strcmp(active.fov.id,'Unsaved position'));
before = viewer.RecentProjects.Paths; menu.Children{2}.invoke();
assert(isequal(viewer.Session.Project,active) && isequal(viewer.RecentProjects.Paths,before));
assert(~viewer.ProjectProgress.Active);
delete(viewer); clear closeViewer;
viewer = detecdiv_ui([],'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile',file);
closeAgain = onCleanup(@()delete(viewer));
assert(isempty(viewer.Sessions) && isequal(viewer.RecentProjects.Paths,before));
viewer.Host.findCommand('Clear Recent Projects').invoke();
assert(strcmp(viewer.Host.findCommand('Recent Projects').Enable,'off'));
assert(isempty(detecdivui.RecentProjects(file).Paths));
% A malformed preferences file cannot prevent viewer startup.
RecentProjects = struct('invalid',true); save(file,'RecentProjects');
assert(isempty(detecdivui.RecentProjects(file).Paths));
disp('Recent projects test passed: shared format, cap/dedup, JSON preference, lazy menu reopening, unsaved state and persistence.');
end
