function tests = testPipelineRunMutationRefresh
tests = functiontests(localfunctions);
end

function testManifestAndTargetedChannelRefresh(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() localRemoveTree(root)); %#ok<NASGU>

writer = localWriterRoi(root, 'roi_1');
verifyTrue(testCase, writer.save([], false));

stale = roi('roi_1', [1 1 4 3]);
stale.path = root;
stale.load('Channel', 'input', 'Data', false, 'Silent');
verifyEqual(testCase, stale.display.channel, {'input'});
verifyEqual(testCase, size(stale.image, 3), 1);

runObj = pipelineRun('', 'mutation_test', 1);
runObj.targetRef = struct('type', 'classi', 'projectPath', '', ...
    'projectName', '', 'fovIds', [], 'roiIds', 1, ...
    'classiPath', root, 'notes', 'test');
report = localReport();
ctx = struct('runId', 'mutation_test', 'roiList', writer, ...
    'targetRef', runObj.targetRef);

manifest = detecdiv_build_run_mutation_manifest(runObj, [], report, ctx);
verifyEqual(testCase, manifest.protocol, 'detecdiv.roi-mutations.v1');
verifyEqual(testCase, manifest.roiIds, {'roi_1'});
verifyEqual(testCase, manifest.rois(1).channels, {'results_cellposeSAM_cell'});

roundTrip = jsondecode(jsonencode(manifest));
verifyEqual(testCase, char(string(roundTrip.rois(1).id)), 'roi_1');

runObj.path = fullfile(root, 'pipeline_runs', runObj.runId);
runObj.status = 'done';
runObj.outputs = struct('report', report, 'mutationManifest', manifest);
pipelineRunSave(runObj);
persisted = jsondecode(fileread(fullfile(runObj.path, 'run.json')));
verifyEqual(testCase, char(string(persisted.outputs.mutationManifest.protocol)), ...
    'detecdiv.roi-mutations.v1');

refresh = detecdiv_refresh_run_mutations(manifest, ...
    'RoiList', stale, 'RetryCount', 1, 'RetryPause', 0);
verifyEqual(testCase, refresh.refreshedRois, 1);
verifyEqual(testCase, refresh.refreshedChannels, 1);
verifyTrue(testCase, any(strcmp(stale.display.channel, 'results_cellposeSAM_cell')));
verifyEqual(testCase, size(stale.image, 3), 2);
verifyEqual(testCase, squeeze(stale.image(1,1,2,:))', uint16([11 12 13]));
end

function testOnlyManifestRoiIsRefreshed(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() localRemoveTree(root)); %#ok<NASGU>

writer1 = localWriterRoi(root, 'roi_1');
writer2 = localWriterRoi(root, 'roi_2');
verifyTrue(testCase, writer1.save([], false));
verifyTrue(testCase, writer2.save([], false));

stale1 = localStaleRoi(root, 'roi_1');
stale2 = localStaleRoi(root, 'roi_2');
runObj = pipelineRun('', 'mutation_subset', 1);
runObj.targetRef = struct('type', 'classi', 'projectPath', '', ...
    'projectName', '', 'fovIds', [], 'roiIds', 1, ...
    'classiPath', root, 'notes', 'test');
ctx = struct('runId', 'mutation_subset', 'roiList', writer1, ...
    'targetRef', runObj.targetRef);
manifest = detecdiv_build_run_mutation_manifest(runObj, [], localReport(), ctx);

refresh = detecdiv_refresh_run_mutations(manifest, ...
    'RoiList', [stale1 stale2], 'RetryCount', 1, 'RetryPause', 0);
verifyEqual(testCase, refresh.matchedRois, 1);
verifyTrue(testCase, any(strcmp(stale1.display.channel, 'results_cellposeSAM_cell')));
verifyFalse(testCase, any(strcmp(stale2.display.channel, 'results_cellposeSAM_cell')));
end

function testNestedLineageSourceIsReportedAsDataseriesMutation(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() localRemoveTree(root)); %#ok<NASGU>

writer = roi('roi_lineage', [1 1 4 3]);
writer.path = root;
ds = dataseries;
ds.groupid = 'cell_information';
sourceKey = matlab.lang.makeValidName('Cell latent lineage GFP v001');
ds.userData = struct('lineageSources', struct());
ds.userData.lineageSources.(sourceKey) = struct( ...
    'outputName', 'Cell latent lineage GFP v001', ...
    'displayName', 'Cell latent lineage GFP v001');
writer.data = ds;

runObj = pipelineRun('', 'mutation_lineage', 1);
runObj.targetRef = struct('type', 'classi', 'projectPath', '', ...
    'projectName', '', 'fovIds', [], 'roiIds', 1, ...
    'classiPath', root, 'notes', 'test');
report = localLineageReport();
ctx = struct('runId', 'mutation_lineage', 'roiList', writer, ...
    'targetRef', runObj.targetRef);

manifest = detecdiv_build_run_mutation_manifest(runObj, [], report, ctx);

verifyEqual(testCase,manifest.rois(1).dataSeries,{'cell_information'});
verifyTrue(testCase,manifest.rois(1).reloadData);
verifyEqual(testCase,manifest.outputs(1).dataSeries,{'cell_information'});
end

function r = localWriterRoi(root, id)
r = roi(id, [1 1 4 3]);
r.path = root;
r.image = zeros(3, 4, 2, 3, 'uint16');
r.image(:,:,1,:) = 5;
r.image(:,:,2,1) = 11;
r.image(:,:,2,2) = 12;
r.image(:,:,2,3) = 13;
r.channelid = [1 2];
r.display = localDisplay();
end

function r = localStaleRoi(root, id)
r = roi(id, [1 1 4 3]);
r.path = root;
r.load('Channel', 'input', 'Data', false, 'Silent');
end

function display = localDisplay()
display = struct( ...
    'intensity', [1 1 1; 0 0 0], ...
    'frame', 1, ...
    'selectedchannel', [1 1], ...
    'binning', 1, ...
    'rgb', [1 1 1; 1 0 0], ...
    'channel', {{'input', 'results_cellposeSAM_cell'}}, ...
    'stretchlim', [], ...
    'displaylim', [0 0; 20 20], ...
    'indexed', [false true], ...
    'alpha', [1 0.35], ...
    'contour', [false false], ...
    'width', [1 1]);
end

function report = localReport()
report = struct('nodeRuns', struct( ...
    'nodeId', 'classifier_cellposesam_1', ...
    'nodeType', 'classifier', ...
    'status', 'done', ...
    'runPolicy', 'restart', ...
    'existingPolicy', 'replace', ...
    'outputName', 'cellposeSAM', ...
    'durationSec', 1, ...
    'before', struct(), ...
    'after', struct(), ...
    'message', ''));
end

function report = localLineageReport()
report = struct('nodeRuns', struct( ...
    'nodeId', 'classifier_celllatentmodel_2', ...
    'nodeType', 'classifier', ...
    'status', 'done', ...
    'runPolicy', 'restart', ...
    'existingPolicy', 'replace', ...
    'outputName', 'Cell latent lineage GFP v001', ...
    'durationSec', 1, ...
    'before', struct(), ...
    'after', struct(), ...
    'message', ''));
end

function localRemoveTree(pathText)
if isfolder(pathText)
    rmdir(pathText, 's');
end
end
