function tests=testClassiLoadFreshSnapshot
tests=functiontests(localfunctions);
end
function setupOnce(~)
detecdiv_setup_path;
end
function testExplicitReloadDoesNotReturnStaleWorkspaceRois(testCase)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
c=classi(folder,'reload',1,'InitTraining',false);c.path=[c.path filesep];
c.roi=[roi('R1',[]) roi('R2',[])];c.trainingset=[1 2];
for k=1:2,c.roi(k).path=c.path;end
c.dataset.split=struct('train',[1 2],'val',[],'test',[]);
classiObj=c;file=fullfile(c.path,[c.strid '_classification.mat']);save(file,'classiObj');
name=['codex_stale_' strrep(char(java.util.UUID.randomUUID()),'-','')];
assignin('base',name,c);clearBase=onCleanup(@()evalin('base',['clear ' name])); %#ok<NASGU>
fresh=load(file,'classiObj');classiObj=fresh.classiObj;
classiObj.roi=classiObj.roi(1);classiObj.trainingset=1;classiObj.dataset.split.train=1;
save(file,'classiObj');
[loaded,~]=classiLoad(file);
verifyEqual(testCase,{loaded.roi.id},{'R1'});
verifyEqual(testCase,{c.roi.id},{'R1','R2'});
verifyEqual(testCase,loaded.trainingset,1);
verifyEqual(testCase,char(java.io.File(loaded.roi.path).getCanonicalPath()), ...
    char(java.io.File(fileparts(file)).getCanonicalPath()));
end
function testLoadingOnAnotherDriveOrFolderUsesSelectedLocation(testCase)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
c=classi(folder,'relink',1,'InitTraining',false);c.roi=roi('R1',[]);
c.path='Z:\nonexistent\classifiers\relink_1\';c.roi.path=c.path;
classiObj=c;file=fullfile(folder,'relink_1_classification.mat');save(file,'classiObj');
[loaded,~]=classiLoad(file);
verifyEqual(testCase,char(java.io.File(loaded.path).getCanonicalPath()), ...
    char(java.io.File(folder).getCanonicalPath()));
verifyEqual(testCase,loaded.roi.path,loaded.path);
verifyEqual(testCase,c.path,'Z:\nonexistent\classifiers\relink_1\');
end
