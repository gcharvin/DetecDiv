function hrls=plotRLS(rls,varargin)

% plot RLS data for one or several curves

% input : rls :  array of struct that contains all division times for all cells
% div.value contains division times, div.sep contains the position of the
% SEP; fuo values can be provided in addition to division times

% param: parameters provided as a single object

% findSEP : find SEP to identify the position of the SEP
% align : whether data should be aligned according to SEP or not
% display style : color map : name or custom colormap : limits for
% colormap, color separation , linewidth spacing etc
% time : generation or physical time

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
l=linspace(0.15,0.85,256);
cmap2=zeros(256,3);
cmap2(:,2)=1*(fliplr(l))';
cmap2(:,1)=0*(fliplr(l))';
cmap2(:,3)=0*(fliplr(l))';

cmapg=zeros(256,3);
cmapg(:,2)=(fliplr(l))';
cmapg(:,1)=(fliplr(l))';
cmapg(:,3)=(fliplr(l))';


param.colormap=cmap2; % should be a colormap with 256 x 3 elements
param.colormapg=cmapg;% colormap for groundtruth data

param.showgroundtruth=1; % display the groundtruth data

param.spacing=1.25; % separation between traces
param.cellwidth=1;
param.interspacing=1.5; %separation between doublets

param.colorbar=1 ; % or 1 if colorbar to be printed
param.colorbarlegend='';

param.findSEP=0; % 1: use find sep to find SEP
param.align=0; % 1 : align with respect to SEP
param.time=0; %0 : generations; 1 : physical time
param.plotfluo=0 ; %1 if fluo to be plotted instead of divisions
param.gradientWidth=0;
param.sepwidth=0.1; % separation between events
param.sepcolor=[1 0 0];


param.minmax=[2 30]; % min and max values for display;
param.startY=3; % origin of Y axis for plot
param.startX=0;
param.figure=[];
param.figure.Position=[0.1 0 0.5 0.9];
param.xlim=[];
param.ylim=[];

param.sort=1; % 1 if sorting of trajectories according to generations
%===end param===   
  
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
% sorting traj according to RLS, grouping by pair, not functional by time
% yet
if param.sort==1 
    if param.time==1
        
        dead=[];
        for j=1:numel(rls)
            dead(j)=rls(j).totaltime(end);
        end
        
        [p, ix]= sort(dead,'Descend');
        % ix,numel(rls)
        rls=rls(ix);
    else
        gt=[rls.groundtruth];
        [p, ix]= sort([rls(gt==1).ndiv],'Descend');
        ix=ix*2;      
        
        for i=1:length(ix)
            rlsm(2*i-1)=rls(ix(i)-1);
            rlsm(2*i)=rls(ix(i));
        end
        rls=rlsm;
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
    div=rls(i).divDuration;
    
    %leg{i}=regexprep(rls(i).trap,'_','-');
    %leg{i}=rls(i).trapfov;
    leg{i}=sprintf('#%i |',incG); %show number of the doublet
    %===========TIME=0=============
    if param.time==0
        rec2=0:1:1*length(div);
        rec2=rec2';
        rec2(:,2)=rec2(:,1)+1;
        rec2(end,2)=rec2(end,1)+0;
        
        maxe=max(maxe,numel(rls(i).framediv));
    end
    
    %===========TIME=1=============
    if param.time==1
        cdiv=cumsum(div);
        rec2=[0 cdiv(1:end-1)];
        rec2=rec2';

        rec2(:,2)=rec2(:,1)+[div]';
        %rec2(end,2)=rec2(end,1)+0;
 
        maxe=max(maxe,max(cdiv));
    end
    %===========FLUO=1=============
    if param.plotfluo==1
        cindex2=uint8(max(1,256*(fluo-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
    else
        cindex2=uint8(max(1,256*(div-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
    end
    
    cindex2(end+1)=1;
    cindex2=min(256,cindex2);
    
    %===========PLOT=============
    %size(rec), size(rec2)
    %figure(hfluo);
    %Traj(rec,'Color',cmap,'colorindex',cindex,'width',cellwidth,'startX',startX,'startY',startY,'sepwidth',sepwidth,'sepColor',[0. 0. 0.],'edgeWidth',1,'gradientwidth',0);
    
    %figure(hdiv);

   
    if rls(i).groundtruth==0
        ti(inc)=startY;
        
        Traj(rec2,'Color',param.colormap,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',0.2,'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).trapfov)]);
        startY=param.spacing+startY;       
        inc=inc+1;
    end
    
    if param.showgroundtruth==1 && rls(i).groundtruth==1
        ti(inc)=startY;     
        Traj(rec2,'Color',param.colormapg,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',0.2,'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).trapfov)]);
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
set(gca,'FontSize',25,'FontWeight','bold','Ytick',ti(1:2:length(ti))+1,'YTickLabel',leg(1:2:length(leg)),'LineWidth',3);


if param.time==0
    xlabel('Generations');
else
    xlabel('Time (frames)');
end

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

%xlim([-30 10]);
ylim([0 (param.spacing*numel(rls)/2 +param.interspacing*numel(rls))]);











