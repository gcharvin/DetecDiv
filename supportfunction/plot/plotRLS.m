function hrls=plotRLS(classif,roiobj,varargin)

% plot RLS data for one or several curves

% input : rls :  array of struct that contains all division times for all cells
% divDur.value contains division times, divDur.sep contains the position of the
% SEP; fuo values can be provided in addition to division times

% param: parameters provided as a single object

% findSEP : find SEP to identify the position of the SEP
% align : whether data should be aligned according to SEP or not
% display style : color map : name or custom colormap : limits for
% colormap, color separation , linewidth spacing etc
% time : generation or physical time
figExport=1;

maxBirth=100; %max frame to be born. After, discard rls.

%===param===
param.showgroundtruth=1; % display the groundtruth data

param.sort=1; % 1 if sorting of trajectories according to generations
param.timefactor=5; %put =1 to put the time in frames

param.colorbar=0 ; % or 1 if colorbar to be printed
param.colorbarlegend='';

param.findSEP=0; % 1: use find sep to find SEP
param.align=0; % 1 : align with respect to SEP
param.time=1; %0 : generations; 1 : physical time
param.plotfluo=0 ; %1 if fluo to be plotted instead of divisions
param.gradientWidth=0;
if param.time==1 %sepwidth=separation between rectangles
    param.sepwidth=10; %unit is dataunit (?), so here in frame
else
    param.sepwidth=0.1; %here in generations
end

classifstrid=classif.strid;
rls=[];
for r=1:numel(roiobj)
    if isfield(roiobj(r).results,'RLS') 
        if isfield(roiobj(r).results.RLS,(classifstrid))
            rls=[rls; roiobj(r).results.RLS.(classifstrid)];
        else
            warning(['The roi ' roiobj(r) 'has no RLS result relative to ' (classifstrid) ', -->ROI skipped'])
        end
    else
        warning(['The roi ' roiobj(r) 'has no RLS result, -->ROI skipped'])
    end
end
%% Plot RLS
rlst=rls([rls.groundtruth]==0);

    rlst=rlst( ([rlst.frameBirth]<=maxBirth) & (~isnan([rlst.frameBirth])) );

    rlstNdivs=[rlst.ndiv];
    [yt,xt]=ecdf(rlstNdivs);
    
    rlsFig=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
    stairs([0 ; xt],[1 ; 1-yt],'Color',[20/255,200/255,50/255],'LineWidth',3);
    
    legend({['Computed; median=' num2str(median(rlstNdivs)) ' (N=' num2str(length(rlstNdivs)) ')']});
    axis square;
    xlabel('Divisions');
    ylabel('Survival');
    p=0;%ranksum(rlstNdivs,rlsgNdivs);
    title(['Replicative lifespan; p=' num2str(0)]);
    set(gca,'FontSize',16, 'FontName','Myriad Pro','LineWidth',3,'FontWeight','bold','XTick',[0:10:max(max(rlstNdivs))],'TickLength',[0.02 0.02]);
    xlim([0 max(max(rlstNdivs))])
    ylim([0 1.05]);
    
    
%     if figExport==1
%         ax=gca;
%         
%         xf_width=sz; yf_width=sz;
%         set(gcf, 'PaperType','a4','PaperUnits','centimeters');
%         %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
%         set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])
%         
%         ax.Children(1).LineWidth=1;
%         ax.Children(2).LineWidth=1;
%         set(ax,'FontSize',8,'LineWidth',1,'FontWeight','bold','XTick',[0:10:max(max(rlstNdivs),max(rlsgNdivs))],'TickLength',[0.02 0.02]);
%         
%         exportgraphics(h3,'h3.pdf','BackgroundColor','none','ContentType','vector')
%     end









