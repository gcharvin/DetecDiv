function tests=testPipeline2ClassifierReferenceUI
% Exercise trained-artifact and module-package controls on synthetic adapters.
tests=functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.before=path;
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(root,fullfile(root,'helpers'),fullfile(root,'structure','io'));
end

function teardownOnce(tc)
path(tc.TestData.before);
end

function testStandaloneModuleDoesNotAskForTrainedClassifier(tc)
fixture=createFixture('referenceUiStandalone',false,true,false);
cleanup=onCleanup(@()removeFixture(fixture)); %#ok<NASGU>
app=pipeline2(fixture.pipe,'UnlockRuntime',true);
appCleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible='off';

verifyEmpty(tc,controlsWithText(app.UIFigure,'Link classifier...'));
verifyEmpty(tc,controlsWithText(app.UIFigure,'Trained classifier'));
verifyNumElements(tc,controlsWithText(app.UIFigure,'Module package'),1);
verifyNumElements(tc,controlsWithText(app.UIFigure,'Choose module...'),1);
verifyNumElements(tc,controlsWithText(app.UIFigure,'Module catalogue...'),1);
verifyNumElements(tc,controlsWithText(app.UIFigure,'Use installed module'),1);
verifyEmpty(tc,findall(app.UIFigure,'Tag','PipelineModuleContractNotice'));
parameters=controlsWithText(app.UIFigure,'Execution parameters...');
assertNumElements(tc,parameters,1);
parameters.ButtonPushedFcn(parameters,[]);
dialog=findall(groot,'Type','figure','Name','Execution parameters - track_lineage');
assertNumElements(tc,dialog,1);
dialogCleanup=onCleanup(@()delete(dialog)); %#ok<NASGU>
dialog.Visible='off';
verifyNumElements(tc,controlsWithText(dialog,'Fixture release manifest'),1);
verifyNumElements(tc,controlsWithText(dialog,'Fixture Python executable'),1);
app.SavecurrentpipelineMenu.MenuSelectedFcn(app.SavecurrentpipelineMenu,[]);
[saved,message]=pipelineLoad(fullfile(fixture.pipe.path,'pipeline.json'));
assertNotEmpty(tc,saved,message);
verifyEqual(tc,saved.nodes(1).params.releaseManifest,'fixture-release.json');
verifyEqual(tc,saved.nodes(1).params.pythonExecutable,'fixture-python.exe');
verifyFalse(tc,isfile(fullfile(fixture.packageDir,'inference_called.txt')));
end

function testStoredLegacyClassifierLinkRemainsEditable(tc)
fixture=createFixture('referenceUiLegacyLinked',false,true,true);
cleanup=onCleanup(@()removeFixture(fixture)); %#ok<NASGU>
app=pipeline2(fixture.pipe,'UnlockRuntime',true);
appCleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible='off';

verifyNumElements(tc,controlsWithText(app.UIFigure,'Trained classifier (optional)'),1);
verifyNumElements(tc,controlsWithText(app.UIFigure,'Link classifier...'),1);
verifyNumElements(tc,controlsWithText(app.UIFigure,'Open linked classifier'),1);
verifyNumElements(tc,controlsWithText(app.UIFigure,'Module package'),1);
verifyFalse(tc,isfile(fullfile(fixture.packageDir,'inference_called.txt')));
end

function testUnspecifiedRequirementRetainsTrainedClassifierControls(tc)
fixture=createFixture('referenceUiRequired',[],true,false);
cleanup=onCleanup(@()removeFixture(fixture)); %#ok<NASGU>
app=pipeline2(fixture.pipe,'UnlockRuntime',true);
appCleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible='off';

verifyNumElements(tc,controlsWithText(app.UIFigure,'Trained classifier'),1);
verifyNumElements(tc,controlsWithText(app.UIFigure,'Link classifier...'),1);
verifyNumElements(tc,controlsWithText(app.UIFigure,'Module package'),1);
verifyFalse(tc,isfile(fullfile(fixture.packageDir,'inference_called.txt')));
end

function testLegacyStandaloneAdapterReportsMissingSemanticContract(tc)
fixture=createFixture('referenceUiLegacyAdapter',false,false,false);
cleanup=onCleanup(@()removeFixture(fixture)); %#ok<NASGU>
app=pipeline2(fixture.pipe,'UnlockRuntime',true);
appCleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible='off';

verifyEmpty(tc,controlsWithText(app.UIFigure,'Link classifier...'));
notice=findall(app.UIFigure,'Tag','PipelineModuleContractNotice');
verifyNumElements(tc,notice,1);
verifyEqual(tc,char(notice.Visible),'on');
verifyTrue(tc,contains(lower(string(notice.Text)),'contract'));
verifyNumElements(tc,controlsWithText(app.UIFigure,'Module package'),1);
verifyFalse(tc,isfile(fullfile(fixture.packageDir,'inference_called.txt')));
end

function testStandaloneModuleKeepsUndeclaredPrivatePathsOutOfPipeline(tc)
fixture=createFixture('referenceUiPrivatePaths',false,true,false,false);
cleanup=onCleanup(@()removeFixture(fixture)); %#ok<NASGU>
app=pipeline2(fixture.pipe,'UnlockRuntime',true);
appCleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible='off';

verifyEmpty(tc,controlsWithText(app.UIFigure,'Link classifier...'));
parameters=controlsWithText(app.UIFigure,'Execution parameters...');
assertNumElements(tc,parameters,1);
parameters.ButtonPushedFcn(parameters,[]);
dialog=findall(groot,'Type','figure','Name','Execution parameters - track_lineage');
assertNumElements(tc,dialog,1);
dialogCleanup=onCleanup(@()delete(dialog)); %#ok<NASGU>
dialog.Visible='off';
verifyEmpty(tc,controlsWithText(dialog,'Fixture release manifest'));
verifyEmpty(tc,controlsWithText(dialog,'Fixture Python executable'));
app.SavecurrentpipelineMenu.MenuSelectedFcn(app.SavecurrentpipelineMenu,[]);
[saved,message]=pipelineLoad(fullfile(fixture.pipe.path,'pipeline.json'));
assertNotEmpty(tc,saved,message);
verifyFalse(tc,isfield(saved.nodes(1).params,'releaseManifest'));
verifyFalse(tc,isfield(saved.nodes(1).params,'pythonExecutable'));
verifyFalse(tc,isfile(fullfile(fixture.packageDir,'inference_called.txt')));
end

function fixture=createFixture(pkg,required,declared,legacyLink,ownsPaths)
if nargin<5,ownsPaths=true;end
folder=tempname;
mkdir(folder);
packageRoot=fullfile(folder,'plugins','classifier');
packageDir=fullfile(packageRoot,['+' pkg]);
mkdir(packageDir);
before=path;
addpath(packageRoot);

defaults=struct('instanceChannelName','instances','brightfieldChannelName','brightfield', ...
    'outputFamilyName','pred_fixture','outputTrackChannelName','results_fixture', ...
    'releaseManifest','fixture-release.json','pythonExecutable','fixture-python.exe');
spec=struct('summary','Reference UI fixture.', ...
    'inputKeys',{{'instanceChannelName','brightfieldChannelName'}}, ...
    'outputKeys',{{'outputFamilyName','outputTrackChannelName'}}, ...
    'artifactKeys',{{'releaseManifest'}},'environmentKeys',{{'pythonExecutable'}}, ...
    'staticKeys',{{'frameIntervalMinutes'}},'defaults',defaults, ...
    'labels',struct('releaseManifest','Fixture release manifest', ...
    'pythonExecutable','Fixture Python executable'));
if ~isempty(required)
    spec.requiresRuntimeClassifier=required;
    if declared,spec.requiresClassifierReference=required;end
end
writeText(fullfile(packageDir,'executionSpec.m'),sprintf([ ...
    'function spec=executionSpec(varargin)\n' ...
    'spec=jsondecode(''%s'');\nend\n'],quote(jsonencode(spec))));
writeText(fullfile(packageDir,'defaults.m'),sprintf([ ...
    'function params=defaults(varargin)\n' ...
    'params=jsondecode(''%s'');\nend\n'],quote(jsonencode(defaults))));
writeText(fullfile(packageDir,'setparam.m'),sprintf([ ...
    'function varargout=setparam(varargin)\n' ...
    'varargout{1}=%s.defaults();\n' ...
    'if nargout>1,varargout{2}=struct();end\nend\n'],pkg));
marker=quote(fullfile(packageDir,'inference_called.txt'));
writeText(fullfile(packageDir,'classify.m'),sprintf([ ...
    'function varargout=classify(varargin)\n' ...
    'fid=fopen(''%s'',''w'');fclose(fid);\n' ...
    'error(''referenceUi:InferenceCalled'',''UI must not execute inference.'');\nend\n'],marker));

if declared
    port=struct('name','roiList','type','roiList','required',true,'source','edge');
    resource=struct('type',{},'role',{},'symbol',{},'param',{},'port',{}, ...
        'nameParam',{},'required',{},'transfer',{});
    paths={};
    if ownsPaths,paths={'releaseManifest','pythonExecutable'};end
    contract=struct('format','detecdiv.module_contract.v1','in',port,'out',port, ...
        'parameters',struct('static',{{'frameIntervalMinutes'}},'paths',{paths}), ...
        'resources',struct('in',resource,'out',resource), ...
        'summary','Declared reference UI fixture contract.');
    writeText(fullfile(packageDir,'moduleContract.m'),sprintf([ ...
        'function contract=moduleContract(varargin)\n' ...
        'contract=jsondecode(''%s'');\n' ...
        'resource=struct(''type'',{},''role'',{},''symbol'',{},''param'',{}, ...\n' ...
        '    ''port'',{},''nameParam'',{},''required'',{},''transfer'',{});\n' ...
        'contract.resources.in=resource;\n' ...
        'contract.resources.out=resource;\nend\n'],quote(jsonencode(contract))));
    descriptor=struct('format','detecdiv.module.v1','id',['fixture.' pkg], ...
        'name','Reference UI fixture','type','classifier','package',pkg, ...
        'adapterVersion','0.1.0','summary','Synthetic standalone classifier adapter.', ...
        'capabilities',{{'tracking'}}, ...
        'entrypoints',struct('execute',[pkg '.classify'], ...
        'parameters',[pkg '.executionSpec'],'contract',[pkg '.moduleContract']), ...
        'compatibility',struct('detecdiv',NaN, ...
        'pipelineContract','detecdiv.module_contract.v1'), ...
        'provenance',struct('repository','https://example.test/reference-ui'));
    writeText(fullfile(packageDir,'module.json'),jsonencode(descriptor));
end

pipe=pipeline(folder,'reference_ui',1);
params=defaults;
params.pkg=pkg;
params.frameIntervalMinutes=5;
params.customPackageRoot=packageRoot;
params.customPackageDir=packageDir;
if legacyLink
    params.modulePath=fullfile(folder,'historical_classifier');
    params.moduleId='historical_classifier';
end
pipe.nodes=struct('id','track_lineage','name','track_lineage','type','classifier', ...
    'pkg',pkg,'func',[pkg '.classify'],'params',params,'enabled',true,'layout',[1 1 1 1]);
pipelineSave(pipe,'Artifacts',false);
fixture=struct('folder',folder,'packageDir',packageDir,'before',before,'pipe',pipe);
end

function controls=controlsWithText(parent,text)
controls=findall(parent,'-property','Text');
keep=false(size(controls));
for i=1:numel(controls)
    if strcmp(controls(i).Type,'uimenu'),continue;end
    keep(i)=isequal(string(controls(i).Text),string(text));
end
controls=controls(keep);
end

function result=quote(value)
result=strrep(value,'''','''''');
end

function writeText(filename,content)
fid=fopen(filename,'w','n','UTF-8');
assert(fid>=0,['Could not create fixture ' filename]);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',content);
end

function removeFixture(fixture)
path(fixture.before);
target=char(java.io.File(fixture.folder).getCanonicalPath());
assert(strcmpi(fileparts(target),char(java.io.File(tempdir).getCanonicalPath())));
if isfolder(target),rmdir(target,'s');end
end
