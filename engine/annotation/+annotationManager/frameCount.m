function count = frameCount(roiObj)
%ANNOTATIONMANAGER.FRAMECOUNT Determine ROI length without requiring full load.

count = 0;
try
    if ~isempty(roiObj.image)
        count = size(roiObj.image, 4);
    end
catch
end
try
    h5File = fullfile(char(string(roiObj.path)), ...
        ['im_' char(string(roiObj.id)) '.h5']);
    if ~isfile(h5File), return; end
    info = h5info(h5File);
    if isempty(info.Datasets), return; end
    for i = 1:numel(info.Datasets)
        datasetPath = ['/' info.Datasets(i).Name];
        diskCount = 0;
        try
            storedFrames = double(h5readatt(h5File, datasetPath, 'frames'));
            storedFrames = storedFrames(isfinite(storedFrames));
            if ~isempty(storedFrames)
                if any(storedFrames == 0) && ~any(storedFrames < 0)
                    storedFrames = storedFrames + 1;
                end
                diskCount = max(storedFrames);
            end
        catch
        end
        if diskCount < 1
            dims = double(info.Datasets(i).Dataspace.Size);
            if numel(dims) >= 4
                diskCount = dims(4);
            elseif numel(dims) == 3
                diskCount = dims(3);
            else
                diskCount = 1;
            end
        end
        count = max(count, diskCount);
    end
catch
    % Keep a trustworthy in-memory count when disk metadata is unavailable.
end
end
