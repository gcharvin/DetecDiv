function [gt pred]=plotValidationSEP(sep)

figExport=1;
% plots the correlation coefficient between gt and predicted value

gt=[];
pred=[];

divclassi=sep.processing.classification(2);

for i=201:250 %1:numel(sep.processing.classification(2).roi)
    
    roiobj=sep.processing.classification(2).roi(i);
    
    div=divclassi.roi(i).results.myclassi_2.RLS.framediv-divclassi.roi(i).results.myclassi_2.RLS.frameBirth +1;
    
    if isfield(roiobj.results,'SEPdetection_2')
        if isfield(roiobj.results.SEPdetection_2,'id')
            if numel(roiobj.results.SEPdetection_2.id)
                
                pix1=find(roiobj.train.SEPdetection_2.id==2,1,'first');
                pix2=find(roiobj.results.SEPdetection_2.id==2,1,'first');
                
                if numel(pix1)==0 %nosep cells
                    div1=0;
                    %disp(i)
                else
                    div1=find(div>=pix1,1,'first');
                end
                if numel(pix2)==0 %nosep cells
                    div2=0;
                else
                    div2=find(div>=pix2,1,'first');
                end
                
                gt=[gt div1];
                pred=[pred div2];
                
                % gt=[gt pix1];
                %  pred=[pred pix2];
            end
        end
    end
end
pred=pred(gt>0);
gt=gt(gt>0);

%% PLOT
data=[];
data.pred=pred;
data.gt=gt;

corsep=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
mz=12;
fz=8;
lw=1;
sz=4;

scatter_kde(data.pred',data.gt','filled','MarkerEdgeColor','k', 'LineWidth',0.1,'MarkerSize',mz); hold on

M=max(max(data.pred),max(data.gt));
plot([0:M],[0:M],'LineStyle','--','LineWidth',1,'Color','k');
xlim([0 M]);
ylim([0 M]);

set(gcf,'Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35])
    
%DataDensityPlot(data.gt',data.pred',32,M,M);
grey=customcolormap([0 0.5 1], {'#5a5a5a','#949494','#d8d8d8'});
colormap(grey)
colorbar

xl=xlim; yl=ylim;

box on
axis square;
r=corrcoef(data.gt,data.pred);

text(2+xl(1),0.9*yl(2),['R^2=' num2str(r(1,2)) newline 'N=' num2str(sum(~isnan(data.gt)))],'FontSize',fz,'FontWeight','bold');
xlabel('Predicted SEP (divisions)');
ylabel('Groundtruth SEP (divisions)');

set(gca,'FontSize',fz, 'FontName','Myriad Pro', 'LineWidth',lw,'FontWeight','bold', 'TickLength',[0.02 0.02],...
    'XTick',[0:5:M],'YTick',[0:5:M]);

if figExport==1
    f=gcf;
    f.Renderer="painters";
    ax=gca;
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
    set(ax,'Units','centimeters', 'Position', [2 2 xf_width yf_width])
    
    exportgraphics(corsep,'','BackgroundColor','none','ContentType','vector')
end
