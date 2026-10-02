function tests = testPipelineRoiPatternPersistence
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testReopeningRunKeepsItsPatternDespiteChangedSharedTemplate(testCase)
saved = patternNode('roipattern_2', 80);
current = [patternNode('roipattern_2', 130), patternNode('new_pattern', 40)];
ctx.pipelineSpec.nodes = jsondecode(jsonencode(saved));
[restored, ids] = pipelineRestoreRoiPatternsFromRun(current, ctx);
verifyEqual(testCase, restored(1).params, ctx.pipelineSpec.nodes.params);
verifyEqual(testCase, restored(2), current(2));
verifyEqual(testCase, ids, {'roipattern_2'});
end

function testMissingSnapshotKeepsTemplate(testCase)
current = patternNode('roipattern_2', 130);
verifyEqual(testCase, pipelineRestoreRoiPatternsFromRun(current, struct()), current);
end

function testEmptyNewFovCannotFallBackToOldProjectRois(testCase)
project = shallow();
old = fov(); old.id = 'Pos0'; old.roi = roi(); old.roi.id = 'Pos0_1';
new = fov(); new.id = 'Pos11';
project.fov = [old new];
ctx = struct('shallow', project, 'sel', struct('fovs', 2));
verifyEmpty(testCase, pipelineScopeRoisToSelectedFovs(old.roi, ctx));
end

function testOnlySelectedFovRoisSurviveProjectFallback(testCase)
project = shallow();
first = fov(); first.id = 'Pos0'; first.roi = roi(); first.roi.id = 'Pos0_1';
second = fov(); second.id = 'Pos11'; second.roi = roi(); second.roi.id = 'Pos11_1';
project.fov = [first second];
ctx = struct('shallow', project, 'sel', struct('fovs', 2));
rois = pipelineScopeRoisToSelectedFovs([first.roi second.roi], ctx);
verifyEqual(testCase, {rois.id}, {'Pos11_1'});
ctx.sel.fovs = [];
verifyEqual(testCase, numel(pipelineScopeRoisToSelectedFovs([first.roi second.roi], ctx)), 2);
end

function node = patternNode(id, width)
node = struct('id',id,'type','roiPattern','params',struct( ...
    'threshold',0.5,'referenceFrame',5,'channel','channel000_z001', ...
    'pattern',struct('rect',[1 1 width width],'image',ones(width))));
end
