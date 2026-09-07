function tests=testClassiRemoveROI
tests=functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(root); detecdiv_setup_path;
end

function testRemovalRetiresGtAndPersistsMembership(testCase)
root=tempname; mkdir(root);
cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c=classi(root,'remove',1,'InitTraining',false);
root=c.path;
r=roi('R1',[]); r.path=root;
r.image=uint16(ones(4,4,1,2)); r.channelid=1;
r.display.channel={'cellpose_gt'};
r.save([],false);
data=r.data; save(fullfile(root,'data_R1.mat'),'data');
r.saveCellModel(cellModel.create(r.id));
other=roi('R10',[]); other.path=root;
other.image=uint16(2*ones(4,4,1,2)); other.channelid=1;
other.display.channel={'raw'}; other.save([],false);
c.roi=[r other];
c.trainingset=[1 2]; c.dataset.split=struct('train',[1 2],'val',2,'test',[]);
trainingBounds.setRoi(c,1,[1 2]); trainingBounds.setRoi(c,2,[2 2]);
mkdir(fullfile(root,'trainingdataset'));
copyfile(fullfile(root,'im_R1.h5'),fullfile(root,'trainingdataset','old_gt.h5'));
writeJson(fullfile(root,'review_hints.json'),struct('items', ...
    struct('roi_id',{'R1','R10'},'frame',{1,1})));
report=c.removeROI(1);
verifyEqual(testCase,{c.roi.id},{'R10'});
verifyEqual(testCase,c.trainingset,1);
verifyEqual(testCase,c.dataset.split.val,1);
verifyEqual(testCase,{c.bounds.RoiValues.roi_id},{'R10'});
verifyEqual(testCase,c.bounds.RoiValues.roi_index,1);
for name={'im_R1.h5','data_R1.mat','objects_R1.h5','trainingdataset'}
    verifyFalse(testCase,isfile(fullfile(root,name{1})) || isfolder(fullfile(root,name{1})));
    verifyTrue(testCase,isfile(fullfile(report.recoveryPath,name{1})) || ...
        isfolder(fullfile(report.recoveryPath,name{1})));
end
verifyTrue(testCase,isfile(fullfile(root,'im_R10.h5')));
saved=load(fullfile(root,[c.strid '_classification.mat']));
verifyEqual(testCase,{saved.classiObj.roi.id},{'R10'});
payload=jsondecode(fileread(fullfile(root,'review_hints.json')));
verifyEqual(testCase,payload.items.roi_id,'R10');
end

function testRollbackOnInvalidMetadata(testCase)
root=tempname; mkdir(root);
cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c=classi(root,'rollback',1,'InitTraining',false);
root=c.path;
r=roi('R1',[]); r.path=root; r.image=uint16(ones(4));
r.channelid=1; r.display.channel={'gt'}; r.save([],false);
data=r.data; save(fullfile(root,'data_R1.mat'),'data');
c.roi=r; c.trainingset=1;
fid=fopen(fullfile(root,'dataset.json'),'w'); fwrite(fid,'broken'); fclose(fid);
failed=false;
try, c.removeROI(1); catch, failed=true; end
verifyTrue(testCase,failed);
verifyEqual(testCase,c.roi.id,'R1');
verifyEqual(testCase,c.trainingset,1);
verifyTrue(testCase,isfile(fullfile(root,'im_R1.h5')));
verifyTrue(testCase,isfile(fullfile(root,'data_R1.mat')));
end

function writeJson(path,value)
fid=fopen(path,'w'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,jsonencode(value));
end

function testExternalSourceIsPreserved(testCase)
root=tempname; mkdir(root);
cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c=classi(root,'external',1,'InitTraining',false);
r=roi('R1',[]); r.path=root; r.image=uint16(ones(4));
r.channelid=1; r.display.channel={'raw'}; r.save([],false);
c.roi=r;
warningState=warning('off','classi:ExternalRoiPreserved');
restore=onCleanup(@()warning(warningState)); %#ok<NASGU>
report=c.removeROI(1);
verifyTrue(testCase,isfile(fullfile(root,'im_R1.h5')));
verifyEqual(testCase,report.externalSourcesPreserved,{'R1'});
verifyEmpty(testCase,c.roi.id);
end
