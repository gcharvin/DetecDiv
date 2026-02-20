function frames=checkGroundtruth(classif,channelstr,roiid)
% check whether an roi has a painted groundtruth on a given channel

for j=roiid
    obj=classif.roi(j);
    
    pix2=find(matches(obj.display.channel,channelstr));
    
    frames=[];
    
    disp([' ROI: ' num2str(j) ' :']);
    
    if numel(pix2)
        pix=find(obj.channelid==pix2); % find channels corresponding to trained data
        
        if numel(obj.image)==0
            obj.load
        end
        
        gfp=obj.image(:,:,pix,:);
        
        for i=1:size(obj.image,4)
            tmp=gfp(:,:,1,i);
            
            if sum(tmp(:))>0
                frames=[frames i];
            end
        end
        
        frames
        
        
    end
end


