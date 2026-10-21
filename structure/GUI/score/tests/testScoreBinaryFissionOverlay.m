function tests = testScoreBinaryFissionOverlay
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root);
detecdiv_setup_path(root);
testCase.TestData.visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
end

function teardownOnce(testCase)
set(groot,'DefaultFigureVisible',testCase.TestData.visibility);
end

function testNoFutureFission(testCase)
[model,masks] = fixture();
verifyEmpty(testCase,cellModelLineageSegments(model,1,1,masks,true));
end

function testTerminatedParentUsesItsOwnFrameDespiteLabelReuse(testCase)
[model,masks] = fixture();
s = cellModelLineageSegments(model,1,2,masks,true);
verifyNumElements(testCase,s,2);
verifyEqual(testCase,[s.parentFrame],[1 1]);
verifyEqual(testCase,[s.childFrame],[2 2]);
verifyEqual(testCase,[s.parentTrack],uint64([10 10]));
verifyEqual(testCase,[s.childTrack],uint64([20 30]));
verifyEqual(testCase,s(1).parentLabel,s(1).childLabel);
verifyEqual(testCase,s(1).parentXY,[3.5 3.5]);
verifyEqual(testCase,s(1).childXY,[7.5 3.5]);
verifyTrue(testCase,all([s.historical]));
end

function testFullAncestrySurvivesSecondGeneration(testCase)
[model,masks] = fixture();
s = cellModelLineageSegments(model,1,4,masks,true);
verifyNumElements(testCase,s,4);
verifyEqual(testCase,[s.childTrack],uint64([20 30 40 50]));
verifyEqual(testCase,[s.childFrame],[3 4 4 4]);
verifyEqual(testCase,[s.parentFrame],[1 1 3 3]);
end

function testMissingVisibleMasksDoNotProduceGhostTrees(testCase)
[model,masks] = fixture();
masks(:,:,:,4) = 0;
verifyEmpty(testCase,cellModelLineageSegments(model,1,4,masks,true));
verifyEmpty(testCase,cellModelLineageSegments(model,2,4,masks,true));
end

function testBudModeKeepsOnlyDirectVisibleChildren(testCase)
[model,masks] = fixture();
s = cellModelLineageSegments(model,1,4,masks,false);
verifyEqual(testCase,[s.childTrack],uint64([30 40 50]));
end

function testExplicitMaskPlane(testCase)
[model,masks] = fixture();
volume = cat(3,zeros(size(masks),'like',masks),masks);
expected = cellModelLineageSegments(model,1,4,masks,true);
verifyEqual(testCase,cellModelLineageSegments(model,1,4,volume,true,2),expected);
verifyEmpty(testCase,cellModelLineageSegments(model,1,4,volume,true,1));
end

function testBinaryFissionJoinsCurrentSistersOnce(testCase)
[model,masks] = binaryFixture();
before = model;
verifyEmpty(testCase,cellModelLineageSegments(model,1,1,masks,true));
s = cellModelLineageSegments(model,1,2,masks,true);
verifyNumElements(testCase,s,1);
verifyEqual(testCase,s.siblingTracks,uint64([20 30]));
verifyEqual(testCase,s.parentTrack,uint64(10));
verifyEqual(testCase,s.parentXY,[7.5 3.5]);
verifyEqual(testCase,s.childXY,[12.5 3.5]);
verifyEqual(testCase,[s.parentFrame s.childFrame],[2 2]);
verifyFalse(testCase,s.historical);
verifyEqual(testCase,model,before);
end

function testBinarySisterLinkFollowsMovementAndEndsAtNextDivision(testCase)
[model,masks] = binaryFixture();
masks(:,:,1,3) = circshift(masks(:,:,1,3),[3 2]);
s = cellModelLineageSegments(model,1,3,masks,true);
verifyNumElements(testCase,s,1);
verifyEqual(testCase,s.parentXY,[9.5 6.5]);
verifyEqual(testCase,s.childXY,[14.5 6.5]);
s = cellModelLineageSegments(model,1,4,masks,true);
verifyNumElements(testCase,s,1);
verifyEqual(testCase,s.siblingTracks,uint64([40 50]));
verifyEqual(testCase,[s.parentFrame s.childFrame],[4 4]);
verifyEqual(testCase,cellModelLineageSegments(model,1,4,masks,false),s);
end

function testBinarySisterLinkRequiresBothCurrentCellsAndCompleteEvent(testCase)
[model,masks] = binaryFixture();
% Explicit indexing avoids treating the same label in another frame as visible.
plane = masks(:,:,1,2); plane(plane==8) = 0; masks(:,:,1,2) = plane;
verifyEmpty(testCase,cellModelLineageSegments(model,1,2,masks,true));
[model,masks] = binaryFixture();
model.relations.child_track_id(2) = uint64(20); % Duplicate is not a sibling pair.
verifyEmpty(testCase,cellModelLineageSegments(model,1,2,masks,true));
end

function testBinarySisterRenderingIsSymmetricInAllRenderers(testCase)
[model,masks] = binaryFixture();
masks(:,:,1,3) = circshift(masks(:,:,1,3),[3 2]);
r = roi('sister-overlay',[1 1 24 24]);
r.image = cat(3,repmat(uint16(16000),[24 24 1 5]),masks);
r.channelid = 1:2;
r.display.channel = {'raw','tracks'};
r.display.indexed = [false true];
r.display.rgb = [1 1 1;0 1 0];
r.display.selectedchannel = [true true];
r.display.contour = [false true];
r.cellModel = model; r.cellModelInfo.loaded = true;
r.display.lineage = struct('enabled',true,'channelName','tracks', ...
    'channelPix',2,'sourceKey','cell_model:1','modelFamilyId',1, ...
    'showGenealogy',true,'showBudPairing',false);
opts = score_collectDisplayOptions('mode','display','overlay',false, ...
    'frames',2,'Nrow',1,'Ncol',1,'Nchannel',1,'hideStamp',true);
opts.channel = r.display.channel;
opts.levels = {[0 65535],{'-1','lines',0.5,true,1}};
opts.RGB = {[1 1 1],[0 1 0]};
opts.tileH = 120; opts.tileW = 120; opts.scale = false;
opts.ShowLineageOverlay = true; opts.ShowBudPairingOverlay = false;
for renderMode = {'raster','vector','per-object'}
    opts.LineageRenderMode = renderMode{1};
    opts.LineagePerObjectVector = strcmp(renderMode{1},'per-object');
    if opts.LineagePerObjectVector, opts.LineageRenderMode = 'vector'; end
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    verifyGreaterThan(testCase,double(gh.lineageHandles.Count),0);
    for key = gh.lineageHandles.keys
        entry = gh.lineageHandles(key{1});
        verifyNumElements(testCase,entry.geoms,1);
        verifyFalse(testCase,entry.geoms.directed);
        verifyEqual(testCase,entry.geoms.lineStyle,'-');
        verifyEqual(testCase,[entry.geoms.xm entry.geoms.xd],[7.5 12.5]);
        if strcmp(renderMode{1},'raster')
            verifyTrue(testCase,any(entry.image.AlphaData(:)>0));
        end
    end
    verifyEmpty(testCase,findall(dh.Figure,'Type','quiver'));
    score_updateRender(gh,r,opts,dh,3);
    for key = gh.lineageHandles.keys
        entry = gh.lineageHandles(key{1});
        verifyEqual(testCase,[entry.geoms.xm entry.geoms.xd],[9.5 14.5]);
    end
    score_updateRender(gh,r,opts,dh,4);
    for key = gh.lineageHandles.keys
        entry = gh.lineageHandles(key{1});
        verifyNumElements(testCase,entry.geoms,1);
        verifyEqual(testCase,[entry.geoms.xm entry.geoms.xd],[7.5 10.5]);
    end
    score_updateRender(gh,r,opts,dh,1);
    for key = gh.lineageHandles.keys
        verifyEmpty(testCase,gh.lineageHandles(key{1}).geoms);
    end
    % Exercise the refresh directly too: score_updateRender intentionally
    % contains optional-overlay errors, which this renderer test must expose.
    refreshLineageOverlays(gh,r,opts,dh,1);
    for key = gh.lineageHandles.keys
        verifyEmpty(testCase,gh.lineageHandles(key{1}).geoms);
    end
    verifyEqual(testCase,r.cellModel,model);
    clear cleanup;
end
end

function testRenderingFissionAndClearingBeforeBirth(testCase)
[model,masks] = fixture();
r = roi('fission-overlay',[1 1 24 24]);
r.image = cat(3,repmat(uint16(16000),[24 24 1 5]),masks);
r.channelid = 1:2;
r.display.channel = {'raw','tracks'};
r.display.indexed = [false true];
r.display.rgb = [1 1 1;0 1 0];
r.display.selectedchannel = [true true];
r.display.contour = [false true];
r.cellModel = model; r.cellModelInfo.loaded = true;
r.display.lineage = struct('enabled',true,'channelName','tracks', ...
    'channelPix',2,'sourceKey','cell_model:1','modelFamilyId',1, ...
    'showGenealogy',true,'showBudPairing',false);
opts = score_collectDisplayOptions('mode','display','overlay',false, ...
    'frames',2,'Nrow',1,'Ncol',1,'Nchannel',1,'hideStamp',true);
opts.channel = r.display.channel;
opts.levels = {[0 65535],{'-1','lines',0.5,true,1}};
opts.RGB = {[1 1 1],[0 1 0]};
opts.tileH = 120; opts.tileW = 120; opts.scale = false;
opts.ShowLineageOverlay = true; opts.ShowBudPairingOverlay = false;
before = r.cellModel;
for renderMode = {'raster','vector'}
    opts.LineageRenderMode = renderMode{1};
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    verifyGreaterThan(testCase,double(gh.lineageHandles.Count),0);
    for key = gh.lineageHandles.keys
        entry = gh.lineageHandles(key{1});
        verifyNumElements(testCase,entry.geoms,2);
        verifyEqual(testCase,{entry.geoms.lineStyle},{'--','--'});
        verifyEqual(testCase,[entry.geoms.xm],[3.5 3.5]);
        if strcmp(renderMode{1},'raster')
            verifyTrue(testCase,any(entry.image.AlphaData(:)>0));
        else
            arrows = findall(dh.Figure,'Type','quiver');
            verifyNotEmpty(testCase,arrows);
            for arrow = reshape(arrows,1,[])
                verifyEqual(testCase,arrow.LineStyle,'--');
            end
        end
    end
    score_updateRender(gh,r,opts,dh,1);
    for key = gh.lineageHandles.keys
        verifyEmpty(testCase,gh.lineageHandles(key{1}).geoms);
    end
    verifyEqual(testCase,r.cellModel,before);
    clear cleanup;
end
end

function [model,masks] = fixture()
model = cellModel.create('fission-overlay');
model.families.family_id = uint32(1);
model.families.name = {'HOCT'};
model.families.mask_provider = {'tracks'};
model.families.lineage_source = {'prediction'};
model.families.color_rgb = uint8([0 255 255]);
% columns: frame, TrackID, mask label, x, y. Parent label 7 is reused.
data = [1 10 7 3 3;2 20 7 7 3;2 30 8 12 3;3 20 7 7 3;3 30 8 12 3; ...
    4 30 8 12 3;4 40 7 7 8;4 50 9 10 8;5 30 8 12 3;5 40 7 7 8;5 50 9 10 8];
n = size(data,1);
model.instances.object_id = uint64((1:n)');
model.instances.family_id = ones(n,1,'uint32');
model.instances.frame = uint32(data(:,1));
model.instances.track_id = uint64(data(:,2));
model.instances.mask_label = uint32(data(:,3));
model.instances.state_id = zeros(n,1,'uint16');
model.relations.relation_id = uint64((1:4)');
model.relations.family_id = ones(4,1,'uint32');
model.relations.parent_track_id = uint64([10;10;20;20]);
model.relations.child_track_id = uint64([20;30;40;50]);
model.relations.event_frame = uint32([2;2;4;4]);
model.relations.type_id = ones(4,1,'uint8');
model.relations.confidence = ones(4,1,'single');
model = cellModel.normalize(model);
masks = zeros(24,24,1,5,'uint16');
for row = data.'
    masks(row(5):row(5)+1,row(4):row(4)+1,1,row(1)) = uint16(row(3));
end
end

function [model,masks] = binaryFixture()
[model,masks] = fixture();
model.provenance.family_division_modes = struct('family_id',1,'mode','binary_fission');
end
