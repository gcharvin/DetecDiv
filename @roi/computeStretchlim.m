function computeStretchlim(obj)

if numel(obj.image)==0
    disp(['No image loaded for ROI ' num2str(obj.id) ', loading image']);
    obj.load
end
tmp=obj.image(:,:,:,:);

for c=1:size(tmp,3)
    for t=1:min(100,size(tmp,4)) %computes stretchlim on the 100 first frames of the timeseries, saturating 1% of pixels
        lm(:,t)=stretchlim(tmp(:,:,c,t),[0.001 0.999]);
    end
    strchlm(:,c)=mean(lm,2);
end
obj.display.stretchlim=strchlm;