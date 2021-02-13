function hrls=plotRLS(rls,param)

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

if nargin<2 % no parameter provided build a param variable 
    param=[];
    
 l=linspace(0.15,0.85,256);
cmap2=zeros(256,3);
cmap2(:,2)=(fliplr(l))';
cmap2(:,1)=(fliplr(l))';
cmap2(:,3)=(fliplr(l))';

cmapg=zeros(256,3);
cmapg(:,2)=0.5*(fliplr(l))';
cmapg(:,1)=0.5*(fliplr(l))';
cmapg(:,3)=(fliplr(l))';


    param.colormap=cmap2; % should be a colormap with 256 x 3 elements 
    param.colormapg=cmapg;% colormap for groundtruth data
    
    param.showgroundtruth=1; % display the groundtruth data
    
    param.colorbar=1 ; % or 1 if colorbar to be printed
    param.colorbarlegend=''; 
    
    param.findSEP=0; % 1: use find sep to find SEP
    param.align=0; % 1 : align with respect to SEP
    param.time=0; %0 : generations; 1 : physical time
    param.plotfluo=0 ; %1 if fluo to be plotted instead of divisions
    param.gradientWidth=0;
    param.cellwidth=1;
    param.sepwidth=0.1; % separation between events
    param.sepcolor=[1 0 0];
    param.spacing=1.5; % separation between traces
    
    param.minmax=[6 5*3]; % min and max values for display;
    param.startY=0; % origin of Y axis for plot
    param.startX=0;
    param.figure=[];
    param.figure.Position=[500 500 1000 300];
    param.xlim=[];
    param.ylim=[];
    
    param.sort=1; % 1 if sorting of trajectories according to generations
    
    
   
end

%if numel(handle)==0
hrls=figure('Color','w','Position',param.figure.Position);
%else

%axes(handle);
%hrls=gcf;
%end

hold on;

startY=param.startY;
startX=param.startX;

maxe=0;

ix=1:numel(rls);

if param.sort==1 % sorting traj according to size
    if param.time==1
        
        dead=[];
        for j=1:numel(rls)
            dead(j)=rls(j).totaltime(end);
        end
            
        [p ix]= sort(dead,'Descend');
       % ix,numel(rls)
        rls=rls(ix);
    else
        gt=[rls.groundtruth];
        [p ix]= sort([rls(gt==1).ndiv],'Descend');
        ix=ix*2;
       
        for i=1:length(ix)
            rlsm(2*i)=rls(ix(i));
            rlsm(2*i-1)=rls(ix(i)-1);
        end
        rls=rlsm;
    end
end

cc=1;

leg={};

med=median([rls.ndiv]);


for i=1:numel(rls)
fprintf('.')  

%aa=rls(i).ndiv
sep=rls(i).sep;
fluo=rls(i).fluo;
div=rls(i).div;

%leg{i}=regexprep(rls(i).trap,'_','-');
leg{i}=rls(i).trap;



if param.time==0
rec2=0:1:1*length(div);
rec2=rec2';
rec2(:,2)=rec2(:,1)+1;
rec2(end,2)=rec2(end,1)+0;

maxe=max(maxe,numel(rls(i).div));
end

if param.time==1
cdiv=cumsum(div);
rec2=[0 cdiv(1:end-1)];
rec2=rec2';


rec2(:,2)=rec2(:,1)+[div]';
%rec2(end,2)=rec2(end,1)+0;    

%rec2
%size(rec2)

maxe=max(maxe,max(cdiv));

end

if param.plotfluo==1
cindex2=uint8(max(1,256*(fluo-param.minmax(1))/(param.minmax(2)-param.minmax(1))));
else
cindex2=uint8(max(1,256*(div-param.minmax(1))/(param.minmax(2)-param.minmax(1))));    
end

cindex2(end+1)=1;
cindex2=min(256,cindex2);




%size(rec), size(rec2)
%figure(hfluo);
%Traj(rec,'Color',cmap,'colorindex',cindex,'width',cellwidth,'startX',startX,'startY',startY,'sepwidth',sepwidth,'sepColor',[0. 0. 0.],'edgeWidth',1,'gradientwidth',0);

%figure(hdiv);
if param.showgroundtruth==1 && rls(i).groundtruth==1
 Traj(rec2,'Color',param.colormapg,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',1,'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).trap)]);   
startY=param.spacing+startY;
end

if rls(i).groundtruth==0
Traj(rec2,'Color',param.colormap,'colorindex',cindex2,'width',param.cellwidth,'startX',startX,'startY',startY,'sepwidth',param.sepwidth,'sepColor',param.sepcolor,'edgeWidth',1,'gradientwidth',param.gradientWidth,'tag',['Trap - ' num2str(rls(i).trap)]);
startY=param.spacing+startY;
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

ti=0:param.spacing: param.spacing*(numel(rls)-1);

if numel(rls)>1
text(30,50, ['Median RLS= ' num2str(med) ' (n=' num2str(numel(rls)) ')'],'FontSize',20);
end

set(gca,'FontSize',14,'Ytick',ti,'YTickLabel',leg);


if param.time==0
xlabel('Generations');
else
xlabel('Time (frames)');    
end

if param.colorbar==1
colormap(param.colormap)
h=colorbar;
ylabel(h,param.colorbarlegend)
xlim([0 1.05*maxe])

h.Ticks=[0 1];
h.TickLabels={num2str(param.minmax(1)) num2str(param.minmax(2))};
h.Location='east';
set(h,'FontSize',14);
ylabel(h,'Division time (frames)');
%h.Position=[1 1 0.3 0.3]
end

%xlim([-30 10]);
%ylim([0 spacing*length(results)+1]);









    
    
