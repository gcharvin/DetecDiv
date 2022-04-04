function [h1,h2,h3,h4]=statRLS(rls,varargin)

% plot statistics associated with automated RLS data
% this assumes that groundtruth and test data are interwined.

% plot correlation between groundtruth rls and observed rls 

figExport=0;
plotCNN=1;
plotFluo=1;
plotVolume=1;
corrdiv=0;

sz=4;
comment='';
for i=1:numel(varargin)
    if strcmp(varargin{i},'Comment')
        comment=[varargin{i+1} '- '];
    end
    
    if strcmp(varargin{i},'CorrelDiv')
        corrdiv=1;
    end
end


%% remove unclassified and unannotated rois
rlsp=[rls.groundtruth]==0;
toremove=(rlsp & [rls.ndiv]==-1); %remove roi with no training
toremoveidx=find(toremove);
toremoveidx=[toremoveidx, toremoveidx+1]; %+1 because in pairs, gt=0 comes first
rls(toremoveidx)=[];

rlsg=[rls.groundtruth]==1;
toremove=(rlsg & [rls.ndiv]==-1); %remove roi with no pred
toremoveidx=find(toremove);
toremoveidx=[toremoveidx, toremoveidx-1]; %-1 because in pairs, gt=1 comes second
rls(toremoveidx)=[];
%%
rlsp=[rls.groundtruth]==0;
rlsg=[rls.groundtruth]==1;
rlsgNdivs=[rls(rlsg).ndiv];
rlspNdivs=[rls(rlsp).ndiv];


rlscnn=[rls.groundtruth]==2;
if sum(rlscnn)==0
    plotCNN=0;
end
rlscnnNdivs=[rls(rlscnn).ndiv];

rlspDivsDuration=[];
rlscnnDivsDuration=[];
rlsgDivsDuration=[];

fz=16;
lw=3;
dz=50;
if figExport==1
    fz=8;
    lw=1;
    dz=15;
end

%% plot rls correlation
h1=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
scatter(rlspNdivs,rlsgNdivs,dz,'filled','MarkerFaceColor',[125/255, 125/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on; 
r=corrcoef(rlspNdivs,rlsgNdivs);

M=max(max(rlspNdivs),max(rlsgNdivs));
txt=[comment 'R^2=' num2str(r(1,2)) newline 'N=' num2str(numel(rlscnnNdivs))];


if plotCNN==1
    scatter(rlscnnNdivs,rlsgNdivs,dz,'filled','MarkerFaceColor',[125/255, 0/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on; 
M=max(M,max(rlscnnNdivs));
rcnn=corrcoef(rlscnnNdivs,rlsgNdivs);
txt=[txt newline 'R^2=' num2str(rcnn(1,2)) newline 'N=' num2str(numel(rlscnnNdivs))];
end

plot(0:M,0:M,'k','LineStyle','--','LineWidth',lw*0.66);


xlim([0 M]);
ylim([0 M]);
xl=xlim; yl=ylim;

box on
axis square;

xlabel('Predicted lifespan (gen.)');
ylabel('Groundtruth lifespan (gen.)');
text(2+xl(1),0.9*yl(2),txt,'FontSize',fz,'FontWeight','bold');


set(gca,'FontSize',fz, 'FontName','Myriad Pro', 'LineWidth',lw,'FontWeight','bold', 'XTick',[0:10:M],'YTick',[0:10:M],'TickLength',[0.02 0.02]);

if figExport==1
    ax=gca;
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])
    
    exportgraphics(h1,'h1.pdf','BackgroundColor','none','ContentType','vector')
end

%% 2/ plot divtimes correlation
if isfield(rls,'noFalseDiv') && corrdiv==1
    %LSTM
    ccd=1;
    flag=[];
    for r=1:numel(rls)/2 %remove rois with pairing mismatch
        if (numel(rls(ccd).divDurationNoFalseDiv)~=numel(rls(ccd+1).divDurationNoFalseDiv)) | isnan(rls(ccd).divDurationNoFalseDiv) | isnan(rls(ccd+1).divDurationNoFalseDiv)
            flag=[flag ccd ccd+1];
        end
        ccd=ccd+2;
    end
    rlsdivs=rls;
    rlsdivs(flag)=[];
    rlspDivsDuration=[rlsdivs([rlsdivs.groundtruth]==0).divDurationNoFalseDiv];
    rlsgDivsDuration=[rlsdivs([rlsdivs.groundtruth]==1).divDurationNoFalseDiv];

    if plotCNN==1
        rlscnnDivsDuration=[rls(rlscnn).divDurationNoFalseDiv];
    end

            FP=numel([rls([rlsdivs.groundtruth]==0).falseDiv]);
            FN=numel([rls([rlsdivs.groundtruth]==1).falseDiv]);
            TP=numel([rls([rlsdivs.groundtruth]==0).framediv])-FP;
            accu=TP/(TP+FP);
            recall=TP/(TP+FN);
            disp(['Accu=' num2str(accu)])
            disp(['Recall=' num2str(recall)])


    rlspDivsDuration=rlspDivsDuration*5;
    rlsgDivsDuration=rlsgDivsDuration*5;
    
    rcoef=corrcoef(rlspDivsDuration,rlsgDivsDuration);
    txt=[comment 'R^2=' num2str(rcoef(1,2)) newline 'N=' num2str(numel(rlsgDivsDuration))];        
    
    h2=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
    scatter(rlspDivsDuration,rlsgDivsDuration,dz,'filled','MarkerFaceColor',[125/255, 125/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on;
    
    box on
    %     hist3([rlsgDivsDuration',rlspDivsDuration'],'CDataMode','auto','Nbins',[50,50])
    %     view(2)
    %     colorbar
    
    %     colormap gray
    %     colorbar
    %scatter_kde(rlspDivsDuration',rlsgDivsDuration','filled','MarkerEdgeColor','k','LineWidth',0.1);
    
    plot(0:max(max(rlspDivsDuration),max(rlsgDivsDuration)),0:max(max(rlspDivsDuration),max(rlsgDivsDuration)),'k','LineStyle','--','LineWidth',lw);
    
%     xlim([20 max(max(rlsgDivsDuration),max(rlspDivsDuration))]);
%     ylim([20 max(max(rlsgDivsDuration),max(rlspDivsDuration))]);
    xlim([20,500])
    ylim([20,500])
    xl=xlim; yl=ylim;
    axis square;
    xlabel('Predicted division time (minutes)');
    ylabel('Groundtruth division time (minutes)');
    
    text(1.2*xl(1),0.75*yl(2),txt,'FontSize',fz,'FontWeight','bold');
    set(gca,'xscale','log','yscale','log')
    ticklog=[20 :20:100,200:100:500];
    set(gca,'FontSize',fz, 'FontName','Myriad Pro','LineWidth',lw,'FontWeight','bold',...
        'XTick',ticklog,...
        'YTick',ticklog,'TickLength',[0.02 0.02]);
else
    h2=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
end

if figExport==1
    ax=gca;
    
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])
    
    exportgraphics(h2,'h2.pdf','BackgroundColor','none','ContentType','vector')
end
%% ======plot ecdf for lifespan======

[ypred,xpred]=ecdf(rlspNdivs);
[yg,xg]=ecdf(rlsgNdivs);
if plotCNN==1
    [ycnn,xcnn]=ecdf(rlscnnNdivs);
    %logrank([rlscnnNdivs', zeros(numel(rlscnnNdivs),1)],[rlsgNdivs', zeros(numel(rlsgNdivs),1)]);
end

h3=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);

stairs([0 ; xpred],[1 ; 1-ypred],'Color','k','LineWidth',lw);hold on,
stairs([0 ; xg],[1 ; 1-yg],'Color',[20/255,200/255,50/255],'LineWidth',lw);
if plotCNN==1
    stairs([0 ; xcnn],[1 ; 1-ycnn],'Color',[20/255,20/255,255/255],'LineWidth',lw);
end

leg={['Predicted; median=' num2str(median(rlspNdivs)) ' (N=' num2str(length(rlspNdivs)) ')'],['Groundtruth; median=' num2str(median(rlsgNdivs)) ' (N=' num2str(length(rlsgNdivs)) ')']};
if plotCNN==1
    leg{3}=['CNN Predicted; median=' num2str(median(rlscnnNdivs)) ' (N=' num2str(length(rlscnnNdivs)) ')'];
end
legend(leg);

axis square;
xlabel('Divisions');
ylabel('Survival');
%logrank([rlspNdivs', zeros(numel(rlspNdivs),1)],[rlsgNdivs', zeros(numel(rlsgNdivs),1)]);
p=0;
title([comment 'Replicative lifespan; p=' num2str(p)]);
set(gca,'FontSize',fz, 'FontName','Myriad Pro','LineWidth',lw,'FontWeight','bold','XTick',[0:10:max(max(rlspNdivs),max(rlsgNdivs))],'TickLength',[0.02 0.02]);
xlim([0 max(max(rlspNdivs),max(rlsgNdivs))])
ylim([0 1.05]);


if figExport==1
    ax=gca;
    
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])        
    exportgraphics(h3,'h3.pdf','BackgroundColor','none','ContentType','vector')
end
%% =====plot overall distribution of division times ======
rlsgNdivs=[rls.groundtruth]==1;
rlspNdivs=[rls.groundtruth]==0;

divg=[rls(rlsgNdivs).divDuration]*5;
divt=[rls(rlspNdivs).divDuration]*5;
p=ranksum(divg,divt);

if plotCNN==1
    rlscnnNdivs=[rls.groundtruth]==2;
    divcnn=[rls(rlscnnNdivs).divDuration]*5;
    pcnn=ranksum(divg,divcnn);
end

bins=[0:5:200, 1000];


h4=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);

histogram(divt,bins,'DisplayStyle','stairs','LineWidth',lw,'EdgeColor','k','EdgeAlpha',0.75);
hold on
histogram(divg,bins,'DisplayStyle','stairs','LineWidth',lw,'EdgeAlpha',0.75,'EdgeColor',[20/255,200/255,50/255]);
if plotCNN==1
   histogram(divcnn,bins,'DisplayStyle','stairs','LineWidth',lw,'EdgeAlpha',0.75,'EdgeColor',[20/255,20/255,255/255]);
end

% stairs(xg,ng,'Color','k','LineWidth',3);hold on;
% p=patch(xt,nt,'Color',[20/255,200/255,50/255],'LineWidth',3); 
%p.Color(4) = 0.25;
% alpha(p,0.5)
%1. ***test*** 
%+

leg={['Predicted; mean+-SEM=' num2str(mean(divt)) '+' num2str(std(divt)/sqrt(length(divt))) ' (N=' num2str(length(divt)) '); p=' num2str(p)],['Grountruth; mean+-SEM=' num2str(mean(divg)) '+' num2str(std(divg)/sqrt(length(divg))) ' (N=' num2str(length(divg)) ')']};
if plotCNN==1
    leg{3}=['CNN Predicted; mean+-SEM=' num2str(mean(divcnn)) '+' num2str(std(divcnn)/sqrt(length(divcnn))) ' (N=' num2str(length(divcnn)) '); p=' num2str(pcnn)];
end
legend(leg);

title([comment 'Division times']);
set(gca,'FontSize',fz, 'FontName','Myriad Pro','LineWidth',lw,'FontWeight','bold','XTick',[0:25:200],'TickLength',[0.02 0.02]);
xlim([0,202]);
axis square;
xlabel('Division time (minutes)');
ylabel('# Events');


if figExport==1
    ax=gca;
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
%     set(gcf,'Units','centimeters','Position', [5 5 xf_width+3 yf_width+3]);
    set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])
    
    exportgraphics(h4,'h4.pdf','BackgroundColor','none','ContentType','vector')
end


