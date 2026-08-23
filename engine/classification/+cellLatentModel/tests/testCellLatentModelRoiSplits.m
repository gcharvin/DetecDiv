function tests = testCellLatentModelRoiSplits
tests = functiontests(localfunctions);
end

function testAutomaticSplitIsStableAcrossTableOrderAndRelocation(testCase)
classifier = splitFixture(6);
[trainA,valA,testA,auditA] = cellLatentModel.resolveRoiSplits( ...
    classifier,1:6,0.34);
verifyEqual(testCase,numel(trainA),4);
verifyEqual(testCase,numel(valA),2);
verifyEmpty(testCase,testA);
verifyEqual(testCase,auditA.mode,'automatic');
verifyEqual(testCase,auditA.algorithm, ...
    'sha256_ranked_stable_roi_identity_v1');
verifyEqual(testCase,auditA.stable_identity_contract,'roi.id');
verifyEqual(testCase,double(auditA.counts.validation_rois),2);
verifyEqual(testCase,double(auditA.actual_validation_roi_fraction),2/6, ...
    'AbsTol',eps);

expectedValidationIds = sort(string({classifier.roi(valA).id}));
order = [4 2 6 1 5 3];
relocated = classifier;
relocated.roi = classifier.roi(order);
for i = 1:numel(relocated.roi)
    relocated.roi(i).path = fullfile('X:\relocated', ...
        relocated.roi(i).id);
end
relocated.dataset.split.train = 1:6;
[~,valB] = cellLatentModel.resolveRoiSplits(relocated,1:6,0.34);
actualValidationIds = sort(string({relocated.roi(valB).id}));
verifyEqual(testCase,actualValidationIds,expectedValidationIds, ...
    ['Automatic validation membership must depend on stable ROI IDs, not ' ...
     'classifierGUI row order or the current storage root.']);
end

function testExplicitValidationRemainsAuthoritative(testCase)
classifier = splitFixture(5);
classifier.dataset.split.train = 1:5;
classifier.dataset.split.val = 3;
classifier.dataset.split.test = 5;
[train,val,test,audit] = cellLatentModel.resolveRoiSplits( ...
    classifier,[],NaN);
verifyEqual(testCase,train,[1 2 4]);
verifyEqual(testCase,val,3);
verifyEqual(testCase,test,5);
verifyEqual(testCase,audit.mode,'explicit');
verifyEqual(testCase,audit.algorithm,'classifier_dataset_split_val');
verifyFalse(testCase,ismember(5,[train val]));
end

function testTestRoisAreExcludedBeforeAutomaticSelection(testCase)
classifier = splitFixture(6);
classifier.dataset.split.train = 1:6;
classifier.dataset.split.val = [];
classifier.dataset.split.test = [2 6];
[train,val,test,audit] = cellLatentModel.resolveRoiSplits( ...
    classifier,[],0.25);
verifyEqual(testCase,test,[2 6]);
verifyEmpty(testCase,intersect([train val],test));
verifyEqual(testCase,sort([train val]),[1 3 4 5]);
verifyEqual(testCase,double(audit.counts.candidate_rois),4);
verifyEqual(testCase,double(audit.counts.validation_rois),1);
end

function testDuplicateStableIdsAreRejected(testCase)
classifier = splitFixture(3);
classifier.roi(3).id = classifier.roi(1).id;
verifyError(testCase,@() cellLatentModel.resolveRoiSplits( ...
    classifier,1:3,0.34), ...
    'cellLatentModel:DuplicateStableRoiIdentity');
end

function testDuplicateStableIdCannotCrossExplicitTrainTest(testCase)
classifier = splitFixture(3);
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = 3;
classifier.roi(3).id = classifier.roi(1).id;
verifyError(testCase,@() cellLatentModel.resolveRoiSplits( ...
    classifier,[],0.2), ...
    'cellLatentModel:DuplicateStableRoiIdentity');
end

function testInvalidAutomaticFractionIsRejected(testCase)
classifier = splitFixture(3);
verifyError(testCase,@() cellLatentModel.resolveRoiSplits( ...
    classifier,1:3,1), ...
    'cellLatentModel:InvalidValidationFraction');
end

function classifier = splitFixture(count)
rois = repmat(struct('id','','path',''),1,count);
for i = 1:count
    rois(i).id = sprintf('Pos0_1_%02d',i);
    rois(i).path = fullfile('C:\source',rois(i).id);
end
classifier = struct( ...
    'strid','split_fixture', ...
    'roi',rois, ...
    'dataset',struct('split',struct( ...
        'train',1:count,'val',[],'test',[])), ...
    'trainingset',1:count);
end
