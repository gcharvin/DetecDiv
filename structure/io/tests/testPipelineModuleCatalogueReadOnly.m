function tests=testPipelineModuleCatalogueReadOnly
tests=functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.before=path;
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'helpers'),fullfile(root,'structure','io'));
end

function teardownOnce(tc)
path(tc.TestData.before);
end

function setup(tc)
tc.TestData.fixture=tempname; mkdir(tc.TestData.fixture);
tc.TestData.path=path;
pkg='validationCatalogueProbe';
tc.TestData.pkg=pkg;
tc.TestData.folder=fullfile(tc.TestData.fixture,['+' pkg]); mkdir(tc.TestData.folder);
writeText(fullfile(tc.TestData.folder,'classify.m'), ...
    'function out=classify(varargin), error(''fixture:Inference'',''Must not infer''); out=[]; end');
marker=strrep(fullfile(tc.TestData.fixture,'activation.txt'),'''','''''');
writeText(fullfile(tc.TestData.fixture,'detecdiv_plugins_addpath.m'),sprintf( ...
    'function detecdiv_plugins_addpath(), fid=fopen(''%s'',''w''); fclose(fid); end',marker));
writeText(fullfile(tc.TestData.fixture,'detecdiv_plugins_list.m'), ...
    'function p=detecdiv_plugins_list(), p=struct([]); end');
addpath(tc.TestData.fixture,'-begin');
end

function teardown(tc)
path(tc.TestData.path);
folder=char(java.io.File(tc.TestData.fixture).getCanonicalPath());
assert(strcmpi(fileparts(folder),char(java.io.File(tempdir).getCanonicalPath())));
rmdir(folder,'s');
end

function testUiValidationUsesSelectedCatalogueCopyWithoutActivation(tc)
[pipe,ctx]=fixturePipeline(tc);
module=struct('pkg',tc.TestData.pkg,'type','classifier','distribution','external', ...
    'path',tc.TestData.folder);
before=path;
[ok,report]=validatePipeline(pipe,ctx,struct('allowGui',false, ...
    'readOnlyModuleDiscovery',true,'moduleCatalogue',module));
verifyTrue(tc,ok,strjoin(report.errors,' | '));
verifyEqual(tc,path,before);
verifyFalse(tc,isfile(fullfile(tc.TestData.fixture,'activation.txt')));
verifyEqual(tc,report.pluginPackages.registeredDir,tc.TestData.folder);
verifyEqual(tc,report.pluginPackages.status,'installed_selected');
verifyFalse(tc,any(contains(report.warnings,'customPackageDir')));
end

function testUiValidationDoesNotSubstituteAnotherDiscoveredCopy(tc)
[pipe,ctx]=fixturePipeline(tc);
other=fullfile(tc.TestData.fixture,'other',['+' tc.TestData.pkg]); mkdir(other);
module=struct('pkg',tc.TestData.pkg,'type','classifier','distribution','external','path',other);
selected=which([tc.TestData.pkg '.classify']);
[ok,report]=validatePipeline(pipe,ctx,struct('readOnlyModuleDiscovery',true, ...
    'moduleCatalogue',module));
verifyTrue(tc,ok,strjoin(report.errors,' | '));
verifyEmpty(tc,report.pluginPackages);
verifyEqual(tc,which([tc.TestData.pkg '.classify']),selected);
verifyFalse(tc,isfile(fullfile(tc.TestData.fixture,'activation.txt')));
end

function testDefaultExecutionValidationRetainsLegacyPluginBootstrap(tc)
[pipe,ctx]=fixturePipeline(tc);
[ok,report]=validatePipeline(pipe,ctx,struct());
verifyTrue(tc,ok,strjoin(report.errors,' | '));
verifyTrue(tc,isfile(fullfile(tc.TestData.fixture,'activation.txt')));
end

function testUiBindingResolutionAlsoAvoidsPluginActivation(tc)
[pipe,ctx]=fixturePipeline(tc);
module=struct('pkg',tc.TestData.pkg,'type','classifier','distribution','external', ...
    'path',tc.TestData.folder);
[resolved,report]=pipelineResolveBindings(pipe,ctx,struct('readOnlyModuleDiscovery',true, ...
    'moduleCatalogue',module));
verifyEqual(tc,resolved.nodes.pkg,tc.TestData.pkg);
verifyEqual(tc,report.validation.pluginPackages.registeredDir,tc.TestData.folder);
verifyFalse(tc,isfile(fullfile(tc.TestData.fixture,'activation.txt')));
end

function [pipe,ctx]=fixturePipeline(tc)
p=struct('pkg',tc.TestData.pkg);
node=struct('id','saved_classifier','type','classifier','pkg',tc.TestData.pkg, ...
    'func',[tc.TestData.pkg '.classify'],'params',p);
pipe=struct('nodes',node,'edges',struct([]),'branches',struct([]));
ctx=struct('roiList',1,'channels',{{'BF'}},'roiChannels',{{'BF'}});
end

function writeText(file,value)
fid=fopen(file,'w'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,value,'char');
end
