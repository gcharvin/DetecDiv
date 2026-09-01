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

function testRejectsMismatchedTrackShape(testCase)
r=roi('synthetic',[1 1 5 4]);
r.image=zeros(4,5,1,3,'uint16');
verifyError(testCase,@()cellLatentModel.utils.materializeTracks( ...
    r,zeros(4,4,3,'uint16'),'results_pred_tracks',1:3), ...
    'cellLatentModel:TrackShapeMismatch');
end
