function extractSignal(obj,type,inputvarargin)
%This fct extracts the signal from the 'Channels' using the 'Method' and
%store them in obj.roi(r).results.classiid.fluo.max(c,t)

%TODO: adapt to roiobj, use roi.display. use architecture of measureRLS3

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
snapinc=3; %1/frequency of snappiong of 
kMaxPix=20;
volThresh=0;
rois=1:numel(obj.roi);
postprocess=1;
%method='full';
%channelSegCell=3;
%channelSegNuc=4;

for i=1:numel(inputvarargin)
    %Method
    if strcmp(inputvarargin{i},'Method')
        method=inputvarargin{i+1};
        if strcmp(method,'full') && strcmp(method,'cell') && strcmp(method,'nucleus') && strcmp(method,'volume')
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
    
end

%%
if strcmp(method,'full')
    
    obj.roi(rois(1)).load();
    prompt=['Type the name of the result classif: (Default: full_with' num2str(kMaxPix) 'maxPixels) '];
    %classiname=input(prompt);
    classiname=['full_with' num2str(kMaxPix) 'maxPixels']; %%to delete
    
    if isempty(classiname)
        classiname=['full_' num2str(kMaxPix) 'maxPixels'];
    end
    
    chans=obj.roi(rois(1)).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';'];
    end
    
    prompt=['Which channel to extract the signal from? (Default: [2:number of channelsExtract])' newline str];
%     channelsExtract=input(prompt);  
%     for c=channelsExtract
%             BckgValue(c)=input(['Choose background value for channel' num2str(c)]);
%     end
                        channelsExtract=[2,3];      %%to delete                  
                        BckgValue(2)=105;%%to delete
                        BckgValue(3)=100;%%to delete
    
    for r=rois %to parfor
        obj.roi(r).load();
        lastFrame=numel(obj.roi(r).image(1,1,1,:));
        if numel(channelsExtract)==0
            channelsExtract=1:numel(obj.roi(r).image(1,1,:,1));
            if numel(channelsExtract)>1
                channelsExtract=2:numel(channelsExtract); %avoid channel 1 that is mostof the time not fluo
            end
        end
        for c=channelsExtract
            for t=1:lastFrame
                %init/reset
                obj.roi(r).results.signal.full.(classiname).meankmaxfluo(c,t)=NaN;
                obj.roi(r).results.signal.full.(classiname).meanfluo(c,t)=NaN;
                obj.roi(r).results.signal.full.(classiname).totalfluo(c,t)=NaN;
                %fill, reshaped used to make it line
                obj.roi(r).results.signal.full.(classiname).meankmaxfluo(c,t)=mean(maxk( reshape(obj.roi(r).image(:,:,c,t),[],1) ,kMaxPix))-BckgValue(c);
                obj.roi(r).results.signal.full.(classiname).meanfluo(c,t)=mean(reshape(obj.roi(r).image(:,:,c,t),[],1));
                obj.roi(r).results.signal.full.(classiname).totalfluo(c,t)=sum(reshape(obj.roi(r).image(:,:,c,t),[],1));
            end
        end
        disp(['Average signal of ' num2str(kMaxPix) 'max pixels, mean and total signal was computed and added to roi(' num2str(r) ').results.signal' num2str(classiname)])
        obj.roi(r).image=[];
        obj.roi(r).save('results')
        clear im
    end
end

%% extract only the volume of the cell
if strcmp(method,'volume')
    obj.roi(rois(1)).load();
    %===channels
    chans=obj.roi(rois(1)).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';  '];
    end
    
    prompt=['Which channel contains the MASK of the CELLS?' newline str newline];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the MASK of the CELLS');
    end
    
    classiname=chans{channelSegCell};
    channelSegCell=find(obj.roi(rois(1)).channelid==channelSegCell,1,'first'); %to deal with combined channels
    %===
    
    %===find the class of the mother, ask it only once.
    prompt=(['Indicate the --number-- of the class corresponding to the mother in the classi: ' classiname ' (Default: 2) ' newline]);
    classidMother=input(prompt);
    if numel(classidMother)==0, classidMother=2; end
    %===
    
    for r=rois %to parfor
        obj.roi(r).load();
        
        %         if contains(chans{channelSegCell},'results_')
        %         classiname=chans{channelSegCell};%extractAfter(chans{channelSegCell},'results_');
        %         else
        % %           classiid=chans{channelSegCell};
        %             error('classi name not found with the given mask channel')
        %         end
        
        
        %extract volume
        lastFrame=numel(obj.roi(r).image(1,1,channelSegCell,:));
        for t=1:lastFrame
            im=obj.roi(r).image(:,:,channelSegCell,t);
            
            %init/reset
            maskTotal=zeros(size(im),'uint16');
            maskMother=zeros(size(im),'uint16');
            obj.roi(r).results.signal.cell.(classiname).volume(t)=NaN;
            
            if isequal(im,maskTotal) %if the image hasnt been classified or annotated
                continue %skip iteration
            end
            
            %=masks
            maskTotal=obj.roi(r).image(:,:,channelSegCell,t); %mask containing all the classes
            maskMother=maskMother+uint16(maskTotal==classidMother)./classidMother;
            
            %=compute and store
            vol=sum(maskMother(:));
            obj.roi(r).results.signal.cell.(classiname).volume(t)=vol;
        end
        disp(['Volume, of mothercell was computed and added to roi(' num2str(r) ').results.signal.cell.' num2str(classiname)])
        obj.roi(r).image=[];
        obj.roi(r).save('results');
        clear im
    end
end


%%
if strcmp(method,'cell')
    obj.roi(rois(1)).load();
    %===channels
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
    
    classiname=chans{channelSegCell};
    channelSegCell=find(obj.roi(rois(1)).channelid==channelSegCell,1,'first'); %to deal with combined channels
    %===
    
    %===find the class of the mother, ask it only once.
    prompt=(['Indicate the --number-- of the class corresponding to the mother in the classi: ' classiname ' (Default: 2) ' newline]);
    classidMother=input(prompt);
    if numel(classidMother)==0, classidMother=2; end
    
    
    prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiname ' (Default: 1) ' newline]);
    classidBckg=input(prompt);
    if numel(classidBckg)==0, classidBckg=1; end
    %===
    
    for r=rois %to parfor
        obj.roi(r).load();
        
        %         if contains(chans{channelSegCell},'results_')
        %         classiname=chans{channelSegCell};%extractAfter(chans{channelSegCell},'results_');
        %         else
        % %           classiid=chans{channelSegCell};
        %             error('classi name not found with the given mask channel')
        %         end
        
        
        %extract fluo for each given channel
        lastFrame=numel(obj.roi(r).image(1,1,channelSegCell,:));
        for c=channelsExtract
            for t=1:lastFrame
                im=obj.roi(r).image(:,:,c,t);
                
                %init/reset
                maskTotal=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskBckg=zeros(size(im),'uint16');
                obj.roi(r).results.signal.cell.(classiname).volume(t)=NaN;
                obj.roi(r).results.signal.cell.(classiname).totalfluo(c,t)=NaN;
                obj.roi(r).results.signal.cell.(classiname).meanfluo(c,t)=NaN;
                
                if isequal(im,maskTotal) %if the image hasnt been classified or annotated
                    continue %skip iteration
                end
                
                %=masks
                maskTotal=obj.roi(r).image(:,:,channelSegCell,t); %mask containing all the classes
                maskMother=maskMother+   uint16(maskTotal==classidMother)./classidMother;
                maskBckg=maskBckg+ uint16(maskTotal==classidBckg)./classidBckg;
                
                %=masked image
                maskedMother=im.*maskMother;
                maskedBckg=im.*maskBckg;
                
                %compute backgroun by removing max and min pixels
                meanbckg=maxk(maskedBckg(:),ceil(0.8*size(im,1)*size(im,2)));
                meanbckg=mink(meanbckg(:),ceil(0.8*size(im,1)*size(im,2)));
                meanbckg=mean(meanbckg);
                
                %=compute and store
                vol=sum(maskMother(:));
                if postprocess==1
                    if vol<volThresh
                        vol=0;
                    end
                end
                obj.roi(r).results.signal.cell.(classiname).volume(t)=vol;
                obj.roi(r).results.signal.cell.(classiname).totalfluo(c,t)=sum(maskedMother(:)-meanbckg);
                obj.roi(r).results.signal.cell.(classiname).meanfluo(c,t)=obj.roi(r).results.signal.cell.(classiname).totalfluo(c,t)/sum(maskMother(:));
            end
            
            %ici enlever les frames en trop
            tremove=1:lastFrame;
            tremove(1:snapinc:end)=[];
            
            obj.roi(r).results.signal.cell.(classiname).totalfluo(c,tremove)=NaN;
            obj.roi(r).results.signal.cell.(classiname).meanfluo(c,tremove)=NaN;
            
        end
        
        disp(['Volume, average and total signal of mothercell was computed and added to roi(' num2str(r) ').results.signal.cell' num2str(classiname)])
        
        obj.roi(r).save('results');
        obj.roi(r).image=[];
        clear im
    end
end

%% nucleus
obj.roi(rois(1)).load();
if strcmp(method,'nucleus')
    
    %===ask channels
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
    
    prompt=['Which channel contains the MASK of the NUCLEUS?' newline str newline];
    channelSegNuc=input(prompt);
    if ~exist('channelSegNuc','var')
        error('Indicate which channel contains the MASK of the CELLS');
    end
    
    classiname=chans{channelSegCell};
    channelSegCell=find(obj.roi(rois(1)).channelid==channelSegCell,1,'first'); %to deal with combined channels
    classiNucName=chans{channelSegNuc};
    channelSegNuc=find(obj.roi(rois(1)).channelid==channelSegNuc,1,'first'); %to deal with combined channels
    %===
    
    %===ask class ID
    prompt=(['Indicate the --number-- of the class corresponding to the mother cell in the classi: ' classiname ' (Default: 2) ' newline]);
    classidMother=input(prompt);
    if numel(classidMother)==0, classidMother=2; end
    %             for i=1:numel(obj.roi(r).classes)
    %                 strB=[strB num2str(i) ' - ' obj.roi(r).classes{i} ';'];
    %             end
    prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiNucName ' (Default: 1) ' newline]);
    classidBckg=input(prompt);
    if numel(classidBckg)==0, classidBckg=1; end
    
    %find the classid of the nucleus, ask it only once.
    prompt=(['Indicate the --number-- of the class corresponding to the nucleus in the classi: ' classiNucName ' (Default: 2) ' newline]);
    classidNucleus=input(prompt);
    if numel(classidNucleus)==0, classidNucleus=2; end
    %===
    
    for r=rois %to parfor
        obj.roi(r).load();
        
        %extract fluo for each given channel
        lastFrame=numel(obj.roi(r).image(1,1,channelsExtract(1),:));
        for c=channelsExtract
            for t=1:lastFrame
                im=obj.roi(r).image(:,:,c,t);
                
                %init/reset
                maskTotal=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskTotalNucleus=zeros(size(im),'uint16');
                maskBckgNucleus=zeros(size(im),'uint16');
                maskNucleus=zeros(size(im),'uint16');
                maskNucleusMother=zeros(size(im),'uint16');
                
                obj.roi(r).results.signal.nucleus.(classiNucName).volume(t)=NaN;
                obj.roi(r).results.signal.nucleus.(classiNucName).totalfluo(c,t)=NaN;
                obj.roi(r).results.signal.nucleus.(classiNucName).meanfluo(c,t)=NaN;
                if isequal(im,maskTotal) %if the image hasnt been classified or annotated
                    continue %skip iteration
                end
                
                %masks
                maskTotal=obj.roi(r).image(:,:,channelSegCell,t); %mask containing all the classes for the cell mask
                maskTotalNucleus=obj.roi(r).image(:,:,channelSegNuc,t); %mask containing all the classes for the nuc mask
                maskMother=maskMother+uint16(maskTotal==classidMother)./classidMother;
                maskBckgNucleus=maskBckgNucleus+uint16(maskTotalNucleus==classidBckg)./classidBckg;
                maskNucleus=maskNucleus+uint16(maskTotalNucleus==classidNucleus)./classidNucleus;
                maskNucleusMother=maskMother.*maskNucleus;
                
                %masked image
                maskedNucleusMother=im.*maskNucleusMother;
                maskedBckgNucleus=im.*maskBckgNucleus;
                
                %compute backgroun by removing max and min pixels
                meanbckg=maxk(maskedBckgNucleus(:),ceil(0.8*size(im,1)*size(im,2)));
                meanbckg=mink(meanbckg(:),ceil(0.8*size(im,1)*size(im,2)));
                meanbckg=mean(meanbckg);
                
                %fill
                obj.roi(r).results.signal.nucleus.(classiNucName).volume(t)=sum(maskNucleusMother(:));
                
                obj.roi(r).results.signal.nucleus.(classiNucName).totalfluo(c,t)=sum(maskedNucleusMother(:)-meanbckg);%todo: take 80% of max pixels of back to avoid traps
                obj.roi(r).results.signal.nucleus.(classiNucName).meanfluo(c,t)=obj.roi(r).results.signal.nucleus.(classiNucName).totalfluo(c,t)/sum(maskNucleusMother(:));                                
            end
            
            %ici enlever les frames en trop
            tremove=1:lastFrame;
            tremove(1:snapinc:end)=[];
            
            obj.roi(r).results.signal.nucleus.(classiNucName).totalfluo(c,tremove)=NaN;
            obj.roi(r).results.signal.nucleus.(classiNucName).meanfluo(c,tremove)=NaN;
        end
        disp(['Volume, average and total signal of nucleus was computed and added to roi(' num2str(r) ').results.signal.nucleus' num2str(classiNucName)])
        obj.roi(r).save('results');
        obj.roi(r).image=[];
        clear im
        
    end
end
end
