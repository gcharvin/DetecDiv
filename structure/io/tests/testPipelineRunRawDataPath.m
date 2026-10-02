function tests = testPipelineRunRawDataPath
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));
end

function testOlderRunRestoresLoaderPathWhenRunPathIsAbsent(testCase)
ctx = jsondecode(jsonencode(struct('run',struct('rawDataPath',''), ...
    'dataLoader',struct('path','/data/Antoine/raw_data/acquisition'))));
verifyEqual(testCase,pipelineRunRawDataPath(ctx),'/data/Antoine/raw_data/acquisition');
end

function testExplicitRunPathWins(testCase)
ctx = struct('run',struct('rawDataPath','X:\new_raw'), ...
    'dataLoader',struct('path','/data/old_raw'));
verifyEqual(testCase,pipelineRunRawDataPath(ctx),'X:\new_raw');
end

function testSavedNodeOverrideWinsOverTemplateDefault(testCase)
ctx.pipelineSpec.nodes = struct('id','loader','type','dataLoader', ...
    'params',struct('path','template_raw'));
ctx.run.nodeParams = struct('id','loader','params',struct('path','selected_raw'));
verifyEqual(testCase,pipelineRunRawDataPath(ctx),'selected_raw');
end

function testMissingPathStaysEmpty(testCase)
verifyEmpty(testCase,pipelineRunRawDataPath(struct()));
verifyEmpty(testCase,pipelineRunRawDataPath(struct('rawDataPath','Project source path not resolved')));
end
