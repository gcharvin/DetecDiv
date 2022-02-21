function im=preProcessROIData(obj,ch,fr,param)

% preprocess frame / channel image of ROI and returns corresponding image

perImage=0;
%here add param.perImage


tmp=obj.image(:,:,ch,fr);
imout=zeros(size(tmp,1),size(tmp,2),numel(ch));

if perImage==1 %if imadjust from each image
    strchlm=stretchlim(tmp(:,:,(end-1)/2 + 1,fr),[0.001 0.999]); 
else %if imadjust with bounds computed from the whole timeseries
    if ~isfield(obj.display,'strchlim') && ~isprop(obj.display,'strchlim')
        obj.computeStretchlim;
    end
    strchlm=obj.display.stretchlim(:,(ch(end)-ch(1))/2 + ch(1)); %middle stack
end
% for t=1:size(tmp,4) %computes strechlim on the whole timeseries, saturating 1% of pixels
%     lm(:,t)=stretchlim(tmp(:,:,(end-1)/2 + 1,t),[0.005 0.995]);
% end
% strchlm=mean(lm,2);
%strchlm=obj.display.strchlim((ch(end)-ch(1))/2 + ch(1),:); %takes the strechlim, computed from the fov, from the middle stack
%strchlm=stretchlim(tmp(:,:,1 + (end-1)/2)); % computes the strecthlim for the middle stack. To be changed once we add multichannels as inputs.
tmp = double(imadjust(tmp,strchlm))/65535;
imout=tmp;


if numel(ch)==1
    im=repmat(imout,[1 1 3]);
elseif numel(ch)==3
    im=imout;
else
    error('This image must have 1 or 3 channels');
end

            