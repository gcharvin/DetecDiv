function roiAssertFrameCoverage(rois, channels, frames, preferDisk)
% Check persisted channel extents without loading or padding image pixels.
if nargin < 4, preferDisk = true; end
if isempty(frames) || ~isnumeric(frames) || isequal(frames, -1), return; end
frames = unique(double(frames(:)'));
if any(~isfinite(frames) | frames < 1 | frames ~= fix(frames))
    error('runPipeline:InvalidFrames', 'Frame selection must contain positive integer indices.');
end
channels = cellstr(string(channels));
for i = 1:numel(rois)
    r = rois(i);
    file = fullfile(char(string(r.path)), ['im_' char(string(r.id)) '.h5']);
    persisted = preferDisk && isfile(file);
    if persisted
        info = h5info(file);
    end
    for j = 1:numel(channels)
        name = channels{j};
        if persisted
            dataset = [];
            for k = 1:numel(info.Datasets)
                d = info.Datasets(k);
                logicalName = attribute(d, 'channel_name', d.Name);
                if strcmp(char(string(logicalName)), name) || ...
                        strcmp(d.Name, regexprep(name, '[^a-zA-Z0-9_]', '_'))
                    dataset = d; break;
                end
            end
            if isempty(dataset)
                fail(r, name, frames, [], file);
            end
            sz = double(dataset.Dataspace.Size);
            storedFrames = double(attribute(dataset, 'frames', []));
            count = 1;
            if numel(sz) >= 4
                count = sz(4);
            elseif numel(sz) == 3 && numel(storedFrames) == sz(3) && ...
                    double(attribute(dataset, 'num_subchannels', 1)) == 1
                count = sz(3);
            end
            % The legacy frames attribute can describe just one write block.
            % H5 stores absolute time indices; use the physical extent.
            available = 1:count;
        else
            if isempty(r.image) || isempty(r.findChannelID(name))
                fail(r, name, frames, [], file);
            end
            available = 1:size(r.image, 4);
        end
        missing = setdiff(frames, available);
        if ~isempty(missing), fail(r, name, frames, available, file); end
    end
end
end

function value = attribute(dataset, key, fallback)
value = fallback;
idx = find(strcmp({dataset.Attributes.Name}, key), 1);
if ~isempty(idx), value = dataset.Attributes(idx).Value; end
end

function fail(r, channel, requested, available, file)
missing = setdiff(requested, available);
error('runPipeline:IncompleteROI', ...
    ['ROI %s channel "%s" is incomplete: requested %d frames through %d, ' ...
     'available %d; first missing frame %d. Re-extract this ROI and rebuild ' ...
     'dependent outputs before processing. Store: %s'], ...
    r.id, channel, numel(requested), max(requested), numel(available), missing(1), file);
end
