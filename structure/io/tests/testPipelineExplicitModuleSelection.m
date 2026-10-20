function tests=testPipelineExplicitModuleSelection
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
tc.TestData.pkg='explicitSelectionProbe';
tc.TestData.selectedRoot=fullfile(tc.TestData.fixture,'selected');
tc.TestData.otherRoot=fullfile(tc.TestData.fixture,'registered');
tc.TestData.selectedDir=fullfile(tc.TestData.selectedRoot,['+' tc.TestData.pkg]);
tc.TestData.otherDir=fullfile(tc.TestData.otherRoot,['+' tc.TestData.pkg]);
mkdir(tc.TestData.selectedDir); mkdir(tc.TestData.otherDir);
for folder={tc.TestData.selectedDir,tc.TestData.otherDir}
    writeText(fullfile(folder{1},'classify.m'), ...
        'function out=classify(varargin), error(''fixture:Inference'',''Must not infer''); out=[]; end');
end
marker=quote(fullfile(tc.TestData.fixture,'activation.txt'));
other=quote(tc.TestData.otherRoot);
writeText(fullfile(tc.TestData.fixture,'detecdiv_plugins_addpath.m'),sprintf( ...
    'function detecdiv_plugins_addpath(), fid=fopen(''%s'',''w''); fclose(fid); addpath(''%s'',''-begin''); end',marker,other));
writeText(fullfile(tc.TestData.fixture,'detecdiv_plugins_list.m'),sprintf( ...
    'function p=detecdiv_plugins_list(), p=struct(''name'',''%s'',''type'',''classifier'',''path'',''%s''); end', ...
    tc.TestData.pkg,quote(tc.TestData.otherDir)));
addpath(tc.TestData.selectedRoot,'-end');
addpath(tc.TestData.otherRoot,'-begin');
addpath(tc.TestData.fixture,'-begin');
rehash;
end

function teardown(tc)
path(tc.TestData.path);
folder=char(java.io.File(tc.TestData.fixture).getCanonicalPath());
assert(strcmpi(fileparts(folder),char(java.io.File(tempdir).getCanonicalPath())));
rmdir(folder,'s');
end

function testExplicitRootAlreadyOnPathOverridesShadowingCopy(tc)
node=fixtureNode(tc);
verifyEqual(tc,which(node.func),fullfile(tc.TestData.otherDir,'classify.m'));
pipelineNodeContract(node);
verifyEqual(tc,which(node.func),fullfile(tc.TestData.selectedDir,'classify.m'));
selectedPath=path;
pipelineNodeContract(node);
verifyEqual(tc,path,selectedPath);
verifyFalse(tc,isfile(fullfile(tc.TestData.fixture,'activation.txt')));
end

function testLinkedValidationKeepsExplicitSelectionWithoutRegistryBootstrap(tc)
node=fixtureNode(tc);
pipe=struct('nodes',node,'edges',struct([]),'branches',struct([]));
ctx=struct('roiList',1,'channels',{{'BF'}},'roiChannels',{{'BF'}});
[ok,report]=validatePipeline(pipe,ctx,struct('allowGui',false));
verifyTrue(tc,ok,strjoin(report.errors,' | '));
verifyFalse(tc,isfile(fullfile(tc.TestData.fixture,'activation.txt')));
verifyEqual(tc,which(node.func),fullfile(tc.TestData.selectedDir,'classify.m'));
verifyEqual(tc,report.pluginPackages.configuredDir,tc.TestData.selectedDir);
verifyTrue(tc,report.pluginPackages.accessible);
end

function node=fixtureNode(tc)
p=struct('pkg',tc.TestData.pkg,'customPackageRoot',tc.TestData.selectedRoot, ...
    'customPackageDir',tc.TestData.selectedDir);
node=struct('id','linked_classifier','type','classifier','pkg',tc.TestData.pkg, ...
    'func',[tc.TestData.pkg '.classify'],'params',p);
end

function value=quote(value)
value=strrep(value,'''','''''');
end

function writeText(file,value)
fid=fopen(file,'w'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,value,'char');
end
