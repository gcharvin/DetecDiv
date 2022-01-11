function paramout=basicObjectTracking(param,roiobj,frames)

% basic tracker to link objects over time 

if nargin==0
    paramout=[];
    
    paramout.input_channel_name='results_segcell_simple_3';
    
    paramout.coefdist='1';
    paramout.size_weight='1';
    
    paramout.max_relative_distance='2';
    
    paramout.output_channel_name='track_segcell_simple_3';
    
    return;
else
paramout=param; 
end

obj=roiobj;
channelstr=param.input_channel_name;

display=0;

channelID=obj.findChannelID(channelstr);

if numel(channelID)==0 % this channel contains the segmented objects
   disp([' This channel ' channelstr ' does not exist ! Quitting ...']) ;
   return;
end

if numel(obj.image)==0
    obj.load
end

im=obj.image(:,:,channelID,:);

% convert image into binary mask

im=logical(im-1);

if nargin<3
    frames=1:size(im,4);
end

if numel(frames)==0
   frames=1:size(im,4);  
end

%creates an output channel to update results

pixresults=findChannelID(obj,paramout.output_channel_name);

if numel(pixresults)>0
%pixresults=find(roiobj.channelid==cc); % find channels corresponding to trained data

obj.image(:,:,pixresults,:)=im; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
else
   % add channel is necessary 
   matrix=im; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
   rgb=[1 1 1];
   intensity=[0 0 0];
   pixresults=size(obj.image,3)+1;
   obj.addChannel(matrix,paramout.output_channel_name,rgb,intensity);
end

% calculate the mean object size during the movie
area=[];



for i=1:size(im,4)
   
    stats=regionprops(im(:,:,1,i)>0,'Area');
    tmp=[stats.Area];
   % size(tmp)
    area=[area; tmp'];
end

area=area';
areamean=mean(area);
distancemean=2*sqrt(areamean)*2/pi;

% typical cell size in movie x 2 

%

imref=im(:,:,1,frames(1));
tmp=bwlabel(imref);

obj.image(:,:,pixresults,frames(1))=tmp;
cellsref=getCells(tmp);

if display==1
   figure; 
   for i=1:numel(cellsref)
      line(cellsref(i).ox,-cellsref(i).oy,'LineStyle','none','Marker','.','MarkerSize',40,'Color','b'); 
      text(cellsref(i).ox,-0.5*cellsref(i).oy,num2str(i),'Color','b');
   end
end
    
for i=frames(1)+1:frames(end) % loop on all frames
    
    imtest=im(:,:,1,i);
    [ltest,ntest]=bwlabel(imtest);
    
    cellstest=getCells(ltest);
    
    if display==1
   
   for j=1:numel(cellstest)
      line(cellstest(j).ox,-cellstest(j).oy,'LineStyle','none','Marker','.','MarkerSize',35,'Color','r'); 
       text(cellstest(j).ox,-0.5*cellstest(j).oy,num2str(j),'Color','r');
      
   end
   
   
    end

    
    cellsrefstore=cellsref;
    
    [cellsref,cost]=hungarianTracker(cellsref,cellstest,distancemean,param);
    
    if display==1
    for j=1:numel(cellsrefstore)
        for k=1:numel(cellstest)
            if ~isinf(cost(j,k))
        line([cellsrefstore(j).ox cellstest(k).ox],[-cellsrefstore(j).oy -cellstest(k).oy],'Color','k');
        
        text(0.5*(cellsrefstore(j).ox+cellstest(k).ox),-0.5*(cellsrefstore(j).oy+cellstest(k).oy),num2str(double(round(1000*cost(j,k))/1000)));
            end
        end
    end
    end
   % disp([cellstest.n]);
    
    %disp('ok')
   % disp([cellsref.n]); 
    
    bw=uint16(zeros(size(imref,1),size(imref,2)));
    
    for j=1:ntest
       pix=ltest==j;
       bw(pix)=cellsref(j).n;
    end

    obj.image(:,:,pixresults,i)=bw;
  
fprintf('.');
end
fprintf('\n');

disp('Tracking done !');


function cells=getCells(l)
% create cell structure from image


r=regionprops(l,'Centroid','Area');

cells=struct('ox',[],'oy',[],'area',[],'n',[]);

for i=1:max(l(:))
    
    cells(i).ox=r(i).Centroid(1);
    cells(i).oy=r(i).Centroid(2);
    cells(i).area=r(i).Area;
    cells(i).n=i;%round(mean(l==i));
    
end

function [newcell,cost]=hungarianTracker(cell0,cell1,meancellsize,param)

% this function performs the tracking of cell contours based on an
% assignment cost matrix and the Hungarian method for assignment

OK=0;
newcell=[];
   
%param=struct('cellsize',70,'cellshrink',1,'coefdist',0,'coefsize',1,'filterpos',0);
  
%newcell=param;

lastObjectNumber=max([cell0.n]);

% buld weight matrix based on distance and size

%a=[cell0.ox]
n0=length(find([cell0.ox]~=0));
n1=length(find([cell1.ox]~=0));

M=Inf*ones(n0,n1);

vec=[];

ind0=find([cell0.ox]~=0);
ind1=find([cell1.ox]~=0);

display=0;

%areamean=mean([cell0.area]);
%meancellsize=30; % pixels sqrt(areamean/pi);

%weigth=10;

for i=1:length(ind0)
    
    id=ind0(i);
    
         % anticipate cell motion using previously calculated cell velocity
        % over the last n frames (n=1?)
  
    for j=1:length(ind1)
       
        %if cell1(j).ox==0
        %    continue
        %end
        jd=ind1(j);
        
        % calculate distance between cells
        %sqdist=(cell0(id).ox+cell0(id).vx-cell1(jd).ox)^2+(cell0(id).oy+cell0(id).vy-cell1(jd).oy)^2;
        
        sqdist=(cell0(id).ox-cell1(jd).ox)^2+(cell0(id).oy-cell1(jd).oy)^2;
        
        dist=sqrt(sqdist)./(meancellsize);
        
        %i,j
       % codist=pdist([cell0(id).ac;cell1(jd).ac], 'cosine');
        
        if dist > str2num(param.max_relative_distance) %sqrt(sqdist)>param.cellsize % 70 % impossible to join cells that are further than 70 pixels
            continue;
        end
        % HERE : see if dist can be replaced by codist for the threshold

        %M(i,j)= codist*dist;
       % M(i,j)=(param.coefdist*dist+param.coefsize*codist);%+param.coefsize*abs(sizedist)/(areamean));
        M(i,j)=str2num(param.coefdist)*dist; %+param.coefsize*codist;
    end
end

%M

[Matching,Cost] = Hungarian(M);

%Matching

[row,col] = find(Matching);

row=ind0(row);
col=ind1(col);

vec=[row' col'];

ind0=[cell0.n];
ind1=[cell1.n];

%row,max(row)

row2=ind0(row);
col2=ind1(col);

vec2=[row2' col2'];

lostcells=setdiff(ind0(find(ind0)),row2);

vec2=[vec2 ; [lostcells' zeros(length(lostcells),1)]];

newcells=setdiff(ind1(find(ind1)),col2);

vec2=[vec2 ; [zeros(length(newcells),1) newcells']];

newcell=cell1;

%count=max(mapOut(:,2));
%a=[segmentation.cells1.n];
count=lastObjectNumber;

for i=1:length(newcell)
   
   if newcell(i).ox~=0
   ind=newcell(i).n;
   %a=vec(:,2)
   ind=find(vec2(:,2)==ind);
   ind=ind(1);
   
   if vec2(ind,1)~=0
       %vec2(ind,1)
       newcell(i).n=vec2(ind,1);
      % newcell(i).vx=newcell(i).ox-cell0(vec(ind,1)).ox;
      % newcell(i).vy=newcell(i).oy-cell0(vec(ind,1)).oy;
   else
       newcell(i).n=count+1;
       
       count=count+1;
   end
   end
end

cost=M;

OK=1;

% if display
% 
% figure;
% 
% for i=1:length(cell0)
%     if cell0(i).ox~=0
%         line(cell0(i).x,cell0(i).y,'Color','r'); hold on
%         text(cell0(i).ox,cell0(i).oy,num2str(cell0(i).n),'Color','r'); hold on;
%         
%         line(cell0(i).x+cell0(i).vx,cell0(i).y+cell0(i).vy,'Color','m'); 
%        % text(cell0(i).ox,cell0(i).oy,num2str(cell0(i).n),'Color','r');
%         
%         hold on;
%     end
% end
% 
% for i=1:length(cell1)
%     if cell1(i).ox~=0
%         line(cell1(i).x,cell1(i).y,'Color','b'); hold on;
%         text(cell1(i).ox,cell1(i).oy,num2str(cell1(i).n),'Color','b');
%         hold on;
%     end
% end
% 
% for i=1:numel(vec(:,1))
%     line([cell0(vec(i,1)).ox cell1(vec(i,2)).ox],[cell0(vec(i,1)).oy cell1(vec(i,2)).oy],'Color','g');
% end
% 
% axis equal tight
% 
% end





