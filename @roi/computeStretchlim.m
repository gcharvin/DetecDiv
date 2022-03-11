function computeStretchlim(obj, varargin)

clearfile=0;
for i=1:numel(varargin)
    if strcmp(varargin{i},'Clear')
        clearfile=1;
    end
end
    
if numel(obj.image)==0
    disp(['No image loaded for ROI ' num2str(obj.id) ', loading image']);
    obj.load
end
tmp=obj.image(:,:,:,:);

for c=1:size(tmp,3)
    tmpimg=tmp(:,:,c,:);
    med(c)=median(tmpimg(:));
    stddev(c)=std(double(tmpimg(:)));
    %for t=1:min(100,size(tmp,4)) %computes stretchlim on the 100 first frames of the timeseries, saturating 1% of pixels
        
        %lm(:,t)=stretchlim(tmp(:,:,c,t),[0.001 0.999]);
    %end
    %strchlm(:,c)=mean(lm,2);
end
obj.display.stretchlim=[max(0,double(med)-4*stddev) ; min(65535,double(med)+4*stddev)]/65535;
%obj.display.stretchlim=strchlm

if clearfile==1
    obj.save;
    obj.clear; %can cause problem if called from another fonction
end