function extractSignal(roiobj,varargin)
%This fct extracts the signal from the 'Channels' using the 'Method' and
%store them in roiobj(r).results.classiid.fluo.max(c,t)

%TODO: make warning message and ignore if roi has no signal

%Arguments:
%*'Method': **'full' computes the average of the kMaxPixels, the total and
%the mean pixel value of the whople image
%           **'OneMask' computes the fluo of channel 'Channels' with the mask
%           of Mask(2). Give 2 channelsExtract in 'Channels. Also extracts the
%           volume of the cell.
%           **'twomask' computes the fluo of channel 'Channels' with the mask
%           of MaskCell inter MaskNuc. Also extracts the
%           surface area of the mask1 and of the mask2.
%           **'volume': computes the number of pixels of class mother
%
%'kMaxPixels': numbers of pixels taken for the maxPixels method. Default=20

%*'Rois': rois array to extract the signal from
snapinc=1; %1/frequency of snappiong of
kMaxPix=20;
volThresh=0;
postprocess=1;
method=[];
%method='full';
%channelSegCell=3;
%channelSegNuc=4;

environment='pc';

for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Method')
        method=varargin{i+1};        
    end
    if strcmp(method,'full') && strcmp(method,'OneMask') && strcmp(method,'TwoMask') && strcmp(method,'volume') && strcmp(method,'fociOrNot')
        error('Please enter a valid method');
    end
    
    %kMaxPixels
    if strcmp(varargin{i},'kMaxPixels')
        kMaxPix=varargin{i+1};
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

end


%%
if strcmp(method,'full')
    roiobj(1).path=modifyPath(roiobj(1),environment);
    roiobj(1).load();
    prompt=['Type the name of the result classif: (Default: full_with' num2str(kMaxPix) 'maxPixels) '];
    %classiname=input(prompt);
    classiname=['full_with' num2str(kMaxPix) 'maxPixels']; %%to delete
    
    if isempty(classiname)
        classiname=['full_' num2str(kMaxPix) 'maxPixels'];
    end
    
    chans=roiobj(1).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} '; '];
    end
    
    prompt=['Which channel(s) to extract the signal from? (Default: [2:number of channelsExtract])' newline str];
    channelsExtract=input(prompt);
    BckgValue(1:numel(roiobj(1).image(1,1,1,:)))=NaN;
    for c=channelsExtract
        BckgValue(c)=input(['Choose background value for channel' num2str(c) ' ']);
    end
%     channelsExtract=[2,3];      %%to delete
%     BckgValue(2)=105;%%to delete
%     BckgValue(3)=100;%%to delete
    
    for r=1:numel(roiobj) %to parfor
        roiobj(r).path=modifyPath(roiobj(r),environment);        
        roiobj(r).load();
        
        lastChan=numel(roiobj(r).image(1,1,:,1));
        lastFrame=numel(roiobj(r).image(1,1,1,:));
        if numel(channelsExtract)==0
            channelsExtract=chans;
            if numel(channelsExtract)>1
                channelsExtract=2:numel(channelsExtract); %avoid channel 1 that is mostof the time not fluo
            end
        end
        
        %init/reset
                roiobj(r).results.signal.full.(['from_' classiname]).meankmaxfluo(1:lastChan,1:lastFrame)=NaN;
                roiobj(r).results.signal.full.(['from_' classiname]).meanfluo(1:lastChan,1:lastFrame)=NaN;
                roiobj(r).results.signal.full.(['from_' classiname]).totalfluo(1:lastChan,1:lastFrame)=NaN;
        for c=channelsExtract
            for t=1:lastFrame                
                %fill, reshaped used to make it line
                roiobj(r).results.signal.full.(['from_' classiname]).meankmaxfluo(c,t)=mean(maxk( reshape(roiobj(r).image(:,:,c,t),[],1) ,kMaxPix))-BckgValue(c);
                roiobj(r).results.signal.full.(['from_' classiname]).meanfluo(c,t)=mean(reshape(roiobj(r).image(:,:,c,t),[],1));
                roiobj(r).results.signal.full.(['from_' classiname]).totalfluo(c,t)=sum(reshape(roiobj(r).image(:,:,c,t),[],1));
            end
        end
        disp(['Average signal of ' num2str(kMaxPix) 'max pixels, mean and total signal was computed and added to roi(' num2str(r) ').results.signal.' num2str(classiname)])
        roiobj(r).clear;
        roiobj(r).save('results')
        
    end
end

%% extract only the volume of the cell
if strcmp(method,'volume')
    roiobj(1).path=modifyPath(roiobj(1),environment);
    roiobj(1).load();

    %===channels
    chans=roiobj(1).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';  '];
    end
    
    prompt=['Which channel contains the MASK?' newline str newline];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the MASK');
    end
    
    classiname=chans{channelSegCell};
    %===
    
    %===find the class of the mother, ask it only once.
    prompt=(['Indicate the --number-- of the class corresponding to the mother in the classi: ' classiname ' (Default: 2) ' newline]);
    classidMother=input(prompt);
    if numel(classidMother)==0, classidMother=2; end
    %===
    
    for r=1:numel(roiobj) %to parfor
        roiobj(r).path=modifyPath(roiobj(r),environment);
        roiobj(r).load();
        
        channelSegCell=findChannelID(roiobj(r),classiname);
        %         if contains(chans{channelSegCell},'results_')
        %         classiname=chans{channelSegCell};%extractAfter(chans{channelSegCell},'results_');
        %         else
        % %           classiid=chans{channelSegCell};
        %             error('classi name not found with the given mask channel')
        %         end
        
        
        %extract volume
        lastFrame=numel(roiobj(r).image(1,1,channelSegCell,:));
        for t=1:lastFrame
            im=roiobj(r).image(:,:,channelSegCell,t);
            
            %init/reset
            maskTotal=zeros(size(im),'uint16');
            maskMother=zeros(size(im),'uint16');
            roiobj(r).results.signal.onemask.(['from_' classiname]).volume(t)=NaN;
            
            if isequal(im,maskTotal) %if the image hasnt been classified or annotated
                continue %skip iteration
            end
            
            %=masks
            maskTotal=roiobj(r).image(:,:,channelSegCell,t); %mask containing all the classes
            maskMother=maskMother+uint16(maskTotal==classidMother)./classidMother;
            
            %=compute and store
            vol=sum(maskMother(:));
            roiobj(r).results.signal.onemask.(['from_' classiname]).volume(t)=vol;
        end
        disp(['Volume, of mothercell was computed and added to roi(' num2str(r) ').results.signal.onemask.' num2str(['.from_' classiname])])
        roiobj(r).clear;
        roiobj(r).save('results');
    end
end


%%
if strcmp(method,'OneMask')
    roiobj(1).path=modifyPath(roiobj(1),environment);
    roiobj(1).load();
    %===channels
    chans=roiobj(1).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';  '];
    end
    
    prompt=['Which channel(s) to EXTRACT the signal from?' newline str newline];
    channelsExtract=input(prompt);
    if ~exist('channelsExtract','var')
        error('Indicate channel(s) from which to extract the signal');
    end
    
    prompt=['Which channel contains the MASK?' newline str newline];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the MASK');
    end
    
    classiname=chans{channelSegCell};
    %===
    
    %===find the class of the mother, ask it only once.
    prompt=(['Indicate the --number-- of the class corresponding to the mother in the classi: ' classiname ' (Default: 2) ' newline]);
    classidMother=input(prompt);
    if numel(classidMother)==0, classidMother=2; end
    
    
    prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiname ' (Default: 1) ' newline]);
    classidBckg=input(prompt);
    if numel(classidBckg)==0, classidBckg=1; end
    %===
    
    for r=1:numel(roiobj) %to parfor
        roiobj(r).path=modifyPath(roiobj(r),environment);
        roiobj(r).load();
        
        channelSegCell=findChannelID(roiobj(r),classiname); 
        %         if contains(chans{channelSegCell},'results_')
        %         classiname=chans{channelSegCell};%extractAfter(chans{channelSegCell},'results_');
        %         else
        % %           classiid=chans{channelSegCell};
        %             error('classi name not found with the given mask channel')
        %         end
        
        
        %extract fluo for each given channel
        lastChan=numel(roiobj(r).image(1,1,:,1));
        lastFrame=numel(roiobj(r).image(1,1,channelSegCell,:));
        
        
        roiobj(r).results.signal.onemask.(['from_' classiname]).volume=[];
        roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo=[];
        roiobj(r).results.signal.onemask.(['from_' classiname]).meanfluo=[];
        
        roiobj(r).results.signal.onemask.(['from_' classiname]).volume(1:lastFrame)=NaN;
        roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(1:lastChan,1:lastFrame)=NaN;
        roiobj(r).results.signal.onemask.(['from_' classiname]).meanfluo(1:lastChan,1:lastFrame)=NaN;
        
        for c=channelsExtract
            meanbckg=[];
            for t=1:lastFrame
                im=roiobj(r).image(:,:,c,t);
                
                %init/reset
                maskTotal=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskBckg=zeros(size(im),'uint16');
  
                if isequal(im,maskTotal) %if the image hasnt been classified or annotated
                    continue %skip iteration
                end
                
                %=masks
                maskTotal=roiobj(r).image(:,:,channelSegCell,t); %mask containing all the classes
                maskMother=maskMother+   uint16(maskTotal==classidMother)./classidMother;
                maskBckg=maskBckg+ uint16(maskTotal==classidBckg)./classidBckg;                
                
                %=masked image
                maskedMother=im.*maskMother;
                maskedBckg=im.*maskBckg;
                maskedBckg=maskedBckg(maskedBckg>0); %remove zero, for the following mean
                
                %compute backgroun by removing max and min pixels
                nominbckg=maxk(maskedBckg(:),ceil(0.8*size(maskedBckg,1)*size(maskedBckg,2)));
                nomaxminbckg=mink(nominbckg,ceil(0.8*size(maskedBckg,1)*size(maskedBckg,2)));
                meanbckg(t)=mean(nomaxminbckg);
                
                %=compute and store
                vol=sum(maskMother(:));
                if postprocess==1
                    if vol<volThresh
                        vol=0;
                    end
                end
                roiobj(r).results.signal.onemask.(['from_' classiname]).volume(t)=vol;
                roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(c,t)=sum(maskedMother(:));
            end
            roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(c,:)=roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(c,:)-mean(meanbckg);
            roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(c,   roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(c,:)<0   )=0;
            roiobj(r).results.signal.onemask.(['from_' classiname]).meanfluo(c,:)=roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(c,:)./roiobj(r).results.signal.onemask.(['from_' classiname]).volume;
            
            %ici enlever les frames en trop
            tremove=1:lastFrame;
            tremove(1:snapinc:end)=[];
            
            roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(c,tremove)=NaN;
            roiobj(r).results.signal.onemask.(['from_' classiname]).meanfluo(c,tremove)=NaN;
        end
        
        disp(['Volume, average and total signal of mothercell was computed and added to roi(' num2str(r) ').results.signal.onemask' num2str(['.from_' classiname])])

        roiobj(r).save('results');
        roiobj(r).clear;
        clear im
    end
end

%% twomask
if strcmp(method,'TwoMask')
    roiobj(1).path=modifyPath(roiobj(1),environment);
    roiobj(1).load();
    %===ask channels
    chans=roiobj(1).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';  '];
    end
    
    prompt=['Which channel(s) to EXTRACT the signal from?' newline str newline];
    channelsExtract=input(prompt);
    if ~exist('channelsExtract','var')
        error('Indicate channel(s) from which to extract the signal');
    end
    
    prompt=['Which channel contains the MASK 1?' newline str newline];
    channelSegCell=input(prompt);
    if ~exist('channelSegCell','var')
        error('Indicate which channel contains the MASK 1');
    end
    
    prompt=['Which channel contains the MASK 2?' newline str newline];
    channelSegNuc=input(prompt);
    if ~exist('channelSegNuc','var')
        error('Indicate which channel contains the MASK 2');
    end
    
    channelExtractName=chans{channelsExtract};
    classiname=chans{channelSegCell};
    classiNucName=chans{channelSegNuc};
    %===
    
    %===ask class ID
    prompt=(['Indicate the --number-- of the class corresponding to the mother onemask in the classi: ' classiname ' (Default: 2) ' newline]);
    classidMother=input(prompt);
    if numel(classidMother)==0, classidMother=2; end
    %             for i=1:numel(roiobj(r).classes)
    %                 strB=[strB num2str(i) ' - ' roiobj(r).classes{i} ';'];
    %             end
    prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiNucName ' (Default: 1) ' newline]);
    classidBckg=input(prompt);
    if numel(classidBckg)==0, classidBckg=1; end
    
    %find the classid of the nucleus, ask it only once.
    prompt=(['Indicate the --number-- of the class corresponding to the nucleus in the classi: ' classiNucName ' (Default: 2) ' newline]);
    classidNucleus=input(prompt);
    if numel(classidNucleus)==0, classidNucleus=2; end
    %===
    
    %NOW WORK ON ALL THE ROIS
    for r=1:numel(roiobj) %to parfor
        roiobj(r).path=modifyPath(roiobj(r),environment);
        roiobj(r).load();
        
        channelsExtract=findChannelID(roiobj(r),channelExtractName);   
        channelSegCell=findChannelID(roiobj(r),classiname);        
        channelSegNuc=findChannelID(roiobj(r),classiNucName);
        
        %extract fluo for each given channel
        lastFrame=numel(roiobj(r).image(1,1,channelsExtract(1),:));
        
        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).volume=[];
        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).totalfluo=[];
        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).meanfluo=[];

        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).volume(1:lastFrame)=NaN;
        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).totalfluo(1:lastChan,1:lastFrame)=NaN;
        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).meanfluo(1:lastChan,1:lastFrame)=NaN;
        
        for c=channelsExtract
            meanbckg=[];
            for t=1:lastFrame
                im=roiobj(r).image(:,:,channelsExtract,t);
                
                %init/reset
                maskTotal=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskTotalNucleus=zeros(size(im),'uint16');
                maskBckgNucleus=zeros(size(im),'uint16');
                maskNucleus=zeros(size(im),'uint16');
                maskNucleusMother=zeros(size(im),'uint16');
                               
                if isequal(im,maskTotal) %if the image hasnt been classified or annotated
                    continue %skip iteration
                end
                
                %masks
                maskTotal=roiobj(r).image(:,:,channelSegCell,t); %mask containing all the classes for the cell mask
                maskTotalNucleus=roiobj(r).image(:,:,channelSegNuc,t); %mask containing all the classes for the nuc mask
                maskMother=maskMother+uint16(maskTotal==classidMother)./classidMother;
                maskBckgNucleus=maskBckgNucleus+uint16(maskTotalNucleus==classidBckg)./classidBckg;
                maskNucleus=maskNucleus+uint16(maskTotalNucleus==classidNucleus)./classidNucleus;
                maskNucleusMother=maskMother.*maskNucleus;
                
                %masked image
                maskedNucleusMother=im.*maskNucleusMother;
                maskedBckgNucleus=im.*maskBckgNucleus;
                maskedBckgNucleus=maskedBckgNucleus(maskedBckgNucleus>0); %remove zero, for the following mean
                
                %compute backgroun by removing max and min pixels
                nominbckg=maxk(maskedBckgNucleus(:),ceil(0.8*size(maskedBckgNucleus,1)*size(maskedBckgNucleus,2)));
                nomaxminbckg=mink(nominbckg,ceil(0.8*numel(maskedBckgNucleus,1)*size(maskedBckgNucleus,2)));
                meanbckg(t)=mean(nomaxminbckg);
                
                %fill
                roiobj(r).results.signal.twomask.(['from_' classiNucName]).volume(t)=sum(maskNucleusMother(:));
                
                roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(c,t)=sum(maskedNucleusMother(:));
                roiobj(r).results.signal.twomask.(['from_' classiNucName]).meanfluo(c,t)=roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(c,t)/sum(maskNucleusMother(:));
            end
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(c,:)=roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(c,:)-mean(meanbckg);
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(c,(roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(c,:)<0))=0;
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).meanfluo(c,:)=roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(c,:)./roiobj(r).results.signal.twomask.(['from_' classiNucName]).volume;            
            
            %Remove duplicated frames (from different snapping frequency)
            tremove=1:lastFrame;
            tremove(1:snapinc:end)=[];
            
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(c,tremove)=NaN;
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).meanfluo(c,tremove)=NaN;
        end
        
        disp(['Volume, average and total signal of twomask was computed and added to roi(' num2str(r) ').results.signal.twomask' num2str(['.from_' classiNucName])])
        roiobj(r).save('results');
        roiobj(r).clear;
        clear im
        
    end
end

%%
if strcmp(method,'fociOrNot')
    roiobj(1).load();
    %===ask channels
    chans=roiobj(1).display.channel;
    str=[];
    for i=1:numel(chans)
        str=[str num2str(i) ' - ' chans{i} ';  '];
    end
    
    prompt=['Which channel contains the foci mask?' newline str newline];
    channelFociMask=input(prompt);
    if ~exist('channelFociMask','var')
        error('Indicate channelof the foci mask');
    end    
    channelFociMaskName=chans{channelFociMask};
    
    for r=1:numel(roiobj)
        roiobj(r).load();
        channelFociMask=findChannelID(roiobj(r),channelFociMaskName);
        lastFrame=numel(roiobj(r).image(1,1,channelFociMask,:));                        
        
        for t=1:lastFrame
            im=roiobj(r).image(:,:,channelFociMask,t);
            if sum(im(:)==2)>0
                roiobj(r).results.signal.foci.(['from_' channelFociMaskName]).bin(t)=1;
            else
                roiobj(r).results.signal.foci.(['from_' channelFociMaskName]).bin(t)=0;
            end
        end
        
        roiobj(r).save('results');
        roiobj(r).clear;
    end
end

end

function path=modifyPath(roi,environment)

if strcmp(environment,'pc') %to change to make it more versatile. Best would be to error message: update path. Cf gui
    path=strrep(roi.path,'/shared/space2/','\\space2.igbmc.u-strasbg.fr\');
else
    path=strrep(roi.path,'\\space2.igbmc.u-strasbg.fr\','/shared/space2/');
end
end
