function hrls=plotDivtimes(roiobjcell,varargin)

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
figExport=0;
maxBirth=100; %max frame to be born. After, discard rls.

szc=size(roiobjcell,1);
comment=cell(szc,1);

rls=cell(szc);

for i=1:numel(varargin)
    if strcmp(varargin{i},'Comment')
        comment=varargin{i+1};
    end
end




%find classistrid
if isfield(roiobjcell{1,1}(1).results,'RLS')
    liststrid=fields(roiobjcell{1,1}(1).results.RLS);
    str=[];
else
    error(['The roi ' roiobjcell{1,1}(1) 'has no RLS result, be sure to measure it with measureRLS3'])
end
for i=1:numel(liststrid)
    str=[str num2str(i) ' - ' liststrid{i} ';'];
end
classifid=input(['Which classi used? (Default: 1)' str]);
if numel(classifid)==0
    classifid=1;
end
classifstrid=liststrid{classifid};

%extract RLS from roiobj
for c=1:szc
    for r=1:numel(roiobjcell{c,1})
        if isfield(roiobjcell{c,1}(r).results,'RLS')
            if isfield(roiobjcell{c,1}(r).results.RLS,(classifstrid))
                rls{c,1}=[rls{c,1}; roiobjcell{c,1}(r).results.RLS.(classifstrid)];
            else
                warning(['The roi ' roiobjcell{c,1}(r) 'has no RLS result relative to ' classifstrid ', -->ROI skipped'])
            end
        else
            warning(['The roi ' roiobjcell{1,1}(r) 'has no RLS result, be sure to measure it with measureRLS3, -->ROI skipped'])
        end
    end
    
    rlst{c,1}=rls{c,1}([rls{c,1}.groundtruth]==0);
    rlst{c,1}=rlst{c,1}( ([rlst{c,1}.frameBirth]<=maxBirth) & (~isnan([rlst{c,1}.frameBirth])) );
    divt{c,1}=[rlst{c,1}.divDuration]*5;
end

%%% plot
bins=[0:5:200, 1000];

leg='';
figure;
for c=1:szc
    histogram(divt{c,1},bins,'DisplayStyle','stairs','LineWidth',3,'EdgeAlpha',0.75,'Normalization','probability');
    hold on
    leg{c,1}=[comment{c}, 'median=' num2str(median(divt{c,1})) ' (N=' num2str(length(divt{c,1})) ')'];
end

textPvalue='';
if szc>1
    pairs=nchoosek(1:szc,2);
    szp=size(pairs,1);    
    for pp=1:szp
        p(pp)=ranksum(divt{pairs(pp,1),1},divt{pairs(pp,2),1});
        textPvalue=[textPvalue newline num2str(pairs(pp,1)) 'vs' num2str(pairs(pp,2)) ': ' num2str(p(pp))];
    end
end

    
legend(leg)
xlim([0,202]);
xl=xlim; yl=ylim;
text(0.5*xl(2),0.5*yl(2),textPvalue,'FontSize',16,'FontWeight','bold');

axis square;
title('Division times');
set(gcf,'Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
set(gca,'FontSize',16, 'FontName','Myriad Pro','LineWidth',3,'FontWeight','bold','XTick',[0:25:200],'TickLength',[0.02 0.02]);

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







