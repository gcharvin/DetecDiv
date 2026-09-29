function [obj, changedCount] = detecdiv_paths_map_fov_sources(obj, mapPath)
% Keep every raw pointer for one FOV in the same host's path view.
% No dataset scan or image read is needed to translate its metadata.
    changedCount = 0;
    for name = {'srcpath', 'omeZarrPath', 'ndtiffPath', 'tiffSource'}
        key = name{1};
        if ~isprop(obj, key), continue; end
        value = mapValue(obj.(key));
        if any(strcmp(key, {'omeZarrPath', 'ndtiffPath'}))
            while iscell(value) && numel(value) == 1, value = value{1}; end
        end
        obj.(key) = value;
    end
    for ch = 1:numel(obj.srclist)
        items = obj.srclist{ch};
        if ~isstruct(items) || ~isfield(items, 'folder'), continue; end
        for k = 1:numel(items)
            items(k).folder = mapValue(items(k).folder);
        end
        obj.srclist{ch} = items;
    end

    function value = mapValue(value)
        if iscell(value)
            for j = 1:numel(value), value{j} = mapValue(value{j}); end
        elseif ischar(value) || (isstring(value) && isscalar(value))
            before = char(string(value));
            if isempty(before), return; end
            value = mapPath(before);
            if ~strcmp(before, value), changedCount = changedCount + 1; end
        end
    end
end
