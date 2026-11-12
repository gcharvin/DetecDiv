function workspaceExposureTest()
% Workspace publication preserves user variables and live handle identity.
group = 'DetecDivUI'; key = 'ExposeWorkspaceObjects';
names = {'project_ExposureTest','project_ExposureTest_1','project_ExposureTest_2', ...
    'userExposureClassifier','classifier_SecondExposure'};
for k = 1:numel(names)
    assert(~evalin('base',sprintf('exist(''%s'',''var'')',names{k})), ...
        'Test variable already exists: %s',names{k});
end
hadPref = ispref(group,key); oldPref = getpref(group,key,false);
hadBindings = isappdata(0,'DetecDivUIWorkspaceBindings'); oldBindings = [];
if hadBindings, oldBindings = getappdata(0,'DetecDivUIWorkspaceBindings'); end
cleanup = onCleanup(@()restore(group,key,hadPref,oldPref,hadBindings,oldBindings)); %#ok<NASGU>
setpref(group,key,false);
setappdata(0,'DetecDivUIWorkspaceBindings',struct('name',{},'object',{}));
assignin('base','project_ExposureTest',42);
project = shallow(); project.io.file = 'ExposureTest';
classifier = classi(); classifier.strid = 'ExposureClassifier';
assignin('base','userExposureClassifier',classifier);
viewer = detecdiv_ui([],'Visible','off','LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
closeViewer = onCleanup(@()safeDelete(viewer)); %#ok<NASGU>
viewer.addProject(project); viewer.Classifiers.add(classifier,false);
assert(evalin('base','exist(''project_ExposureTest_1'',''var'')') == 0);
viewer.Host.findCommand('Settings...').invoke();
settings = findall(groot,'Tag','detective-settings');
assert(strcmp(findall(settings,'Tag','settings-advanced').Title,'Advanced users'));
toggle = findall(settings,'Tag','settings-workspace-objects');
assert(~toggle.Value); toggle.Value = true; toggle.ValueChangedFcn(toggle,[]);
assert(isequal(evalin('base','project_ExposureTest_1'),project));
assert(evalin('base','project_ExposureTest') == 42);
assert(isequal(evalin('base','userExposureClassifier'),classifier));
newClassifier = classi(); newClassifier.strid = 'SecondExposure';
viewer.Classifiers.add(newClassifier,false);
assert(evalin('base','classifier_SecondExposure') == newClassifier);
other = shallow(); other.io.file = 'ExposureTest';
other.tag = 'Second project';
viewer.addProject(other);
assert(isequal(evalin('base','project_ExposureTest_2'),other));
assignin('base','project_ExposureTest_1',17);
toggle.Value = false; toggle.ValueChangedFcn(toggle,[]);
assert(evalin('base','project_ExposureTest_1') == 17);
assert(evalin('base','exist(''project_ExposureTest_2'',''var'')') == 0);
assert(evalin('base','exist(''classifier_SecondExposure'',''var'')') == 0);
assert(isequal(evalin('base','userExposureClassifier'),classifier));
toggle.Value = true; toggle.ValueChangedFcn(toggle,[]);
assert(detecdivui.WorkspaceExposure.enabled());
viewer.closeProject();
assert(~any(arrayfun(@(e)isequal(e.object,other),detecdivui.workspaceObjects())));
delete(viewer);
disp('Workspace exposure passed: settings, live objects, names, collisions and user variable preservation.');
end

function safeDelete(viewer)
if ~isempty(viewer) && isvalid(viewer), delete(viewer); end
end

function restore(group,key,hadPref,oldPref,hadBindings,oldBindings)
detecdivui.WorkspaceExposure.clearManaged();
evalin('base','clear project_ExposureTest project_ExposureTest_1 project_ExposureTest_2 userExposureClassifier classifier_SecondExposure');
if hadPref, setpref(group,key,oldPref); elseif ispref(group,key), rmpref(group,key); end
if hadBindings, setappdata(0,'DetecDivUIWorkspaceBindings',oldBindings);
elseif isappdata(0,'DetecDivUIWorkspaceBindings'), rmappdata(0,'DetecDivUIWorkspaceBindings'); end
end
