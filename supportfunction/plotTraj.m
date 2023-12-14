function plotTraj(handle, xout, yout, aligne_str,dataname)

% to do : 
%- plot contour differently if mother or daughter lineage 
%- put more option in the plot option menu to allow to change color, allow
%- cell sorting, also do trjectory alignement 

%Mout(Mout<0)=0; % remove <0 values of fluo

%cmap2=viridis(256); % colormap for division times

l=linspace(0.15,0.85,256);
cmap2=zeros(256,3);

cmap2(:,2)=(fliplr(l))';
cmap2(:,1)=(fliplr(l))';
cmap2(:,3)=(fliplr(l))';

% cmap for fluo
l=linspace(0.85,0,256);
%l=linspace(0,1,256);
cmap=zeros(256,3);
cmap(:,2)=l';

cmap(:,1)=l';
cmap(:,2)=0.75+0.1*l'; %0.95*ones(256,1);
cmap(:,3)=l';

switch aligne_str
    case "birth"
aligne=0; % 0 --> SEP ; 1--> birth; 2--> death
    case "sep"
aligne=1;
    case "end"
aligne=2;
end


% Example data: N x M array with NaNs

data= yout'

trajectorySizes = sum(~isnan(data),2);

[~, order] = sort(trajectorySizes, 'descend');
sortedData = data(order,:)

% Dimensions
[N, M] = size(sortedData);   

% Spacing between trajectories
delta = 0.2;

% Create figure and axes
figure(handle);
hold on;
axis([0 M 0 N + (N-1)*delta]); % Adjust the y-axis to account for spacing
%colormap('jet');  % Choose a colormap

colormap(cmap)
caxis([min(sortedData(~isnan(sortedData))), max(sortedData(~isnan(sortedData)))]);  % Set color axis, ignoring NaNs

% Draw patches
for j = 1:M
    for i = 1:N
        if ~isnan(sortedData(i, j))  % Check if the data point is not NaN
            % Calculate x and y coordinates with spacing
            xCoords = [j-1; j-1; j; j]-1;
            yCoords = [i-1 + (i-1)*delta; i + (i-1)*delta; i + (i-1)*delta; i-1 + (i-1)*delta];
            patch(xCoords, yCoords, sortedData(i, j), 'EdgeColor', 'black', 'LineWidth', 1);
        end
    end
end

% Add colorbar and label it
cb = colorbar;
ylabel(cb, dataname);


hold off;

set(handle,'Position',[ 100 100 800 N*30])
set(gca,'YTick',[]);

return;

% find nans, remove them and calculate mean fluo level before ERC excision
s=Mout(:,1:5);
pix=~isnan(s);
s=s(pix);
mea=mean(s);

meaDiv=Div(:,2:5);
meaDiv=mean(meaDiv(:));

alignDiv=zeros(size(Mout,1),80);
alignFluo=zeros(size(Mout,1),80);


hdiv=figure('Color','w'); hold on ;
hfluo=figure('Color','w'); hold on;

results=[];

maxfluo=0;
maxdiv=0;

cells=1:size(Mout,1);
%cells=[1:20];

%cells=1:20;

cc=1;

for i=cells
    
index=i;

fluo=Mout(index,:); % raw data
div=Div(index,:);

fluostore=fluo;

% remove nans corresponding to no detection
pix=isnan(fluo(1:SEPdiv(index)));
fluo(pix)=mea;


% cut trajectory (removing trailing nans)
pix=find(isnan(fluo),1,'first'); 

if numel(pix)>0
fluo=fluo(1:pix-1);
div=div(1:pix-1);
end


% find best cutoff timing for fitting

[dfluo,ix]=max(diff(fluo)); 

maxe=max(ix+1,SEPdiv(index)); % peak increase point
maxe=min(maxe,SEPdiv(index)+cutend); % cutoff long after sep
maxe=min(length(fluo),maxe); % shorter than array size

%fluo=fluo(1:maxe); % cutoff applied for single cell fitting only !


results(cc).fluo=fluo;
results(cc).div=div;
results(cc).n=length(fluo);
results(cc).sep=SEPdiv(i);
results(cc).postsep=length(div)-SEPdiv(i);
results(cc).i=i;

maxfluo=max(maxfluo,max(fluo));
maxdiv =max(maxdiv,max(maxdiv));


% table used to average trajectories
alignDiv(cc,1:length(div))=div;

if aligne==0
alignDiv(cc,:)=circshift(alignDiv(cc,:),(size(alignDiv,2)/2-SEPdiv(i))+1);
end

if aligne==2
alignDiv(cc,:)=circshift(alignDiv(cc,:),(size(alignDiv,2)-length(div)));
end

alignFluo(cc,1:length(fluo))=fluo;

if aligne==0
alignFluo(cc,:)=circshift(alignFluo(cc,:),(size(alignFluo,2)/2-SEPdiv(i))+1);
end

if aligne==2
alignFluo(cc,:)=circshift(alignFluo(cc,:),(size(alignFluo,2)-length(fluo)));
end

cc=cc+1;
end


if aligne==0
[so ix]=sort([results.postsep],'descend');
end

if aligne==1
 [so ix]=sort([results.n],'descend');   
end

if aligne==2
 [so ix]=sort([results.n],'descend');   
end

results=results(ix);


for i=1:length(results)

fluo=results(i).fluo;
div=results(i).div;

rec=0:1:1*length(fluo);
rec=rec';
rec(:,2)=rec(:,1)+1;
rec(end,2)=rec(end,1)+0;




cindex=uint8(max(1,256*(fluo-mea)/(6*mea-mea)));
cindex=min(256,cindex);
cindex(end+1)=1;

rec2=0:1:1*length(div);
rec2=rec2';
rec2(:,2)=rec2(:,1)+1;
rec2(end,2)=rec2(end,1)+0;

cindex2=uint8(max(1,256*(div-1.1*meaDiv)/(2*meaDiv-1.05*meaDiv)));
cindex2(end+1)=1;

cindex2=min(256,cindex2);

cellwidth=1;
spacing=1.5;
startY=spacing*i;
sepwidth=0;

if aligne==1
    startX=0;
end
if aligne==0
   startX=-results(i).sep;
end
if aligne==2
   startX=-results(i).n;
end


figure(hfluo);
Traj(rec,'Color',cmap,'colorindex',cindex,'width',cellwidth,'startX',startX,'startY',startY,'sepwidth',sepwidth,'sepColor',[0. 0. 0.],'edgeWidth',0,'gradientwidth',0);

figure(hdiv);
Traj(rec2,'Color',cmap2,'colorindex',cindex2,'width',cellwidth,'startX',startX,'startY',startY,'sepwidth',sepwidth,'sepColor',[0. 0. 0.],'edgeWidth',0,'gradientwidth',0);

end

% figure(hfluo);
% line([0 0],[0 spacing*length(results)+cellwidth],'Color','k','LineWidth',4);
% set(gca,'FontSize',20,'Ytick','','YTickLabel',{});
% colormap(cmap)
% colorbar
% %xlim([-30 10]);
% ylim([0 spacing*length(results)+1]);
% set(gcf,'Renderer','painters')
% 
% xlabel('Generations');

figure(hdiv);
line([0 0],[0 spacing*length(results)+cellwidth],'Color','k','LineWidth',4);
set(gca,'FontSize',20,'Ytick','','YTickLabel',{});
colormap(cmap2)
colorbar
%xlim([-30 10]);
ylim([0 spacing*length(results)+1]);
xlabel('Generations');
set(gcf,'Renderer','painters')













