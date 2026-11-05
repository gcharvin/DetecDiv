function tests = testScoreStaleMaskPreset
tests = functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root);detecdiv_setup_path(root,'ResetPath',false,'Verbose',false);
end

function testForeignProviderFallsBackWithoutChangingPixels(testCase)
r=fixture();before=r.image;
cfg=score_getObjectDisplayConfig(r,'gt');
cfg.maskProvider='results_pred_hoct_tracks';cfg.objectFamily='HOCT';
cfg.lineageMode='genealogy';
r.display.objectDisplay=struct('channels',cfg);
actual=score_getObjectDisplayConfig(r,'gt');
verifyEqual(testCase,actual.maskProvider,'gt');
verifyEqual(testCase,actual.objectFamily,'<auto>');
verifyEqual(testCase,actual.lineageMode,'none');
layout=score_updateLayout(score_collectDisplayOptions('frames',1),r);
verifyNotEmpty(testCase,layout);
verifyEqual(testCase,r.image,before);
end

function testOrphanRecordDoesNotLoadMissingChannel(testCase)
r=fixture();cfg=score_getObjectDisplayConfig(r,'gt');
cfg.channelName='removed_mask';cfg.maskProvider='results_pred_hoct_tracks';
r.display.objectDisplay=struct('channels',cfg);
layout=score_updateLayout(score_collectDisplayOptions('frames',1),r);
verifyNotEmpty(testCase,layout);
end

function testExistingProviderIsPreserved(testCase)
r=fixture();cfg=score_getObjectDisplayConfig(r,'gt');
cfg.maskProvider='prediction';cfg.objectFamily='prediction family';
r.display.objectDisplay=struct('channels',cfg);
actual=score_getObjectDisplayConfig(r,'gt');
verifyEqual(testCase,actual.maskProvider,'prediction');
verifyEqual(testCase,actual.objectFamily,'prediction family');
end

function r=fixture()
r=roi('stale_preset',[]);r.image=zeros(8,8,3,2,'uint16');
r.image(:,:,1,:)=uint16(reshape(1:128,8,8,1,2));r.image(3:5,3:5,2:3,:)=1;
r.channelid=1:3;r.display.channel={'raw','prediction','gt'};
r.display.selectedchannel=[true false true];r.display.indexed=[false true true];
r.display.rgb=ones(3,3);r.display.intensity=[1 1 1;0 0 0;0 0 0];
r.display.displaylim=[0 0 0;128 1 1];r.display.alpha=ones(1,3);
r.display.contour=false(1,3);r.display.width=ones(1,3);
end
