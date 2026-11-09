function pipelineAssertRoiCompleteness(nodes, ctx, planned)
% Validate existing ROI inputs; planned producers are checked at execution.
if nargin < 3, planned = false; end
if ~isfield(ctx, 'roiList') || ~isa(ctx.roiList, 'roi'), return; end
produced = {};
if planned
    for i = 1:numel(nodes)
        if isfield(nodes(i), 'enabled') && ~nodes(i).enabled, continue; end
        if strcmpi(nodes(i).type, 'roiExtract'), return; end
        c = pipelineNodeContract(nodes(i));
        for s = c.resources.out
            if ~any(strcmpi(s.type, {'channel','mask'})), continue; end
            key = char(string(s.nameParam));
            if isfield(nodes(i).params, key)
                value = nodes(i).params.(key);
                if iscell(value), value = value{end}; end
                produced{end+1} = pipelinePhysicalResourceOutputName(nodes(i), s, value); %#ok<AGROW>
            end
        end
    end
end
rois = pipelineScopeRoisToSelectedFovs(ctx.roiList, ctx);
for i = 1:numel(nodes)
    n = nodes(i);
    if isfield(n, 'enabled') && ~n.enabled, continue; end
    if ~any(strcmpi(n.type, {'processor','classifier'})), continue; end
    c = pipelineNodeContract(n); channels = {};
    for s = c.resources.in
        if ~any(strcmpi(s.type, {'channel','mask'})), continue; end
        key = char(string(s.param));
        if ~isfield(n.params, key), continue; end
        value = n.params.(key);
        if iscell(value) && ~isempty(value), value = value{end}; end
        if isempty(value), continue; end
        value = char(string(value));
        if any(strcmpi(value, {'N/A','none','auto','@source','@all_channels'})), continue; end
        if ~any(strcmp(produced, value)), channels{end+1} = value; end %#ok<AGROW>
    end
    if isempty(channels), continue; end
    frames = [];
    if isfield(ctx, 'sel') && isfield(ctx.sel, 'frames'), frames = ctx.sel.frames; end
    if isfield(ctx, 'frames') && ~isempty(ctx.frames), frames = ctx.frames; end
    if isfield(n.params, 'frames') && ~isempty(n.params.frames), frames = n.params.frames; end
    channels = unique(channels, 'stable');
    if isempty(frames) || isequal(frames, -1)
        % An omitted selection means the full acquisition, not the length
        % left in a partially written ROI file.
        for k = 1:numel(rois)
            f = parentFov(rois(k), ctx);
            if isempty(f), continue; end
            for j = 1:numel(channels)
                count = max(f.frames);
                idx = find(strcmp(f.channel, channels{j}), 1);
                if ~isempty(idx) && numel(f.frames) >= idx, count = f.frames(idx); end
                roiAssertFrameCoverage(rois(k), channels(j), 1:count);
            end
        end
    else
        roiAssertFrameCoverage(rois, channels, frames);
    end
end
end

function f = parentFov(r, ctx)
f = [];
if isa(r.parent, 'fov'), f = r.parent; return; end
if ~isfield(ctx, 'fovList'), return; end
for k = 1:numel(ctx.fovList)
    candidate = ctx.fovList(k);
    if any(strcmp({candidate.roi.id}, r.id)), f = candidate; return; end
end
end
