function extractFluo(obj,varargin)
%This method of .fov extract the signal from the 'Channels' using the 'Method' and
%store them in obj.roi(r).results.classiid.fluo.max(c,t)
%

%Arguments:
%*'Method': **'full' computes the average of the kMaxPixels, the total and
%the mean pixel value of the whople image
%           **'cell' computes the fluo of channel 'Channels' with the mask
%           of Mask(2). Give 2 channels in 'Channels
%           **'nucleus' computes the fluo of channel 'Channels' with the mask
%           of MaskCell inter MaskNuc
%
%'kMaxPixels': numbers of pixels taken for the maxPixels method. Default=20
%*'Channels'
%'Mask': required for methods 'cell' (1 element) or 'nucleus' (2 elements)
%*'Rois'




kMaxPix=20;
rois=1:numel(obj.roi);
method='maxPixels';
channelSegCell=3;
channelSegNuc=4;

for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Method')
        method=varargin{i+1};
        if strcmp(method,'maxPixels') && strcmp(method,'mean') && strcmp(method,'cell')
            error('Please enter a valide method');
        end
    end
    
    %kMaxPixels
    if strcmp(varargin{i},'kMaxPixels')
        kMaxPix=varargin{i+1};
    end
    
    %MaskCell
    if strcmp(varargin{i},'ChannelSegCell')
        channelSegCell=varargin{i+1};
    end
    
    %MaskNuc
    if strcmp(varargin{i},'ChannelSegNuc')
        channelSegNuc=varargin{i+1};
    end       
    
%     %lastFrame
%     if strcmp(varargin{i},'lastFrame')
%         lastFrame=varargin{i+1};
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
%%

%if numel(obj.roi(rois(1)).results)~=0
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
%     classiid='tmp';
% end

%%
if strcmp(method,'full')
    for r=rois %to parfor
        obj.roi(r).load();
        lastFrame=numel(obj.roi(r).image(1,1,1,:));
        if ~exist('channels','var')
            channels=1:numel(obj.roi(r).image(1,1,:,1));
            if numel(channels)>1
                channels=2:numel(channels); %avoid channel 1 that is mostof the time not fluo
            end
        end
        for c=channels
            for t=1:lastFrame
                obj.roi(r).results.(classiid).fluo.full.maxf(c,t)=mean(maxk( reshape(obj.roi(r).image(:,:,c,t),[],1) ,kMaxPix));
                obj.roi(r).results.(classiid).fluo.full.meanf(c,t)=mean(reshape(obj.roi(r).image(:,:,c,t),[],1));
                obj.roi(r).results.(classiid).fluo.full.totalf(c,t)=sum(reshape(obj.roi(r).image(:,:,c,t),[],1));
            end
        end
        disp(['Average signal of ' num2str(kMaxPix) 'max pixels, mean and total signal was computed and added to roi(' num2str(r) ').results.' num2str(classiid) '.fluo.full'])
        clear im
    end
end


% 
% if strcmp(method,'mean')
%     for r=rois %to parfor
%         obj.roi(r).load();
%         lastFrame=numel(obj.roi(r).image(1,1,1,:));
%         if ~exist('channels','var')
%             channels=1:numel(obj.roi(r).image(1,1,:,1));
%             if numel(channels)>1
%                 channels=2:numel(channels); %avoid channel 1 that is mostof the time not fluo
%             end
%         end
%         for c=channels
%             for t=1:lastFrame
%                 obj.roi(r).results.(classiid).fluo.full.meanf(c,t)=mean(reshape(obj.roi(r).image(:,:,c,t),[],1));
%             end
%         end
%         disp(['Average signal was computed and added to roi(' num2str(r) ').results.' num2str(classiid) '.fluo.meanf\n'])
%         clear im
%     end
% end

if strcmp(method,'cell')
    if ~exist('channels','var')
        error('Indicate channel on which to extract the signal');
    end
    classMother=0;
    classBckg=0;
    strM='';
    strB='';
    for r=rois %to parfor
        obj.roi(r).load();
        
        %find the classi used to segmente
        chans=obj.roi(rois(1)).display.channel;
        if contains(chans{channelSegCell},'results_')
        classiid=extractAfter(chans{channelSegCell},'results_');
        else
            error('classi name not found with the given ChannelSegCell')
        end
         
        %find the class of the mother, ask it only once.
        if classMother==0
            for i=1:numel(obj.roi(r).classes)
                strM=[strM num2str(i) ' - ' obj.roi(r).classes{i} ';'];
            end
        prompt=(['Indicate the --number-- of the class corresponding to the mother cell among: ' strM]);
        classMother=input(prompt);
        
            for i=1:numel(obj.roi(r).classes)
                strB=[strB num2str(i) ' - ' obj.roi(r).classes{i} ';'];
            end
        prompt=(['Indicate the --number-- of the class corresponding to the background among: ' strB]);
        classBckg=input(prompt);        
        end
        
        %extract fluo for each given channel
        lastFrame=numel(obj.roi(r).image(1,1,channels(1),:));
        for c=channels
            for t=1:lastFrame
                im=obj.roi(r).image(:,:,c,t);
                maskCell=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskBckg=zeros(size(im),'uint16');
                
                maskCell=obj.roi(r).image(:,:,channelSegCell,t);
                maskMother=(maskMother+maskCell.*uint16(maskCell==classMother))./classMother;
                maskBckg=(maskBckg+maskCell.*uint16(maskCell==classBckg))./classBckg;
                
                maskedMother=im.*maskMother;
                maskedBckg=im.*maskBckg;

                obj.roi(r).results.(classiid).fluo.cell(c,t).totalf=sum(maskedMother(:))-mean(maskedBckg(:));
                obj.roi(r).results.(classiid).fluo.cell(c,t).meanf=obj.roi(r).results.(classiid).fluo.cell(c,t).totalf/sum(maskMother(:));
            end
        end
        disp(['Average and total signal of mothercell was computed and added to roi(' num2str(r) ').results.' num2str(classiid) '.fluo.cell\n'])
    end
end

