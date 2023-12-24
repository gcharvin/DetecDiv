function plotTraj(handle, xout, yout,dataname,param,roinames,listylin,listylintemp,rois)
%here put roinames

% to do :
%put tagging on patches to launch 

%cmap2=viridis(256); % colormap for division times

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
if numel(listylintemp)
    datalintemp=listylintemp';
end

ali=xout';

trajectorySizes = sum(~isnan(data),2);

if param.Sort_traj
[~, order] = sort(trajectorySizes, 'descend');
sortedData = data(order,:);
xout=xout(:,order);
if numel(roinames)
roinames=roinames(order);
end

if numel(listylin)
    datalin=datalin(order,:);
end
if numel(listylintemp)
    datalintemp=datalintemp(order,:);
end
else
sortedData = data(:,:);
end


% Dimensions
[N, M] = size(sortedData);

% Spacing between trajectories
delta = 0.2;

% Create figure and axes
figure(handle);
hold on;
axis([0 M 0 N + (N-1)*delta]); % Adjust the y-axis to account for spacing
%colormap('jet');  % Choose a colormap

colormap(cmap);

bounds=str2num(param.Single_cell_min_max);

if isnan(bounds(1))
    xmin=min(sortedData(~isnan(sortedData)));
else
    xmin=bounds(1);
end

if isnan(bounds(2))
    xmax=max(sortedData(~isnan(sortedData)));
else
    xmax=bounds(2);
end

clim([xmin xmax]);  % Set color axis, ignoring NaNs

tticks=[];
ttickslabel={};

% Draw patches
for i = 1:N
    for j = 1:M
        if ~isnan(sortedData(i, j))  % Check if the data point is not NaN
            % Calculate x and y coordinates with spacing
         %   xCoords = [j-1; j-1; j; j]-1;

             xCoords = [xout(j,i)-1; xout(j,i)-1; xout(j,i); xout(j,i)];

            yCoords = [i-1 + (i-1)*delta; i + (i-1)*delta; i + (i-1)*delta; i-1 + (i-1)*delta];

                if param.Display_MD_lineage
                if numel(listylin)
            bb=0.2;
            xCoordsLin = [j-1+bb; j-1+bb; j-1+2*bb; j-1+2*bb]-1;
            yCoordsLin=[  i-1 + (i-1)*delta+bb;   i-1 + (i-1)*delta+ 2*bb;  i-1 + (i-1)*delta+ 2*bb; bb+i-1+(i-1)*delta];
                end
                end

            if param.Display_traj_edge
            hp=patch(xCoords, yCoords, sortedData(i, j), 'EdgeColor', str2num(param.Display_traj_edge_color), 'LineWidth', 1);
            else
            hp=patch(xCoords, yCoords, sortedData(i, j),'LineStyle','none');
            end

            if numel(rois)
            if numel(listylintemp)
            set(hp,'ButtonDownFcn',{@test,gca,rois(i),datalintemp(i,:)});
            else
            set(hp,'ButtonDownFcn',{@test,gca,rois(i),[]});
            end
            end

            if param.Display_MD_lineage
                if numel(listylin)
                    if datalin(i,j)==1
                        patch(xCoordsLin, yCoordsLin,'k');
                    else
                        patch(xCoordsLin, yCoordsLin,'w');
                    end
                end
            end

          
        end
    end

    if param.Display_ROI_name
        if numel(roinames)
        tticks(i)=(i-0.5)*(1+delta);
        ttickslabel{i}=roinames{i};
        end
    end
end

% Add colorbar and label it

set(handle,'Position',[ 100 100 800 N*50+100])

if param.Display_ROI_name
    set(gca,'YTick',tticks);
    yticklabels(ttickslabel);
else
    set(gca,'YTick',[]);
end

cb = colorbar;
ylabel(cb, dataname);

xlim([min(xout(:)),max(xout(:))]);
set(gca,'TickLabelInterpreter','none','FontSize',14)
hold off;

function test(obj, event, handles,roitmp,fralist)

% if isstruct(handlesstruct)
% 
     pt = get(gca, 'CurrentPoint');

      frame=round(pt(1,1));

     if numel(fralist)~=0
           frame=fralist(frame);
     end

    roitmp.view(frame);

% 
%     src=get(obj,'Tag');
%     f1=strfind(src,':');
%     f2=strfind(src,'-');
%     nObject=str2num(src(f1+1:f2-1));
% 
% else
%     src=get(obj,'Tag');
%     axes(handles);
%     title(src);
% end

