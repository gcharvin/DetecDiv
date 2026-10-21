function tests=testAnnotationFrameCountCache
tests=functiontests(localfunctions);
end
function setupOnce(~)
detecdiv_setup_path;
end
function testUpdatedImageStoreInvalidatesCachedLength(testCase)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
r=roi('R1',[]);r.path=folder;r.data=dataseries.empty;
file=fullfile(folder,'im_R1.h5');h5create(file,'/short',[2 2 1 3]);
h5writeatt(file,'/short','frames',1:3);
verifyEqual(testCase,annotationManager.frameCount(r),3);
verifyEqual(testCase,annotationManager.frameCount(r),3);
h5create(file,'/long',[2 2 1 8]);h5writeatt(file,'/long','frames',0:7);
verifyEqual(testCase,annotationManager.frameCount(r),8);
r.image=zeros(2,2,1,10,'uint8');verifyEqual(testCase,annotationManager.frameCount(r),10);
r.image=[];verifyEqual(testCase,annotationManager.frameCount(r),8);
end
function testMissingImageThenMaterializedStoreUsesDiskLength(testCase)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
r=roi('R2',[]);r.path=folder;r.data=dataseries(table((1:20)','VariableNames',{'frame'}));
r.data.type='temporal';verifyEqual(testCase,annotationManager.frameCount(r),20);
file=fullfile(folder,'im_R2.h5');h5create(file,'/raw',[2 2 1 4]);
verifyEqual(testCase,annotationManager.frameCount(r),4);
end
