function tests=test_plugins_reset_link
tests=functiontests(localfunctions);
end

function setupOnce(tc)
repo=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(repo,'helpers'));tc.TestData.repo=repo;
end

function setup(tc)
tc.TestData.path=path;tc.TestData.folder=tempname;mkdir(tc.TestData.folder);
end

function teardown(tc)
clear('resetLinkFixture.process','resetLinkFixture.setparam');
path(tc.TestData.path);
folder=char(java.io.File(tc.TestData.folder).getCanonicalPath());
safe=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(folder,[safe filesep],'IgnoreCase',true));rmdir(folder,'s');
end

function testLoadedBundleIsReplacedAndSettingsPreserved(tc)
old=fixture(tc,'bundle','old');installed=fixture(tc,'installed','new');
addpath(old.root,'-begin');verifyEqual(tc,resetLinkFixture.process(),'old');
node=struct('pkg','resetLinkFixture','type','processor','func','resetLinkFixture.process', ...
    'customPackageRoot',old.root,'customPackageDir',old.path, ...
    'params',struct('customPackageRoot',old.root,'customPackageDir',old.path,'threshold',7,'rawChannelName','DIC'));
runtime=struct('customPackageRoot',old.root,'customPackageDir',old.path,'threshold',9);
[updated,runtime,info]=detecdiv_plugins_reset_link(node,runtime,installed);
verifyEqual(tc,resetLinkFixture.process(),'new');
verifyEqual(tc,updated.params.threshold,7);verifyEqual(tc,runtime.threshold,9);
verifyEqual(tc,updated.params.rawChannelName,'DIC');
verifyEqual(tc,updated.params.newSetting,42);
verifyEqual(tc,updated.customPackageDir,installed.path);
verifyEqual(tc,runtime.customPackageDir,installed.path);
verifyEqual(tc,info.resolvedPath,fullfile(installed.path,'process.m'));
end

function testMissingInstalledPluginKeepsResolution(tc)
old=fixture(tc,'bundle','old');addpath(old.root,'-begin');
node=struct('pkg','resetLinkFixture','type','processor','params',struct());
plugins=struct('name',{},'type',{},'path',{},'entrypoint',{});
verifyError(tc,@() detecdiv_plugins_reset_link(node,struct(),plugins), ...
    'detecdiv_plugins_reset_link:NotInstalled');
verifyEqual(tc,resetLinkFixture.process(),'old');
end

function testSiblingPombePluginIsDiscoveredWithoutRegistration(tc)
node=struct('pkg','detectViterbiPombeDivisionFrame','type','processor', ...
    'params',struct('anchorX',.42));
expected=fullfile(detecdiv_plugins_default_root(),'plugins','processor','+detectViterbiPombeDivisionFrame');
assumeTrue(tc,isfolder(expected));
[updated,~,info]=detecdiv_plugins_reset_link(node);
verifyEqual(tc,updated.customPackageDir,char(java.io.File(expected).getCanonicalPath()));
verifyEqual(tc,updated.params.anchorX,.42);
verifyEqual(tc,updated.params.septumMethod{end},'transverse2d');
verifyEqual(tc,info.entrypoint,'detectViterbiPombeDivisionFrame.process');
end

function plugin=fixture(tc,name,result)
root=fullfile(tc.TestData.folder,name);packageDir=fullfile(root,'+resetLinkFixture');mkdir(packageDir);
write(fullfile(packageDir,'process.m'),sprintf('function value=process()\nvalue=''%s'';\nend\n',result));
write(fullfile(packageDir,'setparam.m'), ...
    sprintf('function p=setparam(~)\np=struct(''threshold'',1,''newSetting'',42);\nend\n'));
plugin=struct('name','resetLinkFixture','type','processor','root',root,'path',packageDir, ...
    'entrypoint','resetLinkFixture.process');
end

function write(file,contents)
fid=fopen(file,'w');cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',contents);
end
