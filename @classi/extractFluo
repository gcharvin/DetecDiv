function extractFluo(obj,varargin)
%This method of .classification extract the signal from the 'Channels' using the 'Method' and
%store them in obj.roi(r).results.classiid.fluo.max(c,t)

%Arguments:
%*'Method': 'maxPixels' computes the average of the kMaxPixels. // 'mean'
%'kMaxPixels': numbers of pixels taken for the maxPixels method. Default=20
%*'Channels'
%*'Rois'




kMaxPix=20;
rois=1:numel(obj.roi);
method='maxPixels';


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
    
%     %Frames
%     if strcmp(varargin{i},'Frames')
%         frames=varargin{i+1};
%     end
    
    %Rois
    if strcmp(varargin{i},'Rois')
        rois=varargin{i+1};
    end
    
    %Channels
    if strcmp(varargin{i},'Channels')
        channels=varargin{i+1};
    end
end

% if numel(obj.roi(rois(1)).results)~=0
%     classiid=fieldnames(obj.roi(rois(1)).results);
%     str=[];
%     for i=1:numel(classiid)
%         str=[str num2str(i) ' - ' classiid{i} ';'];
%     end
%     prompt=['Choose which classi : ' str];
%     classiidsNum=input(prompt);
%     if numel(classiidsNum)==0
%        classiidsNum=numel(classiid);
%     end
%     classiid=classiid{classiidsNum};
% else
    classiid=obj.strid;
% end

%%
if strcmp(method,'maxPixels')
    for r=rois %to parfor
        obj.roi(r).load();
        frames=numel(obj.roi(r).image(1,1,1,:));
        if ~exist('channels','var')
            channels=1:numel(obj.roi(r).image(1,1,:,1));
            if numel(channels)>1
                channels=2:numel(channels); %avoid channel 1 that is mostof the time not fluo
            end
        end
        for c=channels
            for t=1:frames
                obj.roi(r).results.(classiid).fluo.maxf(c,t)=mean(maxk( reshape(obj.roi(r).image(:,:,c,t),[],1) ,kMaxPix));
            end
        end
        disp(['Average signal of ' num2str(kMaxPix) 'max pixels was computed and added to roi(' num2str(r) ').results.' num2str(classiid) '.fluo.maxf'])
        clear im
    end
end

if strcmp(method,'mean')
    for r=rois %to parfor
        obj.roi(r).load();
        frames=numel(obj.roi(r).image(1,1,1,:));
        if ~exist('channels','var')
            channels=1:numel(obj.roi(r).image(1,1,:,1));
            if numel(channels)>1
                channels=2:numel(channels); %avoid channel 1 that is mostof the time not fluo
            end
        end
        for c=channels
            for t=1:frames-1
                obj.roi(r).results.(classiid).fluo.meanf(c,t)=mean(reshape(obj.roi(r).image(:,:,c,t),[],1));
            end
        end
        disp(['Average signal was computed and added to roi(' num2str(r) ').results.' num2str(classiid) '.fluo.meanf\n'])
        clear im
    end
end

