function count = frameCount(roiObj)
%ANNOTATIONMANAGER.FRAMECOUNT Determine ROI length without requiring full load.
persistent imageCounts
if isempty(imageCounts),imageCounts=containers.Map('KeyType','char','ValueType','any');end

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
    stamp=dir(h5File);signature=[];
    if ~isempty(stamp),signature=[stamp(1).bytes stamp(1).datenum];end
    if ~isempty(signature)&&isKey(imageCounts,h5File)
        cached=imageCounts(h5File);
        if isequal(cached.signature,signature)
            count=max(count,cached.count);return;
        end
    end
    info = h5info(h5File);diskMaximum=0;
    for i = 1:numel(info.Datasets)
        diskCount = 0;
        try
            % h5info already materialized attribute values. Reopening the
            % network file once per channel adds seconds to every UI action.
            attributes=info.Datasets(i).Attributes;
            index=find(strcmp({attributes.Name},'frames'),1);
            storedFrames=[];
            if ~isempty(index),storedFrames=double(attributes(index).Value);end
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
        diskMaximum=max(diskMaximum,diskCount);
    end
    count=max(count,diskMaximum);
    if diskMaximum>0&&~isempty(signature)
        if imageCounts.Count>=512,remove(imageCounts,keys(imageCounts));end
        imageCounts(h5File)=struct('signature',signature,'count',diskMaximum);
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
