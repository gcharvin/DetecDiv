function postprocessing(obj,classif,varargin)

% run postprocessing function for pixel classification
% by default, the function used for processing is that specified in classif.outputFun,
% with classif.outputArg as arguments
% the channels names used as input are
% results_classif.strid_results.classes by default

outputFun=classif.outputFun;
outputArg=classif.outputArg;

if strcmp(numel(outputFun),'post')
    if numel(outputArg)==0
        outputArg={'threshold',0.9};
    end
end


NoSave=0;

for i=1:numel(varargin)
    if strcmp(varargin{i},'OutputFun')
        outputFun=varargin{i+1};
    end
    if strcmp(varargin{i},'OutputArg')
        outputArg=varargin{i+1};
    end
     if strcmp(varargin{i},'NoSave') % does not save roi !
       NoSave=1;
    end
end


% load roi
if numel(obj.image)==0
obj.load;
end


% gather proba images

proba=double(zeros(size(obj.image,1),size(obj.image,2),size(classif.classes,1),size(obj.image,4)));

for i=1:numel(classif.classes)
    pixresultstmp=findChannelID(obj,['results_' classif.strid '_' classif.classes{i}]); % gather all channels associated with proba
    
    if numel(pixresultstmp)==0 % channel does not exist, this is a problem
        disp(['Proba channel does not exist for ' classif.strid 'for class ' classif.classes{i} ' ! First classify data with proba output mode ...']);
        return;
    else
        
        proba(:,:,i,:)=double(obj.image(:,:,pixresultstmp,:))./65535.; % convert image from uint16 to [0 1]
        
    end
end


% create separate channel for segmented image if does not exist yet /
% indexed image 

 pixresults=findChannelID(obj,['results_' classif.strid]);
        
 if numel(pixresults)==0 % channels do not exist, hence create them
            matrix=uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
            rgb=[1 1 1];
            intensity=[0 0 0]; % used to display indexed image in .view
        
            obj.addChannel(matrix,['results_' classif.strid],rgb,intensity);

            pixresults=size(roiobj.image,3);
         else
            obj.image(:,:,pixresults,:)=uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
 end
 
 
 % apply postprocessing function to all frames and updates obj.image;

 
for i=1:size(obj.image,4)
    
 obj.image(:,:,pixresults,i)= feval(outputFun,proba(:,:,:,i),classif.classes,outputArg{:});
end

% figure, imshow(obj.image(:,:,pixresults,5),[])

if NoSave==0
obj.save; 
obj.clear;
end


