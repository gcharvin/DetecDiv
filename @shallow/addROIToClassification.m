function addROIToClassification(obj,classid)


%clas=obj.processing.classification;
n=classid;


prompt='Please enter the ROIs tu use as training sets: [FOV1 FOV1 FOV2; ROI1 ROI2 ROI1]; Default: [1 1 1; 1 2 3] ';
rois= input(prompt);

if numel(rois)==0
    rois=[1 1 1; 1 2 3];
end

if size(rois,1) ~=2
    disp('Error : the list of ROIs must be provided as an array of 2 x N elements; Please launch the shallowObj.addROIToClassification() method again ! ');
    return;
end

obj.processing.classification(n).addTrainingData(rois);

% copy dedicated ROIs to local classification folder and change path

cc=numel(obj.processing.classification(n).roi);

if cc==1
   if  numel(obj.processing.classification(n).roi(1).id)==0
       cc=0;
   end
end

for i=1:size(rois,2)
    
    %rois(1,i),rois(2,i)
    disp(['Processing ROI ' num2str(i) '/' num2str(size(rois,2))]);
    roitocopy=obj.fov(rois(1,i)).roi(rois(2,i));
    
    obj.processing.classification(n).roi(cc+1)=roi('',[]);
    
    roitocopy.load;
    
    obj.processing.classification(n).roi(cc+1)=propValues(obj.processing.classification(n).roi(cc+1),roitocopy);
    obj.processing.classification(n).roi(cc+1).path = obj.processing.classification(n).path;
    
    obj.processing.classification(n).roi(cc+1).classes=obj.processing.classification(n).classes;
    
    if strcmp(obj.processing.classification(n).category{1},'Image') | strcmp(obj.processing.classification(n).category{1},'LSTM')
    obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid)=[];
    obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid).id= zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
   % obj.processing.classification(n).roi(cc+1).train= zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
    end
    
    if strcmp(obj.processing.classification(n).category{1},'Pixel')
     im=obj.processing.classification(n).roi(cc+1).image;
     matrix=uint16(zeros(size(im,1),size(im,2),1,size(im,4)));
     obj.processing.classification(n).roi(cc+1).addChannel(matrix,obj.processing.classification(n).strid,[1 1 1],[0 0 0]); 
     %pixelchannel=size(obj.image,3);
    end
    
    
    
    obj.processing.classification(n).roi(cc+1).save;
    obj.processing.classification(n).roi(cc+1).clear; 
    
        cc=cc+1;   
end

%


    function newObj=propValues(newObj,orgObj)
        pl = properties(orgObj);
        for k = 1:length(pl)
            if isprop(newObj,pl{k})
                newObj.(pl{k}) = orgObj.(pl{k});
            end
        end
    
        