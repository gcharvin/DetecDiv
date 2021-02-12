function clearTraining(obj,varargin)

% clear training data for specific ROIs and clean training data for this
% and other classification 

classis={};
rois=1:numel(obj.roi);
allclassi=0;


for i=1:numel(varargin)
    if strcmp(varargin{i},'allclassi')
        allclassi=1;
    end

      if strcmp(varargin{i},'rois')
        rois=varargin{i+1};  
      end
      if strcmp(varargin{i},'classis')
        classis=varargin{i+1};  
      end
end


if allclassi==1
    for i=rois
        obj.roi(i).train=[];
    end
else
   for i=rois
       for j=1:numel(classis)
        obj.roi(i).removeData('train',classis{j});
       end
   end
end
