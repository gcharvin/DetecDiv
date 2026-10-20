function tests = testCellposeModuleRuntime
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
root = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(fullfile(root,'engine','classification'),fullfile(root,'structure','io'));
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testDefaultAliasIsExplicitlyUnverified(testCase)
folder = freshFolder(testCase);
c = classifier(folder);
before = dir(folder);
prepared = cellposesam.prepareRuntime(c,struct());
verifyEqual(testCase,prepared.format,'detecdiv.module_runtime.v1');
verifyEqual(testCase,prepared.context.cellposeModelPath,'sam');
verifyEqual(testCase,prepared.provenance.model.verification,'deferred');
verifyEqual(testCase,prepared.provenance.model.identity.sha256,'');
verifyTrue(testCase,any(strcmp({prepared.diagnostics.code},'BackendManagedModel')));
verifyTrue(testCase,prepared.provenance.engine.runner.exists);
verifyTrue(testCase,prepared.provenance.engine.script.exists);
after = dir(folder);
verifyEqual(testCase,{after.name},{before.name});
end

function testLocalModelPriorityAndChecksums(testCase)
folder = freshFolder(testCase);
c = classifier(folder);
mkdir(fullfile(folder,'models'));
model = fullfile(folder,'models',c.strid);
writeText([model '.pth'],'suffix weights');
prepared = cellposesam.prepareRuntime(c,struct());
verifyEqual(testCase,prepared.context.cellposeModelPath,[model '.pth']);
verifyEqual(testCase,prepared.provenance.model.identity, ...
    pipelineModuleFileIdentity([model '.pth']));
writeText(model,'legacy exact filename weights');
prepared = cellposesam.prepareRuntime(c,struct());
verifyEqual(testCase,prepared.context.cellposeModelPath,model);
verifyEqual(testCase,prepared.provenance.model.source,'classifier_local');
verifyEqual(testCase,prepared.provenance.model.verification,'sha256');
end

function testActualLegacyParametersAndNodeOverrides(testCase)
folder = freshFolder(testCase);
c = classifier(folder);
c.trainingParam = struct('diameter',22,'flow_threshold',0.2);
c.executionParam = struct('diameter',999,'min_size',999);
c.outputType = 'both';
ctx = struct('params',struct('diameter',33,'trackInstances',false, ...
    'outputType','probability'),'names',struct('outputName','pred_test'));
prepared = cellposesam.prepareRuntime(c,ctx);
verifyEqual(testCase,prepared.parameters.diameter,33);
verifyEqual(testCase,prepared.parameters.flow_threshold,0.2);
verifyEqual(testCase,prepared.parameters.min_size,10);
verifyFalse(testCase,prepared.parameters.trackInstances);
verifyEqual(testCase,prepared.parameters.outputType,'probability');
verifyEqual(testCase,prepared.parameters.outputName,'pred_test');
verifyEqual(testCase,c.executionParam.diameter,999);
end

function testInvalidPinnedRunFailsBeforeROIOrPythonAccess(testCase)
c = classifier('');
record = struct('format','detecdiv.module_runtime.v1','package','cellposesam', ...
    'classifierId',c.strid,'runId','earlier-run','status','ready', ...
    'parameters',struct('outputName','pred'),'context',struct('cellposeModelPath','sam'));
ctx = struct('moduleRuntime',record,'runId','current-run');
verifyError(testCase,@()cellposesam.classify([],c,ctx), ...
    'cellposesam:InvalidPinnedModuleRuntime');
end

function testStaticDiagnosticsPreserveOutputFallback(testCase)
diagnostics = cellposesam.validateModule(struct('outputMode','historical_unknown'));
verifyEqual(testCase,{diagnostics.severity},{'warning'});
verifyEqual(testCase,{diagnostics.code},{'LegacyOutputModeFallback'});
diagnostics = cellposesam.validateModule(struct('diameter',NaN));
verifyEmpty(testCase,diagnostics);
diagnostics = cellposesam.validateModule(struct('flow_threshold',[1 2]));
verifyEqual(testCase,diagnostics.severity,'error');
verifyEqual(testCase,diagnostics.parameter,'flow_threshold');
verifyEmpty(testCase,cellposesam.validateModule(struct()));
end

function testNumericTextKeepsLegacyPythonParsing(testCase)
params = struct('diameter','22.5','flow_threshold',"0.4",'cell_prob_threshold','-1');
verifyEmpty(testCase,cellposesam.validateModule(params));
prepared = cellposesam.prepareRuntime(classifier(freshFolder(testCase)), ...
    struct('params',params));
verifyEqual(testCase,prepared.parameters.diameter,'22.5');
verifyEqual(testCase,prepared.parameters.flow_threshold,"0.4");
verifyEqual(testCase,prepared.parameters.cell_prob_threshold,'-1');
verifyEmpty(testCase,cellposesam.validateModule(struct('diameter','NaN', ...
    'flow_threshold','none','cell_prob_threshold','null')));
diagnostics = cellposesam.validateModule(struct('diameter','unparseable'));
verifyEqual(testCase,diagnostics.severity,'error');
diagnostics = cellposesam.validateModule(struct('min_size','10'));
verifyEqual(testCase,diagnostics.severity,'error');
end

function c = classifier(folder)
c = struct('strid','test_model','path',folder,'classifierPkg','cellposesam', ...
    'trainingParam',struct(),'executionParam',struct(),'outputType','segmentation');
end

function folder = freshFolder(testCase)
folder = tempname;
mkdir(folder);
testCase.addTeardown(@()removeFolder(folder));
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder,'s'); end
end

function writeText(path,value)
fid = fopen(path,'w');
assert(fid >= 0);
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,value,'char');
end
