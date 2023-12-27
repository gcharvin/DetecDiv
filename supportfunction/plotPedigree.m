function plotPedigree(handle, xout, yout,dataname,param,listylin)
% plot pedigree based on xout and yout data : list of values including NaN 

% param is as follows : 
%            param=struct('Traj_synchronization',{{'birth','sep','death','birth'}},...
 %               'Single_cell_display_type',{{'traj','plot','traj'}},...
                % 'Single_cell_traj_low_color','0.85 0.85 0.85',...
                % 'Single_cell_traj_high_color','1 0 0',...
                % 'Single_cell_min_max','NaN NaN',...
                %  'Display_traj_edge',true,...
                %  'Display_traj_edge_color','0 0 0',...
                %     'Display_MD_lineage',false,...
                %     'Sort_traj',true,...
                %     'Display_ROI_name',false, ...
                % 'Display_single_cell_plot',true,...
                % 'Display_average',true,...

 % listylin : lineage data ; put [] if no data 

 depth=5; % length of MD chains to consider

handlestruct=[];

x=[0 1];
xv=linspace(0,1,256);

cmap=[];
tmp_low=str2num(param.Single_cell_traj_low_color) ;
tmp_high=str2num(param.Single_cell_traj_high_color) ;

cmap=[];

for k=1:3
    y=[tmp_low(k), tmp_high(k)];
    cmap(:,k)= interp1(x,y,xv);
end

% Example data: N x M array with NaNs

data= yout';

if numel(listylin)
    datalin=listylin'; 
end

ali=xout';

trajectorySizes = sum(~isnan(data),2);

sortedData = data(:,:);

% Dimensions
[N, M] = size(sortedData);


% first, average data on the pedigree 

% Now analyze pedigrees 

% [cx,cy,val]=lineage(sequence)

    treeidx=[];
   treeval={};
   treeposx=[];
   treeposy=[];

for i=1:N
dat=sortedData(i,:);
datlin=datalin(i,:);

for j=1:depth 
    startIndexes = 1:(M-j+1);
    endIndexes = j:M;

    sub = arrayfun(@(s,e) dat(s:e), startIndexes, endIndexes, 'UniformOutput', false);
    sublin = arrayfun(@(s,e) datlin(s:e), startIndexes, endIndexes, 'UniformOutput', false);

    % add extra NaN to prevent empty tree parts
    [sublin2,sub2]=addNaN(j);
    sublin=[sublin, sublin2];
    sub=[sub,sub2];


    for k=1:numel(sublin)
             [cx,cy,idx]=lineage(sublin{k});

            if numel(find(treeidx==idx))==0
                treeidx=[treeidx idx];
                treeval{end+1}= sub{k}(end) ;
                treeposx=[treeposx cx];
                treeposy=[treeposy cy];
            else
               pix=find(treeidx==idx);
                treeval{pix}= [treeval{pix} sub{k}(end)] ;
            end

    end
 %   hasNaN = any(cellfun(@(x) any(isnan(x)), subarrays));

end
end

treeposy=treeposy*2^depth; % s%epearate traj

%treeval
%treeposx
%treeposy

meantree=cellfun(@(s) mean(s,'omitnan'),treeval);
stdtree=cellfun(@(s) std(s,'omitnan'),treeval);


% Create figure and axes
figure(handle);
hold on;

%axis([0 M 0 N + (N-1)*delta]); % Adjust the y-axis to account for spacing
%colormap('jet');  % Choose a colormap

colormap(cmap);
bounds=str2num(param.Single_cell_min_max);

if isnan(bounds(1))
    xmin=min(meantree(~isnan(meantree)));
else
    xmin=bounds(1);
end

if isnan(bounds(2))
    xmax=max(meantree(~isnan(meantree)));
else
    xmax=bounds(2);
end

clim([xmin xmax]);  % Set color axis, ignoring NaNs

tticks=[];
ttickslabel={};

% Draw patches
for i = 1:numel(meantree)
      %  if ~isnan(meantree)  % Check if the data point is not NaN
            % Calculate x and y coordinates with spacing
         %   xCoords = [j-1; j-1; j; j]-1;

         x=treeposx(i);
         y=treeposy(i);
         xCoords = [0; 0; 1; 1]; xCoords=xCoords+x;
         yCoords = [0;1;1;0]; yCoords=yCoords+y;

            if param.Display_traj_edge
            hp=patch(xCoords, yCoords, meantree(i), 'EdgeColor', str2num(param.Display_traj_edge_color), 'LineWidth', 1);
            else
            hp=patch(xCoords, yCoords, meantree(i),'LineStyle','none');
            end

            hp.UserData.data = meantree(i);
% Set buttondownfcn on patch objects.
             datacursormode(handle,'off') %data cursor mode will prevent mouse clicks!
             hp.ButtonDownFcn = @patchButtonDownFcn;

            % now draw a vertical line 
            % find the y position of the daughter cell 


          pix=find(treeposx==x+1 & treeposy>y);
          if numel(pix)
          [cand ix]=min(treeposy(pix));

          posy=treeposy(pix(ix));
          hl=line([x+1 x+1],[y+1 posy+1],'LineWidth',2,'Color','k');
          end


      %  end
end

% Add colorbar and label it

set(handle,'Position',[ 100 100 800 600]);
set(gca,'YTick',[]);

cb = colorbar;
ylabel(cb, dataname);

xlim([0 depth+1]);
set(gca,'TickLabelInterpreter','none','FontSize',14)
hold off;

function [cx,cy,val]=lineage(sequence) % for a iven sequence, returns the position on the phlogeny tree
cx=0;
cy=0;

for i=1:numel(sequence)
        cx=cx+1;

    if sequence(i)==1
        cy=cy+1/(2^(i-1));
    end
end

if sequence(1)==1
cy=cy+0.12;
end

val=cx+cy;

function     [sublin2,sub2]=addNaN(depth)

sublin2={};
sub2={};

N = depth; % Example, change as needed
numCombinations = 2^N;
binaryStrings = dec2bin(0:numCombinations-1, N);
combinations = binaryStrings - '0';

for i=1:size(combinations,1)
       sublin2=[sublin2 {combinations(i,:)}];
       sub2=[sub2 nan(1,depth)];

end

function patchButtonDownFcn(patchObj, hit)
    % Responds to mouse clicks on patch objs.
    % Add point at click location and adds a datacursor representing
    % the underlying patch.
    % datatip() requires Matlab r2019b or later
    % Find closet vertices to mouse click
    hitPoint = hit.IntersectionPoint

val= patchObj.UserData.data;

title(gca,num2str(val));