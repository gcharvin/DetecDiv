function tests = testPipelineCustomModule
tests = functiontests(localfunctions);
end

function testContextFunctionAndArgumentConsumerInBothRunners(t)
p = customModule.setparam();
p.entryPoint = 'customModule.example';
p.parametersJson = '{"value":3,"scale":2}';
p.outputPorts = 'tables';
q = customModule.setparam();
q.entryPoint = 'table2struct';
q.callMode = 'arguments';
q.inputPorts = 'tables';
q.outputPorts = 'metrics';
q.argumentsJson = '[{"context":"tables"}]';
pipe = struct('nodes', [node('producer', p) node('consumer', q)], ...
    'edges', edge('producer', 'consumer', 'tables'), 'branches', struct([]));
for runner = {@runPipeline, @runPipelineDetecDiv}
    [ctx, report] = runner{1}(pipe, struct());
    verifyEqual(t, ctx.tables.Value, 6);
    verifyEqual(t, ctx.metrics.Value, 6);
    verifyEqual(t, {report.nodeRuns.status}, {'done','done'});
    verifyEqual(t, numel(ctx.customModuleRuns), 2);
    verifyEqual(t, strlength(string(ctx.customModuleRuns(1).sha256)), 64);
end
end

function testSaveLoadRunOverrideAndDryRun(t)
root = tempname; mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
pipe = pipeline(root, 'custom_test', 1);
p = customModule.setparam();
p.entryPoint = 'customModule.example';
p.parametersJson = '{"value":3,"scale":2}';
p.outputPorts = 'tables';
pipe.nodes = node('custom_1', p);
pipelineSave(pipe, 'Artifacts', false);
[loaded, message] = pipelineLoad(fullfile(pipe.path, 'pipeline.json'));
assert(~isempty(loaded), message);
c = pipelineNodeContract(loaded.nodes);
verifyEqual(t, {c.out.name}, {'tables'});
project = shallow(); project.fov = fov.empty;
project.io = struct('path', root, 'file', 'project');
ctx.run.nodeParams.custom_1.parametersJson = '{"value":7,"scale":3}';
run = pipelineRunNew(project, loaded.strid, loaded.path, 'Ctx', ctx);
run.ctx.pipelineSpec = struct('nodes', loaded.nodes, 'edges', struct([]));
[ok, dry] = runPipelineDry(loaded, run.ctx, struct('allowGui', false));
verifyTrue(t, ok, strjoin(dry.errors, ' | '));
verifyFalse(t, isfield(run.ctx, 'tables'));
[out, report] = runPipelineDetecDiv(loaded, run.ctx);
verifyEqual(t, out.tables.Value, 21);
verifyEqual(t, loaded.nodes.params.parametersJson, p.parametersJson);
run.ctx = out; run.outputs.report = report; run.status = 'done';
pipelineRunSave(run, struct('verbose', false, 'sidecars', false));
[restored, message] = pipelineRunLoad(fullfile(run.path, 'run.json'));
assert(~isempty(restored), message);
verifyEqual(t, restored.status, 'done');
verifyEqual(t, restored.ctx.customModuleRuns.entryPoint, 'customModule.example');
verifyEqual(t, restored.ctx.pipelineSpec.nodes.params.outputPorts, 'tables');
end

function testExplicitArgumentsLiteralsReferencesAndMultipleOutputs(t)
root = tempname; mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
writeFunction(fullfile(root, 'customTestPair.m'), ...
    sprintf('function [a,b] = customTestPair(x,scale,label)\na=x*scale; b=label;\nend\n'));
p = customModule.setparam();
p.codeFolder = root; p.entryPoint = 'customTestPair.m';
p.callMode = 'arguments'; p.inputPorts = 'source'; p.outputPorts = 'answer, label';
p.parametersJson = '{"scale":4}';
p.argumentsJson = '[{"context":"source"},{"param":"scale"},"ok"]';
originalPath = path;
ctx = customModule.process(struct('source', 5, 'params', p));
verifyEqual(t, ctx.answer, 20); verifyEqual(t, ctx.label, 'ok');
verifyEqual(t, path, originalPath);
end

function testRelativeCodeFolderAndFilePickerReference(t)
root = tempname; mkdir(root); mkdir(fullfile(root, 'code'));
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
file = fullfile(root, 'code', 'relativeCustomTest.m');
writeFunction(file, sprintf('function ctx=relativeCustomTest(ctx)\nctx.answer=ctx.params.value;\nend\n'));
ref = customModule.referenceForFile(file, root);
verifyEqual(t, ref.codeFolder, 'code');
pipe = pipeline(); pipe.path = root;
p = customModule.setparam(); p.entryPoint = ref.entryPoint; p.codeFolder = ref.codeFolder;
p.parametersJson = '{"value":11}'; p.outputPorts = 'answer';
pipe.nodes = node('relative', p);
[ctx, ~] = runPipelineDetecDiv(pipe, struct());
verifyEqual(t, ctx.answer, 11);
direct = customModule.process(struct('params',p, ...
    'pipelineRef',struct('path',fullfile(root,'pipeline.json'))));
verifyEqual(t,direct.answer,11);
end

function testPreflightNeverCallsUserCodeAndRejectsScripts(t)
root = tempname; mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
writeFunction(fullfile(root, 'mustNotRun.m'), ...
    sprintf('function ctx=mustNotRun(ctx)\nerror(''test:Executed'',''Executed during preflight'');\nend\n'));
p = customModule.setparam(); p.entryPoint = 'mustNotRun'; p.codeFolder = root;
[ok, report] = runPipelineDry(singlePipe(p), struct(), struct('allowGui', false));
verifyTrue(t, ok, strjoin(report.errors, ' | '));
writeFunction(fullfile(root, 'legacyCustomScript.m'), 'answer = 42;');
p.entryPoint = 'legacyCustomScript';
[ok, report] = runPipelineDry(singlePipe(p), struct(), struct('allowGui', false));
verifyFalse(t, ok); verifyTrue(t, any(contains(report.errors, 'Wrap scripts')));
end

function testInvalidConfigurationsAndMissingInputs(t)
p = customModule.setparam(); p.entryPoint = 'customModule.example';
cases = { 'parametersJson', '[]'; 'argumentsJson', '{"x":1}'; ...
    'entryPoint', 'disp(1)'; 'inputPorts', 'roiList,roiList'; ...
    'outputPorts', 'run'; 'callMode', 'unknown'; 'codeFolder', 'missing_custom_folder' };
for i = 1:size(cases,1)
    invalid = p; invalid.(cases{i,1}) = cases{i,2};
    [ok, report] = runPipelineDry(singlePipe(invalid), struct(), struct('allowGui', false));
    verifyFalse(t, ok, cases{i,1}); verifyNotEmpty(t, report.errors);
end
p.inputPorts = 'unavailable';
[ok, report] = runPipelineDry(singlePipe(p), struct(), struct('allowGui', false));
verifyFalse(t, ok); verifyTrue(t, any(contains(report.errors, 'Missing inputs')));
end

function testMissingOutputsAndInvalidContextAreErrors(t)
p = customModule.setparam(); p.entryPoint = 'customModule.example';
p.parametersJson = '{"value":3,"scale":2}'; p.outputPorts = 'absent';
verifyError(t, @()customModule.process(struct('params',p)), 'customModule:MissingOutput');
root = tempname; mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
writeFunction(fullfile(root, 'invalidCustomContext.m'), sprintf('function result=invalidCustomContext(ctx)\nresult=42;\nend\n'));
p.entryPoint = 'invalidCustomContext'; p.codeFolder = root; p.outputPorts = '';
verifyError(t, @()customModule.process(struct('params',p)), 'customModule:InvalidContext');
end

function testArgumentsMustDeclareContextInputsAndParameters(t)
p = customModule.setparam(); p.entryPoint = 'disp'; p.callMode = 'arguments';
p.argumentsJson = '[{"context":"tables"}]';
verifyError(t, @()customModule.configuration(p), 'customModule:Argument');
p.argumentsJson = '[{"param":"missing"}]';
verifyError(t, @()customModule.configuration(p), 'customModule:MissingArgument');
end

function testJsonArgumentsPreserveNestedArraysAndEscapedStrings(t)
args = customModule.parseArguments('[[1,2],[3,4],"comma,quote\"slash\\",{"value":{"label":"x,y"}},null]');
verifyEqual(t,numel(args),5);
verifyEqual(t,args{1},[1;2]); verifyEqual(t,args{2},[3;4]);
verifyEqual(t,args{3},'comma,quote"slash\');
verifyEqual(t,args{4}.value.label,'x,y'); verifyEmpty(t,args{5});
end

function testUserFailureRestoresPathAndDisabledNodesSkipPreflight(t)
root = tempname; mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
writeFunction(fullfile(root, 'failCustomTest.m'), ...
    sprintf('function ctx=failCustomTest(ctx)\nerror(''test:ExpectedFailure'',''Intentional failure'');\nend\n'));
p = customModule.setparam(); p.entryPoint = 'failCustomTest'; p.codeFolder = root;
originalPath = path;
verifyError(t, @()customModule.process(struct('params',p)), 'test:ExpectedFailure');
verifyEqual(t, path, originalPath);
p.entryPoint = 'unavailable_function';
n = node('disabled', p); n.enabled = false;
verifyEmpty(t, customModule.validate(n, struct()));
end

function testWorkerPayloadExecutesAndPersistsCustomRun(t)
root = tempname; mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
project = shallow(); project.fov = fov.empty;
project.io = struct('path',root,'file','worker_project');
mkdir(fullfile(root,'worker_project'));
projectFile = fullfile(root,'worker_project.json');
shallowProjectExportLight(project,projectFile);
pipe = pipeline(root,'worker_custom',1);
p = customModule.setparam(); p.entryPoint = 'customModule.example';
p.parametersJson = '{"value":2,"scale":4}'; p.outputPorts = 'tables';
pipe.nodes = node('custom_1',p); pipelineSave(pipe,'Artifacts',false);
run = pipelineRunNew(project,pipe.strid,pipe.path);
payload = pipelineRunJobPayload(run,project,fullfile(pipe.path,'pipeline.json'));
payload.project_ref.project_mat_path = projectFile;
payload.execution.save_project = false;
result = detecdiv_run_pipeline_job(payload);
verifyEqual(t,result.status,'done');
[restored,message] = pipelineRunLoad(result.run_json_path);
assert(~isempty(restored),message);
verifyEqual(t,restored.ctx.customModuleRuns.entryPoint,'customModule.example');
verifyEqual(t,restored.outputs.report.nodeRuns.status,'done');
end

function testCopiedTemplateDefaultsAndOverridesInBothRunners(t)
root = tempname; mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
source = fileread(which('customModule.template'));
source = strrep(source, 'function ctx = template(ctx)', ...
    'function ctx = userTemplateTest(ctx)');
writeFunction(fullfile(root, 'userTemplateTest.m'), source);
p = customModule.setparam(); p.entryPoint = 'userTemplateTest';
p.codeFolder = root; p.outputPorts = 'tables';
for runner = {@runPipeline, @runPipelineDetecDiv}
    [ctx, report] = runner{1}(singlePipe(p), struct('userMarker', 42));
    verifyEqual(t, ctx.tables.Value, 6);
    verifyEqual(t, ctx.userMarker, 42);
    verifyEqual(t, report.nodeRuns.status, 'done');
    initial.run.nodeParams.custom_1.parametersJson = '{"value":4,"scale":5}';
    [ctx, report] = runner{1}(singlePipe(p), initial);
    verifyEqual(t, ctx.tables.Value, 20);
    verifyEqual(t, report.nodeRuns.status, 'done');
end
p.parametersJson = '{"value":"invalid"}';
verifyError(t, @()customModule.process(struct('params',p)), ...
    'MATLAB:userTemplateTest:invalidType');
end

function pipe = singlePipe(p)
pipe = struct('nodes', node('custom_1',p), 'edges', struct([]), 'branches', struct([]));
end
function n = node(id,p)
n = struct('id',id,'type','custom','pkg','customModule','func','customModule.process','params',p,'enabled',true);
end
function e = edge(from,to,port)
e = struct('from',from,'to',to,'fromPort',port,'toPort',port,'condition','');
end
function writeFunction(file, text)
fid = fopen(file,'w'); cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
