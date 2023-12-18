function plotTraj(handle, xout, yout,dataname,param,roinames)
%here put roinames

% to do : 
%- plot contour differently if mother or daughter lineage 
%- put more option in the plot option menu to allow to change color, allow
%- cell sorting, also do trjectory alignement 

% plot sorting, plot roi name, put tagging 


%Mout(Mout<0)=0; % remove <0 values of fluo

%cmap2=viridis(256); % colormap for division times

% l=linspace(0.15,0.85,256);
% cmap2=zeros(256,3);
% 
% cmap2(:,2)=(fliplr(l))';
% cmap2(:,1)=(fliplr(l))';
% cmap2(:,3)=(fliplr(l))';
% 
% % cmap for fluo
% l=linspace(0.85,0,256);
% %l=linspace(0,1,256);
% cmap=zeros(256,3);
% cmap(:,2)=l';
% 
% cmap(:,1)=l';
% cmap(:,2)=0.75+0.1*l'; %0.95*ones(256,1);
% cmap(:,3)=l';


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

ali=xout';

trajectorySizes = sum(~isnan(data),2);

[~, order] = sort(trajectorySizes, 'descend');
sortedData = data(order,:);

% Dimensions
[N, M] = size(sortedData)

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
            xCoords = [j-1; j-1; j; j]-1;
            yCoords = [i-1 + (i-1)*delta; i + (i-1)*delta; i + (i-1)*delta; i-1 + (i-1)*delta];

           
            patch(xCoords, yCoords, sortedData(i, j), 'EdgeColor', str2num(param.Display_traj_edge_color), 'LineWidth', 1);
        end
        end

        tticks(i)=(i-1)*(1+delta);
        ttickslabel{i}=

    end

    

% Add colorbar and label it
cb = colorbar;
ylabel(cb, dataname);


hold off;

set(handle,'Position',[ 100 100 800 N*50])
set(gca,'YTick',[]);
