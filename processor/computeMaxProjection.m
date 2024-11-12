function [paramout,dataout,imageout]=computeMaxProjection(param,roiobj,frames)


% listChannels=['N/A', listChannels];
environment='pc' ;

if nargin==0
     listChannels=listAvailableChannels;

     % Initialisation d'un set pour les noms de canaux uniques
uniqueChannels = {};

% Parcourir chaque élément du cell array
for i = 1:length(listChannels)
    % Extraire la chaîne courante
    currentChannel = listChannels{i};
    
    % Trouver la position du séparateur '_z'
    idx = strfind(currentChannel, '_z');
    
    % Si '_z' est trouvé, extraire le nom de canal
    if ~isempty(idx)
        currentChannel = currentChannel(1:idx-1);
    end
    
    % Ajouter le canal à la liste des canaux uniques si pas déjà présent
    if ~ismember(currentChannel, uniqueChannels)
        uniqueChannels{end+1} = currentChannel; %#ok<AGROW>
    end
end

    paramout=[];
    
    tip={};
    cc=1;

    paramout.method={'Max', 'Mean','Max'};
    paramout.channel=[uniqueChannels uniqueChannels{1}];
    paramout.zstacks='0';
    paramout.outputChannelName='projectedChannel';


    tip{cc}= 'Please choose the projection method; Max: max projection; Mean : mean projection'; cc=cc+1;
    tip{cc}= 'Please select the channel to be projected'; cc=cc+1;
    tip{cc}= 'Please enter 0 if all stacks should be projected; otherwise, please enter the stacks numbers to be used'; cc=cc+1;
    tip{cc}= 'Please enter the name of the output channel'; cc=cc+1;

    paramout.tip=tip;
  
    return;
else
paramout=param; 
end

dataout=[];
obj=roiobj;

channels=roiobj.display.channel;

ids=find(contains(channels, paramout.channel{end}));

chid=[];
cc=1;

for i=1:numel(ids)

channelID=obj.findChannelID(channels{ids(i)});

if numel(channelID)>0
chid(cc)=channelID; 
cc=cc+1;
end

end



if numel(obj.image)==0
    obj.load
end

if nargin<3
    frames=1:size(im,4);
end

if numel(frames)==0
   frames=1:size(im,4);  
end


im=obj.image(:,:,chid,frames);
imout=zeros(size(im));

if strcmp(paramout.method{end},'Mean')
 imout=mean(im,3);
end
if strcmp(paramout.method{end},'Max')
 imout=max(im,[],3);
end

%figure, imshow(imout,[]);

pixresults=findChannelID(obj,paramout.outputChannelName);

if numel(pixresults)>0
%pixresults=find(roiobj.channelid==cc); % find channels corresponding to trained data

obj.image(:,:,pixresults,frames)=imout; %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
else
   % add channel is necessary 
   matrix=uint16(zeros([size(imout,1), size(imout,2), 1, size(imout,4)])); %uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
   matrix(:,:,:,frames)=imout;
   rgb=[1 1 1];
   intensity=[1 1 1]; % makes the image 'ndexed' and not grayscale in draw.m
   %pixresults=size(obj.image,3)+1;
   obj.addChannel(matrix,paramout.outputChannelName,rgb,intensity);
end

imageout=obj.image;
%figure, imshow(imageout(:,:,end,:),[])
