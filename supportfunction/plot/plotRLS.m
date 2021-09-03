function hrls=plotRLS(roiobjcell,varargin)

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
hazardRate=1;
maxBirth=100; %max frame to be born. After, discard rls.

szc=size(roiobjcell,1);
comment=cell(szc,1);

rls=cell(szc);

for i=1:numel(varargin)
    if strcmp(varargin{i},'Comment')
        comment=varargin{i+1};
    end
end

%%
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

%%
for c=1:szc
    for r=1:numel(roiobjcell{c,1})
        if isfield(roiobjcell{c,1}(r).results,'RLS')
            if isfield(roiobjcell{c,1}(r).results.RLS,(classifstrid))
                rls{c,1}=[rls{c,1}; roiobjcell{c,1}(r).results.RLS.(classifstrid)];
            else
                warning(['The roi ' roiobjcell{c,1}(r) 'has no RLS result relative to ' (classifstrid) ', -->ROI skipped'])
            end
        else
            warning(['The roi ' roiobjcell{c,1}(r) 'has no RLS result, -->ROI skipped'])
        end
    end
    
    % selection of RLS
    rlst{c,1}=rls{c,1}([rls{c,1}.groundtruth]==0);
    rlst{c,1}=rlst{c,1}( ([rlst{c,1}.frameBirth]<=maxBirth) & (~isnan([rlst{c,1}.frameBirth])) );
    rlst{c,1}=rlst{c,1}( ~(strcmp({rlst{c,1}.endType},'Arrest') & [rlst{c,1}.frameEnd]<400)  ); %remove weird cells before frame 300 (stop growing)
    rlst{c,1}=rlst{c,1}( ~(strcmp({rlst{c,1}.endType},'Emptied') & [rlst{c,1}.frameEnd]<400)  ); %remove emptied roi before frame 300
    rlstNdivs{c,1}=[rlst{c,1}.ndiv];
    %
end

%% plot
rlsFig=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
leg='';
hold on

lcc=1;
for c=1:szc
    [yt,xt]=ecdf(rlstNdivs{c,1},'Bounds','on');
    splot=stairs([0 ; xt],[1 ; 1-yt],'LineWidth',3);
    col=get(splot,'color');
    leg{lcc,1}=[comment{c}, 'median=' num2str(median(rlstNdivs{c,1})) ' (N=' num2str(length(rlstNdivs{c,1})) ')'];
    lcc=lcc+1;
    
    if hazardRate==1
        dlog=gradient(log(1-yt));
        dt=gradient(xt);
        deathRate=-dlog./dt;
        plot(xt,deathRate,':','LineWidth',3,'Color',col)
        leg{lcc,1}=[comment{c}, 'hazard rate'];
        lcc=lcc+1;
    end
end

textPvalue='';
if szc>1
    pairs=nchoosek(1:szc,2);
    szp=size(pairs,1);
    for pp=1:szp
        [~,p(pp)]=kstest2(rlstNdivs{pairs(pp,1),1},rlstNdivs{pairs(pp,2),1});
        textPvalue=[textPvalue newline num2str(pairs(pp,1)) 'vs' num2str(pairs(pp,2)) ': ' num2str(p(pp))];
    end
end

legend(leg)
text(2,0.25,[textPvalue],'FontSize',16,'FontWeight','bold');



axis square;
xlabel('Divisions');
ylabel('Survival');
M=max([rlstNdivs{:,1}]);
p=0;%ranksum(rlstNdivs,rlsgNdivs);
title(['Replicative lifespan']);
set(gca,'FontSize',16, 'FontName','Myriad Pro','LineWidth',3,'FontWeight','bold','XTick',[0:10:M],'TickLength',[0.02 0.02]);
xlim([0 M])
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









