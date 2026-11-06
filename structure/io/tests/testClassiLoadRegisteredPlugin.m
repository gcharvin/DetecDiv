function tests = testClassiLoadRegisteredPlugin
tests = functiontests(localfunctions);
end

function setupOnce(~)
detecdiv_setup_path;
end

function testRegisteredPackageLoadsItsAnnotationContract(testCase)
exerciseLoad(testCase,true,false);
end

function testDisabledAutomaticPathIsRespected(testCase)
exerciseLoad(testCase,false,false);
end

function testExistingPackageOnPathKeepsPrecedence(testCase)
exerciseLoad(testCase,true,true);
end

function exerciseLoad(testCase,automatic,alreadyLoaded)
folder=tempname;mkdir(folder);
oldPath=path;
cleanup=onCleanup(@()restore(folder,oldPath)); %#ok<NASGU>
pkg='classiLoadRegisteredProbe';
pluginParent=fullfile(folder,'plugins','classifier');
pluginFolder=fullfile(pluginParent,['+' pkg]);mkdir(pluginFolder);
write(fullfile(pluginFolder,'classify.m'),'function result=classify(varargin), result=[]; end');
write(fullfile(pluginFolder,'annotationSpec.m'),'function result=annotationSpec(varargin), result=''registered''; end');
% Isolate preferences from the real user, while exercising real discovery.
mockPrefs=fullfile(folder,'prefs');mkdir(mockPrefs);
write(fullfile(mockPrefs,'detecdiv_prefs_load.m'),sprintf( ...
    'function p=detecdiv_prefs_load, p.plugins=struct(''roots'',{{''%s''}},''autoAddPath'',%d); end', ...
    strrep(folder,'''',''''''),automatic));
addpath(mockPrefs,'-begin');clear detecdiv_prefs_load;
if alreadyLoaded
    existing=fullfile(folder,'existing');mkdir(fullfile(existing,['+' pkg]));
    write(fullfile(existing,['+' pkg],'classify.m'),'function result=classify(varargin), result=[]; end');
    write(fullfile(existing,['+' pkg],'annotationSpec.m'),'function result=annotationSpec(varargin), result=''existing''; end');
    addpath(existing,'-begin');
end
c=classi(folder,'registered_probe',1,'InitTraining',false);
c.classifierPkg=pkg;c.category={'Tracking'};
classiObj=c;file=fullfile(c.path,[c.strid '_classification.mat']);save(file,'classiObj');
loaded=classiLoad(file);
verifyEqual(testCase,loaded.classifierPkg,pkg);
if alreadyLoaded
    verifyEqual(testCase,classiLoadRegisteredProbe.annotationSpec(),'existing');
elseif automatic
    verifyEqual(testCase,classiLoadRegisteredProbe.annotationSpec(),'registered');
else
    verifyEmpty(testCase,which([pkg '.annotationSpec']));
end
end

function write(file,content)
fid=fopen(file,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',content);
end

function restore(folder,oldPath)
path(oldPath);
clear detecdiv_prefs_load classiLoadRegisteredProbe.classify classiLoadRegisteredProbe.annotationSpec;
if isfolder(folder),rmdir(folder,'s');end
end
