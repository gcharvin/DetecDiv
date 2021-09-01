function []=plotValidationVolume(classi,varargin)
figExport=0;

rois=201:210;
titre='tverski 0.4 0.6, thresh=0.5, imadjust';

for i=1:numel(varargin)
    %Rois
    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    end
    
    %title
    if strcmp(varargin{i},'Title')
        titre=varargin{i+1};
    end
end

classistrid=classi.strid;
classistridRes=['results_' classistrid];

GT=[];
RES=[];
for i=rois
    GT=[GT classi.roi(i).results.signal.cell.(classistrid).volume];
    RES=[RES classi.roi(i).results.signal.cell.(classistridRes).volume];
end
RES=RES(~isnan(GT));
GT=GT(~isnan(GT));


figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
scatter(GT,RES,50,'filled','MarkerFaceColor',[125/255, 125/255, 125/255],'MarkerEdgeColor','k','LineWidth',0.1); hold on;

M=max(max(GT(:)),max(RES(:)));
xlim([0 M]);
ylim([0 M]);
xl=xlim; yl=ylim;

plot(0:M,0:M,'k','LineStyle','--','LineWidth',2);
box on
r=corrcoef(GT,RES);


title(titre);
axis square;
xlabel('Groundtruth surface (pix.)');
ylabel('Computed surface (pix.)');
text(2+xl(1),0.9*yl(2),['R^2=' num2str(r(1,2)) newline 'N=' num2str(sum(~isnan(GT)))],'FontSize',16,'FontWeight','bold');

set(gca,'FontSize',16, 'FontName','Myriad Pro', 'LineWidth',3,'FontWeight','bold', 'TickLength',[0.02 0.02]);

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
    
    exportgraphics(h1,'correl_volume.pdf','BackgroundColor','none','ContentType','vector')
end