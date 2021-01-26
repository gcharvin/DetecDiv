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

tmp=obj.image(:,:,ch,fr);
tmp = double(imadjust(tmp,[param.meanphc/65535 param.maxphc/65535],[0 1]))/65535;
im=repmat(tmp,[1 1 3]);

            