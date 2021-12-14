

for i=[ 41 144:200]
   
    i
    
    seg.processing.classification(5).roi(i).load
    
    seg.processing.classification(5).roi(i).removeChannel(6);
    seg.processing.classification(5).roi(i).image=seg.processing.classification(5).roi(i).image(:,:,1:7,:);
    seg.processing.classification(5).roi(i).save
end

shallowSave(seg)
