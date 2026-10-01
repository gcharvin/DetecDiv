function tests = testPipeline2CustomModule
% Exercise the packed App Designer app through its real controls/callbacks.
tests = functiontests(localfunctions);
end

function testPackedCodeMatchesEditableSource(t)
gui = fileparts(fileparts(mfilename('fullpath')));
reader = appdesigner.internal.serialization.FileReader(fullfile(gui,'pipeline2.mlapp'));
packed = reader.readMATLABCodeText();
source = fileread(fullfile(gui,'pipeline2_extracted.m'));
verifyEqual(t,regexprep(packed,'\r\n','\n'),regexprep(source,'\r\n','\n'));
end

function testCustomLibraryControlsEditingAndSaveReload(t)
root = tempname; mkdir(root);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
pipe = pipeline(root,'gui_custom',1);
mkdir(fullfile(pipe.path,'code'));
fid = fopen(fullfile(pipe.path,'code','guiCustomTest.m'),'w');
fprintf(fid,'function ctx=guiCustomTest(ctx)\nctx.tables=table(ctx.params.value*ctx.params.scale,''VariableNames'',{''Value''});\nend\n');
fclose(fid);
p = customModule.setparam(); p.entryPoint = 'guiCustomTest'; p.codeFolder = 'code';
p.parametersJson = '{"value":3,"scale":2}'; p.outputPorts = 'tables';
pipe.nodes = struct('id','custom_1','name','custom_1','type','custom', ...
    'pkg','customModule','func','customModule.process','params',p, ...
    'enabled',true,'layout',[1 1 1 1]);
pipelineSave(pipe,'Artifacts',false);
app = pipeline2(pipe,'UnlockRuntime',true);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
verifyFalse(t,contains(app.PipelineandRuncheckreportLabel.Text,'Relative codeFolder'));
verifyTrue(t, any(strcmp(string(app.UISelectedModuleTable.Data(:,3)),'custom')));
menus = findall(app.UIFigure,'Type','uimenu');
matching = menus(strcmp({menus.Text},'Custom function'));
verifyNotEmpty(t,matching);
external = menus(strcmp({menus.Text},'Add custom package...'));
verifyNotEmpty(t,external);
% Open the existing node's parameter dialog and edit a JSON value >120 chars.
buttons = findall(app.UIFigure,'Type','uibutton');
staticButton = buttons(strcmp({buttons.Text},'Static parameters...'));
assert(~isempty(staticButton),'Custom static parameter dialog was not built.');
staticButton(1).ButtonPushedFcn(staticButton(1),[]);
figs = findall(groot,'Type','figure');
dialog = figs(startsWith(string({figs.Name}),'Static parameters - custom_1'));
assert(~isempty(dialog),'Parameter dialog did not open.');
dialogCleanup = onCleanup(@()delete(dialog)); %#ok<NASGU>
fields = findall(dialog,'Type','uieditfield');
jsonField = fields(strcmp({fields.Value},p.parametersJson));
assert(~isempty(jsonField),'JSON parameter field was not built.');
longJson = ['{"value":9,"scale":2,"description":"' repmat('x',1,160) '"}'];
jsonField(1).Value = longJson;
jsonField(1).ValueChangedFcn(jsonField(1),[]);
app.SavecurrentpipelineMenu.MenuSelectedFcn(app.SavecurrentpipelineMenu,[]);
[loaded,message] = pipelineLoad(fullfile(pipe.path,'pipeline.json'));
assert(~isempty(loaded),message);
verifyEqual(t,loaded.nodes.params.parametersJson,longJson);
[ctx,~] = runPipelineDetecDiv(loaded,struct());
verifyEqual(t,ctx.tables.Value,18);
% Add the genuine custom module via Modules menu, without a package chooser.
menus = findall(app.UIFigure,'Type','uimenu');
for i = 1:numel(menus)
    if isstruct(menus(i).UserData) && isfield(menus(i).UserData,'action') && ...
            strcmp(menus(i).UserData.action,'add') && ...
            strcmp(menus(i).UserData.nodeType,'custom')
        menus(i).MenuSelectedFcn(menus(i),struct('Source',menus(i)));
        break;
    end
end
verifyEqual(t,size(app.UISelectedModuleTable.Data,1),2);
end
