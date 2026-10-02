function path = pipelineRunRawDataPath(ctx)
% Recover the raw acquisition root from current and older run snapshots.
path = '';
if ~isstruct(ctx), return; end
candidates = {};
for key = {'run','io'}
    name = key{1};
    if isfield(ctx,name) && isstruct(ctx.(name)) && isfield(ctx.(name),'rawDataPath')
        candidates{end+1} = ctx.(name).rawDataPath; %#ok<AGROW>
    end
end
if isfield(ctx,'rawDataPath'), candidates{end+1} = ctx.rawDataPath; end
if isfield(ctx,'dataLoader') && isstruct(ctx.dataLoader) && isfield(ctx.dataLoader,'path')
    candidates{end+1} = ctx.dataLoader.path;
end
if isfield(ctx,'pipelineSpec') && isstruct(ctx.pipelineSpec) && isfield(ctx.pipelineSpec,'nodes')
    nodes = ctx.pipelineSpec.nodes;
    for i = 1:numel(nodes)
        if ~isfield(nodes,'type') || ~strcmpi(nodes(i).type,'dataLoader'), continue; end
        if isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'nodeParams')
            overrides = ctx.run.nodeParams;
            for j = 1:numel(overrides)
                if strcmp(overrides(j).id,nodes(i).id) && isfield(overrides(j),'params') ...
                        && isstruct(overrides(j).params) && isfield(overrides(j).params,'path')
                    candidates{end+1} = overrides(j).params.path; %#ok<AGROW>
                end
            end
        end
        if isfield(nodes,'params') && isstruct(nodes(i).params) && isfield(nodes(i).params,'path')
            candidates{end+1} = nodes(i).params.path; %#ok<AGROW>
        end
    end
end
for i = 1:numel(candidates)
    value = candidates{i};
    if ~(ischar(value) || (isstring(value) && isscalar(value))), continue; end
    value = strtrim(char(value));
    if ~isempty(value) && ~strcmpi(value,'Project source path not resolved')
        path = value;
        return;
    end
end
end
