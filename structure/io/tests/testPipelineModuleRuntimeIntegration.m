function tests = testPipelineModuleRuntimeIntegration
% Runtime checks precede ROI mutation and feed both runner reports.
tests = functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.originalPath = path;
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root, 'helpers'), fullfile(root, 'structure', 'io'));
addpath(fullfile(root, 'structure', 'classes'));
end

function teardownOnce(t)
path(t.TestData.originalPath);
end

function setup(t)
t.TestData.fixtureRoot = tempname;
t.TestData.fixturePath = path;
mkdir(t.TestData.fixtureRoot);
t.TestData.pkg = 'runtimeIntegrationProbe';
makePackage(t.TestData.fixtureRoot, t.TestData.pkg);
addpath(t.TestData.fixtureRoot, '-begin');
setappdata(0, 'RuntimeIntegrationPrepareCalls', 0);
setappdata(0, 'RuntimeIntegrationClassifyCalls', 0);
if isappdata(0, 'DetecDivLastPipelineReport')
    rmappdata(0, 'DetecDivLastPipelineReport');
end
end

function teardown(t)
path(t.TestData.fixturePath);
for key = {'RuntimeIntegrationPrepareCalls','RuntimeIntegrationClassifyCalls'}
    if isappdata(0, key{1}), rmappdata(0, key{1}); end
end
root = char(java.io.File(t.TestData.fixtureRoot).getCanonicalPath());
temporaryRoot = char(java.io.File(tempdir).getCanonicalPath());
assert(strcmpi(fileparts(root), temporaryRoot), ...
    'testPipelineModuleRuntimeIntegration:UnsafeCleanup', ...
    'Refusing to remove a fixture outside the temporary root.');
if isfolder(root), rmdir(root, 's'); end
end

function testDryRunUsesStaticValidationWithoutPreparation(t)
node = makeNode(t.TestData.pkg, struct('invalidStatic', true));
[ok, report] = runPipelineDry(singlePipe(node), inputContext(t), struct('allowGui', false));
verifyFalse(t, ok);
verifyTrue(t, any(contains(report.errors, 'Static runtime fixture rejection')));
verifyNotEmpty(t, report.moduleValidation);
verifyEqual(t, getappdata(0, 'RuntimeIntegrationPrepareCalls'), 0);
verifyEqual(t, getappdata(0, 'RuntimeIntegrationClassifyCalls'), 0);
verifyFalse(t, any(contains(report.warnings, 'Semantic validation skipped')));
end

function testPreparationFailurePrecedesRoiMutation(t)
classif = fixtureClassifier(t);
ctx = inputContext(t);
ctx.params = struct('failPrepare', true);
ctx.moduleRuntimeCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
ctx.runId = 'prepare_failure';
ctx.run.eventLogPath = fullfile(t.TestData.fixtureRoot, 'direct_events.jsonl');
beforeImage = ctx.roiList.image;
beforeDisplay = ctx.roiList.display;
verifyError(t, @()classifyData(classif, ctx.roiList, 'Ctx', ctx), ...
    'pipelineModulePrepare:Failed');
verifyEqual(t, ctx.roiList.image, beforeImage);
verifyEqual(t, ctx.roiList.display, beforeDisplay);
verifyEqual(t, getappdata(0, 'RuntimeIntegrationClassifyCalls'), 0);
records = pipelineModuleRuntimeRecords(ctx);
verifyEqual(t, numel(records), 1);
verifyEqual(t, records.status, 'failed');
verifyTrue(t, isfile(ctx.run.eventLogPath));
verifyTrue(t, contains(fileread(ctx.run.eventLogPath), 'fixture:PreparationFailed'));
end

function testSharedInvocationCachePinsBeforeEveryRoi(t)
classif = fixtureClassifier(t);
ctx = struct('runId', 'one_invocation', ...
    'pipeline', struct('currentNode', 'runtime_node'), ...
    'moduleRuntimeCache', containers.Map('KeyType', 'char', 'ValueType', 'any'));
classifyData(classif, roi.empty, 'Ctx', ctx);
classifyData(classif, roi.empty, 'Ctx', ctx);
verifyEqual(t, getappdata(0, 'RuntimeIntegrationPrepareCalls'), 1);
verifyEqual(t, getappdata(0, 'RuntimeIntegrationClassifyCalls'), 0);
records = pipelineModuleRuntimeRecords(ctx);
verifyEqual(t, numel(records), 1);
verifyEqual(t, records.status, 'ready');
end

function testPreparationReceivesDefaultAndExplicitOutputNames(t)
classif = fixtureClassifier(t);
for explicitName = {'', 'selected_prediction'}
    ctx = struct('moduleRuntimeCache', ...
        containers.Map('KeyType', 'char', 'ValueType', 'any'));
    if isempty(explicitName{1})
        classifyData(classif, roi.empty, 'Ctx', ctx);
        expected = classif.strid;
    else
        classifyData(classif, roi.empty, 'Ctx', ctx, 'OutputName', explicitName{1});
        expected = explicitName{1};
    end
    record = pipelineModuleRuntimeRecords(ctx);
    verifyEqual(t, record.parameters.outputName, expected);
end
verifyEqual(t, getappdata(0, 'RuntimeIntegrationClassifyCalls'), 0);
end

function testWindowsPackageAliasKeepsCanonicalRuntimeIdentity(t)
assumeTrue(t, ispc, 'MATLAB package aliases are case-sensitive on other platforms.');
pkg = t.TestData.pkg;
alias = lower(pkg);
selected = which([alias '.classify']);
assumeNotEmpty(t, selected, 'This MATLAB installation does not resolve lowercase package aliases.');
hooks = pipelineModuleHooks(alias);
verifyTrue(t, hooks.supported);
verifyEqual(t, hooks.package, pkg);
classif = fixtureClassifier(t);
ctx = struct('runId', 'case_alias', ...
    'moduleRuntimeCache', containers.Map('KeyType', 'char', 'ValueType', 'any'));
[ctx, record] = pipelineModulePrepare(alias, classif, ctx);
verifyEqual(t, record.package, pkg);
[~, again] = pipelineModulePrepare(alias, classif, ctx);
verifyEqual(t, again.package, pkg);
verifyEqual(t, getappdata(0, 'RuntimeIntegrationPrepareCalls'), 1);
end

function testBothRunnersRetainFailureProvenance(t)
pipe = singlePipe(makeNode(t.TestData.pkg, struct('failPrepare', true)));
for runner = {@runPipeline, @runPipelineDetecDiv}
    ctx = inputContext(t);
    ctx.run.eventLogPath = fullfile(t.TestData.fixtureRoot, ...
        [func2str(runner{1}) '_events.jsonl']);
    caught = [];
    try
        runner{1}(pipe, ctx);
    catch ME
        caught = ME;
    end
    verifyNotEmpty(t, caught, 'Preparation must reject the run.');
    if isempty(caught), continue; end
    verifyTrue(t, contains(caught.message, 'Preparation fixture rejection'));
    verifyTrue(t, isappdata(0, 'DetecDivLastPipelineReport'));
    report = getappdata(0, 'DetecDivLastPipelineReport');
    verifyEqual(t, {report.nodeRuns.status}, {'failed'});
    verifyEqual(t, numel(report.moduleRuntime), 1);
    verifyEqual(t, report.moduleRuntime.status, 'failed');
    verifyEqual(t, report.moduleRuntime.nodeId, 'runtime_node');
    verifyTrue(t, contains(fileread(ctx.run.eventLogPath), 'fixture:PreparationFailed'));
end
verifyEqual(t, getappdata(0, 'RuntimeIntegrationPrepareCalls'), 2);
verifyEqual(t, getappdata(0, 'RuntimeIntegrationClassifyCalls'), 0);
end

function testBothRunnersResetAndRemoveInvocationCache(t)
p = customModule.setparam();
p.entryPoint = 'customModule.example';
p.parametersJson = '{"value":2,"scale":3}';
p.outputPorts = 'tables';
node = struct('id', 'simple_custom', 'type', 'custom', 'pkg', 'customModule', ...
    'func', 'customModule.process', 'params', p);
for runner = {@runPipeline, @runPipelineDetecDiv}
    ctx = struct();
    ctx.moduleRuntime = struct('status', 'stale_previous_run');
    ctx.moduleRuntimeCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
    ctx.moduleRuntimeCache('old') = ctx.moduleRuntime;
    [out, report] = runner{1}(singlePipe(node), ctx);
    verifyEqual(t, out.tables.Value, 6);
    verifyEmpty(t, report.moduleRuntime);
    verifyEmpty(t, out.moduleRuntime);
    verifyFalse(t, isfield(out, 'moduleRuntimeCache'));
end
end

function ctx = inputContext(t)
item = roi('runtime_roi', [1 1 3 3]);
item.path = t.TestData.fixtureRoot;
item.image = uint16(reshape(1:9, 3, 3));
item.display.channel = {'BF'};
ctx = struct('roiList', item, 'channels', {{'BF'}}, ...
    'io', struct('saveMode', 'defer'));
end

function classif = fixtureClassifier(t)
classif = classi('', 'runtime_fixture', 1, 'InitTraining', false);
classif.strid = 'runtime_fixture';
classif.path = t.TestData.fixtureRoot;
classif.classifierPkg = t.TestData.pkg;
classif.classifyFun = [t.TestData.pkg '.classify'];
classif.channelName = {'BF'};
classif.classes = {'cell'};
end

function node = makeNode(pkg, params)
node = struct('id', 'runtime_node', 'type', 'classifier', 'pkg', pkg, ...
    'func', [pkg '.classify'], 'params', params);
end

function pipe = singlePipe(node)
pipe = struct('nodes', node, 'edges', struct([]), 'branches', struct([]));
end

function makePackage(parent, pkg)
folder = fullfile(parent, ['+' pkg]); mkdir(folder);
manifest = struct('format', 'detecdiv.module.v1', ...
    'id', ['test.' pkg], 'name', pkg, 'type', 'classifier', ...
    'package', pkg, 'adapterVersion', '0.1.0', 'summary', 'Runtime integration fixture', ...
    'capabilities', {{'test'}}, 'entrypoints', struct('execute', [pkg '.classify'], ...
    'parameters', [pkg '.executionSpec'], 'contract', [pkg '.moduleContract'], ...
    'validate', [pkg '.validateModule'], 'prepare', [pkg '.prepareRuntime']), ...
    'compatibility', struct('detecdiv', '*', 'pipelineContract', 'detecdiv.module_contract.v1', ...
    'runtimeContract', 'detecdiv.module_runtime.v1'), ...
    'provenance', struct('repository', 'https://example.test/runtime-fixture'));
writeText(fullfile(folder, 'module.json'), jsonencode(manifest));
writeText(fullfile(folder, 'executionSpec.m'), strjoin({ ...
    'function spec=executionSpec(varargin)', ...
    'spec=struct(''staticKeys'',{{''invalidStatic'',''failPrepare''}},''defaults'',struct(),''requiresRuntimeClassifier'',false,''requiresRoiImages'',false);', ...
    'end'}, newline));
writeText(fullfile(folder, 'moduleContract.m'), strjoin({ ...
    'function c=moduleContract(varargin)', ...
    'c=struct(''format'',''detecdiv.module_contract.v1'');', ...
    'c.in=struct(''name'',''roiList'',''type'',''roiList'',''required'',true,''source'',''edge'');', ...
    'c.out=c.in;', ...
    'r=struct(''type'',{},''role'',{},''symbol'',{},''param'',{},''port'',{},''nameParam'',{},''required'',{},''transfer'',{});', ...
    'c.resources=struct(''in'',r,''out'',r);', ...
    'c.requirements=struct(''roi'',struct(''channelsMin'',0),''params'',struct(''required'',{{}}));', ...
    'c.parameters=struct(''template'',{{}},''run'',{{}});', ...
    'c.capabilities=struct(''outputsMasks'',false,''roiMasks'',false,''outputsDataSeries'',false,''roiDataSeries'',false);', ...
    'c.binding=struct(''mode'',''none'',''selectorKeys'',{{}},''minCount'',0,''exactCount'',[]);', ...
    'c.summary=''Runtime integration fixture'';', ...
    'end'}, newline));
writeText(fullfile(folder, 'validateModule.m'), strjoin({ ...
    'function d=validateModule(p)', ...
    'd=struct(''severity'',{},''code'',{},''message'',{},''parameter'',{});', ...
    'if isfield(p,''invalidStatic'') && p.invalidStatic', ...
    'd=struct(''severity'',''error'',''code'',''fixture:StaticRejected'',''message'',''Static runtime fixture rejection'',''parameter'',''invalidStatic'');', ...
    'end', 'end'}, newline));
writeText(fullfile(folder, 'prepareRuntime.m'), strjoin({ ...
    'function p=prepareRuntime(classif,ctx)', ...
    'n=getappdata(0,''RuntimeIntegrationPrepareCalls''); setappdata(0,''RuntimeIntegrationPrepareCalls'',n+1);', ...
    'if isfield(ctx,''params'') && isfield(ctx.params,''failPrepare'') && ctx.params.failPrepare', ...
    'error(''fixture:PreparationFailed'',''Preparation fixture rejection'');', ...
    'end', ...
    'd=struct(''severity'',{},''code'',{},''message'',{},''parameter'',{});', ...
    'parameters=struct(''resolvedValue'',17,''outputName'','''');', ...
    'if isfield(ctx,''names'') && isfield(ctx.names,''outputName''), parameters.outputName=ctx.names.outputName; end', ...
    'p=struct(''format'',''detecdiv.module_runtime.v1'',''parameters'',parameters,''diagnostics'',d,''provenance'',struct(''engine'',''fixture''),''context'',struct());', ...
    'end'}, newline));
writeText(fullfile(folder, 'classify.m'), strjoin({ ...
    'function out=classify(varargin)', ...
    'n=getappdata(0,''RuntimeIntegrationClassifyCalls''); setappdata(0,''RuntimeIntegrationClassifyCalls'',n+1);', ...
    'error(''fixture:UnexpectedInference'',''These integration checks must not perform inference'');', ...
    'out=struct();', 'end'}, newline));
end

function writeText(filename, contents)
fid = fopen(filename, 'w');
assert(fid >= 0, 'Cannot create runtime integration fixture.');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', contents);
end
