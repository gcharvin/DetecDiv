function removeFovContours(shallowObj)
% remove contrours in case a phyloCell import has been done to import
% cells1/ nucleus contours

for i=1: numel(shallowObj)
    
    shallowObj.fov(i).contours=[];
    
end