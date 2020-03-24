function addROI(obj,roival,fovparentid)
% add roi object instance to field of view


if numel(obj.roi)==0 | numel(obj.roi(1).id)==0 % currently no ROI defined
    obj.roi(1) = roi([obj.id '_' num2str(1)],roival);
    obj.roi(1).parent=fovparentid;
else
    tmp=numel(obj.roi);
    obj.roi(tmp+1) = roi([obj.id '_' num2str(tmp+1)],roival);
    obj.roi(tmp+1).parent=fovparentid;
end