function hrls=plotDivtimes(rlsfile,varargin)
%TODO: TAKE AS INPUT rls struct file generated using createRLSfile

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
timeFactor=5;
GT=0;
maxBirth=100; %max frame to be born. After, discard rls.

for i=1:numel(varargin)
%     if strcmp(varargin{i},'Comment')
%         comment=varargin{i+1};
%     end
    if strcmp(varargin{i},'GT')
        GT=1;
    end
end

if GT==1
    szc=2;
    comment={'Prediction', 'Groundtruth'};
else
    szc=max([rlsfile.condition]); %number of conditions
end

%extract RLS from roiobj
for c=1:szc
    
    if GT==0
        rls{c,1}=rlsfile([rlsfile.condition]==c);
        comment{c}=rls{c,1}(1).conditionComment;
    elseif GT==1
        rls{c,1}=rlsfile([rlsfile.groundtruth]==c-1);
    end
    
    rlst=rls;
    %selection of RLS (to put in createRLSfile() for coherence)
    rlst{c,1}=rlst{c,1}( ([rlst{c,1}.frameBirth]<=maxBirth) & (~isnan([rlst{c,1}.frameBirth])) );
    rlst{c,1}=rlst{c,1}([rlst{c,1}.ndiv]>5);
    rlst{c,1}=rlst{c,1}( ([rlst{c,1}.frameBirth]<=maxBirth));
    
    divt{c,1}=[rlst{c,1}.divDuration]*timeFactor;
    
end

%% plot
if figExport==0
    lw=3;
    fs=16;
else
    lw=1;
    fs=8;
end

bins=[0:5:200, 1000];

leg='';
h4=figure;
for c=1:szc
    histogram(divt{c,1},bins,'DisplayStyle','stairs','LineWidth',3,'EdgeAlpha',0.75,'Normalization','probability');
    hold on
    leg{c,1}=[comment{c}, ', median=' num2str(median(divt{c,1})) ' (N=' num2str(length(divt{c,1})) ')'];
    meandivtime=mean(divt{c,1}(divt{c,1}<200));
    stddivtime=std(divt{c,1}(divt{c,1}<200));
    sem=stddivtime/sqrt(sum(divt{c,1}(divt{c,1}<200)));
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
text(0.5*xl(2),0.5*yl(2),textPvalue,'FontSize',fs,'FontWeight','bold');

axis square;
title('Division times');
set(gcf,'Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
set(gca,'FontSize',fs, 'FontName','Myriad Pro','LineWidth',lw,'FontWeight','bold','XTick',[0:25:200],'TickLength',[0.02 0.02]);

xlabel('Division time (minutes)');
ylabel('# Events');

if figExport==1   
    sz=5;
    ax=gca;
    xf_width=sz; yf_width=sz;
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
%     set(gcf,'Units','centimeters','Position', [5 5 xf_width+3 yf_width+3]);
    set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])
        
    exportgraphics(h4,'divtimes.pdf','BackgroundColor','none','ContentType','vector')
end







