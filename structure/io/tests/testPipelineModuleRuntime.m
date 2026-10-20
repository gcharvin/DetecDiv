function tests=testPipelineModuleRuntime
tests=functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.path=path;
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'structure','io'));
end

function teardownOnce(tc)
path(tc.TestData.path);
end

function setup(tc)
tc.TestData.fixture=tempname; mkdir(tc.TestData.fixture);
tc.TestData.before=path;
end

function teardown(tc)
path(tc.TestData.before);
root=char(java.io.File(tc.TestData.fixture).getCanonicalPath());
assert(strcmpi(fileparts(root),char(java.io.File(tempdir).getCanonicalPath())));
rmdir(root,'s');
end

function testPreparePinsOnceAndKeepsEffectiveParamsOutOfUserOverrides(tc)
pkg='runtimePinProbe'; folder=makeModule(tc,pkg,true);
writeText(fullfile(folder,'selection.txt'),'first');
classifier=struct('strid','classifier_1','path',folder);
ctx=struct('runId','run_1','pipeline',struct('currentNode','node_1'), ...
    'params',struct('requested','original'));
ctx.moduleRuntime=struct('package',pkg,'parameters',struct('model','stale_previous_node'));
[ctx,first]=pipelineModulePrepare(pkg,classifier,ctx);
writeText(fullfile(folder,'selection.txt'),'second');
[ctx,second]=pipelineModulePrepare(pkg,classifier,ctx);
verifyEqual(tc,first.parameters.model,'first');
verifyEqual(tc,second.parameters.model,'first');
verifyEqual(tc,ctx.params,struct('requested','original'));
verifyEqual(tc,numel(pipelineModuleRuntimeRecords(ctx)),1);
verifyEqual(tc,numel(first.provenance.adapter.file.sha256),64);
verifyEqual(tc,numel(first.provenance.preparation.sha256),64);
verifyNotEmpty(tc,first.provenance.detecdiv.gitCommit);
ctx.runId='run_2';
[~,next]=pipelineModulePrepare(pkg,classifier,ctx);
verifyEqual(tc,next.parameters.model,'second');
end

function testStaticValidationDoesNotPrepareOrReadArtifacts(tc)
pkg='runtimeStaticProbe'; folder=makeModule(tc,pkg,true);
node=struct('type','classifier','pkg',pkg,'id','node_1','params',struct('reject',true));
before=path;
[d,records]=pipelineModuleValidation(node,struct());
verifyEqual(tc,{d.severity},{'error'});
verifyEqual(tc,d.nodeId,'node_1');
verifyEqual(tc,records.package,pkg);
verifyFalse(tc,isfile(fullfile(folder,'prepared.txt')));
verifyEqual(tc,path,before);
end

function testNormalizedRoiParametersAreSeparateFromPreparedSelection(tc)
pkg='runtimeTraceProbe'; folder=makeModule(tc,pkg,true);
writeText(fullfile(folder,'selection.txt'),'one-deployment');
classifier=struct('strid','trace_classifier','path',folder);
ctx=struct('runId','trace-run','run', ...
    struct('eventLogPath',fullfile(tc.TestData.fixture,'trace_events.jsonl')));
[ctx,prepared]=pipelineModulePrepare(pkg,classifier,ctx);
pipelineModuleTraceParameters(ctx,struct('resolvedChannel','mask_a','gain',2),'roi_a');
pipelineModuleTraceParameters(ctx,struct('resolvedChannel','mask_b','gain',3),'roi_b');
records=pipelineModuleRuntimeRecords(ctx);
verifyEqual(tc,records.parameters,prepared.parameters);
verifyEqual(tc,{records.executionParameters.roiId},{'roi_a','roi_b'});
verifyEqual(tc,records.executionParameters(2).parameters.resolvedChannel,'mask_b');
lines=splitlines(strtrim(fileread(ctx.run.eventLogPath)));
verifyEqual(tc,numel(lines),3);
event=jsondecode(lines{3});
verifyEqual(tc,event.type,'module_execution_parameters');
verifyEqual(tc,event.ExecutionParameters.parameters.gain,3);
verifyNotEmpty(tc,jsonencode(records));
end

function testLegacyDoesNotExecuteSourceHookFromAnotherCopy(tc)
pkg='runtimeLegacyProbe'; source=makeModule(tc,pkg,true);
installed=fullfile(tc.TestData.fixture,'installed'); mkdir(installed);
folder=fullfile(installed,['+' pkg]); mkdir(folder);
writeText(fullfile(folder,'classify.m'),'function out=classify(varargin), out=[]; end');
addpath(installed,'-begin');
classifier=struct('strid','legacy','path',folder);
[~,record]=pipelineModulePrepare(pkg,classifier,struct());
verifyEqual(tc,record.status,'legacy');
verifyEqual(tc,record.provenance.adapter.path,fullfile(folder,'classify.m'));
verifyFalse(tc,isfile(fullfile(source,'prepared.txt')));
end

function testDeclaredMissingHookStopsAndPersistsFailedDiagnostic(tc)
pkg='runtimeMissingProbe'; folder=makeModule(tc,pkg,true);
delete(fullfile(folder,'prepareRuntime.m'));
ctx=struct('runId','missing','moduleRuntimeCache', ...
    containers.Map('KeyType','char','ValueType','any'));
ctx.run=struct('eventLogPath',fullfile(tc.TestData.fixture,'events.jsonl'));
classifier=struct('strid','missing','path',folder);
verifyError(tc,@()pipelineModulePrepare(pkg,classifier,ctx),'pipelineModulePrepare:Failed');
records=pipelineModuleRuntimeRecords(ctx);
verifyEqual(tc,records.status,'failed');
verifyEqual(tc,records.diagnostics.code,'pipelineModuleHooks:Missing');
event=jsondecode(strtrim(fileread(ctx.run.eventLogPath)));
verifyEqual(tc,event.ModuleRuntime.status,'failed');
end

function testFileIdentityStreamsExactBytesAndDetectsChange(tc)
file=fullfile(tc.TestData.fixture,'bytes.dat');
fid=fopen(file,'wb'); fwrite(fid,uint8([0 1 128 255]),'uint8'); fclose(fid);
first=pipelineModuleFileIdentity(file);
verifyEqual(tc,first.bytes,4);
verifyEqual(tc,first.sha256,'0ff830e8c68aca18063bce54c3191d5c116a2dfe33249538b252746cb777ef10');
writeText(file,'changed');
second=pipelineModuleFileIdentity(file);
verifyNotEqual(tc,first.sha256,second.sha256);
end

function folder=makeModule(tc,pkg,declared)
parent=fullfile(tc.TestData.fixture,pkg); mkdir(parent);
folder=fullfile(parent,['+' pkg]); mkdir(folder);
writeText(fullfile(folder,'classify.m'),'function out=classify(varargin), out=[]; end');
if declared
    manifest=struct('format','detecdiv.module.v1','id',['test.' pkg], ...
        'package',pkg,'type','classifier','entrypoints',struct( ...
        'execute',[pkg '.classify'],'validate',[pkg '.validateModule'], ...
        'prepare',[pkg '.prepareRuntime']), ...
        'compatibility',struct('runtimeContract','detecdiv.module_runtime.v1'));
    writeText(fullfile(folder,'module.json'),jsonencode(manifest));
end
writeText(fullfile(folder,'validateModule.m'),sprintf([ ...
    'function d=validateModule(p)\n' ...
    'd=struct(''severity'',{},''code'',{},''message'',{},''parameter'',{});\n' ...
    'if isfield(p,''reject'')&&p.reject\n' ...
    'd=struct(''severity'',''error'',''code'',''fixture:Rejected'',''message'',''Rejected'',''parameter'',''reject''); end\nend\n']));
writeText(fullfile(folder,'prepareRuntime.m'),sprintf([ ...
    'function r=prepareRuntime(c,ctx)\n' ...
    'if isfield(ctx,''moduleRuntime''), error(''fixture:StalePin'',''Old pin reached a new preparation''); end\n' ...
    'folder=fileparts(mfilename(''fullpath''));\n' ...
    'fid=fopen(fullfile(folder,''prepared.txt''),''w''); fclose(fid);\n' ...
    'r=struct(''format'',''detecdiv.module_runtime.v1'',''parameters'',struct(''model'',fileread(fullfile(folder,''selection.txt''))), ...\n' ...
    '''diagnostics'',struct(''severity'',{},''code'',{},''message'',{},''parameter'',{}),''context'',struct(),''provenance'',struct());\nend\n']));
addpath(parent,'-begin');
end

function writeText(file,value)
fid=fopen(file,'w'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,value,'char');
end
