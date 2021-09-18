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
bootStrapping=1;
sz=5;
Nboot=100;
plotHazardRate=1;
maxBirth=100; %max frame to be born. After, discard rls.
load=0;
%TODO: change column and rowof roiobjcell
szc=size(roiobjcell,1);
comment=cell(szc,1);

rls=cell(szc,1);

for i=1:numel(varargin)
    if strcmp(varargin{i},'Comment')
        comment=varargin{i+1};
    end
    if strcmp(varargin{i},'Exportfig')
        figExport=1;
    end
    
    if strcmp(varargin{i},'Load') %load data
        load=1;
    end
end

%% load if required
if load==1
    for c=1:szc
        for r=1:numel(roiobjcell{c,1})
            % load data if required
            roiobjcell{c,1}(r).load('results');
        end
    end
end
%%
%find classistrid
if isfield(roiobjcell{1,1}(1).results)
    liststrid=fields(roiobjcell{1,1}(1).results);
    str=[];
else
    error(['The roi ' roiobjcell{1,1}(1) 'has no classifstrid, be sure to measure it with measureRLS3'])
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
        if isfield(roiobjcell{c,1}(r).results,(classifstrid))
            if isfield(roiobjcell{c,1}(r).results.(classifstrid),'RLS')
                rls{c,1}=[rls{c,1}; roiobjcell{c,1}(r).results.(classifstrid).RLS];
            else
                warning(['The roi ' roiobjcell{c,1}(r) 'has no RLS result relative to ' (classifstrid) ', -->ROI skipped'])
            end
        else
            warning(['The roi ' roiobjcell{c,1}(r) 'has no classif' classifstrid ', -->ROI skipped'])
        end
    end
    
    % selection of RLS
    rlst{c,1}=rls{c,1}([rls{c,1}.groundtruth]==0);
    rlst{c,1}=rlst{c,1}([rlst{c,1}.ndiv]>1);
    rlst{c,1}=rlst{c,1}( ([rlst{c,1}.frameBirth]<=maxBirth) & (~isnan([rlst{c,1}.frameBirth])) );
    rlst{c,1}=rlst{c,1}( ~(strcmp({rlst{c,1}.endType},'Arrest') & [rlst{c,1}.frameEnd]<400)  ); %remove weird cells before frame 300 (stop growing)
    rlst{c,1}=rlst{c,1}( ~(strcmp({rlst{c,1}.endType},'Emptied') & [rlst{c,1}.frameEnd]<400)  ); %remove emptied roi before frame 300
    rlstNdivs{c,1}=[rlst{c,1}.ndiv];
    %
end

%% plot
lw=1;
fz=16;
if figExport==1
    lw=0.5;
    fz=8;
end


%set(gcf,'Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.45 0.45]);
rlsFig=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.45 0.45]);
ax=gca;
colorder=ax.ColorOrder;
leg='';
hold on

lcc=1;
for c=1:szc
    col=colorder(c,:);
    [yt,xt,flo,fup]=ecdf(rlstNdivs{c,1});
    
    plot(xt,1-yt,'LineWidth',lw,'color',col)
%     ax.Children(1).LineWidth=lw;
%     col=ax.Children(1).Color;
    fup(1)=0;
    fup(end)=1;
    flo(1)=0;
    flo(end)=1;
    closedxt = [xt', fliplr(xt')];
    inBetween = [1-fup', fliplr(1-flo')];
    ptch=patch(closedxt, inBetween,col);
    ptch.EdgeColor=col;
    ptch.FaceAlpha=0.15;
    ptch.EdgeAlpha=0.3;
    ptch.LineWidth=lw;
    
    leg{lcc,1}=[comment{c}, ': Median=' num2str(median(rlstNdivs{c,1})) ' (N=' num2str(length(rlstNdivs{c,1})) ')'];
    leg{lcc+1,1}='';
%     leg{lcc+2,1}='';
    lcc=lcc+2;
    
    if plotHazardRate==1
        %BOOTSTRAPPING
        if bootStrapping==1
            bin=2;
            rlst=rlstNdivs{c,1};
            [y ~]=ecdf(rlst);
            
            %cuttof numcell remaining
            cuty=12;
            RemainingCells=size(rlst,2)-y*size(rlst,2);
            cutx=find(RemainingCells<cuty,1,'first');
            %
            dlog=[];
            dt=[];
            deathRate=[];
            binnedDeathRate=[];
            meanDR=[];
            stdDR=[];
            meanBDR=[];
            stdBDR=[];
            semBDR=[];
            semDR=[];
            rlsb=[];
            
            [rlsb] = bootstrp(Nboot,@(x)x,rlst);
            rlsb=[rlst; rlsb ];
            Mx=max(rlstNdivs{c,1}(:));
            mx=min(rlstNdivs{c,1}(:));
            %need to have a stepsize of 1
            Yb=[NaN(Nboot+1,Mx)];
            Xb=[1:Mx];
            
            for b=1:Nboot+1
                [yb, xb]=ecdf(rlsb(b,:));
                %if cutx

                for i=1:numel(yb)
                    Yb(b,xb(i))=yb(i);
                end
                
                %fill NaN with neighbour value
                for i=2:Mx
                    if isnan(Yb(b,i))
                        Yb(b,i)=Yb(b,i-1);
                    end
                end       
                
                %cutx
                Yb(b,cutx:end)=NaN;
                Xb(cutx:end)=NaN;
                
                dlog(b,:)=diff(log(1-Yb(b,:)));
                dlog(dlog==Inf)=NaN;
                dt(b,:)=diff(Xb);
                deathRate(b,:)=-dlog(b,:)./dt(b,:);
                %                 deathRate(b,:)=diff(Yb(b,:))./(1-Yb(b,2:end));
                deathRate(deathRate==Inf)=NaN;
                
                %binning
                cb=1;
                for i=1:2:size(deathRate,2)-1
                    binnedDeathRate(b,cb)=nanmean([deathRate(b,i),deathRate(b,i+1)]);
                    cb=cb+1;
                end
            end
            
            meanDR=nanmean(deathRate,1);
            stdDR=nanstd(deathRate,1);
            semDR=stdDR./sqrt(Nboot+1); %N= number of bootstrappings
            meanBDR=nanmean(binnedDeathRate,1);
            stdBDR=nanstd(binnedDeathRate,1);
            semBDR=stdBDR/sqrt(Nboot+1); %N= number of bootstrappings

            
            %             lineProps.width=lw;
            %             lineProps.col{:}=col;
            %             %mseb(Xb(2:end),meanDR,stdDR,lineProps);
            %             mseb(Xb(2:2:end-1),meanBDR,stdBDR,lineProps);
            
            %remove nans for polygon
            Xb=Xb(~isnan(Xb));
            stdBDR=stdBDR(~isnan(stdBDR));
            semBDR=semBDR(~isnan(semBDR));
            meanBDR=meanBDR(~isnan(meanBDR));
            %plot
            if mod(numel(Xb),2)==0 %even
                t=2:2:numel(Xb);
            else
                t=2:2:numel(Xb)-1;
            end
            plot(Xb(t),meanBDR,'LineWidth',lw,'color',col,'LineStyle','--')
            closedxb=[];
            shadedstd=[];
            closedxb = [Xb(t), fliplr(Xb(t))];
            shadedstd = [meanBDR-semBDR, fliplr(meanBDR+semBDR)];
            ptch=patch(closedxb, shadedstd,col);
            ptch.FaceAlpha=0.15;
            ptch.EdgeAlpha=0.3;
            ptch.LineStyle='--';
            ptch.LineWidth=lw;
            ptch.EdgeColor=col;
            
            leg{lcc,1}=[comment{c}, ': Hazard rate '];
            leg{lcc+1,1}='';
            lcc=lcc+2;
        else
            dlog=gradient(log(1-yt));
            dt=gradient(xt);
            deathRate=-dlog./dt;
            plot(xt,deathRate,'--','LineWidth',lw,'Color',col)
            leg{lcc,1}=[comment{c}, ': Hazard rate '];
            lcc=lcc+1;
        end
    end
end

%p-value
textPvalue='';
if szc>1
    pairs=nchoosek(1:szc,2);
    szp=size(pairs,1);
    for pp=1:szp
        [~,p(pp)]=kstest2(rlstNdivs{pairs(pp,1),1},rlstNdivs{pairs(pp,2),1});
        textPvalue=[textPvalue newline comment{pairs(pp,1)} ' vs ' comment{pairs(pp,2)} ': ' num2str(p(pp))];
    end
end

legend(leg)
text(2,0.25,[textPvalue],'FontSize',fz,'FontWeight','bold');




box on
xlabel('Divisions');
ylabel('Survival');
if plotHazardRate==1
  ylabel(['Survival' newline 'and hazard rate (div^-1)']);
end

M=max([rlstNdivs{:,1}]);
p=0;%ranksum(rlstNdivs,rlsgNdivs);
title(['Replicative lifespan']);
set(gca,'FontSize',fz, 'FontName','Myriad Pro','LineWidth',2*lw,'FontWeight','bold','XTick',[0:10:M],'TickLength',[0.02 0.02]);
xlim([0 M])
ylim([0 1.02]);


if figExport==1
    ax=gca;
    xf_width=1.8*sz; yf_width=sz;
    set(gcf, 'PaperPositionMode', 'auto', 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'InnerPosition', [5 5 xf_width yf_width]) %0.8 if .svg is used
    rlsFig.Renderer='painters';
    %saveas(rlsFig,'\\space2.igbmc.u-strasbg.fr\charvin\Theo\Projects\RAMM\Figures\Fig1\RLS\RLS_sir2_fob1.svg')
    exportgraphics(rlsFig,'\\space2.igbmc.u-strasbg.fr\charvin\Theo\Projects\RAMM\Figures\Fig1\RLS\RLS_sir2_fob1.pdf')
    %print(rlsFig,'\\space2.igbmc.u-strasbg.fr\charvin\Theo\Projects\RAMM\Figures\Fig1\RLS\RLS_sir2_fob1','-dpdf')%,'BackgroundColor','none','ContentType','vector')
    %export_fig RLS_sir2_fob1.pdf
end

