function tests = testBudMotherLinkerExternalIntegration
%TESTBUDMOTHERLINKEREXTERNALINTEGRATION Exercise the real Python boundary.
tests = functiontests(localfunctions);
end

function testPythonInferencePersistsCanonicalLineage(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));

roiobj = syntheticTrackedROI(folder);
param = budMotherLinker.utils.defaultExecutionParam();
param.trackChannelName = 'results_trackastra';
param.outputFamilyName = 'External linker integration';
param.rankMarginThreshold = 0;
param.trackingLoadGuard = false;
param.maxParentContourDistance = 25;
ctx = struct('store', struct('workDir', fullfile(folder, 'runtime')));

[resolved, ~, imageout] = budMotherLinker.core(param, roiobj, ctx);
verifyEmpty(testCase, imageout);
verifyEqual(testCase, resolved.runtime.backend, 'Python');
verifyEqual(testCase, resolved.runtime.package, 'cell_lineage_linker');
verifyTrue(testCase, isfile(resolved.auditFile));
verifyTrue(testCase, isfile(resolved.cellModelFile));

audit = jsondecode(fileread(resolved.auditFile));
verifyEqual(testCase, audit.tool, 'cell_lineage_linker');
verifyGreaterThanOrEqual(testCase, double(audit.summary.events), 1);
verifyGreaterThanOrEqual(testCase, double(audit.summary.linked), 1);
verifyTrue(testCase, isfield(audit, 'detecdiv_runtime'));

[model, report] = roiobj.loadCellModel('Force', true);
verifyTrue(testCase, report.validation.ok);
[familyIndex, familyId] = cellModel.familyIndex( ...
    model, param.outputFamilyName);
verifyNotEmpty(testCase, familyIndex);
verifyEqual(testCase, ...
    model.families.mask_provider{familyIndex}, 'results_trackastra');
verifyEqual(testCase, ...
    model.families.lineage_source{familyIndex}, 'budMotherLinker');
relations = model.relations.family_id == familyId;
verifyGreaterThanOrEqual(testCase, nnz(relations), 1);
verifyTrue(testCase, all(model.relations.parent_track_id(relations) > 0));
verifyTrue(testCase, all(model.relations.child_track_id(relations) > 0));
end

function roiobj = syntheticTrackedROI(folder)
height = 80;
width = 80;
frames = 12;
[xx, yy] = meshgrid(1:width, 1:height);
stack = zeros(height, width, frames, 'uint16');
for frame = 1:frames
    plane = zeros(height, width, 'uint16');
    plane(((xx-32)/10).^2 + ((yy-40)/13).^2 <= 1) = 1;
    plane(((xx-58)/9).^2 + ((yy-40)/12).^2 <= 1) = 2;
    if frame >= 3
        radius = min(8, 4 + floor((frame-1)/2));
        plane(((xx-43)/radius).^2 + ((yy-35)/(radius+1)).^2 <= 1) = 3;
    end
    stack(:,:,frame) = plane;
end

roiobj = roi('external_linker_integration', [1 1 width height]);
roiobj.path = folder;
roiobj.image = reshape(stack, height, width, 1, frames);
roiobj.channelid = 1;
displayState = roiobj.display;
displayState.channel = {'results_trackastra'};
displayState.indexed = true;
displayState.rgb = [1 1 1];
roiobj.display = displayState;
end

function removeFolder(folder)
if isfolder(folder)
    try rmdir(folder, 's'); catch, end
end
end
