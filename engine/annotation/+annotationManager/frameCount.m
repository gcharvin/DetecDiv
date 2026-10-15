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
    if ~isfile(h5File)
        if count==0,count=dataFrameCount(roiObj);end
        return;
    end
    info = h5info(h5File);
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
if count==0,count=dataFrameCount(roiObj);end
end

function count=dataFrameCount(roiObj)
% Data is a fallback only: long object tables cannot extend real images.
count=0;
try
    data=roiObj.data;
    if isempty(data)||all(arrayfun(@(d)isempty(d.data),data))
        filename=fullfile(char(string(roiObj.path)),['data_' char(string(roiObj.id)) '.mat']);
        if isfile(filename),roiObj.load('Data','Silent');end
    end
    for i=1:numel(roiObj.data)
        ds=roiObj.data(i);if ~strcmp(ds.type,'temporal'),continue;end
        if ismember('frame',ds.data.Properties.VariableNames)
            frames=ds.data.frame;
            if isnumeric(frames)&&isvector(frames)&&all(isfinite(frames))&&all(frames>=1)
                count=max([count;double(frames(:))]);
            end
        else
            count=max(count,height(ds.data));
        end
    end
catch
end
end
