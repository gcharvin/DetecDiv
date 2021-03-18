function extractFluo(obj,varargin)
%This function extract the signal from the 'Channels' using the 'Method' and
%store them in obj.roi(r).results.classiid.fluo.max(c,t)

%Arguments:
%*'Method': 'maxPixels' computes the average of the kMaxPixels. // 'mean'
%'kMaxPixels': numbers of pixels taken for the maxPixels method. Default=20
%*'Channels'
%*'Frames'
%*'Rois'




kMaxPix=20;
frames=1:numel(obj.srclist{1}); % take the number of frames from the image list 
rois=1:numel(obj.roi);
method='mean';
channels=1:numel(obj.srcpath);
if numel(channels)>1
    channels=2:numel(obj.srcpath); %avoid channel 1 that is mostof the time not fluo
end

for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Method')
        method=varargin{i+1};
        if strcmp(method,'maxPixels') && strcmp(method,'mean')
            error('Please enter a valide method');
        end
    end
    
    %kMaxPixels
    if strcmp(varargin{i},'kMaxPixels')
        kMaxPix=varargin{i+1};
    end
    
    %Frames
    if strcmp(varargin{i},'Frames')
        frames=varargin{i+1};
    end
    
    %Rois
    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    end
    
    %Channels
    if strcmp(varargin{i},'Channels')
        channels=varargin{i+1};
    end
end

if numel(obj.roi(rois(1)).results)~=0
    classiid=fieldnames(obj.roi(rois(1)).results);
    str=[];
    for i=1:numel(classiid)
        str=[str num2str(i) ' - ' classiid{i} ';'];
    end
    prompt=['Choose which classi : ' str];
    classiidsNum=input(prompt);
    if numel(classiidsNum)==0
       classiidsNum=numel(classiid);
    end
else
    classiid={'fovtmp'};
    classiidsNum=1;
end
%%
if strcmp(method,'maxPixels')
    for r=rois %to parfor
        obj.roi(r).load();
        for c=channels
            for t=frames
                obj.roi(r).results.(classiid{classiidsNum}).fluo.maxf(c,t)=mean(maxk( reshape(obj.roi(r).image(:,:,c,t),[],1) ,kMaxPix));
            end
        end
        disp(['Average signal of ' kMaxPix 'max pixels was computed and added to roi(' r ').results.' classiid{classiidsNum} '.fluo.maxf'])
        clear im
    end
end

if strcmp(method,'mean')
    for r=rois %to parfor
        obj.roi(r).load();
        for c=channels
            for t=frames
                obj.roi(r).results.(classiid{classiidsNum}).fluo.meanf(c,t)=mean(reshape(obj.roi(r).image(:,:,c,t),[],1));
            end
        end
        disp(['Average signal was computed and added to roi(' r ').results.' classiid{classiidsNum} '.fluo.meanf\n'])
        clear im
    end
end
