function computeDisplaylim(obj, varargin)

clearfile=0;
channels=[];

for i=1:numel(varargin)
    if strcmp(varargin{i},'Clear')
        clearfile=1;
    end
      if strcmp(varargin{i},'Channel')
        channels=varargin{i+1};
    end
end

satur=[0.001 0.999];
    
if numel(obj.image)==0
    disp(['No image loaded for ROI ' num2str(obj.id) ', loading image']);
    obj.load
end


if numel(channels)==0
    channels=1:size(obj.image,3);
end

tmp=obj.image;

cc=1;

for c=channels
    tmpimg=tmp(:,:,c,:);
    
%     if sum(tmpimg(tmpimg>0))>0
%         tmpimg=tmpimg(tmpimg>0); % to avoid problems with masked images where most of pixels are =0
%     end

    A=tmpimg==0;
    if numel(A)==0
        A=0;
    end
    A=sum(A(:)); %number of pixels =0
    n=numel(tmpimg(:));
        
    matmp=maxk( tmpimg(:), n- round((satur(2))*n) ); %*A/n... to compensate for the loss of bright pixels from the background, in masked images 
    ma(cc)=min(matmp);
    mitmp = mink(tmpimg(:),round((satur(1) +A/n)*n)); %A/n to account for pixels =0, which have to be saturated, + a corrective term
    if numel(mitmp)==0
        mitmp=0;
    end
    mi(cc) = max(mitmp);

%     med(c)=median(tmpimg(:));
%     stddev(c)=std(double(tmpimg(:)));
    %for t=1:min(100,size(tmp,4)) %computes stretchlim on the 100 first frames of the timeseries, saturating 1% of pixels

        %lm(:,t)=stretchlim(tmp(:,:,c,t),[0.001 0.999]);
    %end
    %strchlm(:,c)=mean(lm,2);
    cc=cc+1;
end


if isa(tmp,'uint16')
  mi=double(mi)/65536;
  ma=double(ma)/65536;
end

if isa(tmp,'uint8')
  mi=double(mi)/256;
  ma=double(ma)/256;
end


% obj.display.stretchlim=[max(0,double(med)-4*stddev) ;
% min(65535,double(med)+4*stddev)]/65535; % does not work well with images
%with large stretches of 0's. 

mi=max([mi;  zeros(1,length(mi))],[],1);
mi=min([mi;  ones(1,length(mi))],[],1);

ma=max([ma;  mi+0.0001],[],1);
ma=min([ma;  ones(1,length(ma))],[],1);
ma=max([ma;  0.001*ones(1,length(ma))],[],1);

obj.display.displaylim=[];
obj.display.displaylim(1:2,channels)=[mi ; ma]; %home made stretchilm to work with multi D images. slow but more reliable

if clearfile==1
    obj.save;
    obj.clear; %can cause problem if called from another fonction
end