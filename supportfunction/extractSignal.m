function extractSignal(obj,type,inputvarargin)
%This method of .fov extract the signal from the 'Channels' using the 'Method' and
%store them in obj.roi(r).results.classiid.fluo.max(c,t)


%Arguments:
%*'Method': **'full' computes the average of the kMaxPixels, the total and
%the mean pixel value of the whople image
%           **'cell' computes the fluo of channel 'Channels' with the mask
%           of Mask(2). Give 2 channelsExtract in 'Channels. Also extracts the
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
        channelsExtract=inputvarargin{i+1};
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

    prompt=['Which channel to extract the signal from? (Default: [2:number of channelsExtract])' newline str];
    channelsExtract=input(prompt);
    for r=rois %to parfor
        obj.roi(r).load();
        lastFrame=numel(obj.roi(r).image(1,1,1,:));
        if ~exist('channelsExtract','var')
            channelsExtract=1:numel(obj.roi(r).image(1,1,:,1));
            if numel(channelsExtract)>1
                channelsExtract=2:numel(channelsExtract); %avoid channel 1 that is mostof the time not fluo
            end
        end
        for c=channelsExtract
            for t=1:lastFrame
                %init/reset
                obj.roi(r).results.signal.full.(classiname).maxfluo(c,t)=NaN;
                obj.roi(r).results.signal.full.(classiname).meanfluo(c,t)=NaN;
                obj.roi(r).results.signal.full.(classiname).totalfluo(c,t)=NaN;
                %fill, reshaped used to make it line
                obj.roi(r).results.signal.full.(classiname).maxfluo(c,t)=mean(maxk( reshape(obj.roi(r).image(:,:,c,t),[],1) ,kMaxPix));
                obj.roi(r).results.signal.full.(classiname).meanfluo(c,t)=mean(reshape(obj.roi(r).image(:,:,c,t),[],1));
                obj.roi(r).results.signal.full.(classiname).totalfluo(c,t)=sum(reshape(obj.roi(r).image(:,:,c,t),[],1));
            end
        end
        disp(['Average signal of ' num2str(kMaxPix) 'max pixels, mean and total signal was computed and added to roi(' num2str(r) ').results.signal.full' num2str(classiname)])
        clear im
    end
end

% 
% if strcmp(method,'mean')
%     for r=rois %to parfor
%         obj.roi(r).load();
%         lastFrame=numel(obj.roi(r).image(1,1,1,:));
%         if ~exist('channelsExtract','var')
%             channelsExtract=1:numel(obj.roi(r).image(1,1,:,1));
%             if numel(channelsExtract)>1
%                 channelsExtract=2:numel(channelsExtract); %avoid channel 1 that is mostof the time not fluo
%             end
%         end
%         for c=channelsExtract
%             for t=1:lastFrame
%                 obj.roi(r).results.(classiid).fluo.full.meanf(c,t)=mean(reshape(obj.roi(r).image(:,:,c,t),[],1));
%             end
%         end
%         disp(['Average signal was computed and added to roi(' num2str(r) ').results.' num2str(classiid) '.fluo.meanf'])
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
    prompt=['Which channel contains the MASK of the CELLS?' newline str];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the MASK of the CELLS');
    end

    for r=rois %to parfor
        obj.roi(r).load();
        
        %find the classi used to segmente
        if contains(chans{channelSegCell},'results_')
            classiname=extractAfter(chans{channelSegCell},'results_');
        else
            %           classiid=chans{channelSegCell};
            error('classi name not found with the given mask channel')
        end
        
        %class of the mother, ask it only once.
            prompt=(['Indicate the --number-- of the class corresponding to the mother cell for the classi: ' classiname ' (Default: 2) ' newline]);
            classidMother=input(prompt);
            if numel(classidMother)==0, classidMother=2; end
        %extract volume
        lastFrame=numel(obj.roi(r).image(1,1,channelsExtract(1),:));
        for t=1:lastFrame
            im=obj.roi(r).image(:,:,c,t);
            maskTotal=zeros(size(im),'uint16');
            maskMother=zeros(size(im),'uint16');
            
            maskTotal=obj.roi(r).image(:,:,channelSegCell,t); %mask containing all the classes
            maskMother=(maskMother+maskTotal.*uint16(maskTotal==classidMother))./classidMother;
            
            %init/reset
            obj.roi(r).results.signal.cell.(classiname).volume(t)=NaN;
            %fill
            obj.roi(r).results.signal.cell.(classiname).volume(t)=sum(maskMother(:));
        end
    end
    disp(['Volume mothercell was computed and added to roi(' num2str(r) ').results.signal.cell.' num2str(classiname) '.volume'])
end

%%
if strcmp(method,'cell')
    chans=obj.roi(rois(1)).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';  '];
    end

    prompt=['Which channel(s) to EXTRACT the signal from?' newline str newline];
    channelsExtract=input(prompt);
    if ~exist('channelsExtract','var')
        error('Indicate channel(s) from which to extract the signal');
    end
    
    prompt=['Which channel contains the MASK of the CELLS?' newline str newline];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the MASK of the CELLS');
    end

    for r=rois %to parfor
        obj.roi(r).load();
        
        %find the classi used to segmente
        if contains(chans{channelSegCell},'results_')
        classiname=chans{channelSegCell};%extractAfter(chans{channelSegCell},'results_');
        else
%           classiid=chans{channelSegCell};
            error('classi name not found with the given mask channel')
        end
         
        %find the class of the mother, ask it only once.

        prompt=(['Indicate the --number-- of the class corresponding to the mother in the classi: ' classiname ' (Default: 2) ' newline]);
        classidMother=input(prompt);
        if numel(classidMother)==0, classidMother=2; end
        
        prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiname ' (Default: 1) ' newline]);
        classidBckg=input(prompt);        
        if numel(classidBckg)==0, classidBckg=1; end
        
        %extract fluo for each given channel
        lastFrame=numel(obj.roi(r).image(1,1,channelsExtract(1),:));
        for c=channelsExtract
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
                
                %init/reset
                obj.roi(r).results.signal.cell.(classiname).volume(t)=NaN;
                obj.roi(r).results.signal.cell.(classiname).totalfluo(c,t)=NaN;
                obj.roi(r).results.signal.cell.(classiname).meanfluo(c,t)=NaN;
                
                obj.roi(r).results.signal.cell.(classiname).volume(t)=sum(maskMother(:));
                obj.roi(r).results.signal.cell.(classiname).totalfluo(c,t)=sum(maskedMother(:))-mean(maskedBckg(:));
                obj.roi(r).results.signal.cell.(classiname).meanfluo(c,t)=obj.roi(r).results.signal.cell.(classiname).totalfluo(c,t)/sum(maskMother(:));
            end
        end
        disp(['Volume, average and total signal of mothercell was computed and added to roi(' num2str(r) ').results.signal.cell' num2str(classiname)])
    end
end


%% nucleus

if strcmp(method,'nucleus')
    prompt=['Which channel(s) to EXTRACT the signal from?' newline];
    channelsExtract=input(prompt);
    if ~exist('channelsExtract','var')
        error('Indicate channel(s) from which to extract the signal');
    end
    
    prompt=['Which channel contains the MASK of the CELLS?' newline];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the MASK of the CELLS');
    end
    
    prompt=['Which channel contains the MASK of the NUCLEUS?' newline];
    channelSegNuc=input(prompt);
    if ~exist('channelSegNucleus','var')
        error('Indicate which channel contains the MASK of the CELLS');
    end
    
    for r=rois %to parfor
        obj.roi(r).load();
        
        %find the classi used to segmente
        chans=obj.roi(rois(1)).display.channel;
        if contains(chans{channelSegCell},'results_')
        classiname=chans{channelSegCell};%extractAfter(chans{channelSegCell},'results_');
        else
            error('classi name not found with the given mask channel')
        end
        
        if contains(chans{channelSegNuc},'results_')
        classiNucName=chans{channelSegNuc};
        else
            error('classi name not found with the given mask channel')
        end

        prompt=(['Indicate the --number-- of the class corresponding to the mother cell in the classi: ' classiname ' (Default: 2) ' newline]);
        classidMother=input(prompt);
        if numel(classidMother)==0, classidMother=2; end
%             for i=1:numel(obj.roi(r).classes)
%                 strB=[strB num2str(i) ' - ' obj.roi(r).classes{i} ';'];
%             end
        prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiname ' (Default: 1) ' newline]);
        classidBckg=input(prompt);                
        if numel(classidBckg)==0, classidBckg=1; end
        
        %find the classid of the nucleus, ask it only once.
        prompt=(['Indicate the --number-- of the class corresponding to the nucleus in the classi: ' classiNucName ' (Default: 2) ' newline]);
        classidNucleus=input(prompt);       
        if numel(classidNucleus)==0, classidNucleus=2; end
        
        %extract fluo for each given channel
        lastFrame=numel(obj.roi(r).image(1,1,channelsExtract(1),:));
        for c=channelsExtract
            for t=1:lastFrame
                im=obj.roi(r).image(:,:,c,t);
                maskTotal=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskBckg=zeros(size(im),'uint16');
                maskNucleus=zeros(size(im),'uint16');
                
                maskTotal=obj.roi(r).image(:,:,channelSegCell,t); %mask containing all the classes for the cell mask
                maskTotalNucleus=obj.roi(r).image(:,:,channelSegNuc,t); %mask containing all the classes for the nuc mask
                maskMother=(maskMother+maskTotal.*uint16(maskTotal==classidMother))./classidMother;
                maskBckg=(maskBckg+maskTotal.*uint16(maskTotal==classidBckg))./classidBckg;
                maskNucleus=(maskNucleus+maskTotalNucleus.*uint16(maskTotalNucleus==classidNucleus))./classidNucleus;
                maskNucleusMother=maskMother.*maskNucleus;
                
                maskedNucleusMother=im.*maskNucleusMother;
                maskedBckg=im.*maskBckg;
                
                %init/reset
                obj.roi(r).results.signal.nucleus.(classiname).volume(t)=NaN;
                obj.roi(r).results.signal.nucleus.(classiname).totalfluo(c,t)=NaN;
                obj.roi(r).results.signal.nucleus.(classiname).meanfluo(c,t)=NaN;
                %fill  
                obj.roi(r).results.signal.nucleus.(classiname).volume(t)=sum(maskNucleusMother(:));
                obj.roi(r).results.signal.nucleus.(classiname).totalfluo(c,t)=sum(maskedNucleusMother(:))-mean(maskedBckg(:));
                obj.roi(r).results.signal.nucleus.(classiname).meanfluo(c,t)=obj.roi(r).results.signal.nucleus.(classiname).totalfluo(c,t)/sum(maskMother(:));
            end
        end
        disp(['Volume, average and total signal of nucleus was computed and added to roi(' num2str(r) ').results.signal.nucleus' num2str(classiname)])
    end
end
end
