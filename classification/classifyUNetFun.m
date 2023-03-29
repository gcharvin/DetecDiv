function [results,image]=classifyUNetFun(roiobj,classif,classifier,varargin)

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

% pix=[]; PREVIOUS VERSION BEOFRE CHANGING MULTICHANNEL MODE BELOW
% for i=1:numel(channel) % loop on all selected channels
% pix=[pix roiobj.findChannelID(channel{i})];
% end

pix=roiobj.findChannelID(channel);

    if iscell(pix) %  MULTICHANNEL MODE
            pix=cell2mat(pix);
    end

%pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data

gfp=roiobj.image(:,:,pix,:);

if numel(frames)==0
    frames=1:numel(gfp(1,1,1,:));
end

% if numel(pix)==1
%     gfp=formatImage(gfp);
% end

% BEWARE : rather use formatted image in lstm .mat variable
% need to distinguish between formating for training versus validation
% function --> formatfordeepclassification

% check whether output is segmentation, proba, or postprocessing

switch classif.outputType
    case 'proba' % outputs proba of classes
        pixresults=[];
        for i=1:numel(classif.classes)
            pixresultstmp=findChannelID(roiobj,['results_' classif.strid '_' classif.classes{i}]); % gather all channels associated with proba

            if numel(pixresultstmp)==0 % channel does not exist, hence create them
                pixresults=[pixresults size(roiobj.image,3)];
            else
                pixresults=[pixresults pixresultstmp];
            end
        end

    otherwise %  outputs segmentation or segmentation after postprocessing
        pixresults=findChannelID(roiobj,['results_' classif.strid]);

        if numel(pixresults)==0 % channels do not exist, hence create them
            pixresults=size(roiobj.image,3);
        end
end


  param=[];

%gfp=uint16(zeros(size(gfp,1),size(gfp,2),3));

gfp=double(zeros(size(gfp,1),size(gfp,2),3,numel(frames)));

for fr=frames % remove the loop on frames here !!!! andtry ti use a gpu array
        gfp(:,:,:,fr)=roiobj.preProcessROIData(pix,fr,param);
end

      gfp=uint8(gfp*256);

    if size(gfp,1)<inputSize(1) | size(gfp,2)<inputSize(2)
        gfp=imresize(gfp,inputSize(1:2));
    end


if gpu==1
    [C,score,features]= semanticseg(gfp, net,'ExecutionEnvironment',"gpu");%,'Acceleration','mex'); % this is no longer required if we extract the probabilities from the previous laye

else
    [C,score,features]= semanticseg(gfp, net,'ExecutionEnvironment',"cpu");
end

image=roiobj.image;
           %   if size(gfp,1)<inputSize(1) | size(gfp,2)<inputSize(2)
                features=imresize(features,size(image,1:2));
                C=imresize(C,size(image,1:2));

             tmpout=uint16(zeros(size(roiobj.image(:,:,pixresults,frames))));



           % tmpout=uint16(zeros(size(roiobj.image(:,:,pixresults,fr))));

            switch classif.outputType
                    case 'proba' % outputs proba

                        for i=1:numel(classif.classes)
                           tmpout(:,:,i)=65535*features(:,:,i);
                        end

                    case 'segmentation'

                         for i=2:numel(classif.classes) % 1 st class is considered default class
                        BW=features(:,:,i)>0.9;
                        res=uint16(uint16(BW)*(i));
                         tmpout=tmpout+res;
                         end

                       tmpout(tmpout==0)=1; %fill background


                    case 'postprocessing'


                        if numel(classif.outputFun)==0
                            classif.outputFun='post';
                        end
                        if numel(classif.outputArg)==0
                            classif.outputArg={ 'threshold'  '0.9'};
                        end

                        tmpout= feval(classif.outputFun,features,classif.classes,classif.outputArg{:});


            end

            image(:,:,pixresults,frames)=tmpout;
     %   end

        results=roiobj.results;

        %roiobj.save;
        %roiobj.clear;
        fprintf('\n');
