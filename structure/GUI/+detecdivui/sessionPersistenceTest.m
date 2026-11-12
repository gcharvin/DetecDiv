function sessionPersistenceTest()
% Closing a viewer retains live objects; closing a project removes it.
key = 'DetecDivUISession';
hadState = isappdata(0,key);
oldState = [];
if hadState, oldState = getappdata(0,key); end
cleanup = onCleanup(@()restoreState(key,hadState,oldState)); %#ok<NASGU>
if hadState, rmappdata(0,key); end
project = shallow(); project.io.file = 'Session project';
project.fov.id = 'Position';
classifier = classi(); classifier.strid = 'Session classifier';
first = detecdiv_ui([],'Visible','off','LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
first.addProject(project);
first.Classifiers.add(classifier,false);
project.tag = 'Unsaved session change';
delete(first);

second = detecdiv_ui();
closeSecond = onCleanup(@()safeDelete(second)); %#ok<NASGU>
assert(isequal(second.Session.Project,project));
assert(strcmp(second.Session.Project.tag,'Unsaved session change'));
assert(any(cellfun(@(c)isequal(c,classifier),second.Classifiers.Classifiers)));
second.closeProject();
delete(second);

third = detecdiv_ui();
closeThird = onCleanup(@()safeDelete(third)); %#ok<NASGU>
assert(~any(cellfun(@(s)isequal(s.Project,project) && isempty(s.Classifier),third.Sessions)));
assert(any(cellfun(@(c)isequal(c,classifier),third.Classifiers.Classifiers)));
delete(third);
disp('Viewer session persistence passed: live project and classifier handles, explicit project close.');
end

function safeDelete(viewer)
if ~isempty(viewer) && isvalid(viewer), delete(viewer); end
end

function restoreState(key,hadState,oldState)
if hadState, setappdata(0,key,oldState);
elseif isappdata(0,key), rmappdata(0,key); end
end
