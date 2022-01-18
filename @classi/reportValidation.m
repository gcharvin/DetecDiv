function []=reportValidation(classi,varargin)
dateT=char( datetime('now','Format','yyyy-MM-dd-HH-mm-ss'));
path=fullfile(classi.path, 'TrainingValidation');

if ~exist(path)
    disp('TrainingValidation folder does not exist; Likely cause: no training has been done !');
end

folder=dir(path);
folder=folder(contains({folder.name},string(dateT)));

% dateT=[dateT '-n' num2str(numel(folder))];
mkdir(fullfile(path, dateT));

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

%%
commentsLSTM="ND";
switch classi.category{1}
    case 'Pixel'
        
    case 'LSTM'
        for i=1:numel(varargin)
            %Comment
            if strcmp(varargin{i},'CommentLSTM')
                commentsLSTM=string(varargin{i+1});
            end
        end
end

load(fullfile(path,'trainingParam.mat'));

copyfile(fullfile(classi.path, [classi.strid '.mat']),fullfile(path, dateT, [classi.strid '.mat']));

%move classifiers to unique folder
switch classi.category{1}
    case 'Pixel'
        
    case 'LSTM'
        copyfile(fullfile(classi.path, 'netCNN.mat'),fullfile(path, dateT,  'netCNN.mat'));
        copyfile(fullfile(classi.path, 'netLSTM.mat'),fullfile(path, dateT,  'netLSTM.mat'));
end

%% training plot
% move CNN Training plot to dedicated folder
includeCNNTraining=0;
if exist(fullfile(path, 'CNNTraining.pdf'))
    copyfile(fullfile(path, 'CNNTraining.pdf'),fullfile(path, dateT, 'CNNTraining.pdf'));
    includeCNNTraining=1;
else
    disp(['File ' path 'CNNTraining.pdf' ' does not exist! Skipping...' ])
end

folder=dir(path);
CNNfile=folder(contains({folder.name},'CNNTraining.pdf'));
%==

%move LSTM training plot to dedicated folder
includeLSTMTraining=0;
switch classi.category{1}
    case 'LSTM'
        % LSTM Training
        
        if exist(fullfile(path,'LSTMTraining.pdf'))
            
            copyfile(fullfile(path,'LSTMTraining.pdf'),fullfile(path,dateT,'LSTMTraining.pdf'));
            includeLSTMTraining=1;
        else
            disp(['File ' path 'LSTMTraining.pdf' ' does not exist ! Skipping ...' ])
            
        end
        
        LSTMfile=folder(contains({folder.name},'LSTMTraining.pdf'));
end
%==

%% Param
% CNNparam
if includeCNNTraining
    figCNN=figure('Name', CNNfile.date,'Units', 'Normalized', 'Position',[0.1, 0.1, 0.5, 0.5]);
    
    if exist([path  '\CNNOptions.mat'])
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
        export_fig(figCNN, fullfile(path, dateT, 'CNNParam.pdf'));
        copyfile(fullfile(path,  'CNNOptions.mat'),fullfile(path, dateT, 'CNNOptions.mat'));
    end
end


switch classi.category{1}
    case 'LSTM'
        if includeLSTMTraining
            % LSTMparam
            figLSTM=figure('Name', LSTMfile.date, 'Units', 'Normalized', 'Position',[0.1, 0.1, 0.5, 0.5],'HandleVisibility', 'on');
            if exist(fullfile(path, 'LSTMOptions.mat'))
                load(fullfile(path, 'LSTMOptions.mat'));
                
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
                export_fig(figLSTM, fullfile(path, dateT, 'LSTMParam.pdf'));
                copyfile(fullfile(path,  'LSTMOptions.mat'),fullfile(path, dateT, 'LSTMOptions.mat'));
            end
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


export_fig(hClassiStats1, fullfile(path,dateT, 'accuracy_ROIs_Train.pdf'));
export_fig(hClassiStats2, fullfile(path,dateT, 'accuracy_classes_Train.pdf'));
export_fig(hClassiStats3, fullfile(path,dateT, 'confusion_Train.pdf'));

if numel(roisTest)>0
    
    [hClassiStats_Test1, hClassiStats_Test2, hClassiStats_Test3] =classi.stats('ROI',roisTest,'Dataset','TESTSET');
    
    export_fig(hClassiStats_Test1, fullfile(path,dateT, 'accuracy_ROIs_Test.pdf'));
    export_fig(hClassiStats_Test2, fullfile(path,dateT, 'accuracy_classes_Test.pdf'));
    export_fig(hClassiStats_Test3, fullfile(path,dateT, 'confusion_Test.pdf'));
end

%% Traj
% below validation is only for CNN+LSTM+RLS analysis
if plottraj==1
    tic
    cctraj=1;
    for i=roisTrain
        trajiTrain(cctraj)=classi.roi(i).traj(classi.strid,'Hide',1,'Comment', ['TRAINSET, roi' num2str(i)]);
        export_fig(trajiTrain(cctraj), fullfile(path,dateT,['traj_Train_' num2str(i) '.pdf']));
        close(trajiTrain(cctraj));
        cctraj=cctraj+1;
    end
    
    cctraj=1;
    for i=roisTest
        trajiTest(cctraj)=classi.roi(i).traj(classi.strid,'Hide',1,'Comment', ['TESTSET, roi' num2str(i)]);
        export_fig(trajiTest(cctraj), fullfile(path, dateT, ['traj_Test_' num2str(i) '.pdf']));
        close(trajiTest(cctraj));
        cctraj=cctraj+1;
    end
    toc
end

%% measure RLS and plot and export pdf. Might be broken now
if plotrls==1
    % RLS
    [rlsTrain,~,~]=measureRLS2(classi,'Rois',roisTrain);
    [rlsTest,~,~]=measureRLS2(classi,'Rois',roisTest);
    % statRLS
    [hRlsStats1Train,~,hRlsStats2Train,hRlsStats3Train]=statRLS(rlsTrain,'Comment','TRAINSET');
    export_fig(hRlsStats1Train, fullfile(path,dateT, 'rlsStats1Train.pdf'));
    export_fig(hRlsStats2Train, fullfile(path,dateT, 'rlsStats2Train.pdf'));
    export_fig(hRlsStats3Train, fullfile(path,dateT, 'rlsStats3Train.pdf'));
    
    [hRlsStats1Test,~,hRlsStats2Test,hRlsStats3Test]=statRLS(rlsTest,'Comment','TESTSET');
    export_fig(hRlsStats1Test,fullfile(path,dateT, 'rlsStats1Test.pdf'));
    export_fig(hRlsStats2Test, fullfile(path,dateT, 'rlsStats2Test.pdf'));
    exposhrt_fig(hRlsStats3Test, fullfile(path,dateT, 'rlsStats3Test.pdf'));
    % plotRLS
    hRlsTrain=plotRLS(rlsTrain,'Comment','TRAINSET');
    export_fig(hRlsTrain,fullfile(path,dateT, 'rlsTrain.pdf'));
    
    hRlsTest=plotRLS(rlsTest,'Comment','TESTSET');
    export_fig(hRlsTest, fullfile(path,dateT, 'rlsTest.pdf'));
end


%% Report: merge all the pdfs and create a full report
if exist([path  '\' dateT '\' 'Report_' dateT '.pdf'],'file') %should not happen, but in case...
    error('Cant write PDF, file already exists');
end

dirpath= fullfile(path,dateT);
reportpath=fullfile(dirpath,['Report_' dateT  '.pdf']);

if numel(roisTest)>0
    disp('test data available, printing them on the report')
    
    append_pdfs(reportpath,...
        fullfile(dirpath,'CNNParam.pdf'),...
        fullfile(dirpath,'CNNTraining.pdf'));
    
    switch classi.category{1}
        case 'LSTM'
            append_pdfs(reportpath,...
                fullfile(dirpath,'LSTMParam.pdf'),...
                fullfile(dirpath,'LSTMTraining.pdf'));
    end
    
    append_pdfs(reportpath,...
        fullfile(dirpath,'accuracy_ROIs_Train.pdf'),...
        fullfile(dirpath,'accuracy_classes_Train.pdf'),...
        fullfile(dirpath,'confusion_Train.pdf'),...
        fullfile(dirpath,'accuracy_ROIs_Test.pdf'),...
        fullfile(dirpath,'accuracy_classes_Test.pdf'),...
        fullfile(dirpath,'confusion_Test.pdf'));
    
    if plotrls==1
        append_pdfs(reportpath,...
            fullfile(dirpath,'rlsStats1Train.pdf'),...
            fullfile(dirpath,'rlsStats2Train.pdf'),...
            fullfile(dirpath,'rlsStats3Train.pdf'),...
            fullfile(dirpath,'rlsTrain.pdf'),...
            fullfile(dirpath,'rlsStats1Test.pdf'),...
            fullfile(dirpath,'rlsStats2Test.pdf'),...
            fullfile(dirpath,'rlsStats3Test.pdf'),...
            fullfile(dirpath,'rlsTest.pdf'));
    end
    
else
    disp('no test data')
    append_pdfs(reportpath,...
        fullfile(dirpath,'CNNParam.pdf'),...
        fullfile(dirpath,'CNNTraining.pdf'));
    
    switch classi.category{1}
        case 'LSTM'
            append_pdfs(reportpath,...
                fullfile(dirpath,'LSTMParam.pdf'),...
                fullfile(dirpath,'\LSTMTraining.pdf'));
    end
    
    append_pdfs(reportpath,...
        fullfile(dirpath,'accuracy_ROIs_Train.pdf'),...
        fullfile(dirpath,'accuracy_classes_Train.pdf'),...
        fullfile(dirpath,'confusion_Train.pdf'));
    
    if plotrls==1
        append_pdfs(reportpath,...
            fullfile(dirpath,'rlsStats1Train.pdf'),...
            fullfile(dirpath,'rlsStats2Train.pdf'),...
            fullfile(dirpath,'rlsStats3Train.pdf'),...
            fullfile(dirpath,'rlsTrain.pdf'));
    end
    
end

%===TRAJ===
if plottraj==1
    for i=roisTrain
        append_pdfs(reportpath,...
            fullfile(dirpath,['traj_Train_' num2str(i) '.pdf']));
        delete(fullfile(dirpath,['traj_Train_' num2str(i) '.pdf']))
    end
    for i=roisTest
        append_pdfs(reportpath,...
            fullfile(dirpath,['traj_Test_' num2str(i) '.pdf']));
        delete(fullfile(dirpath,['traj_Test_' num2str(i) '.pdf']))
    end
end

save(fullfile(dirpath,'trainingParam.mat'),'trainingParam');

delete(fullfile(dirpath,'CNNParam.pdf'));
delete(fullfile(dirpath,'CNNTraining.pdf'));

switch classi.category{1}
    case 'LSTM'
        delete(fullfile(dirpath,'LSTMParam.pdf'));
        delete(fullfile(dirpath,'LSTMTraining.pdf'));
end

delete(fullfile(dirpath,'accuracy_ROIs_Train.pdf'));
delete(fullfile(dirpath,'accuracy_classes_Train.pdf'));
delete(fullfile(dirpath,'confusion_Train.pdf'));

if plotrls==1
    delete(fullfile(dirpath,'rlsStats1Train.pdf'));
    delete(fullfile(dirpath,'rlsStats2Train.pdf'));
    delete(fullfile(dirpath,'rlsStats3Train.pdf'));
    delete(fullfile(dirpath,'rlsTrain.pdf'));
    delete(fullfile(dirpath,'rlsStats1Test.pdf'));
    delete(fullfile(dirpath,'rlsStats2Test.pdf'));
    delete(fullfile(dirpath,'rlsStats3Test.pdf'));
    delete(fullfile(dirpath,'rlsTest.pdf'));
end

if numel(roisTest)>0
    delete(fullfile(dirpath,'accuracy_ROIs_Test.pdf'));
    delete(fullfile(dirpath,'accuracy_classes_Test.pdf'));
    delete(fullfile(dirpath,'confusion_Test.pdf'));
end


close all
clear figCNN figLSTM uit uitCNN uitLSTM
