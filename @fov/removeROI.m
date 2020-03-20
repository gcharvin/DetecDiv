function removeROI(obj,roiid)
% add roi object instance to field of view

if ischar(roiid)
     obj.roi=roi('',[]);
    return;
end

if numel(obj.roi)==1
    obj.roi=roi('',[]);
    return;
end

pix=setxor(1:numel(obj.roi),roiid);
obj.roi=obj.roi(pix);