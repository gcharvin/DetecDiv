function tests=testPipeline2ModuleCatalogueUI
% Exercise catalogue menus without changing saved module execution identity.
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

function testSavedPilotNodesLoadAndCatalogueAddsKeepLegacyIdentity(tc)
folder=tempname; mkdir(folder);
cleanup=onCleanup(@()removeFixture(folder)); %#ok<NASGU>
pipe=pipeline(folder,'saved_catalogue',1);
packages={'cellposesam','cellLatentModel','hoctModel'};
nodeCells=cell(1,3);
for i=1:3
    p=struct('pkg',packages{i},'outputName',['historical_' num2str(i)], ...
        'legacyCatalogueSentinel',i);
    nodeCells{i}=struct('id',['old_' num2str(i)],'name',['old_' num2str(i)], ...
        'type','classifier','pkg',packages{i},'func',[packages{i} '.classify'], ...
        'params',p,'enabled',true,'layout',[i 1 1 1]);
end
pipe.nodes=[nodeCells{:}];
pipelineSave(pipe,'Artifacts',false);
selectedHOCT=which('hoctModel.classify');
app=pipeline2(pipe,'UnlockRuntime',true);
appCleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible='off';
verifyEqual(tc,which('hoctModel.classify'),selectedHOCT, ...
    'Opening a saved pipeline must not promote a registered release.');
verifyEqual(tc,size(app.UISelectedModuleTable.Data,1),3);
menus=findall(app.UIFigure,'Type','uimenu');
verifyTrue(tc,any(strcmp({menus.Text},'Module catalogue...')));
verifyTrue(tc,any(strcmp({menus.Text},'Add module...')));
verifyFalse(tc,any(strcmp({menus.Text},'Add built-in module')));
verifyFalse(tc,any(strcmp({menus.Text},'Add plugin module')));
refresh=menus(strcmp({menus.Text},'Refresh module catalogue'));
verifyNumElements(tc,refresh,1);
refresh.MenuSelectedFcn(refresh,[]);
verifyEqual(tc,which('hoctModel.classify'),selectedHOCT);
verifyEqual(tc,size(app.UISelectedModuleTable.Data,1),3);
menus=findall(app.UIFigure,'Type','uimenu');
added=false;
for i=1:numel(menus)
    d=menus(i).UserData;
    if ~isstruct(d)||~all(isfield(d,{'action','nodeType','pkg'})), continue; end
    if strcmp(d.action,'add')&&strcmp(d.nodeType,'classifier')&&strcmp(d.pkg,'cellposesam')
        verifyEqual(tc,char(menus(i).Enable),'on');
        verifyTrue(tc,contains(menus(i).Text,'CellposeSAM'));
        menus(i).MenuSelectedFcn(menus(i),struct('Source',menus(i)));
        added=true; break;
    end
end
verifyTrue(tc,added,'The common catalogue must offer the selected CellposeSAM adapter.');
verifyEqual(tc,size(app.UISelectedModuleTable.Data,1),4);
app.SavecurrentpipelineMenu.MenuSelectedFcn(app.SavecurrentpipelineMenu,[]);
[saved,message]=pipelineLoad(fullfile(pipe.path,'pipeline.json'));
assertNotEmpty(tc,saved,message);
for i=1:3
    verifyEqual(tc,saved.nodes(i).pkg,packages{i});
    verifyEqual(tc,saved.nodes(i).func,[packages{i} '.classify']);
    verifyEqual(tc,saved.nodes(i).params.outputName,['historical_' num2str(i)]);
    verifyEqual(tc,saved.nodes(i).params.legacyCatalogueSentinel,i);
end
verifyEqual(tc,saved.nodes(4).pkg,'cellposesam');
verifyEqual(tc,saved.nodes(4).func,'cellposesam.classify');
verifyFalse(tc,isfield(saved.nodes,'ModuleCatalogueItems'));
verifyEqual(tc,which('hoctModel.classify'),selectedHOCT);
end

function removeFixture(folder)
target=char(java.io.File(folder).getCanonicalPath());
assert(strcmpi(fileparts(target),char(java.io.File(tempdir).getCanonicalPath())));
if isfolder(target), rmdir(target,'s'); end
end
