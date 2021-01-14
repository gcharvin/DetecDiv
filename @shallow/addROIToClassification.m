function addROIToClassification(obj,classid,option)


%clas=obj.processing.classification;
n=classid;

if nargin< 3 
prompt='Import ROIs from other existing classification [y/n] (Default: n): ';
prevclas= input(prompt,'s');
if numel(prevclas)==0
    prevclas='n';
end
else
    prevclas='y';
end


if strcmp(prevclas,'n')
    
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
   % rois(1,i),rois(1,i)
    %rois(1,i),rois(2,i)
    disp(['Processing ROI ' num2str(i) '/' num2str(size(rois,2))]);
    roitocopy=obj.fov(rois(1,i)).roi(rois(2,i));
    
   % aa=roitocopy
    
    obj.processing.classification(n).roi(cc+1)=roi('',[]);
    
    if numel(roitocopy.image)==0
    roitocopy.load;
    end
    
    obj.processing.classification(n).roi(cc+1)=propValues(obj.processing.classification(n).roi(cc+1),roitocopy);
    obj.processing.classification(n).roi(cc+1).path = obj.processing.classification(n).path;
    
    obj.processing.classification(n).roi(cc+1).classes=obj.processing.classification(n).classes;
    
    %size(obj.processing.classification(n).roi(cc+1).image)
    
    if strcmp(obj.processing.classification(n).category{1},'Image') | strcmp(obj.processing.classification(n).category{1},'LSTM')
    obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid)=[];
    obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid).id= zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
   % obj.processing.classification(n).roi(cc+1).train= zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
    end
    
     if strcmp(obj.processing.classification(n).category{1},'Pedigree')
    obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid)=[];
    obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid).id= zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
    obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid).mother= [];%zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
   % obj.processing.classification(n).roi(cc+1).train= zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
   
     im=obj.processing.classification(n).roi(cc+1).image;
     %size(im)
     matrix=im(:,:,obj.processing.classification(n).channel(2),:); 
     
     obj.processing.classification(n).roi(cc+1).addChannel(matrix,obj.processing.classification(n).strid,[1 1 1],[0 0 0]); 
    end
    
    if strcmp(obj.processing.classification(n).category{1},'Pixel')
     im=obj.processing.classification(n).roi(cc+1).image;
     matrix=uint16(zeros(size(im,1),size(im,2),1,size(im,4)));
     obj.processing.classification(n).roi(cc+1).addChannel(matrix,obj.processing.classification(n).strid,[1 1 1],[0 0 0]); 
     obj.processing.classification(n).roi(cc+1).display.selectedchannel(end)=1;
     %pixelchannel=size(obj.image,3);
    end
    
    if strcmp(obj.processing.classification(n).category{1},'Object')
     im=obj.processing.classification(n).roi(cc+1).image;
     %size(im)
     matrix=uint16(im(:,:,obj.processing.classification(n).channel(2),:)>0); 
     
     obj.processing.classification(n).roi(cc+1).addChannel(matrix,obj.processing.classification(n).strid,[1 1 1],[0 0 0]); 
     %pixelchannel=size(obj.image,3);
    end
    
    
    obj.processing.classification(n).roi(cc+1).save;
    obj.processing.classification(n).roi(cc+1).clear; 
    
        cc=cc+1;   
end

else % rois are imported from previous classiciation
    if nargin<3 % specificy classif to import from 
    prompt='Enter the id number of the classification to import from (Default: 1): ';
    prevclas= input(prompt);
    if numel(prevclas)==0
        prevclas=1;
    end
    else
        prevclas=option;
    end
    
    disp(' ');
    
disp(['Number of ROIs available in the classification training set: ' num2str(numel(obj.processing.classification(prevclas).roi))]);
    for j=1:numel(obj.processing.classification(prevclas).roi)
       disp([num2str(j) '- '  obj.processing.classification(prevclas).roi(j).id]);
    end
     disp(' ');
    prompt='Enter the id numbers of the ROIs to import in a comma-separated way (Default: 1): ';
    ids= input(prompt,'s');
    if numel(ids)==0
        ids=1;
    else
       ids=str2num(ids); 
    end
    
    obj.processing.classification(n).trainingset=obj.processing.classification(prevclas).trainingset;

% copy dedicated ROIs to local classification folder and change path

cc=numel(obj.processing.classification(n).roi);

if cc==1
   if  numel(obj.processing.classification(n).roi(1).id)==0
       cc=0;
   end
end



    for i=ids
   % rois(1,i),rois(1,i)
    %rois(1,i),rois(2,i)
    disp(['Processing ROI ' num2str(cc+1) '/' num2str(numel(ids))]);
    
    roitocopy=obj.processing.classification(prevclas).roi(i); %obj.fov(rois(1,i)).roi(rois(2,i));
    
   % aa=roitocopy
    
    if cc==0
    obj.processing.classification(n).roi=roi('',[]);    
    end
    obj.processing.classification(n).roi(cc+1)=roi('',[]);
    
    if numel(roitocopy.image)==0
    roitocopy.load;
    end
    
    obj.processing.classification(n).roi(cc+1)=propValues(obj.processing.classification(n).roi(cc+1),roitocopy);
    obj.processing.classification(n).roi(cc+1).path = obj.processing.classification(n).path;
    
    obj.processing.classification(n).roi(cc+1).classes=obj.processing.classification(n).classes;
    
    %size(obj.processing.classification(n).roi(cc+1).image)
    
%     if strcmp(obj.processing.classification(n).category{1},'Image') | strcmp(obj.processing.classification(n).category{1},'LSTM')
%     obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid)=[];
%     obj.processing.classification(n).roi(cc+1).train.(obj.processing.classification(n).strid).id= zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
%    % obj.processing.classification(n).roi(cc+1).train= zeros(1,size(obj.processing.classification(n).roi(cc+1).image,4));
%     end
    
    if strcmp(obj.processing.classification(n).category{1},'Pixel') && strcmp(obj.processing.classification(prevclas).category{1},'Pixel')
      
      pixid=obj.processing.classification(n).roi(i).findChannelID(obj.processing.classification(prevclas).strid);
      obj.processing.classification(n).roi(i).display.channel{pixid}=obj.processing.classification(n).strid;
        
     %im=obj.processing.classification(n).roi(cc+1).image;
    % matrix=uint16(zeros(size(im,1),size(im,2),1,size(im,4)));
     %obj.processing.classification(n).roi(cc+1).addChannel(matrix,obj.processing.classification(n).strid,[1 1 1],[0 0 0]); 
     %obj.processing.classification(n).roi(cc+1).display.selectedchannel(end)=1;
     %pixelchannel=size(obj.image,3);
    end
    
    if strcmp(obj.processing.classification(n).category{1},'Object')
        
      pixid=obj.processing.classification(n).roi(i).findChannelID(obj.processing.classification(prevclas).strid);
      obj.processing.classification(n).roi(i).display.channel{pixid}=obj.processing.classification(n).strid;
      
    % im=obj.processing.classification(n).roi(cc+1).image;
     %size(im)
    % matrix=uint16(im(:,:,obj.processing.classification(n).channel(2),:)>0); 
     
    % obj.processing.classification(n).roi(cc+1).addChannel(matrix,obj.processing.classification(n).strid,[1 1 1],[0 0 0]); 
     %pixelchannel=size(obj.image,3);
    end
    
    
    
    obj.processing.classification(n).roi(cc+1).save;
    obj.processing.classification(n).roi(cc+1).clear; 
    
        cc=cc+1;   
    end
  
end


    function newObj=propValues(newObj,orgObj)
        pl = properties(orgObj);
        for k = 1:length(pl)
            if isprop(newObj,pl{k})
                newObj.(pl{k}) = orgObj.(pl{k});
            end
        end
    
        