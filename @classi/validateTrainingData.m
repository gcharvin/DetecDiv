function validateTrainingData(classif,varargin)
% high level function to classify data using a classifier on ROIs in a
% @classi object.

% classif is the ref to a @classi object

% 'roilist' is a vector containing ROI  from the classi object

% 'roiwithgt' option only validates rois with  groundth data

%'Classifier' loads the classifier

for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifierStore=varargin{i+1};
    end
    if strcmp(varargin{i},'ClassifierCNN')
        classifierCNN=varargin{i+1};
    end
end

classifyFun=classif.classifyFun;

disp(['Classifying data used as groundtruth in ' classif.strid ' for validation purposes using ' classifyFun]);

%classif=obj.processing.classification(classiid);

path=classif.path;
name=classif.strid;

% loading the CNN network as well for comparison purposes

% first load classifier if not loadad to save some time
if exist('classifierStore','var')==0
    disp(['Loading classifier: ' name]);
    str=[path '/' name '.mat'];
    load(str); % load classifier
    classifierStore=classifier;
end

if exist('classifierCNN','var')==0
    str=[path '/netCNN.mat'];
    disp(['Loading CNN classifier: ' str]);
    
    if exist(str)
        load(str);
        classifierCNN=classifier;
    else
        classifierCNN=[];
        disp(['CNN classifier not found, skipping CNN classif']);
    end
end

classifier=classifierStore; %either loaded or provided as an argument

roiwithgt=1;
for i=1:numel(varargin)
    if strcmp(varargin{i},'Rois')
        roilist=varargin{i+1};
    end
    
    if strcmp(varargin{i},'roiwithgt')
        roiwithgt=1;
        roilist=1:numel(classif.roi);
    end
end

%classifier
if exist('roilist','var')==0 %if no roilist is indicated
    roilist=1:numel(classif.roi);
end

disp([num2str(length(roilist)) ' ROIs to classify, be patient...']);

tmp=roi; % build list of rois
for i=1:length(roilist)
    tmp(i)=classif.roi(roilist(i));
end


for i=1:length(roilist) % loop on all ROIs using parrallel computing  
    roiobj=tmp(i);
    
    if numel(roiobj.id)==0
        continue;
    end
    
    goclassif=0;
    if roiwithgt==1 % chacks if goclassif truth data are avaiable for this ROI, otherwise skips the ROI
        switch classif.typeid
            case {2,8} % pixel classification
                ch= roiobj.findChannelID(classif.strid);
                if numel(ch)>0 % groundtruth channel exists
                    % checks if at least one image has been annotated  first!
                    
                    if numel( roiobj.image)==0 % loads the image
                        roiobj.load;
                    end
                    
                    im= roiobj.image;
                    frames=1:numel(im(1,1,1,:));
                    imch=im(:,:,ch,:);
                    
                    if sum(imch(:))>0 % at least one image was annotated
                        goclassif=1;
                        flag=[];
                        for f=frames
                            if max(max(imch(:,:,1,f)))>1 %takes only frames with cells annotated
                                flag=[flag, f];
                            end
                        end
                        frames=flag;%frames to classify
                    else
                        goclassif=0;
                    end
                end
                
            otherwise % image classification
                classistr=classif.strid;
                % if roi was used for user training, display the training data first
                if numel( roiobj.train)~=0
                    if isfield(roiobj.train,classistr)
                        if numel(roiobj.train.(classistr).id) > 0
                            if sum(roiobj.train.(classistr).id)>0 ||  ( numel(roiobj.train.(classistr).id)==1 && ~isnan(roiobj.train.(classistr).id))  % training exists for this ROI ! put a condition if there is only one element 
                                goclassif=1;
                            else
                                goclassif=0;
                            end
                        end
                    end
                end
        end        
        
    else
        frames=0; %take all frames
    end
    
    if goclassif==1
        disp('-----------');
        disp(['Classifying ' num2str(roiobj.id) ' - ' num2str(i)]);
        
        %  if strcmp(classif.category{1},'Image') % in this case, the results are provided as a series of labels
        %  roiobj.results=zeros(1,size(roiobj.image,4)); % pre allocate results for labels
        %  end
        
        if numel(classifierCNN) % in case an LSTM classification is done, validation is performed with a CNN classifier as well
            feval(classifyFun,roiobj,classif,classifier,classifierCNN); % launch the training function for classification
        else
            switch classif.typeid
                case {2,8} % pixel classification
                    feval(classifyFun,roiobj,classif,classifier,frames); % launch the training function for classification
                otherwise
                    feval(classifyFun,roiobj,classif,classifier); % launch the training function for classification
            end
        end
        
        
    elseif goclassif==0
        disp(['There is no groundtruth available for roi ' num2str(roiobj.id) ' , skipping roi...']);
    end
end

for i=1:length(roilist)
    classif.roi(roilist(i))=tmp(i);
    
    % classif.roi(i).save;
    %classif.roi(i).clear;
end

% disp('Classification job is done and saved...');
disp('You must save the shallow project to save these classified data !');

