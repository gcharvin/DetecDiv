function []=plotValidationVolume(classi,varargin)
% colormap
% C(1,:)=[0 0 0];
% colormap=C;

load=0;
figExport=1;
sz=4;
sphereApprox=0;
rois=40:49;
titre='';

for i=1:numel(varargin)
    %Rois
    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    end
    
    %title
    if strcmp(varargin{i},'Title')
        titre=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Load') %load data
        load=1;
    end
end

classistrid=classi.strid;
classistridRes=['results_' classistrid];

%% load data if required
if load==1
    for r=rois
        classi.roi(r).load('results');
    end
end
    
%%
GT=[];
RES=[];

for i=rois
    GT=[GT classi.roi(i).results.signal.cell.(classistrid).volume(1:1:end)];
    RES=[RES classi.roi(i).results.signal.cell.(classistridRes).volume(1:1:end)];
end

%converts in um²
GT=GT*0.1056;
RES=RES*0.1056;

GT(GT==0)=NaN;
% GT(GT>120)=NaN;
% GT(RES<15)=NaN;
RES=RES(~isnan(GT));
GT=GT(~isnan(GT));

% if sphereApprox==1
%     RES=RES.^(3/2);
%     RES=RES;
% end

M=max(max(GT(:)),max(RES(:)));


figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);

%scatter(GT,RES,50,'filled','MarkerFaceColor',[125/255, 125/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on;
% hist3([GT',RES'],'CDataMode','auto','edges',{0:M 0:M},'Edgecolor','none')
% view(2)
% colorbar

% cmap=colormap(corrvol);
% cmap(1,:)=[1 1 1];
% colormap(cmap);

scatter_kde(RES',GT','filled','MarkerEdgeColor','k', 'LineWidth',0.1);
corrvol=gcf;
set(gcf,'Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35])
    
%DataDensityPlot(GT',RES',32,M,M);
colormap gray
colorbar
xlim([0 40]);
ylim([0 40]);
xl=xlim; yl=ylim;

hold on
plot(0:M,0:M,'k','LineStyle','--','LineWidth',2);
box on
r=corrcoef(GT,RES);

title(titre);
axis square;
ylabel('Groundtruth surface (µm²)');
xlabel('Predicted surface (µm²)');
text(2+xl(1),0.9*yl(2),['R^2=' num2str(r(1,2)) newline 'N=' num2str(sum(~isnan(GT)))],'FontSize',16,'FontWeight','bold');

set(gca,'FontSize',16, 'FontName','Myriad Pro', 'LineWidth',3,'FontWeight','bold', 'TickLength',[0.02 0.02],...
    'XTick',[0:10:M],'YTick',[0:10:M]);

if figExport==1
    f=gcf;
    f.Renderer="painters";
    ax=gca;
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'Position', [2 2 xf_width yf_width])
    
    set(ax,'FontSize',8, 'LineWidth',1);
    ax.Children(2).LineWidth=1; %diagonale size
    ax.Children(3).SizeData=12; %dot size
    ax.Children(1).FontSize=8; %R² size
    
    exportgraphics(corrvol,'\\space2.igbmc.u-strasbg.fr\charvin\Theo\Projects\RAMM\Figures\Fig2\correl_volume.pdf','BackgroundColor','none','ContentType','vector')
end