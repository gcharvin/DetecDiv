function im=preProcessROIData(obj,ch,fr,dorepmat)



tmp=obj.image(:,:,ch,fr);
imout=zeros(size(tmp,1),size(tmp,2),numel(ch));


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


            