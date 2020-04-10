function classifyData(obj,classiid,roilist,classifier)
% high level function to classify data

% classiid is the index of the classifier to be used 

% roilist is an 2 x N array containing FOV IDs and ROI IDs from the shallow
% object to be classified 

if nargin<=3
   classifier=[];
end

if nargin==2
   % classify all ROIs
   roilist=[];
   roilist2=[];
   
   for i=1:length(obj.fov)
      % for j=1:numel(obj.fov(i).roi)
      
     %size( ones(1,length(obj.fov(i).roi)) )
           roilist = [roilist i*ones(1,length(obj.fov(i).roi)) ];
           roilist2 = [roilist2  1:length(obj.fov(i).roi) ]; 
      % end
   end
  
end


classifyFun=obj.processing.classification(classiid).classifyFun;

disp(['Classifying new data using ' classifyFun]);


classif=obj.processing.classification(classiid);

path=classif.path;
name=classif.strid;

% first load classifier if not loadad to save some time 
if numel(classifier)==0
    disp(['Loading classifier: ' name '...']);
    str=[path '/' name '.mat'];
    load(str); % load classifier 
end

%classifier


disp([num2str(size(roilist,2)) ' ROIs to classify, be patient...']);

for i=1:size(roilist,2) % loop on all ROIs
    
 roiobj=obj.fov(roilist(1,i)).roi(roilist(2,i));
 
  disp('-----------');
  disp(['Classifying ' num2str(roiobj.id)]);
 
%  if strcmp(classif.category{1},'Image') % in this case, the results are provided as a series of labels
%  roiobj.results=zeros(1,size(roiobj.image,4)); % pre allocate results for labels
%  end
 
feval(classifyFun,roiobj,classif,classifier); % launch the training function for classification
% since roiobj is a handle, no need to have an output to this the function
% in roiobj.results

end
