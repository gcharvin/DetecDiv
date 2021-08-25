function extractSignal(obj,type,inputvarargin)
%This method of .fov extract the signal from the 'Channels' using the 'Method' and
%store them in obj.roi(r).results.classiid.fluo.max(c,t)


%Arguments:
%*'Method': **'full' computes the average of the kMaxPixels, the total and
%the mean pixel value of the whople image
%           **'cell' computes the fluo of channel 'Channels' with the mask
%           of Mask(2). Give 2 channels in 'Channels. Also extracts the
%           volume of the cell.
%           **'nucleus' computes the fluo of channel 'Channels' with the mask
%           of MaskCell inter MaskNuc. Also extracts the
%           volume of the cell and of the nucleus.
%           **'volume': computes the number of pixels of class mother
%
%'kMaxPixels': numbers of pixels taken for the maxPixels method. Default=20

%*'Rois': rois array to extract the signal from

kMaxPix=20;
rois=1:numel(obj.roi);
%method='full';
%channelSegCell=3;
%channelSegNuc=4;

for i=1:numel(inputvarargin)
    %Method
    if strcmp(inputvarargin{i},'Method')
        method=inputvarargin{i+1};
        if strcmp(method,'full') && strcmp(method,'cell') && strcmp(method,'nucleus')
            error('Please enter a valid method');
        end
    end
    
    %kMaxPixels
    if strcmp(inputvarargin{i},'kMaxPixels')
        kMaxPix=inputvarargin{i+1};
    end
    
%     %MaskCell
%     if strcmp(inputvarargin{i},'ChannelSegCell')
%         channelSegCell=inputvarargin{i+1};
%     end
    
    %MaskNuc
%     if strcmp(inputvarargin{i},'ChannelSegNuc')
%         channelSegNuc=inputvarargin{i+1};
%     end       
    
%     %lastFrame
%     if strcmp(inputvarargin{i},'lastFrame')
%         lastFrame=inputvarargin{i+1};
%     end
    
    %Rois
    if strcmp(inputvarargin{i},'Rois')
        rois=inputvarargin{i+1};
    end
    
    %Channels
    if strcmp(inputvarargin{i},'Channels')
        channels=inputvarargin{i+1};
    end
end
    
%% 
if strcmp(method,'full')
%     if type=='fov'
%         if numel(obj.roi(rois(1)).results)~=0
%             classiname=fieldnames(obj.roi(rois(1)).results);
%             str=[];
%             for i=1:numel(classiname)
%                 str=[str num2str(i) ' - ' classiname{i} ';'];
%             end
%             prompt=['Choose which classi : ' str];
%             classiidsNum=input(prompt);
%             if numel(classiidsNum)==0
%                 classiidsNum=numel(classiname);
%             end
%             classiname=classiname{classiidsNum};
%         else
%             classiname='tmp';
%         end
%         
%     elseif type=='classi'
%         classiname=obj.strid; %works only for extractFluo as a classi method.
%     end

    prompt=['Type the name of the result classif: (Default: full_' kMaxPix 'maxPixels) '];
    classiname=input(prompt);
    if isempty(classiname)
        classiname=['full_' kMaxPix 'maxPixels'];
    end
    
    chans=obj.roi(rois(1)).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';'];
    end

    prompt=['Which channel to extract the signal from? (Default: [2:number of channels])' newline str];
    channels=input(prompt);
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
                obj.roi(r).results.signal.full.(classiname).maxfluo(c,t)=mean(maxk( reshape(obj.roi(r).image(:,:,c,t),[],1) ,kMaxPix));
                obj.roi(r).results.signal.full.(classiname).meanfluo(c,t)=mean(reshape(obj.roi(r).image(:,:,c,t),[],1));
                obj.roi(r).results.signal.full.(classiname).totalfluo(c,t)=sum(reshape(obj.roi(r).image(:,:,c,t),[],1));
            end
        end
        disp(['Average signal of ' num2str(kMaxPix) 'max pixels, mean and total signal was computed and added to roi(' num2str(r) ').results.' num2str(classiname) '.fluo.full'])
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


%% extract only the volume of the cell
if strcmp(method,'volume')
    chans=obj.roi(rois(1)).display.channel;
    
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} '; '];
    end
    prompt=['Which channel contains the mask of the cells?' newline str];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the mask of the cells');
    end
    
    classidMother=0;
    classidBckg=0;
    strM='';
    strB='';
    for r=rois %to parfor
        obj.roi(r).load();
        
        %find the classi used to segmente
        if contains(chans{channelSegCell},'results_')
            classiname=extractAfter(chans{channelSegCell},'results_');
        else
            %           classiid=chans{channelSegCell};
            error('classi name not found with the given mask channel')
        end
        
        %find the class of the mother, ask it only once.
        if classidMother==0
%             for i=1:max(obj.roi(r).image(:,:,channelSegCell,1))
%                 strM=[strM num2str(i) ' - ' obj.roi(r).classes{i} ';'];
%             end
            prompt=(['Indicate the --number-- of the class corresponding to the mother cell for the classi: ' classiname]);
            classidMother=input(prompt);
        end
        
        %extract volume
        lastFrame=numel(obj.roi(r).image(1,1,channels(1),:));
        for t=1:lastFrame
            im=obj.roi(r).image(:,:,c,t);
            maskTotal=zeros(size(im),'uint16');
            maskMother=zeros(size(im),'uint16');
            
            maskTotal=obj.roi(r).image(:,:,channelSegCell,t); %mask containing all the classes
            maskMother=(maskMother+maskTotal.*uint16(maskTotal==classidMother))./classidMother;
            
            obj.roi(r).results.signal.cell.(classiname).volume(t)=numel(maskedMother(:));
        end
    end
    disp(['Volume mothercell was computed and added to roi(' num2str(r) ').results.' num2str(classiname) '.signal.volume\n'])
end

%%
if strcmp(method,'cell')
    chans=obj.roi(rois(1)).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';  '];
    end

    prompt=['Which channel(s) to extract the signal from?' newline str];
    channels=input(prompt);
    if ~exist('channels','var')
        error('Indicate channel(s) from which to extract the signal');
    end
    
    prompt=['Which channel contains the mask of the cells?' newline str];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the mask of the cells');
    end
    
    classidMother=0;
    classidBckg=0;
    strM='';
    strB='';
    for r=rois %to parfor
        obj.roi(r).load();
        
        %find the classi used to segmente
        if contains(chans{channelSegCell},'results_')
        classiname=extractAfter(chans{channelSegCell},'results_');
        else
%           classiid=chans{channelSegCell};
            error('classi name not found with the given mask channel')
        end
         
        %find the class of the mother, ask it only once.
        if classidMother==0
%             for i=1:numel(obj.roi(r).classes)
%                 strM=[strM num2str(i) ' - ' obj.roi(r).classes{i} ';'];
%             end
        prompt=(['Indicate the --number-- of the class corresponding to the mother in the classi: ' classiname]);
        classidMother=input(prompt);
        
%             for i=1:numel(obj.roi(r).classes)
%                 strB=[strB num2str(i) ' - ' obj.roi(r).classes{i} ';'];
%             end
        prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiname]);
        classidBckg=input(prompt);        
        end
        
        %extract fluo for each given channel
        lastFrame=numel(obj.roi(r).image(1,1,channels(1),:));
        for c=channels
            for t=1:lastFrame
                im=obj.roi(r).image(:,:,c,t);
                maskTotal=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskBckg=zeros(size(im),'uint16');
                
                maskTotal=obj.roi(r).image(:,:,channelSegCell,t); %mask containing all the classes
                maskMother=(maskMother+maskTotal.*uint16(maskTotal==classidMother))./classidMother;
                maskBckg=(maskBckg+maskTotal.*uint16(maskTotal==classidBckg))./classidBckg;
                
                maskedMother=im.*maskMother;
                maskedBckg=im.*maskBckg;
                
                obj.roi(r).results.signal.cell.(classiname).volume(t)=numel(maskedMother(:));
                obj.roi(r).results.signal.cell.(classiname).totalfluo(c,t)=sum(maskedMother(:))-mean(maskedBckg(:));
                obj.roi(r).results.signal.cell.(classiname).meanfluo(c,t)=obj.roi(r).results.(classiname).fluo.cell(c,t).totalf/sum(maskMother(:));
            end
        end
        disp(['Average and total signal of mothercell was computed and added to roi(' num2str(r) ').results.' num2str(classiname) '.fluo.cell\n'])
    end
end


%% nucleus


%TODO
if strcmp(method,'nucleus')
    prompt='Which channel(s) to extract the signal from?';
    channels=input(prompt);
    if ~exist('channels','var')
        error('Indicate channel(s) from which to extract the signal');
    end
    
    prompt='Which channel contains the mask of the cells?';
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the mask of the cells');
    end
    
    prompt='Which channel contains the mask of the nucleus?';
    channelSegCell=input(prompt);
    if ~exist('channelSegNucleus','var')
        error('Indicate which channel contains the mask of the cells');
    end
    
    %extract mothercell
    classidMother=0;
    classidBckg=0;
    strM='';
    strB='';
    for r=rois %to parfor
        obj.roi(r).load();
        
        %find the classi used to segmente
        chans=obj.roi(rois(1)).display.channel;
        if contains(chans{channelSegCell},'results_')
        classiname=extractAfter(chans{channelSegCell},'results_');
        else
%           classiid=chans{channelSegCell};
            error('classi name not found with the given mask channel')
        end
         
        %find the classid of the mother, ask it only once.
        if classidMother==0
%             for i=1:numel(obj.roi(r).classes)
%                 strM=[strM num2str(i) ' - ' obj.roi(r).classes{i} ';'];
%             end
        prompt=(['Indicate the --number-- of the class corresponding to the mother cell in the classi: ' classiname]);
        classidMother=input(prompt);
        
%             for i=1:numel(obj.roi(r).classes)
%                 strB=[strB num2str(i) ' - ' obj.roi(r).classes{i} ';'];
%             end
        prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiname]);
        classidBckg=input(prompt);        
        end
        
        %find the classid of the nucleus, ask it only once.
        if classidNucleus==0
%             for i=1:numel(obj.roi(r).classes)
%                 strN=[strN num2str(i) ' - ' obj.roi(r).classes{i} ';'];
%             end
        prompt=(['Indicate the --number-- of the class corresponding to the nucleus in the classi: ' classiname]);
        classidNucleus=input(prompt);       
        end
        
        %extract fluo for each given channel
        lastFrame=numel(obj.roi(r).image(1,1,channels(1),:));
        for c=channels
            for t=1:lastFrame
                im=obj.roi(r).image(:,:,c,t);
                maskTotal=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskBckg=zeros(size(im),'uint16');
                maskNucleus=zeros(size(im),'uint16');
                
                maskTotal=obj.roi(r).image(:,:,channelSegCell,t); %mask containing all the classes
                maskMother=(maskMother+maskTotal.*uint16(maskTotal==classidMother))./classidMother;
                maskBckg=(maskBckg+maskTotal.*uint16(maskTotal==classidBckg))./classidBckg;
                maskNucleus=(maskNucleus+maskTotal.*uint16(maskTotal==classNucleus))./classidBckg;
                maskNucleusMother=maskMother.*maskNucleus;
                
                maskedNucleusMother=im.*maskNucleusMother;
                maskedBckg=im.*maskBckg;
                
                obj.roi(r).results.signal.nucleus.(classiname).volume(t)=numel(maskNucleusMother(:));
                obj.roi(r).results.signal.nucleus.(classiname).totalfluo(c,t)=sum(maskedNucleusMother(:))-mean(maskedBckg(:));
                obj.roi(r).results.signal.nucleus.(classiname).meanfluo(c,t)=obj.roi(r).results.(classiname).fluo.cell(c,t).totalf/sum(maskMother(:));
            end
        end
        disp(['Average and total signal of mothercell was computed and added to roi(' num2str(r) ').results.' num2str(classiname) '.fluo.cell\n'])
    end
end
end
