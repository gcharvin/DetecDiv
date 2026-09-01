function tests = testCellLatentModelMaterializeTracks
tests=functiontests(localfunctions);
end

function testCreatesAndPopulatesIndexedTrackChannel(testCase)
r=roi('synthetic',[1 1 5 4]);
r.image=zeros(4,5,2,3,'uint16');
r.display.channel={'BF','instances'};
r.display.intensity=ones(2,3);
r.display.rgb=ones(2,3);
r.display.indexed=[false true];
r.display.alpha=ones(1,2);
r.display.contour=[false true];
r.display.width=ones(1,2);
r.display.selectedchannel=ones(1,2);
r.channelid=[1 2];
tracks=uint16(cat(3,ones(4,5),2*ones(4,5),3*ones(4,5)));

[image,name]=cellLatentModel.utils.materializeTracks( ...
    r,tracks,'results_pred_tracks',1:3);

verifyEqual(testCase,name,'results_pred_tracks');
idx=r.findChannelID(name,'exact');
verifyEqual(testCase,idx,3);
verifyEqual(testCase,squeeze(image(:,:,idx,:)),tracks);
verifyEqual(testCase,squeeze(r.image(:,:,idx,:)),tracks);
verifyTrue(testCase,r.display.indexed(3));
end

function testReusesExistingTrackChannel(testCase)
r=roi('synthetic',[1 1 5 4]);
r.image=zeros(4,5,2,3,'uint16');
r.display.channel={'BF','results_pred_tracks'};
r.display.intensity=[1 1 1;0 0 0];
r.display.rgb=ones(2,3);
r.display.indexed=[false true];
r.display.alpha=ones(1,2);
r.display.contour=[false true];
r.display.width=ones(1,2);
r.display.selectedchannel=ones(1,2);
r.channelid=[1 2];
tracks=uint16(7*ones(4,5,3));

image=cellLatentModel.utils.materializeTracks( ...
    r,tracks,'results_pred_tracks',1:3);

verifyEqual(testCase,size(image,3),2);
verifyEqual(testCase,squeeze(image(:,:,2,:)),tracks);
end

function testAttachesCompactLogicalTrackChannelWithoutDuplicate(testCase)
r=roi('synthetic',[1 1 5 4]);
r.image=zeros(4,5,2,3,'uint16');
r.display.channel={'BF','instances','results_pred_tracks'};
r.display.intensity=[1 1 1;0 0 0;0 0 0];
r.display.rgb=ones(3,3);
r.display.indexed=[false true true];
r.display.alpha=ones(1,3);
r.display.contour=[false true true];
r.display.width=ones(1,3);
r.display.selectedchannel=ones(1,3);
r.channelid=[1 2];
tracks=uint16(9*ones(4,5,3));

image=cellLatentModel.utils.materializeTracks( ...
    r,tracks,'results_pred_tracks',1:3);

verifyEqual(testCase,size(image,3),3);
verifyEqual(testCase,r.channelid,[1 2 3]);
verifyEqual(testCase,r.display.channel, ...
    {'BF','instances','results_pred_tracks'});
verifyEqual(testCase,sum(strcmpi(r.display.channel, ...
    'results_pred_tracks')),1);
verifyEqual(testCase,squeeze(image(:,:,3,:)),tracks);
end

function testReloadsPersistedCompactTrackChannelAndSaves(testCase)
testRoot=tempname;
mkdir(testRoot);
cleanup=onCleanup(@()cleanupDir(testRoot)); %#ok<NASGU>
r=roi('compact_tracks',[1 1 5 4]);
r.path=testRoot;
r.image=zeros(4,5,1,3,'uint16');
r.display.channel={'BF'};
r.display.intensity=ones(1,3);
r.display.rgb=ones(1,3);
r.display.indexed=false;
r.display.alpha=1;
r.display.contour=false;
r.display.width=1;
r.display.selectedchannel=1;
r.channelid=1;
r.addChannel(ones(4,5,1,3,'uint16'),'instances', ...
    [1 1 1],[0 0 0]);
r.addChannel(2*ones(4,5,1,3,'uint16'),'results_pred_tracks', ...
    [1 1 1],[0 0 0]);
verifyTrue(testCase,r.save([],false));

r.image=[];
r.load('Channel',{'BF','instances'},'Data',false,'Silent');
verifyEmpty(testCase,r.findChannelID('results_pred_tracks','exact'));
verifyEqual(testCase,sum(strcmpi(r.display.channel, ...
    'results_pred_tracks')),1);
tracks=uint16(11*ones(4,5,3));
cellLatentModel.utils.materializeTracks( ...
    r,tracks,'results_pred_tracks',1:3);

verifyEqual(testCase,r.channelid,[1 2 3]);
verifyEqual(testCase,sum(strcmpi(r.display.channel, ...
    'results_pred_tracks')),1);
verifyTrue(testCase,r.save([],false));
fresh=roi(r.id,r.value);
fresh.path=testRoot;
fresh.load('Silent');
verifyEqual(testCase,sum(strcmpi(fresh.display.channel, ...
    'results_pred_tracks')),1);
idx=fresh.findChannelID('results_pred_tracks','exact');
verifyEqual(testCase,squeeze(fresh.image(:,:,idx,:)),tracks);
end

function testRepairsDuplicateLogicalTrackNames(testCase)
r=roi('synthetic',[1 1 5 4]);
r.image=zeros(4,5,2,3,'uint16');
r.display.channel={'BF','results_pred_tracks','results_pred_tracks'};
r.display.intensity=[1 1 1;0 0 0;0 0 0];
r.display.rgb=ones(3,3);
r.display.indexed=[false true true];
r.display.alpha=[1 .35 .35];
r.display.contour=[false true true];
r.display.width=[1 1.5 1.5];
r.display.selectedchannel=ones(1,3);
r.channelid=[1 3];
tracks=uint16(13*ones(4,5,3));

image=cellLatentModel.utils.materializeTracks( ...
    r,tracks,'results_pred_tracks',1:3);

verifyEqual(testCase,r.display.channel,{'BF','results_pred_tracks'});
verifyEqual(testCase,r.channelid,[1 2]);
verifyEqual(testCase,squeeze(image(:,:,2,:)),tracks);
end

function testRejectsMismatchedTrackShape(testCase)
r=roi('synthetic',[1 1 5 4]);
r.image=zeros(4,5,1,3,'uint16');
verifyError(testCase,@()cellLatentModel.utils.materializeTracks( ...
    r,zeros(4,4,3,'uint16'),'results_pred_tracks',1:3), ...
    'cellLatentModel:TrackShapeMismatch');
end


function cleanupDir(pathStr)
if exist(pathStr,'dir')==7
    rmdir(pathStr,'s');
end
end
