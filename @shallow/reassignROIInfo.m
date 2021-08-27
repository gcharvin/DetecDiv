function reassignROIInfo(obj,varargin)

% reassign roi.display
% To be used in case saveCroppedImages has been done on multiple computers at the same time
fovlist=numel(obj.fov);
for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Fovs')
        fovlist=varargin{i+1};
    end
end
temp=[1 1 1];
for i=1:fovlist
    for j=1:numel(obj.fov(i).roi)
        rpath=fullfile([obj.io.path obj.io.file],obj.fov(i).id);
        obj.fov(i).roi(j).path=rpath;

        obj.fov(i).roi(j).display.channel=[];
        for k=1:numel(obj.fov(i).srclist)
            obj.fov(i).roi(j).display.channel{k}=obj.fov(i).channel{k}; %['Channel ' num2str(k)];
            obj.fov(i).roi(j).display.intensity(k,:)=temp;
            obj.fov(i).roi(j).channelid(k)=k;
            obj.fov(i).roi(j).display.selectedchannel(k)=1;
            obj.fov(i).roi(j).display.rgb(k,:)=temp;
        end
        disp(['Reinitialized path and display for fov(' obj.fov(i).id '.roi(' num2str(j) ')'])
    end
end