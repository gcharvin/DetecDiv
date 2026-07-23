function filename = pathForROI(roiobj)
%CELLMODEL.PATHFORROI Return the conventional independent HDF5 sidecar path.
if isempty(roiobj) || isempty(roiobj.path) || isempty(roiobj.id)
    filename=''; return;
end
filename=fullfile(char(string(roiobj.path)),sprintf('objects_%s.h5',char(string(roiobj.id))));
end
