function removeROIs(obj)

for i=1:numel(obj.fov)
   obj.fov(i).removeROI;
end