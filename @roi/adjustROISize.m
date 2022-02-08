function adjustROISize(obj,val)
% change the ROI array

% val must be : [ x y width height ]

switch numel(val)
    case 4 % 
        if val(1)==0 % change width and height but keep centering
           tmp=obj.value;
           
           obj.value(3:4)=val(3:4);
           
           obj.value(1)=obj.value(1)-(val(3)-tmp(3))/2;
           obj.value(2)=obj.value(2)-(val(4)-tmp(4))/2;
        else
           obj.value=val;      
        end
    case 2 % change position origin
        obj.value(1:2)= val;
end

    
