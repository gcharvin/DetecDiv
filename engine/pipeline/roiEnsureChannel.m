function [pix, created] = roiEnsureChannel(roiobj, chName, opts)
% roiEnsureChannel Ensure a logical channel exists in a ROI.
%   [pix, created] = roiEnsureChannel(roiobj, chName, opts)
% opts fields (all optional):
%   - data: [H W k T] data to initialize
%   - size: [H W k T] or [H W T]
%   - k:    number of subchannels (1 or 3)
%   - type: 'indexed' | 'grayscale' | 'rgb'
%   - class: datatype for zeros when creating
%   - rgb: [1 3]
%   - intensity: [1 3]

    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    if isstring(chName), chName = char(chName); end
    if ~ischar(chName)
        error('roiEnsureChannel:BadName', 'Channel name must be char or string.');
    end

    pix = roiobj.findChannelID(chName);
    if ~isempty(pix)
        created = false;
        return;
    end

    data = [];
    if isfield(opts, 'data') && ~isempty(opts.data)
        data = opts.data;
    end

    if isempty(data)
        if ~isempty(roiobj.image)
            sz = size(roiobj.image);
            while numel(sz) < 4, sz(end+1) = 1; end
            H = sz(1); W = sz(2); T = sz(4);
            k = 1;
            if isfield(opts, 'k') && ~isempty(opts.k), k = opts.k; end
            cls = 'uint16';
            if isfield(opts, 'class') && ~isempty(opts.class), cls = char(opts.class); end
            data = zeros(H, W, k, T, cls);
        elseif isfield(opts, 'size') && ~isempty(opts.size)
            sz = opts.size;
            if numel(sz) == 3
                sz = [sz(1) sz(2) 1 sz(3)];
            end
            if numel(sz) ~= 4
                error('roiEnsureChannel:BadSize', 'opts.size must be [H W k T] or [H W T].');
            end
            cls = 'uint16';
            if isfield(opts, 'class') && ~isempty(opts.class), cls = char(opts.class); end
            data = zeros(sz(1), sz(2), sz(3), sz(4), cls);
        else
            error('roiEnsureChannel:NoSize', 'Cannot create channel without image data or size.');
        end
    end

    data = normalizeDataHWkT(data);

    k = size(data, 3);
    if ~(k == 1 || k == 3)
        error('roiEnsureChannel:BadK', 'Data third dimension must be 1 or 3.');
    end

    rgb = [1 1 1];
    intensity = [1 1 1];

    if isfield(opts, 'rgb') && ~isempty(opts.rgb), rgb = opts.rgb; end
    if isfield(opts, 'intensity') && ~isempty(opts.intensity), intensity = opts.intensity; end

    if isfield(opts, 'type')
        t = lower(string(opts.type));
        if t == "indexed"
            intensity = [0 0 0];
        end
    end

    roiobj.addChannel(data, chName, rgb, intensity);
    pix = roiobj.findChannelID(chName);
    created = true;
end

function data = normalizeDataHWkT(data)
    sz = size(data);
    if numel(sz) == 2
        data = reshape(data, [sz(1) sz(2) 1 1]);
    elseif numel(sz) == 3
        data = reshape(data, [sz(1) sz(2) sz(3) 1]);
    end
end
