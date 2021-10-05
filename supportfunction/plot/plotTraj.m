function hrls=plotTraj(rls,varargin)

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
resultid=0;%choose what result to plot (CNN or CNN+LSTM or CNN+PP...)
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

maxBirth=1000; %max frame to be born. After, discard rls.

%===param===
param.showgroundtruth=0; % display the groundtruth data

param.sort=1; % 1 if sorting of trajectories according to generations
param.timefactor=5; %put =1 to put the time in frames

param.colorbar=1 ; % or 1 if colorbar to be printed
param.colorbarlegend='';

param.findSEP=0; % 1: use find sep to find SEP
param.align=0; % 1 : align with respect to SEP
param.time=0; %0 : generations; 1 : physical time
param.plotSignal=1 ; %1 if fluo to be plotted instead of divisions
param.gradientWidth=0;
if param.time==1 %sepwidth=separation between rectangles
    param.sepwidth=10; %unit is dataunit (?), so here in frame
else
    param.sepwidth=0.1; %here in generations
end

param.edgewidth=2;
if figExport==1
    param.edgewidth=0.1;
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

param.autoBounds=0; % computes minmax automatically
param.minmax=[70 150]; % min and max values for colordisplay;
%% rr
param.plotSignal=1 ;
param.minmax=[1 2.5];
%%
param.startY=0.1+param.cellwidth/2; % origin of Y axis for plot
param.startX=0;
param.figure=[];
param.figure.Position=[0.1 0 0.5 0.5];
param.xlim=[];
param.ylim=[];

if param.colorbar==1
    red=customcolormap([0 0.5 1], {'#ff0000','#ff7c7c','#b4b4b4'});
    green=customcolormap([0 0.75 1], {'#01df00','#6fdf6f','#e7e7e7'});
    orange=customcolormap([0 0.5 1], {'#fd7e00','#ffbd7c','#e7e7e7'});
    grey=customcolormap([0 0.5 1], {'#212121','#7f7f7f','#d8d8d8'});
     l=linspace(0.01,1,256);
%     cmap2=zeros(256,3);
%     cmap2(:,2)=0*fliplr(l)';
%     cmap2(:,1)=fliplr(l)';%(fliplr(l))';
%     cmap2(:,3)=0*fliplr(l)';
    cmap2=orange;
    
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

%% cleanup
% flag=[];
% for i=1:numel(rls)
%     if sum(isnan(rls(i).framediv))>0
%        flag=[flag, i];
%     end
% end
% rls(flag)=[];
rls([rls.ndiv]<5)=[];
%%
if param.plotSignal==1
    
% ask signal
liststrid=fields(rls(1).divSignal); %full, cell, nucleus, div
liststrid(contains(liststrid,'divDuration'))=[];

str=[];
for i=1:numel(liststrid)
    str=[str num2str(i) ' - ' liststrid{i} '; '];
end

signalid=input(['Which signal type? (Default: 1)' str]);
if numel(signalid)==0
    signalid=1;
end

signalstrid=liststrid{signalid};

% ask classistrid
    liststrid=fields(rls(1).divSignal.(signalstrid));
    str=[];
    
    for i=1:numel(liststrid)
        str=[str num2str(i) ' - ' liststrid{i} '; '];
    end
    classifid=input(['Which classi used for extracting signal? (Default: 1)' str]);
    if numel(classifid)==0
        classifid=1;
    end
    
    classifstrid=liststrid{classifid};

% ask fluo
    liststrid=fields(rls(1).divSignal.(signalstrid).(classifstrid));
    str=[];
    
    for i=1:numel(liststrid)
        str=[str num2str(i) ' - ' liststrid{i} '; '];
    end
    fluoid=input(['Which type of signal? (Default: 1)' str]);
    if numel(fluoid)==0
        fluoid=1;
    end
    
    fluostrid=liststrid{fluoid};

% ask channel
    channumber=size(rls(1).divSignal.(signalstrid).(classifstrid).(fluostrid),1);
    str=[];   
    chanid=input(['Which channel ? (Default: 1)' num2str(1:channumber)]);
    if numel(chanid)==0
        chanid=1;
    end    
end
%==

%% plot trajs
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
    if param.showgroundtruth==1
        if param.time==1
            gt=[rls.groundtruth];
            dead=[];
            cc=1;
            for j=1:numel(rls)
                if rls(j).groundtruth==1
                    dead(cc)=rls(j).frameEnd;
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
        else %generation
            gt=[rls.groundtruth];
            [p, ix]= sort([rls(gt==1).ndiv],'Descend');
            ix=ix*2;
            
            for i=1:length(ix)
                rlstmp(2*i-1)=rls(ix(i)-1);
                rlstmp(2*i)=rls(ix(i));
            end
            rls=rlstmp;
        end
    else %if no gt
        if param.time==1
            gt=[rls.groundtruth];
            dead=[];
            cc=1;
            for j=1:numel(rls)
                if rls(j).groundtruth==resultid
                    dead(cc)=rls(j).frameEnd;
                    cc=cc+1;
                end
            end
            [p, ix]= sort(dead,'Descend');
            % ix,numel(rls)
            rlssorted=rls(ix);
            rls=rlssorted;
        else
            gt=[rls.groundtruth];
            [p, ix]= sort([rls(gt==resultid).ndiv],'Descend');
            rlssorted=rls(ix);
            rls=rlssorted;
        end
    end
end

leg={};

med=median([rls.ndiv]);

%============PREPARE LINES========
cc=1;
inc=1;
incG=1;
maxsignal=NaN;
minsignal=NaN;

if param.plotSignal==1 && param.autoBounds==1
    for i=1:numel(rls)
    signal=rls(i).divSignal.(signalstrid).(classifstrid).(fluostrid)(chanid,:);

        for s=1:numel(signal)
            maxsignal=max(maxsignal,signal(s));
            minsignal=min(minsignal,signal(s));
        end
    end
end

for i=1:numel(rls)
    cindex2=[];
    fprintf('.')
    if ~(rls(i).frameBirth>maxBirth) && ~isnan(rls(i).frameBirth) && rls(i).ndiv>1
        %aa=rls(i).ndiv
        sep=rls(i).sep;
        signal=[];
        if param.plotSignal==1
            signal=rls(i).divSignal.(signalstrid).(classifstrid).(fluostrid)(chanid,:);
        end
%         if (signal(end)>1.1)
%             continue
%         end
        
        divDur=rls(i).divDuration;
        %leg{i}=regexprep(rls(i).trap,'_','-');
        %leg{i}=rls(i).roiid;
        leg{i}=sprintf('#%i |',incG); %show number of the doublet
        %===========TIME=0=============
        if param.time==0 || param.plotSignal==1
            rec2=0:1:1*length(divDur)-1;
            rec2=rec2';
            rec2(:,2)=rec2(:,1)+1;
            %rec2(end,2)=rec2(end,1)+0;
            maxe=max(maxe,numel(rls(i).framediv));
            
            fEnd=rls(i).frameEnd*param.timefactor;
            divDur=[rls(i).divDuration fEnd-rls(i).totaltime(end)];
            divDur=divDur*param.timefactor;
            if param.plotSignal==0
            cindex2=uint8(max(1,256*(divDur-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
            
            %SIGNAL
            elseif param.plotSignal==1                
                for s=1:numel(signal)
                    if param.autoBounds==1
                        cindex2(s)=uint8(max(1,256*(signal(s)-minsignal)/(maxsignal-minsignal)));
                    else
                        cindex2(s)=uint8(max(1,256*(signal(s)-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
                    end
                end
                
            end
            %===========TIME=1=============
        elseif param.time==1 && param.plotSignal==0
            ttime=rls(i).totaltime*param.timefactor;
            %fBirth=rls(i).frameBirth*param.timefactor;
            fEnd=rls(i).frameEnd*param.timefactor;
            
            rec2=[0 ttime(1:end)];
            %rec2=[0 fdiv(1:end-1)];
            rec2=rec2';
            rec2(:,2)=[ttime(1:end) fEnd]';
            %rec2(:,2)=[fdiv(1:end)]';
            %rec2(end,2)=rec2(end,1)+0;
            maxe=max(maxe,max(ttime)); 
        end
        
        
        %===========ColorIndex=============
%         if param.plotSignal==1
%             cindex2=uint8(max(1,256*(signal-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
%             
%         elseif param.colorbar==1%div duration
%             cindex2=uint8(max(1,256*(divDur-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
%             
%         else
%             cindex2=1:numel(rec2);
%         end
%         
%         cindex2=min(256,cindex2);
        
        %% ===========PLOT=============
        %size(rec), size(rec2)
        %figure(hfluo);
        %Traj(rec,'Color',cmap,'colorindex',cindex,'width',cellwidth,'startX',startX,'startY',startY,'sepwidth',sepwidth,'sepColor',[0. 0. 0.],'edgeWidth',1,'gradientwidth',0);
        
        %figure(hdiv);
        
        %result
        if rls(i).groundtruth==resultid
            if param.sort==1
                ti(inc)=startY+param.spacing/2;
            else
                ti(inc)=1;%to code
            end
            Traj(rec2,'Color',param.colormap,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',param.edgewidth,...
                'edgeColor',param.edgeColorR,...
                'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).roiid)]);
            startY=param.spacing+startY;
            inc=inc+1;
        end
        
        %GT
        if param.showgroundtruth==1 && rls(i).groundtruth==1
            ti(inc)=startY;
            Traj(rec2,'Color',param.colormapg,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',param.edgewidth,...
                'edgeColor',param.edgeColorG,...
                'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).roiid)]);
            startY=param.spacing+startY +param.interspacing;
            
            inc=inc+1;
            incG=incG+1;
        end
        
        %         if param.showgroundtruth==1 && plotMulti==1 && rls(i).groundtruth==2
        %             ti(inc)=startY;
        %             Traj(rec2,'Color',param.colormapg,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',param.edgewidth,...
        %                 'edgeColor',param.edgeColorG,...
        %                 'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).roiid)]);
        %             startY=param.spacing+startY +param.interspacing;
        %
        %             inc=inc+1;
        %             incG=incG+1;
        %         end
        %
        %         if param.showgroundtruth==1 && plotMulti==1 && rls(i).groundtruth==3
        %             ti(inc)=startY;
        %             Traj(rec2,'Color',param.colormapg,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',param.edgewidth,...
        %                 'edgeColor',param.edgeColorG,...
        %                 'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).roiid)]);
        %             startY=param.spacing+startY +param.interspacing;
        %
        %             inc=inc+1;
        %             incG=incG+1;
        %         end
        %
        %         if mod(cc,50)==0
        %             fprintf('\n')
        %         end
        %         cc=cc+1;
        %
    else
        disp(['roi(' num2str(i) ') born too late, ignored traj'])
    end
end
%%
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
    if param.autoBounds==0
        h.TickLabels={num2str(param.minmax(1)) num2str(param.minmax(2))};
    else
        h.TickLabels={num2str(minsignal) num2str(maxsignal)};
    end
    set(h,'FontSize',25);
    ylabel(h,'Division time (minutes)');
    %h.Position=[1 1 0.3 0.3]
end

xlim([0 1.2*maxe]);
ylim([0 (param.spacing*numel(rls) +param.interspacing*numel(rls)/2)+param.startY]);

set(gca,'FontSize',16, 'FontName','Myriad Pro', 'LineWidth',3,'FontWeight','bold','TickLength',[0.02 0.02]);
htraj=gcf;
if figExport==1
    ax=gca;
    sz=6;
    xf_width=sz; yf_width=3;
    xlim([0,1.01*maxe]);
    set(gcf, 'PaperType','a4','PaperUnits','centimeters');
    %set(gcf,'Units','centimeters','Position', [5 5 xf_width yf_width]);
    set(ax,'Units','centimeters', 'InnerPosition', [2 2 xf_width yf_width])
    
    set(ax,'FontSize',8, 'LineWidth',1,'FontWeight','bold','TickLength',[0.02 0.02],'TickDir','out');
    htraj.Renderer='painters';
    exportgraphics(htraj,'\\space2.igbmc.u-strasbg.fr\charvin\Theo\Projects\RAMM\Figures\Fig2\traj.pdf','BackgroundColor','none','ContentType','vector')
end








