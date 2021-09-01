function [h1,h2,h3,h4]=statRLS(rls,varargin)

% plot statistics associated with automated RLS data
% this assumes that groundtruth and test data are interwined.

% plot correlation between groundtruth rls and observed rls 

% C=colormap BUGGGGGGGGGGGGGEDD
% C(1,:)=[0 0 0];
% colormap=C;
figExport=1;
plotFluo=1;
plotVolume=1;

sz=4;
comment='';
for i=1:numel(varargin)
    if strcmp(varargin{i},'Comment')
        comment=[varargin{i+1} '- '];
    end
end

rlsg=[rls.groundtruth]==1;
rlsgNdivs=[rls(rlsg).ndiv];

rlst=[rls.groundtruth]==0;
rlstNdivs=[rls(rlst).ndiv];

rlstDivsDuration=[];
rlsgDivsDuration=[];

%% plot rls correlation
h1=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
scatter(rlsgNdivs,rlstNdivs,50,'filled','MarkerFaceColor',[125/255, 125/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on; 

M=max(max(rlstNdivs),max(rlsgNdivs));
plot(0:M,0:M,'k','LineStyle','--','LineWidth',2);
box on
r=corrcoef(rlsgNdivs,rlstNdivs);

xlim([0 M]);
ylim([0 M]);
xl=xlim; yl=ylim;

axis square;
xlabel('Groundtruth lifespan (gen.)');
ylabel('Computed lifespan (gen.)');
text(2+xl(1),0.9*yl(2),[comment 'R^2=' num2str(r(1,2)) newline 'N=' num2str(numel(rlstNdivs))],'FontSize',16,'FontWeight','bold');

set(gca,'FontSize',16, 'FontName','Myriad Pro', 'LineWidth',3,'FontWeight','bold', 'XTick',[0:10:M],'YTick',[0:10:M],'TickLength',[0.02 0.02]);

if figExport==1
    ax=gca;
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])
    
    set(ax,'FontSize',8, 'LineWidth',1,'FontWeight','bold', 'XTick',[0:10:M],'YTick',[0:10:M],'TickLength',[0.02 0.02]);
    ax.Children(2).LineWidth=1; %diagonale size
    ax.Children(3).SizeData=12; %dot size
    ax.Children(1).FontSize=8; %R² size
    
    exportgraphics(h1,'h1.pdf','BackgroundColor','none','ContentType','vector')
end

%% 2/ plot divtimes correlation
if isfield(rls,'noFalseDiv')
    for i=1:2:numel(rls)-1
        if numel(rls(i).divDurationNoFalseDiv)==numel(rls(i+1).divDurationNoFalseDiv)
            rlstDivsDuration=[rlstDivsDuration, rls(i).divDurationNoFalseDiv];
            rlsgDivsDuration=[rlsgDivsDuration, rls(i+1).divDurationNoFalseDiv];
        end
    end
    rlstDivsDuration=rlstDivsDuration*5;
    rlsgDivsDuration=rlsgDivsDuration*5;
    %rlstDivsDuration=rlstDivsDuration(~isempty(rlstDivsDuration));
    %rlsgDivsDuration=rlstDivsDuration(~isempty(rlstDivsDuration));

    h2=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
    scatter(rlsgDivsDuration,rlstDivsDuration,50,'filled','MarkerFaceColor',[125/255, 125/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on;
    box on
%     hist3([rlsgDivsDuration',rlstDivsDuration'],'CDataMode','auto','Nbins',[50,50])
%     view(2)
%     colorbar

    %scatter_kde(rlsgDivsDuration',rlstDivsDuration');

    plot(0:max(max(rlsgDivsDuration),max(rlstDivsDuration)),0:max(max(rlsgDivsDuration),max(rlstDivsDuration)),'k','LineStyle','--','LineWidth',2);
    r=corrcoef(rlsgDivsDuration,rlstDivsDuration);
    
    xlim([20 max(max(rlsgDivsDuration),max(rlstDivsDuration))]);
    ylim([20 max(max(rlsgDivsDuration),max(rlstDivsDuration))]);
    xl=xlim; yl=ylim;
    axis square;
    xlabel('Groundtruth division time (minutes)');
    ylabel('Computed division time (minutes)');
    
    text(1.2*xl(1),0.75*yl(2),[comment 'R^2=' num2str(r(1,2)) newline 'N=' num2str(numel(rlsgDivsDuration))],'FontSize',16,'FontWeight','bold');
    a.LineStyle='none';
    set(gca,'xscale','log','yscale','log')
    ticklog=[[20 :20:100],[200:100:500]];
    set(gca,'FontSize',16, 'FontName','Myriad Pro','LineWidth',3,'FontWeight','bold',...
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
    
    set(ax,'FontSize',8, 'LineWidth',1,'FontWeight','bold',...
         'XTick',ticklog,...
         'YTick',ticklog,'TickLength',[0.02 0.02]);
    ax.Children(2).LineWidth=1; %diagonale size
    ax.Children(3).SizeData=12; %dot size
    ax.Children(1).FontSize=8; %R² size
    
    exportgraphics(h2,'h2.pdf','BackgroundColor','none','ContentType','vector')
end
%% ======plot ecdf for lifespan======

[yt,xt]=ecdf(rlstNdivs);
[yg,xg]=ecdf(rlsgNdivs);


h3=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
stairs([0 ; xg],[1 ; 1-yg],'Color','k','LineWidth',3);hold on,
stairs([0 ; xt],[1 ; 1-yt],'Color',[20/255,200/255,50/255],'LineWidth',3); 

legend({['GT; median=' num2str(median(rlsgNdivs)) ' (N=' num2str(length(rlsgNdivs)) ')'],['Computed; median=' num2str(median(rlstNdivs)) ' (N=' num2str(length(rlstNdivs)) ')']});
axis square;
xlabel('Divisions');
ylabel('Survival');
p=ranksum(rlstNdivs,rlsgNdivs);
title([comment 'Replicative lifespan; p=' num2str(p)]);
set(gca,'FontSize',16, 'FontName','Myriad Pro','LineWidth',3,'FontWeight','bold','XTick',[0:10:max(max(rlstNdivs),max(rlsgNdivs))],'TickLength',[0.02 0.02]);
xlim([0 max(max(rlstNdivs),max(rlsgNdivs))])
ylim([0 1.05]);


if figExport==1
    ax=gca;
    
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])
    
    ax.Children(1).LineWidth=1;
    ax.Children(2).LineWidth=1;
    set(ax,'FontSize',8,'LineWidth',1,'FontWeight','bold','XTick',[0:10:max(max(rlstNdivs),max(rlsgNdivs))],'TickLength',[0.02 0.02]);
    
    exportgraphics(h3,'h3.pdf','BackgroundColor','none','ContentType','vector')
end
%% =====plot overall distribution of division times ======
rlsgNdivs=[rls.groundtruth]==1;
rlstNdivs=[rls.groundtruth]==0;

divg=[rls(rlsgNdivs).divDuration]*5;
divt=[rls(rlstNdivs).divDuration]*5;

bins=[0:5:200, 1000];


h4=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);

histogram(divg,bins,'DisplayStyle','stairs','LineWidth',3,'EdgeColor','k','EdgeAlpha',0.75);
hold on
histogram(divt,bins,'DisplayStyle','stairs','LineWidth',3,'EdgeColor',[20/255,200/255,50/255],'EdgeAlpha',0.75);
% stairs(xg,ng,'Color','k','LineWidth',3);hold on;
% p=patch(xt,nt,'Color',[20/255,200/255,50/255],'LineWidth',3); 
%p.Color(4) = 0.25;
% alpha(p,0.5)

p=ranksum(divg,divt);
legend({['GT; median=' num2str(median(divg)) ' (N=' num2str(length(divg)) ')'],['Computed; median=' num2str(median(divt)) ' (N=' num2str(length(divt)) ')']});

title([comment 'Division times; p=' num2str(p)]);
set(gca,'FontSize',16, 'FontName','Myriad Pro','LineWidth',3,'FontWeight','bold','XTick',[0:25:200],'TickLength',[0.02 0.02]);
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
    
    set(ax,'FontSize',8,'LineWidth',1,'FontWeight','bold','XTick',[0:50:200],'TickLength',[0.02 0.02]); %put thiner axes and line
    ax.Children(1).LineWidth=1;
    ax.Children(2).LineWidth=1;
    
    exportgraphics(h4,'h4.pdf','BackgroundColor','none','ContentType','vector')
end

%% plot volume correlation
if isfield(rls,'noFalseDiv')
    for i=1:2:numel(rls)-1
        if numel(rls(i).divDurationNoFalseDiv)==numel(rls(i+1).divDurationNoFalseDiv)
            rlstDivsDuration=[rlstDivsDuration, rls(i).divDurationNoFalseDiv];
            rlsgDivsDuration=[rlsgDivsDuration, rls(i+1).divDurationNoFalseDiv];
        end
    end
    rlstDivsDuration=rlstDivsDuration*5;
    rlsgDivsDuration=rlsgDivsDuration*5;
    %rlstDivsDuration=rlstDivsDuration(~isempty(rlstDivsDuration));
    %rlsgDivsDuration=rlstDivsDuration(~isempty(rlstDivsDuration));

    h2=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
    scatter(rlsgDivsDuration,rlstDivsDuration,50,'filled','MarkerFaceColor',[125/255, 125/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on;
    box on
%     hist3([rlsgDivsDuration',rlstDivsDuration'],'CDataMode','auto','Nbins',[50,50])
%     view(2)
%     colorbar

    %scatter_kde(rlsgDivsDuration',rlstDivsDuration');

    plot(0:max(max(rlsgDivsDuration),max(rlstDivsDuration)),0:max(max(rlsgDivsDuration),max(rlstDivsDuration)),'k','LineStyle','--','LineWidth',2);
    r=corrcoef(rlsgDivsDuration,rlstDivsDuration);
    
    xlim([20 max(max(rlsgDivsDuration),max(rlstDivsDuration))]);
    ylim([20 max(max(rlsgDivsDuration),max(rlstDivsDuration))]);
    xl=xlim; yl=ylim;
    axis square;
    xlabel('Groundtruth division time (minutes)');
    ylabel('Computed division time (minutes)');
    
    text(1.2*xl(1),0.75*yl(2),[comment 'R^2=' num2str(r(1,2)) newline 'N=' num2str(numel(rlsgDivsDuration))],'FontSize',16,'FontWeight','bold');
    a.LineStyle='none';
    set(gca,'xscale','log','yscale','log')
    ticklog=[[20 :20:100],[200:100:500]];
    set(gca,'FontSize',16, 'FontName','Myriad Pro','LineWidth',3,'FontWeight','bold',...
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
    
    set(ax,'FontSize',8, 'LineWidth',1,'FontWeight','bold',...
         'XTick',ticklog,...
         'YTick',ticklog,'TickLength',[0.02 0.02]);
    ax.Children(2).LineWidth=1; %diagonale size
    ax.Children(3).SizeData=12; %dot size
    ax.Children(1).FontSize=8; %R² size
    
    exportgraphics(h2,'h2.pdf','BackgroundColor','none','ContentType','vector')
end

%% plot fluo correlation
if isfield(rls,'noFalseDiv')
    for i=1:2:numel(rls)-1
        if numel(rls(i).divDurationNoFalseDiv)==numel(rls(i+1).divDurationNoFalseDiv)
            rlstDivsDuration=[rlstDivsDuration, rls(i).divDurationNoFalseDiv];
            rlsgDivsDuration=[rlsgDivsDuration, rls(i+1).divDurationNoFalseDiv];
        end
    end
    rlstDivsDuration=rlstDivsDuration*5;
    rlsgDivsDuration=rlsgDivsDuration*5;
    %rlstDivsDuration=rlstDivsDuration(~isempty(rlstDivsDuration));
    %rlsgDivsDuration=rlstDivsDuration(~isempty(rlstDivsDuration));

    h2=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
    scatter(rlsgDivsDuration,rlstDivsDuration,50,'filled','MarkerFaceColor',[125/255, 125/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on;
    box on
%     hist3([rlsgDivsDuration',rlstDivsDuration'],'CDataMode','auto','Nbins',[50,50])
%     view(2)
%     colorbar

    %scatter_kde(rlsgDivsDuration',rlstDivsDuration');

    plot(0:max(max(rlsgDivsDuration),max(rlstDivsDuration)),0:max(max(rlsgDivsDuration),max(rlstDivsDuration)),'k','LineStyle','--','LineWidth',2);
    r=corrcoef(rlsgDivsDuration,rlstDivsDuration);
    
    xlim([20 max(max(rlsgDivsDuration),max(rlstDivsDuration))]);
    ylim([20 max(max(rlsgDivsDuration),max(rlstDivsDuration))]);
    xl=xlim; yl=ylim;
    axis square;
    xlabel('Groundtruth division time (minutes)');
    ylabel('Computed division time (minutes)');
    
    text(1.2*xl(1),0.75*yl(2),[comment 'R^2=' num2str(r(1,2)) newline 'N=' num2str(numel(rlsgDivsDuration))],'FontSize',16,'FontWeight','bold');
    a.LineStyle='none';
    set(gca,'xscale','log','yscale','log')
    ticklog=[[20 :20:100],[200:100:500]];
    set(gca,'FontSize',16, 'FontName','Myriad Pro','LineWidth',3,'FontWeight','bold',...
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
    
    set(ax,'FontSize',8, 'LineWidth',1,'FontWeight','bold',...
         'XTick',ticklog,...
         'YTick',ticklog,'TickLength',[0.02 0.02]);
    ax.Children(2).LineWidth=1; %diagonale size
    ax.Children(3).SizeData=12; %dot size
    ax.Children(1).FontSize=8; %R² size
    
    exportgraphics(h2,'h2.pdf','BackgroundColor','none','ContentType','vector')
end