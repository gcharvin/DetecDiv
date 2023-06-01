function [data,image]=classifyImageLSTMNetFun(roiobj,classif,classifier,varargin)

%load([path '/netCNN.mat']); % load the googlenet to get the input size of image

% now load and read video
fprintf('Load videos...\n');

%inputSize = netCNN.Layers(1).InputSize(1:2);

data=[]; %roi;
image=[];

for i=1:numel(classifier.Layers)
%maa= strcmp(class(classifier.Layers(i)), 'nnet.cnn.layer.SequenceInputLayer')

    if strcmp(class(classifier.Layers(i)), 'nnet.cnn.layer.SequenceInputLayer')
  
        inputSize = classifier.Layers(i).InputSize(1:2);

        break
    end
end


channel=classif.channelName;
frames=[];
classifierCNN=[];
gpu=0;

for i=1:numel(varargin)
    if strcmp(varargin{i},'classifierCNN')   
        classifierCNN=varargin{i+1};
        net=classifierCNN;
        inputSizeCNN = net.Layers(1).InputSize;
        classNamesCNN = net.Layers(end).ClassNames;
        numClassesCNN = numel(classNamesCNN);
    end
      if strcmp(varargin{i},'Frames')
          frames=varargin{i+1};
          % not yet implemented
      end
        if strcmp(varargin{i},'Channel')
           channel=varargin{i+1};
        end
        if strcmp(varargin{i},'Exec')
           gpu=varargin{i+1};
        end
end




if numel(roiobj.image)==0
    roiobj.load;
end

pix=roiobj.findChannelID(channel);

    if iscell(pix)
            pix=cell2mat(pix);
    end

%pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data
if numel(frames)==0
    frames=1:size(roiobj.image,4);
end

im=roiobj.image(:,:,pix,frames);


%im=roiobj.image(:,:,pix,frames);

disp('Formatting video before classification....');
%size(im)

% si=58;
% sz=size(im);
% rect=[round((sz(2)-si)/2)+1 round((sz(1)-si)/2)+1 si-1 si-1]
% si=[si si];

si=size(im);
vid=uint8(zeros(si(1),si(2),3,numel(frames)));

cc=1;

param=[]; 

%param
for j=frames  
    tmp=roiobj.preProcessROIData(pix,j,param);

    if numel(tmp)==0 % empty frame 
         vid(:,:,:,cc)=uint8(0);
    else
    
    %tmp = double(imadjust(tmp,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    %tmp=repmat(tmp,[1 1 3]);        
    vid(:,:,:,cc)=uint8(256*tmp);
    end
    cc=cc+1;
end

video = centerCrop(vid,inputSize);

disp('Starting video classification...');

 try  

    if gpu==1
    [x, prob]=classify(classifier,video,'ExecutionEnvironment',"gpu");
    if numel(classifierCNN)
         [labelCNN,probCNN] = classify(classifierCNN,video,'ExecutionEnvironment',"gpu");
             probCNN=predict(classifierCNN,video);
    end

    else
    [x, prob]=classify(classifier,video,'ExecutionEnvironment',"cpu");
    if numel(classifierCNN)
         [labelCNN,probCNN] = classify(classifierCNN,video,'ExecutionEnvironment',"cpu");
             probCNN=predict(classifierCNN,video);
    end
    end

   % probCNN=predict(classifierCNN,video);
    

    catch
    
    disp('Error with predict function  : likely out of memory issue with GPU, trying CPU computing...');
    prob=predict(classifier,video,'ExecutionEnvironment', 'cpu');
    %probCNN=predict(classifierCNN,video,'ExecutionEnvironment', 'cpu');
    if numel(classifierCNN)
      %  [labelCNN,probCNN] = classify(classifierCNN,gfp);
         [labelCNN,probCNN] =classify(classifierCNN,video,'ExecutionEnvironment', 'cpu');
    end

end

labels = classifier.Layers(end).Classes;
if size(prob,1) == numel(labels) % adjust matrix depending on matlab version
    prob=prob';
end

[~, idx] = max(prob,[],2);
label = labels(idx);

if numel(classifierCNN)
    labelCNN = classifierCNN.Layers(end).Classes;
    if size(probCNN,1) == numel(labelCNN) % adjust matrix depending on matlab version
        probCNN=probCNN';
    end
    [~, idx] = max(probCNN,[],2);
    labelCNN = labelCNN(idx);
end

%if size(probCNN,1) == numel(labels) % adjust matrix depending on matlab version
%  probCNN=probCNN';
%end
%[~, idx] = max(probCNN,[],2);
%labelCNN = labels(idx);

%  [~, idx] = max(prob,[],2);
%  label = labels(idx);
% %label = classify(classifier,video,'ExecutionEnvironment', 'cpu'); % in case the gpu crashes because of out of memory
% % prob=activations(classifier,video,'softmax','OutputAs','channels','ExecutionEnvironment', 'cpu');
% end

%label=[];

% lab=[];
% %if size(im,4)>nframes
% for i=1:narr
%    lab = [lab label{i}];
% end
%else
%label=label{1};
%end

%label=lab(1:size(im,4));

%results=roiobj.results;

data=roiobj.data;

if numel(data)==0
    roiobj.data=dataseries;
    data=roiobj.data;
end

pixdata=find(arrayfun(@(x) strcmp(x.groupid,classif.strid),roiobj.data));

 if numel(pixdata)
     cc=pixdata; % data to be overwritten
 else
     n=numel(roiobj.data);
     if n==1 & numel(roiobj.data.data)==0
      cc=1; % replace empty dataset
     else
     cc=numel(roiobj.data)+1;
     end
 end


    data(cc)=dataseries;
    data(cc).class="classification";
    data(cc).groupid=classif.strid;
    data(cc).parentid=roiobj.id; 
    data(cc).plotGroup={[] [] [] [] [] {'id' 'prob' 'labels'}};


datatmp=data(cc);

%results.(classif.strid)=[];

if classif.output==0
    n=size(roiobj.image,4);
else
    n=1;
end

    datatmp.addData(zeros(n,1),'id');
    for i=1:numel(classif.classes)
    datatmp.addData(zeros(n,1),['prob_' classif.classes{i}]);
    end

    tmp=categorical(zeros(n,1),0,{'undefined'});
    datatmp.addData(tmp,'labels');

%     %results.(classif.strid).id=zeros(1,size(roiobj.image,4));
%    % results.(classif.strid).prob=zeros(numel(classif.classes),size(roiobj.image,4));
%     %results.(classif.strid).labels(1:size(roiobj.image,4))=categorical({''});
% else
% %     results.(classif.strid).id =0;
% %     results.(classif.strid).prob=zeros(numel(classif.classes),1);
% %     results.(classif.strid).labels(1:size(roiobj.image,4))=categorical({''});
% 
%     data.addData(zeros(1,1),'id');
%     for i=1:numel(classif.classes)
%     data.addData(zeros(1,1),['prob_' classif.classes{i}]);
%     end
% 
%     tmp=categorical(zeros(1,1),0,{'ok'});
%     data.addData(tmp,'labels');
% 
% 
% end

datatmp.data.labels(frames)=label;
datatmp.userData.classes=classif.classes;

for i=1:numel(classif.classes)
    if size(prob,2)>=i
    datatmp.data.(['prob_' classif.classes{i}])(frames)=prob(frames,i);
    end
end

datatmp.data.id(frames)=idx;
 
%here 
%results.(classif.strid).labels(frames)=label';
%results.(classif.strid).classes=classif.classes;
%results.(classif.strid).prob(:,frames)=prob';
% 
% for i=1:numel(classif.classes)
%     pix=results.(classif.strid).labels==classif.classes{i};
%     results.(classif.strid).id(pix)=i;
% end

if numel(classifierCNN)

  
    if classif.output==0
    n=size(roiobj.image,4);
    else
    n=1;
    end

    datatmp.addData(zeros(n,1),'idCNN');
    for i=1:numel(classif.classes)
    datatmp.addData(zeros(n,1),['probCNN_' classif.classes{i}]);
    end

    tmp=categorical(zeros(n,1),0,{'undefined'});
    datatmp.addData(tmp,'labelsCNN');

%     if classif.output==0
%         results.(classif.strid).idCNN=zeros(1,size(roiobj.image,4));
%         results.(classif.strid).probCNN=zeros(numel(classif.classes),size(roiobj.image,4));
%         results.(classif.strid).labelsCNN(1:size(roiobj.image,4))=categorical({''});
%     else
%         results.(classif.strid).idCNN=0;
%         results.(classif.strid).probCNN=zeros(numel(classif.classes),1);
%         results.(classif.strid).labelsCNN(1:size(roiobj.image,4))=categorical({''});
%     end

datatmp.data.labelsCNN(frames)=labelCNN;
datatmp.userData.classesCNN=classif.classes;

for i=1:numel(classif.classes)
    if size(probCNN,2)>=i
    datatmp.data.(['probCNN_' classif.classes{i}])(frames)=probCNN(frames,i);
    end
end

datatmp.data.idCNN(frames)=idx;
    
%     results.(classif.strid).labelsCNN(frames)=labelCNN';
%     results.(classif.strid).classesCNN=classif.classes;
%     tmpprob=flipud(probCNN');
%     results.(classif.strid).probCNN(1:size(tmpprob,1),frames)=flipud(probCNN'); % fix orientation of array here !!!!
%     
%     for i=1:numel(classif.classes)
%         pix=results.(classif.strid).labelsCNN==classif.classes{i};
%         results.(classif.strid).idCNN(pix)=i;
%     end
end

t={};
varnames=datatmp.data.Properties.VariableNames;
%columnformat={[] [] [] [] [] {'id' 'prob' 'labels'}};

   for i=1:numel(varnames)
                    
                   t{i,1}= true; % set to true to  plot by default
                   t{i,2}= varnames{i};
                   t{i,3}= class(datatmp.data.(varnames{i}));
                   t{i,4}= 'k';
                   t{i,5}= 2;
                    
                   if numel(find(contains(varnames{i},'id')))
                   t{i,6}= 'id';
                   t{i,1}= false;
                   end
                   if numel(find(contains(varnames{i},'prob')))
                   t{i,6}= 'prob';
                   end
                   if numel(find(contains(varnames{i},'labels')))
                   t{i,6}= 'labels';
                   end
   end

datatmp.plotProperties=t;
data(cc)=datatmp;

%roiobj.results=results;

image=roiobj.image;

%roiobj.save;
%roiobj.clear;

function videoResized = centerCrop(video,inputSize)

sz = size(video);

if sz(1) < sz(2)
    % Video is landscape
    idx = floor((sz(2) - sz(1))/2);
    video(:,1:(idx-1),:,:) = [];
    video(:,(sz(1)+1):end,:,:) = [];
    
elseif sz(2) < sz(1)
    % Video is portrait
    idx = floor((sz(1) - sz(2))/2);
    video(1:(idx-1),:,:,:) = [];
    video((sz(2)+1):end,:,:,:) = [];
end

videoResized = imresize(video,inputSize(1:2));


%analyzeNetwork(lgraph)




%etc ...