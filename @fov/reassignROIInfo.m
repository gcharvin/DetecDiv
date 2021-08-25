function reassignROIInfo(obj,varargin)

%reassign roi.display
%To be used in case saveCroppedImages has been done on multiple computers at the same time
roi=numel(obj.roi);
for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Rois')
        roi=varargin{i+1};
    end
end
temp=[1 1 1];
for j=1:numel(obj(i).roi)
    rpath=fullfile([theo.io.path theo.io.file],obj(i).id);
    obj(i).roi(j).path=rpath;
    
    obj(i).roi(j).display.channel=[];
    for k=1:numel(obj(i).srclist)
        obj(i).roi(j).display.channel{k}=obj(i).channel{k}; %['Channel ' num2str(k)];
        obj(i).roi(j).display.intensity(k,:)=temp;
        obj(i).roi(j).channelid(k)=k;
        obj(i).roi(j).display.selectedchannel(k)=1;
        obj(i).roi(j).display.rgb(k,:)=temp;
    end
    disp(['Reinitialized path and display for fov(' obj.id '.roi(' j ')'])
end