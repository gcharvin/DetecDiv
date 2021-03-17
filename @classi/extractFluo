function extractFluo(obj,vargin)
%This function extract the signal from the 'Channels' using the 'Method' and
%store them in obj.roi(r).results.classiid.fluo.max(c,t)

%Arguments:
%'Method': 'maxPixels' computes the average of the kMaxPixels. // 'mean'
%'Channels'
%'Frames'
%'Rois'



classiid=fieldnames(obj.roi.results);
str=[];
for i=1:numel(classiid)
    str=[str num2str(i) ' - ' classiid{i} ';'];
end
prompt=['Choose which classi : ' str];
classiid=input(prompt);
if numel(classiid)==0
                classiids=numel(classiid);
end


for i=1:numel(varargin)
    
    if strcmp(varargin{i},'Method')
        method=varargin{i+1};
    else
        error('You must indicate a method. Use the Method argument')
    end
    
    if strcmp(varargin{i},'Frames')
        frames=varargin{i+1};
    else
        frames=1:numel(obj.srclist{1}); % take the number of frames from the image list 
    end
    
    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    else 
        rois=1:numel(obj.roi);
    end
    
    if strcmp(varargin{i},'Channels')
        channels=varargin{i+1};
    else
        channels=1:numel(obj.srcpath);
        if numel(channels)>1
            channels=2:numel(obj.srcpath); %avoid channel 1 that is mostof the time not fluo
        end
    end
end

%%
if strcmp(method,'maxPixels')
    kMaxPix=20;
    for r=1:rois %to parfor
        load(obj.roi(r).path)
        for c=1:channels
            for t=1:frames
                obj.roi(r).results.classiids{classiid}.fluo.max(c,t)=mean(maxk( reshape(im(:,:,c,t),[],1) ,kMaxPix));
            end
        end
        disp(['Average signal of ' kMaxPix 'max pixels was computed and added to roi(' r ').results.' obj.roi(r).results.classiids{classiid} '.fluo.max'])
        clear im
    end
end

if strcmp(method,'mean')
    for r=1:rois %to parfor
        load(obj.roi(r).path)
        for c=1:channels
            for t=1:frames
                obj.roi(r).results.classiids{classiid}.fluo.meanf(c,t)=mean(reshape(im(:,:,c,t),[],1));
            end
        end
        disp(['Average signal was computed and added to roi(' r ').results.' obj.roi(r).results.classiids{classiid} '.fluo.meanf\n'])
        clear im
    end
end
    
