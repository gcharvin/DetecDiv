function im=preProcessROIData(obj,ch,fr,dorepmat)
perFrames=0;
satur=[0.001 0.999];

if numel(dorepmat)==0
    dorepmat=1;
end

tmp=obj.image(:,:,ch,fr);
imout=zeros(size(tmp,1),size(tmp,2),numel(ch));

if perFrames==0
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
end

for i=1:numel(ch)
    %  strchlm=obj.display.stretchlim(:,(ch(end)-ch(1))/2 + ch(1)); %middle stack
    if perFrames==0
        strchlm=obj.display.stretchlim(:,ch(i));
    else
        strchlm=stretchlim(tmp(:,:,ch(i),:),satur);
    end

    if strchlm(1)>= strchlm(2)
        im=[];
        return;
    end

    %  imout(:,:,i)=tmp(:,:,i);
    imout(:,:,i)=double(imadjust(tmp(:,:,i),strchlm))/65535;
end


switch numel(ch)
    case 1
        if dorepmat==1
            im=repmat(imout,[1 1 3]);
        else
            im=imout;
        end
    case 2
        im=imout;
        im(:,:,3)=0;
    case 3
        im=imout;
    otherwise
        im=[];
        disp('This image has more than 3 channels!')
end


