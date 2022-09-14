function output=formatLSTMTrainingSet(foldername,classif,rois,varargin)


Frames=[];
for i=1:numel(varargin)
    if strcmp(varargin{i},'Frames')
        Frames=varargin{i+1};
    end
end

output=0;
if ~isfolder([classif.path '/' foldername '/images'])
    mkdir([classif.path '/' foldername], 'images');
end

if ~isfolder(fullfile(classif.path, 'TrainingValidation'))
    mkdir(classif.path,'TrainingValidation');
end


if strcmp(classif.category{1},'LSTM')
    for i=1:numel(classif.classes)
        if ~isfolder([classif.path '/' foldername '/images/' classif.classes{i}])
            mkdir([classif.path '/' foldername '/images'], classif.classes{i});
        end
    end
end

if strcmp(classif.category{1},'LSTM Regression')
    % regression
    if ~isfolder([classif.path '/' foldername '/response/'])
        mkdir([classif.path '/' foldername], 'response');
    end
end


if ~isfolder([classif.path '/' foldername '/timeseries'])
    mkdir([classif.path '/' foldername], 'timeseries');
end
        
cltmp=classif.roi;

disp('Starting parallelized jobs for data formatting....')

warning off all
%for i=rois

channel=classif.channelName;

disp(['These ROIs will be processed : ' num2str(rois)]);



for i=1:numel(rois)
      emptyFrame=[];
    disp(['Launching ROI ' num2str(i) :' processing...'])
    
    if numel(cltmp(rois(i)).image)==0
        cltmp(rois(i)).load; % load image sequence
    end
    
    % normalize intensity levels
    
    pix=cltmp(rois(i)).findChannelID(channel);

    if iscell(pix)
            pix=cell2mat(pix);
    end
    

    %  pix=find(cltmp(i).channelid==classif.channel(1)); % find channel
    im=cltmp(rois(i)).image(:,:,pix,:);


    if numel(Frames)==0
        fra=1:size(im,4);
    else
        fra=Frames;
    end

%       if isfield(cltmp(rois(i)).train.(classif.strid),'bounds') % restricting frames used on a per-ROI basis
%                     minet=cltmp(rois(i)).train.(classif.strid).bounds(1); 
%                     maxet=cltmp(rois(i)).train.(classif.strid).bounds(2);
% 
%                     minet=max(minet,fra(1));
%                     if maxet==0
%                     maxet=max(maxet,fra(end));
%                     else
%                     maxet=min(maxet,fra(end));
%                     end
% 
%                     fra=minet:maxet;
%         end

    %fra
    
    if numel(classif.trainingset)==0
        param.nframes=1; % number of temporal frames per frame
    else
        param.nframes=classif.trainingset; % number of temporal frames per frame
    end
    
    param=[];
    imtest=cltmp(rois(i)).preProcessROIData(pix,1,param); % done to determine image size
   
    if numel(imtest)==0 % preprocessing failed 
            disp('Pre-processing failed, likely because the image is void !');
            continue; 
    end
  
    vid=uint8(zeros(size(imtest,1),size(imtest,2),3,1));
    
    if strcmp(classif.category{1},'LSTM')%classif.typeid~=12 % only for  image classif
        pixb=numel(cltmp(rois(i)).train.(classif.strid).id(fra));
        pixa=find(cltmp(rois(i)).train.(classif.strid).id(fra)==0);
        
        if numel(pixa)>0 || numel(pixa)==0 && pixb==0 % some images are not labeled, quitting ...
            disp('Error: some images are not labeled in this ROI - LSTM requires all images to be labeled in the timeseries!');
            continue
        end
        
        % 'pasok'
        
        lab= categorical(cltmp(rois(i)).train.(classif.strid).id(fra),1:numel(classif.classes),classif.classes); % creates labels for classification
    else
        lab=[];
    end
    
    if strcmp(classif.category{1},'LSTM') % image lstm classification
        reverseStr = '';               
        
        cc=1;

        for j=fra
            
            tmp=cltmp(rois(i)).preProcessROIData(pix,j,param);   

                if numel(tmp)==0 % preprocessing failed 
            disp('Pre-processing failed, likely because the image is void !');
            emptyFrame=1;
            break; 
                end

            %figure, imshow(tmp);
            %pause;
            %close;      
     
            vid(:,:,:,cc)=uint8(256*tmp);
            
        %    figure, imshow(vid(:,:,:,cc),[])
          %  pause

            tr=num2str(j);
            while numel(tr)<4
                tr=['0' tr];
            end
            
            if classif.output==0
                cmp=cltmp(rois(i)).train.(classif.strid).id(j); % seuquence-to-sequence classif
            else
                cmp=cltmp(rois(i)).train.(classif.strid).id; % sequence-to-one classif
            end
            
            if cmp~=0 % if training is done
                % if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
                imwrite(tmp,[classif.path '/' foldername '/images/' classif.classes{cmp} '/' cltmp(rois(i)).id '_frame_' tr '.tif']);
                output=output+1;
                % end
            end
            
            msg = sprintf('Processing frame: %d / %d for ROI %s', cc, numel(fra),cltmp(rois(i)).id); %Don't forget this semicolon
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));

            cc=cc+1;
        end

    end
    
    if strcmp(classif.category{1},'LSTM Regression') % image lstm classification
        % image regression
        tmp=zeros(size(im,1),size(im,2),3,1);

        cc=1;

        for j=fra
            % tmp(:,:,:j)=im(:,:,:,j);
            
            tmp=cltmp(rois(i)).preProcessROIData(pix,j,param);
            vid(:,:,:,cc)=uint8(256*tmp);
            cc=cc+1;
        end
        
        %  if cltmp(i).train.(classif.strid).id(j)~=-1 % if training is done
        parsaveim([classif.path '/' foldername '/images/' cltmp(rois(i)).id '.mat'],tmp);
        
        parsaveresp([classif.path '/' foldername '/response/' cltmp(rois(i)).id '.mat'],cltmp(rois(i)).train.(classif.strid).id(fra));
        output=output+1;
        %   end
    end
    
    fprintf('\n');
    
    deep=cltmp(rois(i)).train.(classif.strid).id(fra);
%     aah=vid;
%      figure, imshow(vid(:,:,:,87),[]);
%      save('test.mat','aah')
    % assignin('base','test',vid);
   %  size(vid)


   if numel(emptyFrame)==0
    parsave([classif.path '/' foldername '/timeseries/lstm_labeled_' cltmp(rois(i)).id '.mat'],deep,vid,lab);
    
    cltmp(rois(i)).save;
   else
    disp('This ROI was not saved because it has empty frames');
   end
    
    disp(['Processing ROI: ' num2str(rois(i)) ' ... Done !'])
end


warning on all;

for i=rois
    cltmp(i).clear; %%% remove !!!!
end


function parsaveim(fname, im)
eval(['save  ''''  '  fname  ''''  '  im']);

function parsaveresp(fname, response)
eval(['save  ' '''' fname  ''''  '  response']);

function parsave(fname, deep,vid,lab)

%   fname
eval(['save  ' ''''  fname  ''''  '  deep vid lab']);


