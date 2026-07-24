function tests = testTrackastraJointContract
%TESTTRACKASTRAJOINTCONTRACT Verify opt-in joint decoder metadata.
tests = functiontests(localfunctions);
end

function testJointDecoderIsExplicitOptIn(testCase)
p = trackastra.utils.defaultExecutionParam();
verifyFalse(testCase,p.jointDecoder);
verifyTrue(testCase,p.jointOverwriteOutputFamily);
verifyNotEmpty(testCase,p.jointOutputFamilyName);
end

function testExecutionSpecExposesNoRepositoryPath(testCase)
spec = trackastra.executionSpec([]);
verifyTrue(testCase,ismember('jointDecoder',spec.staticKeys));
verifyTrue(testCase,ismember('jointOutputFamilyName',spec.outputKeys));
allKeys = [spec.staticKeys spec.artifactKeys spec.environmentKeys ...
    spec.outputKeys];
verifyFalse(testCase,any(contains(lower(string(allKeys)), ...
    {'repository','packagepath','pythonmodule'})));
end

function testJointLineagePersistsWithoutDuplicatingMask(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
roiobj = roi('joint_contract',[1 1 8 8]);
roiobj.path = folder;
tracked = zeros(8,8,2,'uint16');
tracked(2:5,2:5,:) = 1;
tracked(5:7,5:7,2) = 2;
roiobj.image = reshape(single(tracked),8,8,1,2);
roiobj.channelid = 1;
displayState = roiobj.display;
displayState.channel = {'results_joint_track'};
displayState.indexed = true;
displayState.rgb = [1 1 1];
roiobj.display = displayState;
p = trackastra.utils.defaultExecutionParam();
p.jointOutputFamilyName = 'Joint lineage test';
audit = struct('lineage_edges',struct( ...
    'status','linked', ...
    'pred_parent_id',1, ...
    'child_track_id',2, ...
    'bud_appearance_frame',2, ...
    'top_score',0.99));
[familyId,~] = trackastra.persistJointLineage( ...
    roiobj,tracked,'results_joint_track',p,audit,'joint.json');
[model,loadReport] = roiobj.loadCellModel('Force',true);
verifyTrue(testCase,loadReport.validation.ok);
[familyIndex,resolvedId] = cellModel.familyIndex( ...
    model,p.jointOutputFamilyName);
verifyNotEmpty(testCase,familyIndex);
verifyEqual(testCase,resolvedId,uint32(familyId));
verifyEqual(testCase, ...
    model.families.mask_provider{familyIndex},'results_joint_track');
relations = model.relations.family_id == uint32(familyId);
verifyEqual(testCase,sum(relations),1);
verifyEqual(testCase,model.relations.parent_track_id(relations),uint64(1));
verifyEqual(testCase,model.relations.child_track_id(relations),uint64(2));
end

function removeFolder(folder)
if isfolder(folder)
    try rmdir(folder,'s'); catch, end
end
end
