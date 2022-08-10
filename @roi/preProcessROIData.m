function im=preProcessROIData(obj,ch,fr,dorepmat)



% if numel(dorepmat)==0
%     dorepmat=1;
% end
% preprocess frame / channel image of ROI and returns corresponding image
% %fr must be a double, not a vector;
% perImage=0;
% %here add param.perImage


tmp=obj.image(:,:,ch,fr);
imout=zeros(size(tmp,1),size(tmp,2),numel(ch));

%if perImage==1 %if imadjust from each image
%    strchlm=stretchlim(tmp(:,:,(end-1)/2 + 1,fr),[0.001 0.999]); 
%else %if imadjust with bounds computed from the whole timeseries
    
    %     if ~isfield(obj.display,'stretchlim') && ~isprop(obj.display,'stretchlim')
%         error(['No stretch limits found for ROI ' num2str(obj.id) ', launch their computation using roi.computeStretchlim...']);
%     end

   cmpt=0;
    if (~isfield(obj.display,'stretchlim') && ~isprop(obj.display,'stretchlim')) || size(obj.display.stretchlim,2)~=numel(obj.channelid) 
      cmpt=1;
    else
     for i=1:numel(ch)
         if obj.display.stretchlim(2,ch(i))==0
             cmpt=1;
         end
     end
    end

    if cmpt==1
              disp(['No stretch limits found for ROI ' num2str(obj.id) ', computing them...']);
            obj.computeStretchlim;
    end
  
    for i=1:numel(ch)
  %  strchlm=obj.display.stretchlim(:,(ch(end)-ch(1))/2 + ch(1)); %middle stack
   strchlm=obj.display.stretchlim(:,ch(i));
 %  imout(:,:,i)=tmp(:,:,i);
   imout(:,:,i)=double(imadjust(tmp(:,:,i),strchlm))/65535;
    end

%end
% for t=1:size(tmp,4) %computes strechlim on the whole timeseries, saturating 1% of pixels
%     lm(:,t)=stretchlim(tmp(:,:,(end-1)/2 + 1,t),[0.005 0.995]);
% end
% strchlm=mean(lm,2);
%strchlm=obj.display.strchlim((ch(end)-ch(1))/2 + ch(1),:); %takes the strechlim, computed from the fov, from the middle stack
%strchlm=stretchlim(tmp(:,:,1 + (end-1)/2)); % computes the strecthlim for the middle stack. To be changed once we add multichannels as inputs.
%tmp = double(imadjust(tmp,strchlm))/65535;
%imout=tmp;


switch numel(ch)
    case 1
   im=repmat(imout,[1 1 3]);
    case 2
  im=imout;
  im(:,:,3)=0;
    case 3
  im=imout;
    otherwise
   im=[];
   disp('This image has more than 3 channels!')
end
% 
% if dorepmat==1 && numel(ch)==1
%     im=repmat(imout,[1 1 3]);
% elseif dorepmat==0
%     im=imout;
% elseif numel(ch)==3
%     im=imout;
% else
%     error('This image must have 1 or 3 channels');
% end

            