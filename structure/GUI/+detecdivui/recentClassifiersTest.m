function recentClassifiersTest()
%RECENTCLASSIFIERSTEST Classic MRU and native File menu preserve live edits.
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
file=fullfile(folder,'prefs','recentClassifiers.mat');
missing=fullfile(folder,'missing_classification.mat');
mapped='Z:\unavailable-classifier\model_classification.mat';
unc='\\detecdiv-missing-host\unavailable-share\model_classification.mat';
memory=detecdivui.RecentClassifiers(''); memory.remember(mapped); memory.remember(unc);
assert(numel(memory.Paths)==2 && isempty(memory.File) && isempty(memory.LastError));
assert(isempty(dir(fullfile(folder,'**','*.mat'))));
history=detecdivui.RecentClassifiers(file); assert(~isfile(file));
for k=1:12, history.remember(fullfile(folder,sprintf('Model%02d_classification.mat',k))); end
assert(numel(history.Paths)==10 && contains(history.Paths(1),'Model12'));
history.remember(fullfile(folder,'.','Model11_classification.mat'));
assert(numel(history.Paths)==10 && contains(history.Paths(1),'Model11'));
if ispc
    history.remember(upper(history.Paths(1))); assert(numel(history.Paths)==10);
end
loaded=detecdivui.RecentClassifiers(file); assert(isequal(loaded.Paths,history.Paths));
stored=load(file); assert(isfield(stored,'RecentClassifiers') && isstring(stored.RecentClassifiers));
other=detecdivui.RecentClassifiers(file); other.remember(mapped); history.remember(unc);
assert(detecdivui.RecentClassifiers.samePath(history.Paths(2),mapped));
history.clear(); assert(isempty(detecdivui.RecentClassifiers(file).Paths));
RecentClassifiers={mapped,unc,mapped,'',missing}; save(file,'RecentClassifiers');
history.reload(); assert(numel(history.Paths)==3 && isempty(history.LastError));
before=fileread(file); memory.remember(missing); assert(strcmp(before,fileread(file)));
RecentClassifiers=struct('invalid',true); save(file,'RecentClassifiers'); history.reload(); assert(isempty(history.Paths));

classiObj=classi(folder,'Recent',1); classiObj.category={'Pixel'}; classiObj.classes={'cell'};
classiObj.trainingParam=struct('epochs',3);
r=roi('Recent cell',[1 1 10 12]); r.path=classiObj.path;
r.image=repmat(reshape(uint16(101:103),1,1,1,3),12,10,1,1);
r.channelid=1; r.display.channel={'Phase'}; r.save(); classiObj.roi=r; classiSave(classiObj);
path=fullfile(classiObj.path,[classiObj.strid '_classification.mat']);
history.remember(missing); history.remember(path);
v=launch(file); clean=onCleanup(@()delete(v));
assert(isempty(v.Classifiers.Classifiers) && isempty(v.Sessions));
menu=v.Host.findCommand('Recent Classifiers'); assert(strcmp(menu.Enable,'on') && numel(menu.Children)==3);
assert(contains(menu.Children{1}.Text,'Recent_1_classification.mat'));
v.Host.menuScript(sprintf('document.querySelector(''[data-command="%s"]'').click()',menu.Children{1}.Id));
started=tic;
while isempty(v.Classifiers.Classifiers)
    assert(toc(started)<20,'Recent classifier menu did not open its source.'); pause(.05); drawnow;
end
assert(isscalar(v.Classifiers.Classifiers) && isequal(v.Session.Classifier,v.Classifiers.Current));
c=v.Classifiers.Current; c.trainingParam.epochs=99; v.Classifiers.setMode('Edit');
v.navigateDataFrame(c.roi(1),3); before=v.RecentClassifiers.Paths;
menu.Children{1}.invoke();
assert(isequal(v.Classifiers.Current,c) && c.trainingParam.epochs==99 && v.annotationFrame()==3);
assert(strcmp(v.Classifiers.Mode,'Edit') && numel(v.Classifiers.Classifiers)==1);
menu.Children{2}.invoke();
assert(isequal(v.Classifiers.Current,c) && v.annotationFrame()==3 && isequal(before,v.RecentClassifiers.Paths));
assert(~v.Classifiers.Progress.Active);

% A newly loaded snapshot is intentional for Open; Recent focuses that live
% snapshot, preserving its unsaved settings instead of choosing an older one.
fresh=v.openClassifier(path); assert(~isequal(fresh,c) && numel(v.Classifiers.Classifiers)==2);
fresh.trainingParam.epochs=33; menu.Children{1}.invoke();
assert(isequal(v.Classifiers.Current,fresh) && fresh.trainingParam.epochs==33 && c.trainingParam.epochs==99);
v.Classifiers.setMode('Edit'); v.Classifiers.save();
assert(detecdivui.RecentClassifiers.samePath(v.RecentClassifiers.Paths(1),path));
saved=load(path,'classiObj'); assert(saved.classiObj.trainingParam.epochs==33);
v2=launch(file); clean2=onCleanup(@()delete(v2));
assert(isempty(v2.Classifiers.Classifiers) && isempty(v2.Sessions) && isequal(v2.RecentClassifiers.Paths,v.RecentClassifiers.Paths));
delete(v2); clear clean2;

% Newly saved workspace classifiers join history; discovery/registration do not.
workspace=classi(folder,'Workspace',2); workspace.category={'Pixel'};
before=v.RecentClassifiers.Paths; v.Classifiers.add(workspace);
assert(isequal(before,v.RecentClassifiers.Paths));
v.Classifiers.setMode('Edit'); v.Classifiers.save();
newPath=fullfile(workspace.path,[workspace.strid '_classification.mat']);
assert(detecdivui.RecentClassifiers.samePath(v.RecentClassifiers.Paths(1),newPath));
v.Host.findCommand('Clear Recent Classifiers').invoke();
assert(strcmp(menu.Enable,'off') && isempty(detecdivui.RecentClassifiers(file).Paths));
assert(numel(v.Classifiers.Classifiers)==3 && isequal(v.Classifiers.Current,workspace));
assert(isempty(dir([file '.*.tmp'])));
fprintf('Recent classifiers passed: shared legacy history, native menu, no startup loads, missing paths, live edits, snapshots, save history and clear.\n');
end
function v=launch(file)
v=detecdiv_ui([],'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile',file);
end
