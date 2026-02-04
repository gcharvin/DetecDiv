function roiApplyPatch(roiobj, patch, ctx)
% roiApplyPatch Apply ROI-level patch instructions to one or more ROI objects.

    if nargin < 3
        ctx = struct();
    end
    if nargin < 2 || isempty(patch) || isempty(roiobj)
        return;
    end

    if numel(roiobj) > 1
        for i = 1:numel(roiobj)
            roiApplyPatch(roiobj(i), patch, ctx);
        end
        return;
    end

    if isfield(patch, 'roi')
        roiPatch = patch.roi;
    else
        roiPatch = patch;
    end

    % Channels add
    if isfield(roiPatch, 'channels') && isfield(roiPatch.channels, 'add')
        addList = roiPatch.channels.add;
        if isstruct(addList), addList = num2cell(addList); end
        for i = 1:numel(addList)
            entry = addList{i};
            if isempty(entry), continue; end
            chName = entry.name;
            opts = struct();
            if isfield(entry, 'type'), opts.type = entry.type; end
            if isfield(entry, 'class'), opts.class = entry.class; end
            if isfield(entry, 'k'), opts.k = entry.k; end
            if isfield(entry, 'rgb'), opts.rgb = entry.rgb; end
            if isfield(entry, 'intensity'), opts.intensity = entry.intensity; end
            if isfield(entry, 'size'), opts.size = entry.size; end
            roiEnsureChannel(roiobj, chName, opts);
        end
    end

    % Image write
    if isfield(roiPatch, 'image') && isfield(roiPatch.image, 'write')
        writes = roiPatch.image.write;
        if isstruct(writes), writes = num2cell(writes); end
        for i = 1:numel(writes)
            w = writes{i};
            if isempty(w), continue; end

            if ~isfield(w, 'data') || isempty(w.data)
                continue;
            end

            data = normalizeDataHWkT(w.data);
            frames = [];
            if isfield(w, 'frames'), frames = w.frames; end

            if isfield(w, 'scale') && ~isempty(w.scale)
                data = applyScale(data, w.scale);
            end

            if isempty(frames)
                frames = 1:size(data,4);
            end

            if numel(frames) ~= size(data,4)
                if size(data,4) == 1 && numel(frames) > 1
                    data = repmat(data, 1, 1, 1, numel(frames));
                else
                    error('roiApplyPatch:FrameMismatch', 'frames length does not match data T.');
                end
            end

            if isfield(w, 'channel')
                ch = w.channel;
            else
                error('roiApplyPatch:MissingChannel', 'image.write requires channel.');
            end

            if isstring(ch), ch = char(ch); end
            if ischar(ch)
                opts = struct();
                if isfield(w, 'type'), opts.type = w.type; end
                if isfield(w, 'class'), opts.class = w.class; end
                if isfield(w, 'rgb'), opts.rgb = w.rgb; end
                if isfield(w, 'intensity'), opts.intensity = w.intensity; end
                if isempty(roiobj.image)
                    opts.data = data;
                    [~, ~] = roiEnsureChannel(roiobj, ch, opts);
                    continue;
                end
                [pix, ~] = roiEnsureChannel(roiobj, ch, opts);
            else
                pix = ch;
            end

            if isempty(roiobj.image)
                error('roiApplyPatch:NoImage', 'ROI image is empty and channel could not be created.');
            end

            pix = pix(:).';
            if numel(pix) ~= size(data,3)
                error('roiApplyPatch:ChannelMismatch', 'Data k does not match channel subchannels.');
            end

            roiobj.image(:, :, pix, frames) = data;
        end
    end

    % Dataseries upsert
    if isfield(roiPatch, 'dataseries') && isfield(roiPatch.dataseries, 'upsert')
        upsertList = roiPatch.dataseries.upsert;
        if isstruct(upsertList), upsertList = num2cell(upsertList); end
        if isempty(roiobj.data) || (numel(roiobj.data)==1 && isempty(roiobj.data(1).data))
            try
                roiobj.load('data');
            catch
            end
        end
        for i = 1:numel(upsertList)
            entry = upsertList{i};
            if isempty(entry), continue; end

            mode = 'replace';
            if isfield(entry, 'mode') && ~isempty(entry.mode)
                mode = lower(char(entry.mode));
            end

            ds = [];
            if isfield(entry, 'dataseries')
                ds = entry.dataseries;
            elseif isfield(entry, 'data')
                ds = dataseries(entry.data, {}, 'groupid', entry.groupid);
            end
            if isempty(ds)
                continue;
            end

            groupid = '';
            if isprop(ds, 'groupid'), groupid = ds.groupid; end
            if isempty(groupid) && isfield(entry, 'groupid')
                groupid = entry.groupid;
                try, ds.groupid = groupid; end
            end

            if isempty(groupid)
                error('roiApplyPatch:MissingGroup', 'dataseries upsert requires groupid.');
            end

            idx = find(arrayfun(@(x) strcmp(x.groupid, groupid), roiobj.data));
            if strcmp(mode, 'append') || isempty(idx)
                roiobj.data(end+1) = ds; %#ok<AGROW>
            else
                roiobj.data(idx(1)) = ds;
            end
        end
    end

    % Tables upsert (stored under roiobj.results.tables)
    if isfield(roiPatch, 'tables') && isfield(roiPatch.tables, 'upsert')
        upsertList = roiPatch.tables.upsert;
        if isstruct(upsertList), upsertList = num2cell(upsertList); end
        if isempty(roiobj.results) || ~isstruct(roiobj.results)
            roiobj.results = struct();
        end
        if ~isfield(roiobj.results, 'tables') || ~isstruct(roiobj.results.tables)
            roiobj.results.tables = struct();
        end
        for i = 1:numel(upsertList)
            entry = upsertList{i};
            if isempty(entry), continue; end
            if ~isfield(entry, 'name') || ~isfield(entry, 'table')
                continue;
            end
            safeName = matlab.lang.makeValidName(entry.name);
            roiobj.results.tables.(safeName) = entry.table;
        end
    end

    % Attributes update
    if isfield(roiPatch, 'attrs') && isstruct(roiPatch.attrs)
        f = fieldnames(roiPatch.attrs);
        for i = 1:numel(f)
            roiobj.(f{i}) = roiPatch.attrs.(f{i});
        end
    end

    if isfield(ctx, 'log') && isstruct(ctx.log) && isfield(ctx.log, 'info')
        try
            ctx.log.info('roiApplyPatch: applied patch to ROI %s', string(roiobj.id));
        catch
        end
    end
end

function data = normalizeDataHWkT(data)
    sz = size(data);
    if numel(sz) == 2
        data = reshape(data, [sz(1) sz(2) 1 1]);
    elseif numel(sz) == 3
        data = reshape(data, [sz(1) sz(2) sz(3) 1]);
    end
end

function data = applyScale(data, scale)
    if ~isstruct(scale)
        return;
    end
    if isfield(scale, 'mode') && strcmpi(scale.mode, 'clip')
        lo = -inf; hi = inf;
        if isfield(scale, 'lo'), lo = scale.lo; end
        if isfield(scale, 'hi'), hi = scale.hi; end
        data = min(max(data, lo), hi);
    end
    if isfield(scale, 'dtype') && ~isempty(scale.dtype)
        data = cast(data, scale.dtype);
    end
end
