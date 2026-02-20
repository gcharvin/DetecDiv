function detectFluoPattern(obj,varargin)
%This function detects if a fluoThreshold has been reached for at least
%frameThreshold frames in obj.roi(r).results.classiid.fluo.methodf(c,t) for the 'Channels' c using the 'Method'.
%Stores the info in fov.flaggedROIs
%obj.extractFluo must have been run beforehand.

%Arguments:
%*'Method': 'full' check .fluo.full.maxf // 'mean' checks the fluo.meanf
%*'Channels'
%*'Frames'
%*'Rois'
%*'fluoThreshold'
%*'frameThreshold' number of frames to be above fluoThreshold

fluoThreshold=500;
frameThreshold=15;
frames=1:numel(obj.srclist{1}); % take the number of frames from the image list 
rois=1:numel(obj.roi);
method='full';
channels=1:numel(obj.srcpath);
if numel(channels)>1
    channels=2:numel(obj.srcpath); %avoid channel 1 that is mostof the time not fluo
end

for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Method')
        method=varargin{i+1};
        if strcmp(method,'full') %&& strcmp(method,'mean')
            error('Please enter a valide method');
        end
    end
    %fluoThresold
    if strcmp(varargin{i},'fluoThreshold')
        fluoThreshold=varargin{i+1};
    end

    %timeThresold
    if strcmp(varargin{i},'frameThreshold')
        frameThreshold=varargin{i+1};
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

%%
if strcmp(method,'full')
    %pick classi
    if numel(obj.roi(rois(1)).results.signal.full)~=0
        classiname=fieldnames(obj.roi(rois(1)).results.signal.full);
        str=[];
        for i=1:numel(classiname)
            str=[str num2str(i) ' - ' classiname{i} ';'];
        end
        prompt=['Choose which classi : ' str];
        classiid=input(prompt);
        if numel(classiid)==0
            classiid=numel(classiname);
        end
        classiname=classiname{classiid};
    else
        error('You must extract the fluo of the ROI before running this method. See .extractFluo');
    end
    
    
    obj.flaggedROIs=[];
    for r=rois %to parfor
        for c=channels
            flagFluo=0;
            for t=frames
                if numel(obj.roi(r).results.signal.full.(classiname).meankmaxfluo)==0
                    error('You must extract the meanfluo of the ROI before running this method. See .extractFluo. At least one frame has not been extracted');
                elseif obj.roi(r).results.signal.full.(classiname).meankmaxfluo(c,t)>fluoThreshold
                    flagFluo=flagFluo+1;
                end
            end
            if flagFluo>frameThreshold
                if ~ismember(r,obj.flaggedROIs) % to avoid redundancy in case 2 channels are positive
                    obj.flaggedROIs=[obj.flaggedROIs r];
                end
                disp(['ROI' num2str(r) ' is positive for channel ' num2str(c)])
            else
                disp(['ROI' num2str(r) ' is negative for channel ' num2str(c)])
            end
        end
        fprintf('\n')
    end
end




% if strcmp(method,'mean')
%     obj.flaggedROIs=[];
%     for r=rois %to parfor
%         for c=channels
%             flagFluo=0;
%             for t=frames
%                 if numel(obj.roi(r).results.(classiid).fluo.full.meanf)==0
%                     error('You must extract the meanfluo of the ROI before running this method. See .extractFluo. At least one frame has not been extracted');
%                 elseif obj.roi(r).results.(classiid).fluo.full.meanf(c,t)>fluoThreshold
%                     flagFluo=flagFluo+1;
%                 end
%             end
%             if flagFluo>frameThreshold
%                 if ~ismember(r,obj.flaggedROIs) % to avoid redundancy in case 2 channels are positive
%                     obj.flaggedROIs=[obj.flaggedROIs r];
%                 end
%                 disp(['ROI' num2str(r) ' is positive for channel ' num2str(c)])
%             else
%                 disp(['ROI' num2str(r) ' is negative for channel ' num2str(c)])
%             end
%         end
%         fprintf('\n')
%     end
% end