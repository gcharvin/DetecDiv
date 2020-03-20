function setintensity(obj,val)
% set intensity value to display gfp images

obj.intensity=val;

for i=1:numel(obj.trap)
    obj.trap(i).intensity=obj.intensity; 
    
end