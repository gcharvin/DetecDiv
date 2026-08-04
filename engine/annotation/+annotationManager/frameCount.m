function count = frameCount(roiObj)
%ANNOTATIONMANAGER.FRAMECOUNT Determine ROI length without requiring full load.

count = 0;
try
    if ~isempty(roiObj.image)
        count = size(roiObj.image, 4);
        if count > 0, return; end
    end
catch
end
try
    h5File = fullfile(char(string(roiObj.path)), ...
        ['im_' char(string(roiObj.id)) '.h5']);
    if ~isfile(h5File), return; end
    info = h5info(h5File);
    if isempty(info.Datasets), return; end
    dims = double(info.Datasets(1).Dataspace.Size);
    if numel(dims) >= 4
        count = dims(4);
    elseif numel(dims) == 3
        count = dims(3);
    else
        count = 1;
    end
catch
    count = 0;
end
end
