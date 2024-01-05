function [data,image] = classifySolov2Fun(roiobj,classif,classifier,varargin)

% HERE make classi function + improve training set

%function [data,image]=classifyPixelDeeplabNetFun(roiobj,classif,classifier,varargin)

% this function can be used to classify any roi object, by providing the
% classi object and the classifier

gpu=0;

if numel(classifier)==0 % loading the classifier // not recommende because it takes time
    path=classif.path;
    name=classif.strid;
    str=[path '/' name '.mat'];
    load(str); % load classifier
end
% classify new images

frames=[];
channel=classif.channelName;

for i=1:numel(varargin)
    if strcmp(varargin{i},'Frames')
        frames=varargin{i+1};
    end

    if strcmp(varargin{i},'Channel')
        channel=varargin{i+1};
    end
      if strcmp(varargin{i},'Exec')
           gpu=varargin{i+1};
      end
end

net=classifier;

inputSize = net.Layers(1).InputSize;
% classNames = net.Layers(end).ClassNames;
% numClasses = numel(classNames);

if numel(roiobj.image)==0 % load stored image in any case
    roiobj.load;
end

data=roiobj.data;
if numel(data)==0
    roiobj.data=dataseries;
    data=roiobj.data;
end

pix=roiobj.findChannelID(channel);

    if iscell(pix)
            pix=cell2mat(pix);
    end

%pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data

gfp=roiobj.image(:,:,pix,:);

if numel(frames)==0
    frames=1:numel(gfp(1,1,1,:));
end

% BEWARE : rather use formatted image in lstm .mat variable
% need to distinguish between formating for training versus validation
% function --> formatfordeepclassification

%switch classif.outputType
  %  case 'proba' % outputs proba of classes
        pixresults=[];
        for i=1:numel(classif.classes)
            pixresultstmp=findChannelID(roiobj,['results_' classif.strid '_' classif.classes{i}]);
            % gather all channels associated with proba

            if numel(pixresultstmp)==0 % channel does not exist, hence create them
                pixresults=[pixresults size(roiobj.image,3)];
            else
                pixresults=[pixresults pixresultstmp];
            end
        end


%    otherwise %  outputs segmentation or segmentation after postprocessing
          pixresults2=findChannelID(roiobj,['results_' classif.strid]);
        % % 
          if numel(pixresults2)==0 % channels do not exist, hence create them
            pixresults2=size(roiobj.image,3)+1;
       %   else
       %    pixresults2=[pixresults pixresults2];
          end

%end

image=roiobj.image;

param=[];

%gfp=uint16(zeros(size(gfp,1),size(gfp,2),3));

gfp=double(zeros(size(gfp,1),size(gfp,2),3,numel(frames)));

for fr=frames % remove the loop on frames here !!!! andtry ti use a gpu array
        gfp(:,:,:,fr)=roiobj.preProcessROIData(pix,fr,param);
end

      gfp=uint8(gfp*256);

 % resize image to have a multiple of 32. 

          [M, N, ~] = size(gfp);
           newM = ceil(M / 32) * 32;
           newN = ceil(N / 32) * 32;

           gfp= imresize(gfp, [newM newN]);

      %      size(gfp)
      %      figure, imshow(gfp(:,:,1),[])
       %     class(gfp)

     % if size(gfp,1)<inputSize(1) | size(gfp,2)<inputSize(2)
     %     gfp=imresize(gfp,inputSize(1:2));
     % end


 %gfptmp=gfp;

 %for fr=frames
    % gfp=gfptmp(:,:,:,fr);
    %C = semanticseg(tmp, net); % this is no longer required if we extract the probabilities from the previous layer
    %    if numel(gpuDeviceCount)==0
    %     features = activations(net,tmp,'softmax-out'); % this is used to get the probabilities rather than the classification itself
    %    else
    %     features = activations(net,tmp,'softmax-out','Acceleration','mex');
    %    end

% <<<<<<< Updated upstream
%     [C,score,features]= semanticseg(tmp, net);%,'Acceleration','mex'); % this is no longer required if we extract the probabilities from the previous layer
%     if size(gfp,1)<inputSize(1) | size(gfp,2)<inputSize(2)
%         features=imresize(features,size(gfp,1:2));
%         C=imresize(C,size(gfp,1:2));
%     end
%
%     % figure, imshow(features(:,:,2),[]);
%
%     tmpout=uint16(zeros(size(roiobj.image(:,:,pixresults,fr))));
%
%     image=roiobj.image;
% =======

if gpu==1
    [C,labels,score] = segmentObjects(net,gfp,'ExecutionEnvironment',"gpu",'SelectStrongest',true,'Threshold',0.2);
  %  [C,score,features]= semanticseg(gfp, net,'ExecutionEnvironment',"gpu");%,'Acceleration','mex'); % this is no longer required if we extract the probabilities from the previous laye

else
     [C,labels,score] = segmentObjects(net,gfp,'ExecutionEnvironment',"cpu",'SelectStrongest',true,'Threshold',0.2);
end

   % if size(gfp,1)~=inputSize(1) | size(gfp,2)~=inputSize(2)
     %   features=imresize(features,size(image,1:2));

    % C = cell2mat(reshape(C, 1, 1, []));
%      size(concatenate)
% [numRows, numCols] = size(C{1});  % Size of one image
% numImages = numel(C);  % Number of images
% C = reshape(concatenate, [numRows, numCols, numImages]);

% if size(C,3)>0
%         C=imresize(C,size(image,1:2));
% else
%           tmpout=uint16(zeros(size(roiobj.image(:,:,numel(classif.classes),frames))));
%           image(:,:,pixresults,frames)=tmpout;
%           return;
% end
%    % end
% 
%    size(C) % HERE reorganize output 
%   %  tmpout=uint16(zeros(size(roiobj.image(:,:,pixresults,fr))));

 %   switch classif.outputType
   %     case 'proba' % outputs proba

      tmpout=uint16(zeros(size(roiobj.image(:,:,numel(classif.classes),frames))));
      tmpout2=uint16(zeros(size(roiobj.image(:,:,1,frames))));

      if iscell(C)
           nfra=numel(C);
       else
            nfra=1;
      end

   for i=1:nfra % loop on frames
  
       if iscell(C)
           rawim=C{i};
       else
            rawim=C;
       end
       
       if numel(rawim)==0
           continue
       end
       
       rawim=imresize(rawim, [M N]);

     
       cc=1;
         for k=1:size(rawim,3) % loop on found mask 
           %    figure, imshow(rawim(:,:,k),[]);
               if iscell(labels)
                   lab=labels{i};
               else
                   lab=labels;
               end

                pix=find(classif.classes==lab(k));
                allim=tmpout(:,:,pix,i);
                allim(rawim(:,:,k))=cc;
                 tmpout(:,:,pix,i)=allim;

                  allim=tmpout2(:,:,1,i);
                allim(rawim(:,:,k))=pix;
                 tmpout2(:,:,1,i)=allim;

              %  tmpout(:,:,pix,i)=  tmpout(:,:,pix,i)+uint16(cc*rawim(:,:,k));
             %   tmpout2(:,:,1,i)=  tmpout2(:,:,1,i)+uint16(pix*rawim(:,:,k));
                cc=cc+1;
         end
   end

     %   case 'segmentation'

            % tmpout=uint16(zeros(size(roiobj.image(:,:,1,frames))));
            % 
            % for i=1:numel(classif.classes) % 1 st class is considered default class
            %    % BW=features(:,:,i,:)>0.9;
            %     res=uint16(uint16(BW)*(i));
            % 
            % 
            %     tmpout=tmpout+res;
            % end
            % 
            % 
            % 
            % tmpout(tmpout==0)=1; %fill background

        %      tmpout=uint16(zeros(size(roiobj.image(:,:,numel(classif.classes),frames))));

            % for i=1:numel(classif.classes)
            %     tmpout(:,:,i,:)=65535*C(:,:,i,:);
            % end


  %      case 'postprocessing'


            % if numel(classif.outputFun)==0
            %     classif.outputFun='post';
            % end
            % if numel(classif.outputArg)==0
            %     classif.outputArg={ 'threshold'  '0.9'};
            % end
            % %tmpout=uint16(zeros(size(roiobj.image(:,:,1,frames))));
            % 
            % tmpout= feval(classif.outputFun,features,classif.classes,classif.outputArg{:});
 %   end

    %      figure, imshow(tmpout,[]);


%<<<<<<< Updated upstream
%    image(:,:,pixresults,fr)=tmpout;
%end
%=======
    image(:,:,pixresults,frames)=tmpout;
    image(:,:,pixresults2,frames)=tmpout2;

   % image(:,:,pixresults,fr)=tmpout;

%>>>>>>> Stashed changes



%roiobj.save;
%roiobj.clear;
fprintf('\n');
