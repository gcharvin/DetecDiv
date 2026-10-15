function tests=testClassifierSampleImage
tests=functiontests(localfunctions);
end
function setupOnce(~)
addpath(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));detecdiv_setup_path;
end
function testNumericPlotBecomesPixelsAndPreservesExistingFigures(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
sentinel=figure('Visible','off');finish=onCleanup(@()delete(sentinel)); %#ok<NASGU>
before=findall(groot,'Type','figure');
pixels=classifierSampleImage(c);
verifyClass(testCase,pixels,'uint8');verifyEqual(testCase,size(pixels,3),3);verifyGreaterThan(testCase,std(double(pixels(:))),1);
verifyTrue(testCase,isvalid(sentinel));verifyEqual(testCase,numel(findall(groot,'Type','figure')),numel(before));
verifyFalse(testCase,isfile(fullfile(c.path,'sampleImage.png')));
end
function testExistingImageCacheRemainsNumeric(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
expected=repmat(uint8(reshape(1:60,4,5,3)),2,2,1);imwrite(expected,fullfile(c.path,'sampleImage.png'));
verifyEqual(testCase,classifierSampleImage(c),expected);
end
function testLegacyImageMontageRemainsSupported(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
c.classifierPkg='';c.category={'Image'};
images=fullfile(c.path,'trainingdataset','images','budding');mkdir(images);
imwrite(repmat(uint8(reshape(1:64,8,8)),4,4),fullfile(images,'sample.tif'));
before=findall(groot,'Type','figure');pixels=classifierSampleImage(c);
verifyClass(testCase,pixels,'uint8');verifyNotEmpty(testCase,pixels);
verifyEqual(testCase,numel(findall(groot,'Type','figure')),numel(before));
end
function testMissingDatasetDoesNotCloseUnrelatedFigure(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
delete(fullfile(c.path,'trainingdataset','lstm_timeseries_dataset.mat'));
sentinel=figure('Visible','off');finish=onCleanup(@()delete(sentinel)); %#ok<NASGU>
verifyEmpty(testCase,classifierSampleImage(c));verifyTrue(testCase,isvalid(sentinel));
end
function testMainTreeSelectionDisplaysAndRepairsNumericPreviewCache(testCase)
[c,cleanup]=fixture(); %#ok<ASGLU>
name='numericPreviewTestClassifier';assignin('base',name,c);
baseCleanup=onCleanup(@()evalin('base',['clear ' name])); %#ok<NASGU>
app=detecdiv;finish=onCleanup(@()delete(app)); %#ok<NASGU>
app.DetecDivUIFigure.Visible='off';
nodes=app.IndependentClassifiersNode.Children;
node=nodes(strcmp({nodes.Text},name));verifyNumElements(testCase,node,1);
app.Tree.SelectedNodes=node;cb=app.Tree.SelectionChangedFcn;cb(app.Tree,[]);drawnow;
verifyTrue(testCase,isnumeric(node.NodeData));verifyEqual(testCase,size(node.NodeData,3),3);
images=findall(app.UIAxes,'Type','image');verifyNumElements(testCase,images,1);
verifyEqual(testCase,images.CData,node.NodeData);
% Repair a figure cached by the previous implementation, without deleting
% that pre-existing figure or the DetecDiv window.
sentinel=figure('Visible','off');closeSentinel=onCleanup(@()delete(sentinel)); %#ok<NASGU>
node.NodeData=sentinel;cb(app.Tree,[]);drawnow;
verifyTrue(testCase,isnumeric(node.NodeData));verifyTrue(testCase,isvalid(sentinel));verifyTrue(testCase,isvalid(app.DetecDivUIFigure));
delete(fullfile(c.path,'trainingdataset','lstm_timeseries_dataset.mat'));
node.NodeData=[];cb(app.Tree,[]);drawnow;
verifyEmpty(testCase,findall(app.UIAxes,'Type','image'));verifyTrue(testCase,isvalid(app.DetecDivUIFigure));
end
function [c,cleanup]=fixture()
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
c=lstm_timeseries.create(root,'numeric_preview',1,{'budding','arrested','dead'});c.roi=roi.empty;
mkdir(fullfile(c.path,'trainingdataset'));
sample=struct('roiId','preview_roi','frames',1:60,'X',[sin((1:60)/5);cos((1:60)/7)], ...
 'Y',categorical("budding",c.classes),'split','train');
dataset=struct('samples',sample);
save(fullfile(c.path,'trainingdataset','lstm_timeseries_dataset.mat'),'dataset');
end
