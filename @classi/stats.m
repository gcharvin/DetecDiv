function [h1, h2, h3]=stats(classif,roiid,varargin)
outputstr='temp';
% compute, displays and stores statististics regarding the selected classification 

% roiid is an array of roiid from the object classi 

for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Dataset')
        datasetType=varargin{i+1};
    end
end

% if nargin==1
% disp(['All ROIs in the @classi object will be used: ' num2str(numel(classif.roi))]);
% listroi=1:numel(classif.roi);
% end
% 
% if nargin==2
disp(['Stats will be done on the following ROIs: ' num2str(roiid)]);    
listroi=roiid;
% end

idstat=[];

path=classif.path;
name=classif.strid;
strpath=[path '/' outputstr '_' name];

classistr=classif.strid;

for j=listroi
    
    obj=classif.roi(j);
    disp([num2str(j) ' - '  obj.id ' - checking data']);
    
    % classiid represents the strid of the classifier to be displayed
    
    resok=0;
    ground=0;
    
    if numel(obj.results)==0
        disp('There is no result available for this roi');
    else
        resok=1;
    end
    
    if ~isfield(obj.results,classistr)
        disp('There is no result available for this classification id');
    else
        resok=1;
    end
    
    % if roi was used for user training, display the training data first
    
    if numel(obj.train)~=0
        if isfield(obj.train,classistr)
            if numel(obj.train.(classistr).id) > 0
                if sum(obj.train.(classistr).id)>0 % training exists for this ROI !
                    ground=1;
                    
                end
            end
        end
    end
    
    % then display the results
    
    if ground ==1 && resok==1 % list of rois used to compute stats
        idstat=[idstat j];
    end
    
end

cc=1;


% =============accuracy per ROI===============
acc=[];
sumyr=[];
sumyg=[];


if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
    accCNN=[];
    sumyrCNN=[];
end


lab={};
for i=idstat
    obj=classif.roi(i);
    yr=obj.results.(classistr).id;
    yg=obj.train.(classistr).id;
    
    if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
       yrCNN=obj.results.(classistr).idCNN;
       sumyrCNN=[sumyrCNN yrCNN];
       accCNN(cc)= 100*sum(yrCNN==yg)./length(yg);
    end
    
    acc(cc)= 100*sum(yr==yg)./length(yg);
    sumyr=[sumyr yr];
    sumyg=[sumyg yg];   
    lab{cc}=num2str(i);
    
    cc=cc+1;
end

acctot= 100*sum(sumyr==sumyg)./length(sumyg);
if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
    acctotCNN= 100*sum(sumyrCNN==sumyg)./length(sumyg);
end

%===plot===
h1=figure('Color','w','Units', 'normalized', 'Position',[0.1, 0.1, 0.5, 0.5]);
plot(acc,'Color','k','LineWidth',2,'Marker','o');
ylim([0 100]);
ylabel('Validation accuracy (%)');
xlabel('ROI #');
title({['Dataset:' datasetType ' - Mean acc.: '  num2str(acctot)  '% - ' name] [' - ROIs:' num2str(idstat)]},'interpreter','none');
set(gca,'FontSize',14,'XTick',1:numel(idstat),'XTicklabel',lab);

if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
    hold on
    plot(accCNN,'Color','g','LineWidth',2,'Marker','o');
    title({['Dataset:' datasetType ' - Mean acc. LSTM VS CNN: '  num2str(acctot)  '% - VS ' num2str(acctotCNN) '% - ' name ' - ']},'interpreter','none');
end

% disp(['Saving plot to ' strpath '_accuracy_ROIs.fig']);
% savefig([strpath '_accuracy_ROIs.fig']);
% disp(['Saving plot to ' strpath '_accuracy_ROIs.pdf']);
% saveas(gca,[strpath '_accuracy_ROIs.pdf']);



%  =============accuracy per class for all ROIs==================
% acc=[];
% sumyr=[];
% sumyg=[];
% 
% if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
%     accCNN=[];
%     sumygCNN=[];
% end
% 
% for i=idstat
%     obj=classif.roi(i);
%     yr=obj.results.(classistr).id;
%     yg=obj.train.(classistr).id; 
%     sumyr=[sumyr yr];
%     sumyg=[sumyg yg]; 
%     
%     if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
%         yrCNN=obj.results.(classistr).idCNN;
%         sumyrCNN=[sumyrCNN yrCNN];
%         accCNN(cc)= 100*sum(yrCNN==yg)./length(yg);
%     end
%     cc=cc+1;
% end

freqg=[];
freqr=[];
for i=1:numel(classif.classes)
    pix= sumyg==i;
    pixr= sumyr==i;
    unio= sumyg==i | sumyr==i; 
    ss=sumyr(pix);  
    acc(i)=100*sum(ss==i)./sum(unio);
    freqg(i)=100*sum(pix)./length(sumyg);
    freqr(i)=100*sum(pixr)./length(sumyr);
    
    if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
        pixrCNN=sumyrCNN==i;
        unioCNN= sumyg==i | sumyrCNN==i; 
        ssCNN=sumyrCNN(pix);  
        accCNN(i)=100*sum(ssCNN==i)./sum(unioCNN);
        freqrCNN(i)=100*sum(pixrCNN)./length(sumyrCNN);  
    end
end

acctot= 100*sum(sumyr==sumyg)./length(sumyg);
if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
    acctotCNN= 100*sum(sumyrCNN==sumyg)./length(sumyg);
end

%===plot===
h2=figure('Color','w','Units', 'normalized', 'Position',[0.1, 0.1, 0.5, 0.5]);
    subplot(2,1,1);
    plot(acc,'Color','k','LineWidth',2,'Marker','o');
    ylim([0 100]);
    xlim([0 numel(classif.classes)+1]);
    ylabel('Validation IoU (%)'); 
    title({['Dataset:' datasetType ' - Mean acc.: '  num2str(acctot)  '% - N=' num2str(length(sumyg)) ' - ' name ' - ROIs:' num2str(idstat)]},'interpreter','none');
    set(gca,'FontSize',14,'XTick',1:numel(classif.classes),'XTickLabel',{});

    if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
        hold on
        plot(acc,'Color','g','LineWidth',2,'Marker','o');
        title({['Dataset:' datasetType ' - Mean acc. LSTM VS CNN: '  num2str(acctot)  '% - VS' num2str(acctotCNN) '% - ' name] [' - ROIs:' num2str(idstat)]},'interpreter','none');
    end

    subplot(2,1,2);
    plot(freqg,'Color','k','LineWidth',2,'Marker','o'); hold on;
    plot(freqr,'Color','r','LineWidth',2,'Marker','o'); hold on;
    ylim([0 100]);
    xlim([0 numel(classif.classes)+1]);
    ylabel('Frequency');
    xlabel('classes');
    legend({'Groundtruth','Classification'});
    set(gca,'FontSize',14,'XTick',1:numel(classif.classes),'XTickLabel',classif.classes);

    if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
        hold on
        plot(freqrCNN,'Color','g','LineWidth',2,'Marker','o'); hold on;
        legend({'Groundtruth','Classification LSTM','Classification CNN'});
    end

% savefig([strpath '_accuracy_classes.fig']);
% saveas(gca,[strpath '_accuracy_classes.pdf']);

% disp(['Saving plot to ' strpath '_accuracy_classes.fig']);
% savefig([strpath '_accuracy_classes.fig']);
% disp(['Saving plot to ' strpath '_accuracy_classes.pdf']);
% saveas(gca,[strpath '_accuracy_classes.pdf']);

% check is if classes are not present

classs={};
cc=1;
for i=1:numel(classif.classes)
    if ~any(sumyr==i) && ~any(sumyg==i)
       % remove class i
    else
      classs{cc}=classif.classes{i};  
      cc=cc+1;
    end
end

%======CONFUSION MATRIX======
% remove unclassified groundtruth events
pix=sumyg~=0;
sumyg=sumyg(pix);
sumyr=sumyr(pix);
sumyrCNN=sumyrCNN(pix);
cate=categorical(classs);
mate=confusionmat(sumyg,sumyr);
mateCNN=confusionmat(sumyg,sumyrCNN);

h3=figure('Color','w','Units', 'normalized', 'Position',[0.1, 0.1, 0.5, 0.5]);
    subplot(2,1,1)
    cm=confusionchart(mate,cate,'ColumnSummary','column-normalized','RowSummary','row-normalized');
    xlabel('Classification predictions');
    ylabel('Groundtruth');
    title({['Dataset:' datasetType ' - N=' num2str(length(sumyg)) ' - ' name] [' - ROIs:' num2str(idstat)]});

    subplot(2,1,2)
    if classif.typeid==4 %%if LSTM classif: compute CNN accuracy
        cmCNN=confusionchart(mateCNN,cate,'ColumnSummary','column-normalized','RowSummary','row-normalized');
        xlabel('Classification predictions CNN');
        ylabel('Groundtruth');
        title({['Dataset:' datasetType ' - N=' num2str(length(sumyg)) ' - ' name] [' - ROIs:' num2str(idstat)]});
    end

% disp(['Saving plot to ' strpath '_confusion.fig']);
% savefig([strpath '_confusion.fig']);
% disp(['Saving plot to ' strpath '_confusion.pdf']);
% saveas(gca,[strpath '_confusion.pdf']);


% plot confusion matrix for classification 
disp('Done!');

