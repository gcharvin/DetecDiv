function []=plotValidation(classi,varargin)
dateT=char( datetime('now','Format','yyyy-MM-dd-HH-mm-ss'));
path=[classi.path '\TrainingValidation\'];

if ~exist(path)
    disp('TrainingValidation folder does not exist; Likely cause: no training has been done !');
end

folder=dir(path);
folder=folder(contains({folder.name},string(dateT)));

% dateT=[dateT '-n' num2str(numel(folder))];
mkdir([path dateT]);

commentsCNN="ND";

plottraj=0;
plotrls=0;

for i=1:numel(varargin)
    %Comment
    if strcmp(varargin{i},'CommentCNN')
        commentsCNN=string(varargin{i+1});
    end
    %plotTraj
    if strcmp(varargin{i},'Traj')
    plottraj=varargin{i+1};
    end
    
    if strcmp(varargin{i},'RLS')
    plotrls=varargin{i+1};
    end
end


commentsLSTM="ND";

switch classi.typeid
    case {2,8}
        
    case 4
for i=1:numel(varargin)
    %Comment
    if strcmp(varargin{i},'CommentLSTM')
        commentsLSTM=string(varargin{i+1});
    end
end
end

load([path  '\trainingParam.mat']);
copyfile([classi.path '\' classi.strid '.mat'],[path  dateT '\' classi.strid '.mat']);

switch classi.typeid
    case {2,8}
        
    case 4
copyfile([classi.path '\netCNN.mat'],[path dateT  '\netCNN.mat']);
copyfile([classi.path '\netLSTM.mat'],[path dateT  '\netLSTM.mat']);
end

 %% CNN Training
 includeCNNTraining=0;
 if exist([path 'CNNTraining.pdf'])
copyfile([path 'CNNTraining.pdf'],[path dateT '\CNNTraining.pdf']);
includeCNNTraining=1;
 else
     disp(['File ' path 'CNNTraining.pdf' ' does not exist! Skipping...' ])  
 end
 
folder=dir(path);
CNNfile=folder(contains({folder.name},'CNNTraining.pdf'));

 includeLSTMTraining=0;
switch classi.typeid
    case 4
%% LSTM Training

if exist([path 'LSTMTraining.pdf'])
copyfile([path 'LSTMTraining.pdf'],[path dateT '\LSTMTraining.pdf']);
 includeLSTMTraining=1;
else
disp(['File ' path 'LSTMTraining.pdf' ' does not exist ! Skipping ...' ])  

end

LSTMfile=folder(contains({folder.name},'LSTMTraining.pdf'));
end


%% CNNparam
if includeCNNTraining
figCNN=figure('Name', CNNfile.date,'Units', 'Normalized', 'Position',[0.1, 0.1, 0.5, 0.5]);
load([path  '\CNNOptions.mat']);

if numel(CNNOptions.InitialLearnRate)==0
    CNNOptions.InitialLearnRate=999;
end

tableCNN=table(string(datetime('now','Format','HH:mm:ss')),...
    string(CNNfile.date),...
    string(classi.path),...
    string(classi.strid),...
    numel([trainingParam.rois]),...
    string(num2str([trainingParam.rois])),...
    string(trainingParam.network),...
    trainingParam.split,...
    string(num2str(trainingParam.rotateAugmentation)),...
    string(num2str(trainingParam.translateAugmentation)),...
    CNNOptions.InitialLearnRate,...
    string(CNNOptions.LearnRateScheduleSettings.Method ),...
    CNNOptions.LearnRateScheduleSettings.DropRateFactor,...
    CNNOptions.LearnRateScheduleSettings.DropPeriod,...
    CNNOptions.L2Regularization,...
    string(CNNOptions.Shuffle),...
    CNNOptions.MaxEpochs,...
    CNNOptions.MiniBatchSize,...
    string(CNNOptions.GradientThresholdMethod),...
    CNNOptions.GradientThreshold,...
    string(commentsCNN),...
    'VariableNames',...
    {'DateOfReport',...
    'DateOfTraining',...
    'path',...
    'classi',...
    'NumberOfRois',...
    'ROIList',...
    'CNNNetwork',...
    'CNNSplit',...
    'rotateAugmentation',...
    'translateAugmentation',...
    'InitialLearnRate' ,...
    'LearnRateScheduleMethod',...
    'LearnRateScheduleDropFactor',...
    'LearnRateScheduleDropPeriod',...
    'L2Reg',...
    'Shuffle',...
    'MaxEpochs',...
    'MiniBatchSize',...
    'GradientThresholdMethod',...
    'GradientThreshold',...
    'Comments'});
    %CNNOptions.LearnRateDropFactor,...
    %CNNOptions.LearnRateDropPeriod,...
%     'LearnRateScheduleDropFactor',...
%     'LearnRateScheduleDropPeriod',...
    
if isfield(CNNOptions,'Momentum')
    tableCNN_specific=table("SGDM",...
        CNNOptions.Momentum,...
        'VariableNames',...
        {'Method',...
        'Momentum'});
    
elseif isfield(CNNOptions,'Epsilon')
    tableCNN_specific=table("ADAM",...
        CNNOptions.GradientDecayFactor,...
        CNNOptions.Epsilon,...
        'VariableNames',...
        {'Method',...
        'GradientDecayFactor',...
        'Epsilon'});
end

tableCNN=[tableCNN tableCNN_specific];
tableCNN = table(tableCNN{:,:}.','RowNames',tableCNN.Properties.VariableNames);
%         tableCNN.Properties.VariableNames="ADAM";

%need to pass table into cell to use fig instead uifig, because
%the export functions for uifig are bugged (not thanks, Mathworks)
cellCNN=table2cell(tableCNN);
for i=1:numel(cellCNN)
    cellCNN{i}=char(cellCNN{i});
end

uitCNN=uitable(figCNN,'Data',cellCNN,'RowName',tableCNN.Row,'ColumnWidth',{1500},'Units', 'Normalized', 'Position',[0, 0,1, 1],...
    'FontWeight', 'bold');
export_fig(figCNN, [path dateT '\CNNParam.pdf']);
copyfile([path  '\CNNOptions.mat'],[path dateT '\CNNOptions.mat']);
end


switch classi.typeid
    case 4

        if includeLSTMTraining
        %% LSTMparam
figLSTM=figure('Name', LSTMfile.date, 'Units', 'Normalized', 'Position',[0.1, 0.1, 0.5, 0.5],'HandleVisibility', 'on');
load([path  'LSTMOptions.mat']);

tableLSTM=table(string(LSTMfile.date),...
    string(classi.path),...
    string(classi.strid),...
    numel([trainingParam.rois]),...
    string(num2str([trainingParam.rois])),...
    trainingParam.lstmlayers,...,
    trainingParam.lstmsplit,...
    LSTMOptions.InitialLearnRate,...
    string(LSTMOptions.LearnRateScheduleSettings.Method ),...
    LSTMOptions.LearnRateScheduleSettings.DropRateFactor,...
    LSTMOptions.LearnRateScheduleSettings.DropPeriod,...
    LSTMOptions.L2Regularization,...
    string(LSTMOptions.Shuffle),...
    LSTMOptions.MaxEpochs,...
    LSTMOptions.MiniBatchSize,...
    string(LSTMOptions.GradientThresholdMethod),...
    LSTMOptions.GradientThreshold,...
    string(commentsLSTM),...
    'VariableNames',...
    {'DateOfTraining',...
    'path',...
    'classi',...
    'NumberOfROIs',...  
    'ROIList',...
    'NumberOfLayers',...
    'LSTMSplit',...
    'InitialLearnRate' ,...
    'LearnRateScheduleMethod',...
    'LearnRateScheduleDropFactor',...
    'LearnRateScheduleDropPeriod',...
    'L2Reg',...
    'Shuffle',...
    'MaxEpochs',...
    'MiniBatchSize',...
    'GradientThresholdMethod',...
    'GradientThreshold',...
    'Comments'});

if isfield(LSTMOptions,'Momentum')
    tableLSTM_specific=table("SGDM",...
        LSTMOptions.Momentum,...
        'VariableNames',...
        {'Method',...
        'Momentum'});
    
elseif isfield(LSTMOptions,'Epsilon')
    tableLSTM_specific=table("ADAM",...
        LSTMOptions.GradientDecayFactor,...
        LSTMOptions.Epsilon,...
        'VariableNames',...
        {'Method',...
        'GradientDecayFactor',...
        'Epsilon'});
end
tableLSTM=[tableLSTM tableLSTM_specific];
tableLSTM = table(tableLSTM{:,:}.','RowNames',tableLSTM.Properties.VariableNames);
%         tableLSTM.Properties.VariableNames="ADAM";
        
        %need to pass table into cell to use fig instead uifig, because
        %the export functions for uifig are bugged (not thanks, Mathworks)
        cellLSTM=table2cell(tableLSTM);
        for i=1:numel(cellLSTM)
        cellLSTM{i}=char(cellLSTM{i});
        end
        
    uitLSTM=uitable(figLSTM,'Data',cellLSTM,'RowName',tableLSTM.Row,'ColumnWidth',{1500},'Units', 'Normalized', 'Position',[0, 0,1, 1],...
        'FontWeight', 'bold');
    export_fig(figLSTM, [path dateT '\LSTMParam.pdf']);
    copyfile([path  '\LSTMOptions.mat'],[path dateT '\LSTMOptions.mat']);
        end
end

%% Classif stats

if isfield(trainingParam,'rois')
if iscell(trainingParam.rois)
    roisTrain=[trainingParam.rois{1,:}];
else
    roisTrain=trainingParam.rois;
end
else
   roisTrain=1:numel(classi.roi(:)); 
end
roisTest=1:numel(classi.roi(:));
%take all the rois of the classi

%roisTrain
roisTest=setdiff(roisTest,roisTrain);

%remove the training rois


[hClassiStats1, hClassiStats2, hClassiStats3] =classi.stats('ROI',roisTrain,'Dataset','TRAINSET');


export_fig(hClassiStats1, [path dateT '\accuracy_ROIs_Train.pdf']);
export_fig(hClassiStats2, [path dateT '\accuracy_classes_Train.pdf']);
export_fig(hClassiStats3, [path dateT '\confusion_Train.pdf']);

if numel(roisTest)>0

    [hClassiStats_Test1, hClassiStats_Test2, hClassiStats_Test3] =classi.stats('ROI',roisTest,'Dataset','TESTSET');

    export_fig(hClassiStats_Test1, [path dateT '\accuracy_ROIs_Test.pdf']);
    export_fig(hClassiStats_Test2, [path dateT '\accuracy_classes_Test.pdf']);
    export_fig(hClassiStats_Test3, [path dateT '\confusion_Test.pdf']);
end


%% below validation is only for CNN+LSTM+RLS analysis 

%% Traj
if plottraj==1
    tic
    cctraj=1;
    for i=roisTrain
        trajiTrain(cctraj)=classi.roi(i).traj(classi.strid,'Hide',1,'Comment', ['TRAINSET, roi' num2str(i)]);
        export_fig(trajiTrain(cctraj), [path dateT '\traj_Train_' num2str(i) '.pdf']);
        close(trajiTrain(cctraj));
        cctraj=cctraj+1;
    end
    
    cctraj=1;
    for i=roisTest
        trajiTest(cctraj)=classi.roi(i).traj(classi.strid,'Hide',1,'Comment', ['TESTSET, roi' num2str(i)]);
        export_fig(trajiTest(cctraj), [path dateT '\traj_Test_' num2str(i) '.pdf']);
        close(trajiTest(cctraj));
        cctraj=cctraj+1;
    end
    toc
end

if plotrls==1
%% RLS
[rlsTrain,~,~]=measureRLS2(classi,'Rois',roisTrain);
[rlsTest,~,~]=measureRLS2(classi,'Rois',roisTest);
%% statRLS
[hRlsStats1Train,hRlsStats2Train,hRlsStats3Train]=statRLS(rlsTrain,'Comment','TRAINSET');
export_fig(hRlsStats1Train, [path dateT '\rlsStats1Train.pdf']);
export_fig(hRlsStats2Train, [path dateT '\rlsStats2Train.pdf']);
export_fig(hRlsStats3Train, [path dateT '\rlsStats3Train.pdf']);

[hRlsStats1Test,hRlsStats2Test,hRlsStats3Test]=statRLS(rlsTest,'Comment','TESTSET');
export_fig(hRlsStats1Test, [path dateT '\rlsStats1Test.pdf']);
export_fig(hRlsStats2Test, [path dateT '\rlsStats2Test.pdf']);
export_fig(hRlsStats3Test, [path dateT '\rlsStats3Test.pdf']);
%% plotRLS
hRlsTrain=plotRLS(rlsTrain,'Comment','TRAINSET');
export_fig(hRlsTrain, [path dateT '\rlsTrain.pdf']);

hRlsTest=plotRLS(rlsTest,'Comment','TESTSET');
export_fig(hRlsTest, [path dateT '\rlsTest.pdf']);
end


%% Report
if exist([path  '\' dateT '\' 'Report_' dateT '.pdf'],'file')
    error('Cant write PDF, file already exists');
end

if numel(roisTest)>0
    disp('test data available, printing them on the report')

append_pdfs([path  '\' dateT '\' 'Report_' dateT  '.pdf'],...
    [path dateT '\CNNParam.pdf'],...
    [path dateT '\CNNTraining.pdf']);

switch classi.typeid
    case 4
    append_pdfs([path  '\' dateT '\' 'Report_' dateT  '.pdf'],...  
    [path dateT '\LSTMParam.pdf'],...
    [path dateT '\LSTMTraining.pdf']);
end

append_pdfs([path  '\' dateT '\' 'Report_' dateT  '.pdf'],...
    [path dateT '\accuracy_ROIs_Train.pdf'],...
    [path dateT '\accuracy_classes_Train.pdf'],...
    [path dateT '\confusion_Train.pdf'],...
    [path dateT '\accuracy_ROIs_Test.pdf'],...
    [path dateT '\accuracy_classes_Test.pdf'],...
    [path dateT '\confusion_Test.pdf']);
    
if plotrls==1
append_pdfs([path  '\' dateT '\' 'Report_' dateT  '.pdf'],...
    [path dateT '\rlsStats1Train.pdf'],...
    [path dateT '\rlsStats2Train.pdf'],...
    [path dateT '\rlsStats3Train.pdf'],...
    [path dateT '\rlsTrain.pdf'],...
    [path dateT '\rlsStats1Test.pdf'],...
    [path dateT '\rlsStats2Test.pdf'],...
    [path dateT '\rlsStats3Test.pdf'],...
    [path dateT '\rlsTest.pdf']);    
end

else
    disp('no test data')
append_pdfs([path  '\' dateT '\' 'Report_' dateT  '.pdf'],...
    [path dateT '\CNNParam.pdf'],...
    [path dateT '\CNNTraining.pdf']);

switch classi.typeid
    case 4
    append_pdfs([path  '\' dateT '\' 'Report_' dateT  '.pdf'],...  
    [path dateT '\LSTMParam.pdf'],...
    [path dateT '\LSTMTraining.pdf']);
end

append_pdfs([path  '\' dateT '\' 'Report_' dateT  '.pdf'],...
    [path dateT '\accuracy_ROIs_Train.pdf'],...
    [path dateT '\accuracy_classes_Train.pdf'],...
    [path dateT '\confusion_Train.pdf']);
    
if plotrls==1
append_pdfs([path  '\' dateT '\' 'Report_' dateT  '.pdf'],...
    [path dateT '\rlsStats1Train.pdf'],...
    [path dateT '\rlsStats2Train.pdf'],...
    [path dateT '\rlsStats3Train.pdf'],...
    [path dateT '\rlsTrain.pdf']); 
end  

end

save([path dateT '\trainingParam.mat'],'trainingParam');

delete([path dateT '\CNNParam.pdf']);
delete([path dateT '\CNNTraining.pdf']);

switch classi.typeid
    case 4
delete([path dateT '\LSTMParam.pdf']);
delete([path dateT '\LSTMTraining.pdf']);
end

delete([path dateT '\accuracy_ROIs_Train.pdf']);
delete([path dateT '\accuracy_classes_Train.pdf']);
delete([path dateT '\confusion_Train.pdf']);

if plotrls==1
delete([path dateT '\rlsStats1Train.pdf']);
delete([path dateT '\rlsStats2Train.pdf']);
delete([path dateT '\rlsStats3Train.pdf']);
delete([path dateT '\rlsTrain.pdf']);
delete([path dateT '\rlsStats1Test.pdf']);
delete([path dateT '\rlsStats2Test.pdf']);
delete([path dateT '\rlsStats3Test.pdf']);
delete([path dateT '\rlsTest.pdf']);
end

if numel(roisTest)>0
    delete([path dateT '\accuracy_ROIs_Test.pdf']);
    delete([path dateT '\accuracy_classes_Test.pdf']);
    delete([path dateT '\confusion_Test.pdf']);
end

%===TRAJ===
if plottraj==1
    for i=roisTrain
        append_pdfs([path  '\' dateT '\' 'Report_' dateT '.pdf'],...
            [path dateT '\traj_Train_' num2str(i) '.pdf']);
        delete([path dateT '\traj_Train_' num2str(i) '.pdf'])
    end
    for i=roisTest
        append_pdfs([path  '\' dateT '\' 'Report_' dateT '.pdf'],...
            [path dateT '\traj_Test_' num2str(i) '.pdf']);
        delete([path dateT '\traj_Test_' num2str(i) '.pdf'])
    end    
end

        
close all
clear figCNN figLSTM uit uitCNN uitLSTM
