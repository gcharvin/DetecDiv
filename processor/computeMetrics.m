function paramout=computeMetrics(param,roiobj,frames)

 listChannels=listAvailableChannels;
 listChannels=['N/A', listChannels];
environment='pc' ;

if nargin==0
    paramout=[];
    
     tip={'Name of Mask channel  #1 (eg cell contours)',...
            'Compute detailed Mask #1 statistics (area, etc)',...
            'Class number used to identify (cell) contours for Mask #1 (defaullt:2)',...  
            'Name of Mask channel  #2 (optional, eg nucleus, foci,etc...)',...
            'Class number used to identify (subcellular) contours for Mask #2 (defaullt:2)',...
            'Compute detailed Mask #2 statistics (area, etc)',...
            'Channel name #1 to score',...
            'Channel name #2 to score',...
            'Channel name #3 to score',...
            'Channel name #4 to score',...
            'Max intensity pixel number (default 20)',...
            'Number of frames between 2 fluo acquisitions'};
        
   paramout.mask1_name=[listChannels listChannels{1}]; 
   paramout.mask1_stat=true;
   paramout.mask1_class=2;
   paramout.mask2_name=[listChannels listChannels{1}];
   paramout.mask2_stat=true;
   paramout.mask2_class=2;

   paramout.channel1_name=[listChannels listChannels{1}];
   paramout.channel2_name=[listChannels listChannels{1}];
   paramout.channel3_name=[listChannels listChannels{1}];
   paramout.channel4_name=[listChannels listChannels{1}];
  
    paramout.kMaxPixels=20;
    paramout.snapinc=1;

    paramout.tip=tip;
  
    return;
else
paramout=param; 
end

snapinc=paramout.snapinc;

channelsExtract={};

 paramout.mask1_name= paramout.mask1_name{end};
 paramout.mask2_name= paramout.mask2_name{end};

 i=1;
 cha=paramout.(['channel' num2str(i) '_name']);

for i=1:4
   paramout.(['channel' num2str(i) '_name'])= paramout.(['channel' num2str(i) '_name']){end};
    if ~strcmp( paramout.(['channel' num2str(i) '_name']),'N/A')
        cha=roiobj.findChannelID(paramout.(['channel' num2str(i) '_name']));
        channelsExtract=[channelsExtract cha];
    end
end

if numel(channelsExtract)==0 % this channel contains the segmented objects
   disp([' These channels do not exist for this ROI ! Quitting ...']) ;
   return;
end

if numel(obj.image)==0
    roiobj.load
end

% compute mask metrics 

data=roiobj.data; 

for i=1:2
    if  paramout.(['mask' num2str(i) '_stat']) &  ~strcmp(paramout.(['mask' num2str(i) '_name']),'N/A') % if detailed stat should be computed
       
cha=roiobj.findChannelID(paramout.(['mask' num2str(i) '_name']));

if numel(cha)==0
    continue
end

BW_3D=roiobj.im(:,:,cha,:);

 pixdata=find(arrayfun(@(x) strcmp(x.groupid, paramout.mask1_name),roiobj.data)); % find if object exists already 

% 
 if numel(pixdata)
     cc=pixdata; % data to be overwritten
 else
     if numel(roiobj.data.data)==0
      cc=1; % replace empty dataset
     else
     cc=numel(roiobj.data)+1;
     end
 end


 % chatGPT code inserted 
 nb_temps = size(BW_3D, 3);

% Obtenir la liste des valeurs entières différentes du masque
liste_valeurs = unique(BW_3D(:));

% Initialiser les tableaux pour stocker les résultats
surface = zeros(length(liste_valeurs), nb_temps);
axe_majeur = zeros(length(liste_valeurs), nb_temps);
axe_mineur = zeros(length(liste_valeurs), nb_temps);

% Calculer les statistiques pour chaque valeur de masque et chaque temps
for v = 1:length(liste_valeurs)
    for t = 1:nb_temps
        % Extraire le masque BW pour la valeur et le temps courants
        valeur = liste_valeurs(v);
        BW = (BW_3D(:,:,t) == valeur);
        
        % Calculer les statistiques
        stats = regionprops(BW, 'Area', 'MajorAxisLength', 'MinorAxisLength');
        
        % Stocker les résultats dans les tableaux
        surface(v,t) = sum([stats.Area]);
        axe_majeur(v,t) = mean([stats.MajorAxisLength]);
        axe_mineur(v,t) = mean([stats.MinorAxisLength]);
    end
end
 
 data(cc)=dataseries(data,datanames,'groupid',paramout.mask1_name,'parentid',roiobj.id);



    end
end


return

%%
if strcmp(method,'full')
    roiobj(1).path=modifyPath(roiobj(1),environment);
    roiobj(1).load();
  %  prompt=['Type the name of the result classif: (Default: full_with' num2str(kMaxPix) 'maxPixels) '];
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
    
   % prompt=['Which channel(s) to extract the signal from? (Default: [2:number of channelsExtract])' newline str];
 %   channelsExtract=input(prompt);
    for c=channelsExtract
        BckgValue(c)=0; %input(['Choose background value for channel' num2str(c) ' ']);
    end
    
  %  for r=1:numel(roiobj) %to parfor
        r=1;
        roiobj(r).path=modifyPath(roiobj(r),environment);        
        roiobj(r).load();
        
        lastFrame=numel(roiobj(r).image(1,1,1,:));
        if numel(channelsExtract)==0
            channelsExtract=1:numel(roiobj(r).image(1,1,:,1));
            if numel(channelsExtract)>1
                channelsExtract=2:numel(channelsExtract); %avoid channel 1 that is mostof the time not fluo
            end
        end
        
        cinc=1;
        for c=channelsExtract
            for t=1:lastFrame
                %init/reset
                roiobj(r).results.signal.full.(['from_' classiname]).meankmaxfluo(cinc,t)=NaN;
                roiobj(r).results.signal.full.(['from_' classiname]).meanfluo(cinc,t)=NaN;
                roiobj(r).results.signal.full.(['from_' classiname]).totalfluo(cinc,t)=NaN;
                %fill, reshaped used to make it line
                roiobj(r).results.signal.full.(['from_' classiname]).meankmaxfluo(cinc,t)=mean(maxk( reshape(roiobj(r).image(:,:,c,t),[],1) ,kMaxPix))-BckgValue(cinc);
                roiobj(r).results.signal.full.(['from_' classiname]).meanfluo(cinc,t)=mean(reshape(roiobj(r).image(:,:,c,t),[],1));
                roiobj(r).results.signal.full.(['from_' classiname]).totalfluo(cinc,t)=sum(reshape(roiobj(r).image(:,:,c,t),[],1));
            end
        end
        disp(['Average signal of ' num2str(kMaxPix) 'max pixels, mean and total signal was computed and added to roi(' num2str(r) ').results.signal.' num2str(classiname)])
        roiobj(r).clear;
        roiobj(r).save('results')
        
        cinc=cinc+1;
  %  end
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
    
   % prompt=['Which channel contains the MASK?' newline str newline];
    channelSegCell=paramout.mask_channel_name1;
    classiname=channelSegCell;
  %  if ~exist('channelSegCell','var')
  %      error('Indicate which channel contains the MASK');
  %  end
    
   % classiname=chans{channelSegCell};
    %===
    
    %===find the class of the mother, ask it only once.
   % prompt=(['Indicate the --number-- of the class corresponding to the mother in the classi: ' classiname ' (Default: 2) ' newline]);
    classidMother= paramout.mask_channel_class1;
    %input(prompt);
    
  %  if numel(classidMother)==0, classidMother=2; end
    %===
    
   % for r=1:numel(roiobj) %to parfor
       r=1;
        roiobj(r).path=modifyPath(roiobj(r),environment);
        roiobj(r).load();

    %   channelSegCell
        channelSegCell=roiobj(r).findChannelID(channelSegCell);
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
   % end
end


%%



if strcmp(method,'oneMask')

    roiobj.path=modifyPath(roiobj,environment);
    roiobj.load;

    %===channels
%     chans=roiobj(1).display.channel;
%     str=[];
%     for i=1:numel(chans)
%         str=[str num2str(i) ' - ' chans{i} ';  '];
%     end
    
 %   prompt=['Which channel(s) to EXTRACT the signal from?' newline str newline];
   % channelsExtract=%input(prompt);
%    if ~exist('channelsExtract','var')
%        error('Indicate channel(s) from which to extract the signal');
%    end
    
  %  prompt=['Which channel contains the MASK?' newline str newline];
  %  channelSegCell=input(prompt);
 %   if ~exist('channelSegCell','var')
 %       error('Indicate which channel contains the MASK');
 %   end

    channelSegCell=paramout.mask_channel_name1;
    classiname=channelSegCell; %chans{channelSegCell};
    %===
    
    %===find the class of the mother, ask it only once.
  %  prompt=(['Indicate the --number-- of the class corresponding to the mother in the classi: ' classiname ' (Default: 2) ' newline]);
    classidMother= paramout.mask_channel_class1;%input(prompt);
   % if numel(classidMother)==0, classidMother=2; end
    
    
    %prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiname ' (Default: 1) ' newline]);
    classidBckg=1;%input(prompt);
 %   if numel(classidBckg)==0, classidBckg=1; end
    %===
    
   r=1; %  for r=1:numel(roiobj) %to parfor
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
        lastFrame=numel(roiobj(r).image(1,1,channelSegCell,:));
        
        
        roiobj(r).results.signal.onemask.(['from_' classiname]).volume=[];
        roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo=[];
        roiobj(r).results.signal.onemask.(['from_' classiname]).meanfluo=[];
     
        cinc=1;
        for c=channelsExtract
            meanbckg=[];
            for t=1:lastFrame
                im=roiobj(r).image(:,:,c,t);
                
                %init/reset
                maskTotal=zeros(size(im),'uint16');
                maskMother=zeros(size(im),'uint16');
                maskBckg=zeros(size(im),'uint16');
                roiobj(r).results.signal.onemask.(['from_' classiname]).volume(t)=NaN;
                roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(cinc,t)=NaN;
                roiobj(r).results.signal.onemask.(['from_' classiname]).meanfluo(cinc,t)=NaN;
                
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
                if postprocess==true
                    if vol<volThresh
                        vol=0;
                    end
                end
                roiobj(r).results.signal.onemask.(['from_' classiname]).volume(t)=vol;
                roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(cinc,t)=sum(maskedMother(:));
            end
            roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(cinc,:)=roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(cinc,:)-mean(meanbckg);
            roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(cinc,   roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(cinc,:)<0   )=0;
            roiobj(r).results.signal.onemask.(['from_' classiname]).meanfluo(cinc,:)=roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(cinc,:)./roiobj(r).results.signal.onemask.(['from_' classiname]).volume;
            
            %ici enlever les frames en trop
            tremove=1:lastFrame;
            tremove(1:snapinc:end)=[];
            
            roiobj(r).results.signal.onemask.(['from_' classiname]).totalfluo(cinc,tremove)=NaN;
            roiobj(r).results.signal.onemask.(['from_' classiname]).meanfluo(cinc,tremove)=NaN;
            cinc=cinc+1;
        end
        
        disp(['Volume, average and total signal of mothercell was computed and added to roi(' num2str(r) ').results.signal.onemask' num2str(['.from_' classiname])])

        roiobj(r).save('results');
        roiobj(r).clear;
        clear im
end

%% twomask
if strcmp(method,'TwoMask')
    roiobj(1).path=modifyPath(roiobj(1),environment);
    roiobj(1).load();
    %===ask channels
%     chans=roiobj(1).display.channel;
%     str=[];
%     for i=1:numel(chans)
%         str=[str num2str(i) ' - ' chans{i} ';  '];
%     end
    
   % prompt=['Which channel(s) to EXTRACT the signal from?' newline str newline];
    %channelsExtract=input(prompt);
    %if ~exist('channelsExtract','var')
      %  error('Indicate channel(s) from which to extract the signal');
   % end
    
  %  prompt=['Which channel contains the MASK 1?' newline str newline];
  %  channelSegCell=input(prompt);

    channelSegCell=paramout.mask_channel_name1;
    classiname=channelSegCell; %chans{channelSegCell};
 classidMother= paramout.mask_channel_class1;

  %  if ~exist('channelSegCell','var')
  %      error('Indicate which channel contains the MASK 1');
  %  end
    
 %   prompt=['Which channel contains the MASK 2?' newline str newline];
%    channelSegNuc=input(prompt);
   % if ~exist('channelSegNuc','var')
     %   error('Indicate which channel contains the MASK 2');
    %end
    
     channelSegNuc=paramout.mask_channel_name2;
     classiNucName= channelSegNuc;
      classidNucleus= paramout.mask_channel_class2;

 %   channelExtractName=chans{channelsExtract};
%    classiname=chans{channelSegCell};
  %  classiNucName=chans{channelSegNuc};
    %===
    
    %===ask class ID
%     prompt=(['Indicate the --number-- of the class corresponding to the mother onemask in the classi: ' classiname ' (Default: 2) ' newline]);
%     classidMother=input(prompt);
%     if numel(classidMother)==0, classidMother=2; end
    %             for i=1:numel(roiobj(r).classes)
    %                 strB=[strB num2str(i) ' - ' roiobj(r).classes{i} ';'];
    %             end
%    prompt=(['Indicate the --number-- of the class corresponding to the background in the classi: ' classiNucName ' (Default: 1) ' newline]);
    classidBckg=1; %input(prompt);
  %  if numel(classidBckg)==0, classidBckg=1; end
    
    %find the classid of the nucleus, ask it only once.
 %   prompt=(['Indicate the --number-- of the class corresponding to the nucleus in the classi: ' classiNucName ' (Default: 2) ' newline]);
   % classidNucleus=input(prompt);
    %if numel(classidNucleus)==0, classidNucleus=2; end
    %===
    
    %NOW WORK ON ALL THE ROIS
 %   for r=1:numel(roiobj) %to parfor
 r=1;
        roiobj(r).path=modifyPath(roiobj(r),environment);
        roiobj(r).load();
        
    %    channelsExtract=findChannelID(roiobj(r),channelExtractName);   
        channelSegCell=findChannelID(roiobj(r),classiname);        
        channelSegNuc=findChannelID(roiobj(r),classiNucName);
        
        %extract fluo for each given channel
        lastFrame=numel(roiobj(r).image(1,1,channelsExtract(1),:));
        
        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).volume=[];
        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).totalfluo=[];
        roiobj(r).results.signal.nucleus.(['from_' classiNucName]).meanfluo=[];
        
        cinc=1;
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
                
                roiobj(r).results.signal.nucleus.(['from_' classiNucName]).volume(t)=NaN;
                roiobj(r).results.signal.nucleus.(['from_' classiNucName]).totalfluo(cinc,t)=NaN;
                roiobj(r).results.signal.nucleus.(['from_' classiNucName]).meanfluo(cinc,t)=NaN;
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
                
                roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(cinc,t)=sum(maskedNucleusMother(:));
                roiobj(r).results.signal.twomask.(['from_' classiNucName]).meanfluo(cinc,t)=roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(cinc,t)/sum(maskNucleusMother(:));
            end
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(cinc,:)=roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(cinc,:)-mean(meanbckg);
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(cinc,(roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(cinc,:)<0))=0;
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).meanfluo(cinc,:)=roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(cinc,:)./roiobj(r).results.signal.twomask.(['from_' classiNucName]).volume;            
            
            %Remove duplicated frames (from different snapping frequency)
            tremove=1:lastFrame;
            tremove(1:snapinc:end)=[];
            
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).totalfluo(cinc,tremove)=NaN;
            roiobj(r).results.signal.twomask.(['from_' classiNucName]).meanfluo(cinc,tremove)=NaN;
        cinc=cinc+1;
        end
        
        disp(['Volume, average and total signal of twomask was computed and added to roi(' num2str(r) ').results.signal.twomask' num2str(['.from_' classiNucName])])
        roiobj(r).save('results');
        roiobj(r).clear;
        clear im
        
%    end
end

%%
if strcmp(method,'fociOrNot')
    roiobj(1).load();
    %===ask channels
%     chans=roiobj(1).display.channel;
%     str=[];
%     for i=1:numel(chans)
%         str=[str num2str(i) ' - ' chans{i} ';  '];
%     end
    
%    prompt=['Which channel contains the foci mask?' newline str newline];
    %channelFociMask=input(prompt);
   % if ~exist('channelFociMask','var')
     %   error('Indicate channelof the foci mask');
    %end    
    channelFociMaskName=paramout.mask_channel_name1;
    
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

