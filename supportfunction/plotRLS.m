function hrls=plotRLS(rls,varargin)

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

param=[];
comment='';
for i=1:numel(varargin)  
    if strcmp(varargin{i},'Comment')
        comment=varargin{i+1};
    end
    
    if strcmp(varargin{i},'Param')
        param=varargin{i+1};
    end
end

%===param===
param.showgroundtruth=1; % display the groundtruth data
param.plotRLS=1; %make an independant ploit where RLS of the result is plotted
param.plotTrajs=0;

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

param.edgewidth=2;
if figExport==1
    param.edgewidth=0.5;
end
param.sepcolor=[1 0 0];
param.edgeColorR=[0/255,0/255,0/255]; %edge color of Results. Should be a matrix of size 3xsizerec2
param.edgeColorG=[0/255,0/255,0/255];

param.cellwidth=0.05;
param.spacing=param.cellwidth+0.025; % separation between traces
if param.showgroundtruth==1 && param.sort==1
    param.interspacing=0.05; %separation between doublets
else
    param.interspacing=0;
end

param.minmax=[2 30]; % min and max values for colordisplay;
param.startY=0.1+param.cellwidth/2; % origin of Y axis for plot
param.startX=0;
param.figure=[];
param.figure.Position=[0.1 0 0.5 0.5];
param.xlim=[];
param.ylim=[];

if param.colorbar==1
    l=linspace(0.15,0.85,256);
    cmap2=zeros(256,3);
    cmap2(:,2)=1*(fliplr(l))';
    cmap2(:,1)=0*(fliplr(l))';
    cmap2(:,3)=0*(fliplr(l))';

    cmapg=zeros(256,3);
    cmapg(:,2)=(fliplr(l))';
    cmapg(:,1)=(fliplr(l))';
    cmapg(:,3)=(fliplr(l))';

else %no colored data, just filled rectangles with unique color
    %param.fillColorR=[20/255,200/255,50/255];
    param.fillColorR=[251/255,176/255,59/255];
    param.fillColorG=[175/255,175/255,175/255];
    cmap2=repmat(param.fillColorR,256,1); %for unicolored rectangles
    cmapg=repmat(param.fillColorG,256,1); %for unicolored rectangles
end
param.colormap=cmap2; % should be a colormap with 256 x 3 elements
param.colormapg=cmapg;% colormap for groundtruth data  
%===end param===   
  
  
%% plot trajs

if param.plotTrajs==1
    %if numel(handle)==0
    hrls=figure('Color','w','Units', 'Normalized', 'Position', param.figure.Position);

    title(comment)
    %else

    %axes(handle);
    %hrls=gcf;
    %end

    hold on;

    startY=param.startY;
    startX=param.startX;

    maxe=0;

    ix=1:numel(rls);

    %========================SORT========================
    % sorting traj according to RLS, grouping by pair
    if param.sort==1
        if param.time==1
            gt=[rls.groundtruth];
            dead=[];
            cc=1;
            for j=1:numel(rls)
                if rls(j).groundtruth==1
                    dead(cc)=rls(j).totaltime(end);
                    cc=cc+1;
                end
            end
            [p, ix]= sort(dead,'Descend');
            ix=ix*2;
            % ix,numel(rls)
            for i=1:length(ix)
                rlstmp(2*i-1)=rls(ix(i)-1);
                rlstmp(2*i)=rls(ix(i));
            end
            rls=rlstmp;
        else
            gt=[rls.groundtruth];
            [p, ix]= sort([rls(gt==1).ndiv],'Descend');
            ix=ix*2;      

            for i=1:length(ix)
                rlstmp(2*i-1)=rls(ix(i)-1);
                rlstmp(2*i)=rls(ix(i));
            end
            rls=rlstmp;
        end
    end

    leg={};

    med=median([rls.ndiv]);

    %============PREPARE LINES========
    cc=1;
    inc=1;
    incG=1;
    for i=1:numel(rls)
        fprintf('.')

        %aa=rls(i).ndiv
        sep=rls(i).sep;
        fluo=rls(i).fluo;
        divDur=rls(i).divDuration;
        %leg{i}=regexprep(rls(i).trap,'_','-');
        %leg{i}=rls(i).trapfov;
        leg{i}=sprintf('#%i |',incG); %show number of the doublet
        %===========TIME=0=============
        if param.time==0
            rec2=0:1:1*length(divDur);
            rec2=rec2';
            rec2(:,2)=rec2(:,1)+1;
            %rec2(end,2)=rec2(end,1)+0;
            maxe=max(maxe,numel(rls(i).framediv));
        end

        %===========TIME=1=============
        if param.time==1
            fdiv=rls(i).framediv*param.timefactor;
            fBirth=rls(i).frameBirth*param.timefactor;
            fEnd=rls(i).frameEnd*param.timefactor;

            rec2=[0 fdiv(1:end)-fBirth];
            %rec2=[0 fdiv(1:end-1)];
            rec2=rec2';
            rec2(:,2)=[fdiv(1:end)-fBirth, fEnd-fBirth]';
            %rec2(:,2)=[fdiv(1:end)]';
            %rec2(end,2)=rec2(end,1)+0;
            maxe=max(maxe,max(fdiv));
        end



        %===========ColorIndex=============
        if param.plotfluo==1
            cindex2=uint8(max(1,256*(fluo-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
        else
            cindex2=uint8(max(1,256*(fdiv-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
        end

        cindex2(end+1)=1;
        cindex2=min(256,cindex2);

        %% ===========PLOT=============
        %size(rec), size(rec2)
        %figure(hfluo);
        %Traj(rec,'Color',cmap,'colorindex',cindex,'width',cellwidth,'startX',startX,'startY',startY,'sepwidth',sepwidth,'sepColor',[0. 0. 0.],'edgeWidth',1,'gradientwidth',0);

        %figure(hdiv);


        if rls(i).groundtruth==0
            if param.sort==1
                ti(inc)=startY+param.spacing/2;
            else
                ti(inc)=1;%to code
            end
            Traj(rec2,'Color',param.colormap,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',param.edgewidth,...
                'edgeColor',param.edgeColorR,...
                'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).trapfov)]);
            startY=param.spacing+startY;       
            inc=inc+1;
        end

        if param.showgroundtruth==1 && rls(i).groundtruth==1
            ti(inc)=startY;     
            Traj(rec2,'Color',param.colormapg,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',param.edgewidth,...
                'edgeColor',param.edgeColorG,...
                'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).trapfov)]);
            startY=param.spacing+startY +param.interspacing;

            inc=inc+1;
            incG=incG+1;
        end

        if mod(cc,50)==0
            fprintf('\n')
        end
        cc=cc+1;
    end
    %end

    % figure(hfluo);
    % line([0 0],[0 spacing*length(results)+cellwidth],'Color','k','LineWidth',4);

    %set(gca,'FontSize',20,'Ytick','','YTickLabel',{});
    % colormap(cmap)
    % colorbar
    % %xlim([-30 10]);
    % ylim([0 spacing*length(results)+1]);
    %
    % xlabel('Generations');

    %figure(hdiv);
    %line([0 0],[0 spacing*length(results)+cellwidth],'Color','k','LineWidth',4);


    if numel(rls)>1
        text(30,50, ['Median RLS= ' num2str(med) ' (n=' num2str(numel(rls)) ')'],'FontSize',25);
    end

    %PLOT LABEL
    set(gca,'FontSize',25,'FontWeight','bold','YTick',ti(1:2:length(ti)),'YTickLabel',leg(1:2:length(leg)),'LineWidth',3);
    box on
    if param.time==0
        xlabel('Generations');
    else
        if param.timefactor~=1
            xlabel('Time (minutes)');
        else
            xlabel('Time (frames)');
        end
    end


    %COLOR BAR
    if param.colorbar==1
        colormap(param.colormap)
        h=colorbar;
        ylabel(h,param.colorbarlegend)
        xlim([0 1*maxe])

        h.Ticks=[0 1];
        h.TickLabels={num2str(param.minmax(1)) num2str(param.minmax(2))};
        set(h,'FontSize',25);
        ylabel(h,'Division time (frames)');
        %h.Position=[1 1 0.3 0.3]
    end

    xlim([0 maxe+0.2*maxe]);
    ylim([0 (param.spacing*numel(rls) +param.interspacing*numel(rls)/2)+param.startY]);

    set(gca,'FontSize',16, 'FontName','Myriad Pro', 'LineWidth',3,'FontWeight','bold','TickLength',[0.02 0.02]);
    htraj=gcf;
    if figExport==1
        ax=gca;
        sz=10;
        xf_width=sz; yf_width=3;
        set(gcf, 'PaperType','a4','PaperUnits','centimeters');
        %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
        set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])

        set(ax,'FontSize',8, 'LineWidth',1,'FontWeight','bold','TickLength',[0.02 0.02]);
        htraj.Renderer='painters';
        exportgraphics(htraj,'\\space2.igbmc.u-strasbg.fr\charvin\Theo\Projects\RAMM\Figures\Fig1\RLS/htraj.pdf','BackgroundColor','none','ContentType','vector')
    end
end



%% Plot just RLS
if param.plotRLS==1
    rlst=[rls.groundtruth]==0;
    rlstNdivs=[rls(rlst).ndiv];
    
    [yt,xt]=ecdf(rlstNdivs);
    
    rlsFig=figure('Color','w','Units', 'Normalized', 'Position',[0.1 0.1 0.35 0.35]);
    stairs([0 ; xt],[1 ; 1-yt],'Color',[20/255,200/255,50/255],'LineWidth',3);
    
    legend({['Computed; median=' num2str(median(rlstNdivs)) ' (N=' num2str(length(rlstNdivs)) ')']});
    axis square;
    xlabel('Divisions');
    ylabel('Survival');
    p=0;%ranksum(rlstNdivs,rlsgNdivs);
    title([comment 'Replicative lifespan; p=' num2str(p)]);
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
end








