function txt = describeFov(fovObj)
% workflowui.describeFov  Build a short textual summary for a FOV.

parts = {};
try
    if isprop(fovObj,'id') && ~isempty(fovObj.id)
        parts{end+1} = ['ID: ' char(string(fovObj.id))]; %#ok<AGROW>
    end
catch
end
try
    if isprop(fovObj,'srcpath') && iscell(fovObj.srcpath) && ~isempty(fovObj.srcpath) && ~isempty(fovObj.srcpath{1})
        parts{end+1} = ['Path: ' char(string(fovObj.srcpath{1}))]; %#ok<AGROW>
    end
catch
end
try
    if isprop(fovObj,'srclist') && iscell(fovObj.srclist) && ~isempty(fovObj.srclist) && ~isempty(fovObj.srclist{1})
        parts{end+1} = ['Frames: ' num2str(numel(fovObj.srclist{1}))]; %#ok<AGROW>
    elseif isprop(fovObj,'frames') && ~isempty(fovObj.frames)
        parts{end+1} = ['Frames: ' num2str(max(double(fovObj.frames(:))))]; %#ok<AGROW>
    end
catch
end
try
    if isprop(fovObj,'channel') && ~isempty(fovObj.channel)
        parts{end+1} = ['Channels: ' strjoin(cellstr(string(fovObj.channel(:)')) , ', ')]; %#ok<AGROW>
    end
catch
end
try
    im = readImage(fovObj, 1, 1);
    if ~isempty(im)
        s = size(im);
        parts{end+1} = sprintf('Size: %dx%d', s(2), s(1)); %#ok<AGROW>
    end
catch
end
if isempty(parts)
    txt = '';
else
    txt = strjoin(parts, ' | ');
end
end
