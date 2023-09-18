function addChannel(obj,matrix,str,rgb,intensity)

% a channel is a matrix that has either 1 or 3 sub channels , other
% dimensions being like the obj.image.

if numel(obj.image)==0
    obj.load
end

if numel(obj.image)==0
    disp(['Error, matrix size mismatch:  obj.image:' num2str(size(obj.image)) ' vs matrix:' num2str(size(matrix)) ] );
    return;
end

if size(obj.image,1)~= size(matrix,1)
    disp(['Error, matrix size mismatch:  obj.image:' num2str(size(obj.image)) ' vs matrix:' num2str(size(matrix)) ] );
    return;
end
if size(obj.image,2)~= size(matrix,2)
    disp(['Error, matrix size mismatch:  obj.image:' num2str(size(obj.image)) ' vs matrix:' num2str(size(matrix)) ] );
    return;
end
if size(obj.image,4)~= size(matrix,4)
    disp(['Error, matrix size mismatch:  obj.image:' num2str(size(obj.image)) ' vs matrix:' num2str(size(matrix)) ] );
end

if  size(matrix,3)~=1 && size(matrix,3)~=3
    disp(['Error, matrix size 3rd dimension must be either 1 or 3' ] );
end

% add matrix to existing list of channel

if nargin<=3
    rgb=[1 1 1];
    intensity=[1 1 1];
end

matrix=uint16(matrix);

imz=size(obj.image); % 3rd dimension 
% here

obj.display.channel{end+1}=str;
obj.display.intensity(end+1,:)=intensity;
obj.display.rgb(end+1,:)=rgb;

if  numel(imz)<3
    obj.image(:,:,1+1:1+size(matrix,3),:)=matrix;
else
    obj.image(:,:,imz(3)+1:imz(3)+size(matrix,3),:)=matrix;
end


obj.display.selectedchannel(end+1)=1;

tmp=(max(obj.channelid)+1)*ones(1,size(matrix,3));

obj.channelid=[obj.channelid tmp];

 obj.log(['Added channel ' num2str(numel(obj.display.channel)) ' to ROI'],'Processing');


% then create pipeline to make machine learning : training + classification
% classi class that belongs to shallow object % can be either standard
% machine learning or 

% can be iether image classif, pixel classification, and LSTM