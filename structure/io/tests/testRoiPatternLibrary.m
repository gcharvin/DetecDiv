function tests = testRoiPatternLibrary
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
detecdiv_setup_path(root,'Verbose',false);
end

function testNewNamesNeverSilentlyOverwrite(testCase)
[folder,clean] = tempFolder(); %#ok<ASGLU>
p = pattern();
first = pipelineRoiPatternLibrary('save',folder,'Trap',p);
verifyError(testCase,@()pipelineRoiPatternLibrary('save',folder,'trap',p),'pipelineRoiPatternLibrary:NameExists');
library = pipelineRoiPatternLibrary('load',folder);
verifyEqual(testCase,numel(library.entries),1);
verifyEqual(testCase,library.entries.id,first.id);
second = pipelineRoiPatternLibrary('save',folder,'Other trap',p);
verifyNotEqual(testCase,second.id,first.id); % Writer lock was released on error.
end

function testRevisionReplacementKeepsRunSnapshot(testCase)
[folder,clean] = tempFolder(); %#ok<ASGLU>
first = pipelineRoiPatternLibrary('save',folder,'Trap',pattern());
params = pipelineApplyRoiPatternPreset(struct('channel','target','referenceFrame',7,'threshold',.6),first);
nodes = struct('id','pattern_1','type','roiPattern','params',params);
run = pipelineSnapshotRoiPatternOverrides(nodes,struct());
new = pattern(); new.image(:) = 3;
replacement = pipelineRoiPatternLibrary('save',folder,'Trap',new,first.id,first.revision);
verifyEqual(testCase,replacement.id,first.id);
verifyEqual(testCase,replacement.revision,2);
verifyEqual(testCase,run.pattern_1.pattern.image,first.pattern.image);
verifyEqual(testCase,run.pattern_1.patternPreset.revision,1);
verifyError(testCase,@()pipelineRoiPatternLibrary('save',folder,'Trap',new,first.id,first.revision), ...
    'pipelineRoiPatternLibrary:Conflict');
end

function testPresetKeepsTargetBindingsAndClearsStalePreview(testCase)
[folder,clean] = tempFolder(); %#ok<ASGLU>
entry = pipelineRoiPatternLibrary('save',folder,'Trap',pattern());
p = struct('channel','target','referenceFrame',9,'threshold',.7, ...
    'previewRects',[1 1 130 130],'patternImage',ones(130),'crop',[1 1 500 500]);
p = pipelineApplyRoiPatternPreset(p,entry);
verifyEqual(testCase,p.channel,'target'); verifyEqual(testCase,p.referenceFrame,9);
verifyEqual(testCase,p.threshold,.7); verifyEqual(testCase,p.crop,[1 1 500 500]);
verifyFalse(testCase,isfield(p,'previewRects')); verifyFalse(testCase,isfield(p,'patternImage'));
verifyEqual(testCase,p.pattern.image,entry.pattern.image);
end

function testLibraryRequiresPixelsAndRespectsWriterLock(testCase)
[folder,clean] = tempFolder(); %#ok<ASGLU>
verifyError(testCase,@()pipelineRoiPatternLibrary('save',folder,'Bad',struct('rect',[1 1 20 20])), ...
    'pipelineRoiPatternLibrary:NoImage');
file = java.io.RandomAccessFile(fullfile(folder,'roi_pattern_library.json.lock'),'rw');
channel = file.getChannel(); lock = channel.tryLock(); %#ok<NASGU>
writerCleanup = onCleanup(@()channel.close());
verifyError(testCase,@()pipelineRoiPatternLibrary('save',folder,'Trap',pattern()),'pipelineRoiPatternLibrary:Busy');
verifyFalse(testCase,isfile(fullfile(folder,'roi_pattern_library.json')));
clear writerCleanup;
end

function testPopupChoiceIsExplicitAndRequiresNoSourceImages(testCase)
[folder,clean] = tempFolder(); %#ok<ASGLU>
entry = pipelineRoiPatternLibrary('save',folder,'Trap',pattern());
app = roiPatternLibraryDialog(folder,struct('channel','target','referenceFrame',7),'pattern_1',false);
guiClean = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
use = findobj(app.UIFigure,'Tag','PatternLibraryUse');
verifyEqual(testCase,use.Enable,matlab.lang.OnOffSwitchState.off);
click(app.UIFigure,'PatternChoice2'); click(app.UIFigure,'PatternLibraryUse');
verifyEqual(testCase,app.Action,'use');
verifyEqual(testCase,app.Result.patternPreset.id,entry.id);
verifyEqual(testCase,app.Result.channel,'target');
verifyFalse(testCase,isfile(fullfile(folder,'pipeline.json')));
end

function testPopupCancelAndTestDoNotSaveLibrary(testCase)
[folder,clean] = tempFolder(); %#ok<ASGLU>
params = struct('pattern',pattern());
app = roiPatternLibraryDialog(folder,params,'pattern_1',true);
guiClean = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
click(app.UIFigure,'PatternLibraryEdit');
verifyEqual(testCase,app.Action,'edit'); verifyEqual(testCase,app.Result,params);
verifyFalse(testCase,isfile(fullfile(folder,'roi_pattern_library.json')));
delete(app); clear guiClean;
app = roiPatternLibraryDialog(folder,params,'pattern_1',true);
guiClean = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
click(app.UIFigure,'PatternLibraryCancel'); verifyEqual(testCase,app.Action,'cancel');
verifyFalse(testCase,isfile(fullfile(folder,'roi_pattern_library.json')));
end

function testLockedRunGalleryCannotChangeRunOrLibrary(testCase)
[folder,clean] = tempFolder(); %#ok<ASGLU>
entry = pipelineRoiPatternLibrary('save',folder,'Trap',pattern());
params = struct('pattern',pattern());
app = roiPatternLibraryDialog(folder,params,'pattern_1',false,true);
guiClean = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
click(app.UIFigure,'PatternChoice2');
verifyEqual(testCase,findobj(app.UIFigure,'Tag','PatternLibrarySave').Enable,matlab.lang.OnOffSwitchState.off);
verifyEqual(testCase,findobj(app.UIFigure,'Tag','PatternLibraryReplace').Enable,matlab.lang.OnOffSwitchState.off);
click(app.UIFigure,'PatternLibraryUse');
verifyEqual(testCase,app.Action,'cancel'); verifyEqual(testCase,app.Result,params);
library = pipelineRoiPatternLibrary('load',folder);
verifyEqual(testCase,library.entries.id,entry.id);
end

function testPipelinePopupSavesRunOverrideWithoutChangingTemplate(testCase)
[folder,clean] = tempFolder(); %#ok<ASGLU>
project = shallow(); project.io.path = folder; project.io.file = 'test_project';
raw = fullfile(folder,'raw'); mkdir(raw);
imwrite(uint16(reshape(1:4096,64,64)),fullfile(raw,'frame1.tif'));
f = fov(); f.id = 'source'; f.number = 1; f.srcpath = {raw};
f.srclist = {dir(fullfile(raw,'frame*.tif'))}; f.channel = {'phase'}; f.frames = 1;
f.interval = 1; f.parent = project; f.roi = roi(); project.fov = f;
pipe = pipeline('','librarytest'); pipe.path = fullfile(folder,'template'); mkdir(pipe.path);
p = struct('channel','phase','channelIndex',1,'referenceFrame',1,'threshold',.5,'pattern',pattern());
pipe.nodes = struct('id','pattern_1','name','pattern_1','type','roiPattern','pkg','roiPattern', ...
    'func','roiPattern.process','gui','roiPattern.ui','params',p,'inputs',{{'images'}}, ...
    'outputs',{{'roiList'}},'layout',[20 20 20 10]);
pipelineSave(pipe);
before = fileread(fullfile(pipe.path,'pipeline.json'));
new = pattern(); new.image(:) = 99;
entry = pipelineRoiPatternLibrary('save',pipe.path,'Other trap',new);
app = pipeline2(pipe,project,'Fovs',1,'Frames',1,'InputSourceMode','existing_project');
guiClean = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
t = timer('StartDelay',.8,'TimerFcn',@(~,~)selectPreset());
timerClean = onCleanup(@()delete(t)); %#ok<NASGU>
start(t);
click(app.UIFigure,'OpenPatternLibrary');
app.SaverunMenu.MenuSelectedFcn(app.SaverunMenu,struct());
verifyEqual(testCase,fileread(fullfile(pipe.path,'pipeline.json')),before);
files = dir(fullfile(folder,'test_project','pipeline','*','run_params.json'));
verifyNotEmpty(testCase,files);
saved = jsondecode(fileread(fullfile(files(1).folder,files(1).name)));
verifyEqual(testCase,saved.run.nodeParams.pattern_1.patternPreset.id,entry.id);
verifyEqual(testCase,saved.run.nodeParams.pattern_1.pattern.image,double(new.image));
% Cancelling the mandatory pattern choice must stop Run before processing.
snapshotFile = fullfile(files(1).folder,files(1).name);
beforeRun = fileread(snapshotFile);
stopTimer = timer('StartDelay',.8,'TimerFcn',@(~,~)cancelPatternChoice());
stopClean = onCleanup(@()delete(stopTimer)); %#ok<NASGU>
start(stopTimer);
app.RunButton.ButtonPushedFcn(app.RunButton,struct());
verifyEqual(testCase,fileread(snapshotFile),beforeRun);
verifyEmpty(testCase,project.fov(1).roi.id);
end

function selectPreset()
fig = findall(0,'Type','figure','Name','Pattern for run: pattern_1');
click(fig,'PatternChoice2'); click(fig,'PatternLibraryUse');
end

function cancelPatternChoice()
fig = findall(0,'Type','figure','Name','Pattern for run: pattern_1');
click(fig,'PatternLibraryCancel');
end

function click(fig,tag)
button = findobj(fig,'Tag',tag);
button.ButtonPushedFcn(button,struct());
end

function p = pattern()
p = struct('rect',[20 20 12 12],'crop',[20 20 12 12],'fovId','source', ...
    'fovIndex',1,'referenceFrame',1,'channel','phase','channelIndex',1, ...
    'image',uint16(reshape(1:144,12,12)));
end

function [folder,clean] = tempFolder()
folder = tempname; assert(startsWith(folder,tempdir,'IgnoreCase',true)); mkdir(folder);
clean = onCleanup(@()rmdir(folder,'s'));
end
