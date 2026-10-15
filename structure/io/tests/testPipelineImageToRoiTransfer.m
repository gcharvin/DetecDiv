function tests = testPipelineImageToRoiTransfer
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(root));
t.TestData.root = tempname; mkdir(t.TestData.root);
producer = pipelineNodeContract(struct('type','roiExtract','pkg','roiExtract'));
producer.binding.mode = 'none'; producer.binding.selectorKeys = {};
producer.requirements.roi.required = false;
producer.selectors.channelsParam = '';
consumer = pipelineNodeContract(struct('type','processor','pkg','ddTestSixChannelConsumer'));
consumer.requirements.roi.channelsMin = 6;
consumer.binding.mode = 'none'; consumer.binding.selectorKeys = {};
writePackage(t.TestData.root,'ddTestExtractionTransfer',producer);
producer.binding.transfer = '';
writePackage(t.TestData.root,'ddTestUndeclaredTransfer',producer);
writePackage(t.TestData.root,'ddTestSixChannelConsumer',consumer);
addpath(t.TestData.root);
end

function teardownOnce(t)
rmpath(t.TestData.root);
rmdir(t.TestData.root,'s');
end

function testDeclaredTransferProjectsRawChannels(t)
[pipe,ctx] = fixture('ddTestExtractionTransfer',6);
[ok,r] = validatePipeline(pipe,ctx,struct('allowGui',false));
verifyTrue(t,ok,strjoin(r.errors,' | '));
outputs = r.binding.nodes.extract.resources.outputs;
verifyTrue(t,all(ismember(ctx.channels,{outputs.concreteName})));
verifyTrue(t,all(strcmp({outputs.sourceKind},'imagesToRoi')));
end

function testOrdinaryProcessorDoesNotInheritRawChannels(t)
[pipe,ctx] = fixture('ddTestUndeclaredTransfer',6);
[ok,r] = validatePipeline(pipe,ctx,struct('allowGui',false));
verifyFalse(t,ok);
verifyTrue(t,any(contains(r.errors,'expects at least 6 channel(s)')));
end

function testInsufficientSourceInventoryStillFails(t)
[pipe,ctx] = fixture('ddTestExtractionTransfer',5); ctx.roiChannels = {};
[ok,r] = validatePipeline(pipe,ctx,struct('allowGui',false));
verifyFalse(t,ok);
verifyTrue(t,any(contains(r.errors,'expects at least 6 channel(s)')));
end

function [pipe,ctx] = fixture(producer,count)
a = node('extract',producer); b = node('analysis','ddTestSixChannelConsumer');
pipe = struct('nodes',[a b],'edges',struct('from','extract','to','analysis', ...
    'fromPort','roiList','toPort','roiList','condition',''));
names = arrayfun(@(i)sprintf('raw%d',i),1:count,'UniformOutput',false);
ctx = struct('images',1,'roiList',1,'channels',{names},'roiChannels',{{'Channel 1'}}, ...
    'run',struct('inputSourceMode','existing_rois'));
end

function n = node(id,pkg)
n = struct('id',id,'type','processor','pkg',pkg,'func',[pkg '.process'], ...
    'params',struct('pkg',pkg),'enabled',true);
end

function writePackage(root,name,contract)
folder = fullfile(root,['+' name]); mkdir(folder);
save(fullfile(folder,'contract.mat'),'contract');
fid = fopen(fullfile(folder,'executionSpec.m'),'w');
fprintf(fid,['function spec=executionSpec()\n' ...
    's=load(fullfile(fileparts(mfilename(''fullpath'')),''contract.mat''));\n' ...
    'spec=struct(''contract'',s.contract);\nend\n']); fclose(fid);
fid = fopen(fullfile(folder,'process.m'),'w');
fprintf(fid,'function out=process(varargin)\nout=[];\nend\n'); fclose(fid);
end
