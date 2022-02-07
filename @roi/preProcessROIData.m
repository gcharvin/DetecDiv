function im=preProcessROIData(obj,ch,fr,param)

% preprocess frame / channel image of ROI and returns corresponding image

% fra=[];
% fra(1)=fr-1;
% fra(2)=fr;
% fra(3)=fr+1;
% 
% if fr==1
%    fra(1)=1;
% end
% 
% if fr==size(obj.image,4)
%    fra(3)= size(obj.image,4);
% end

% im=zeros(size(obj.image,1),size(obj.image,2),3);
% 
% 
% for i=1:3
% tmp=obj.image(:,:,ch,fra(i));
% tmp = double(imadjust(tmp,[param.meanphc/65535 param.maxphc/65535],[0 1]))/65535;
% im(:,:,i)=tmp;
% end

if ~isfield(param,'nframes')
    param.nframes=1;
end

switch  param.nframes % number of images to be stitched together
    case 1
    n=1; 
    
    case {2,3,4}
      n=2;
      
    case {5,6,7,8,9}
      n=3;
      
    otherwise
      n=3;
end

tmp=obj.image(:,:,ch,fr);
imout=zeros(n*size(tmp,1),n*size(tmp,2),numel(ch));

cc=1;
ccol=1;

for i=1:param.nframes
    frshift=fr-round(param.nframes/2)+i;
  %  cc
    if frshift>=1 && frshift<= size(obj.image,4)
     %   'ok'
     
        crow=mod((cc-1),n);
        ccol=floor((cc-1)/n);
        
        tmp=obj.image(:,:,ch,frshift);
        tmp = double(imadjust(tmp,stretchlim(tmp)))/65535;

        
        imout(ccol*size(tmp,1)+1:(ccol+1)*size(tmp,1),crow*size(tmp,2)+1:(crow+1)*size(tmp,2),:)=tmp;
       
    end
     cc=cc+1;
end

if numel(ch)==1
    im=repmat(imout,[1 1 3]);
elseif numel(ch)==3
    im=imout;
else
    error('This image must have 1 or 3 channels');
end

            