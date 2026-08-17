function name = pipelinePhysicalResourceOutputName(node, spec, name)
% pipelinePhysicalResourceOutputName  Return the name physically written by a node.
%
% Pipeline parameters often store a logical output base name while legacy
% ROI writers add package-specific prefixes or suffixes. Both validation and
% GUI binding choices must use this same conversion so one output is never
% presented as two different resources.

name = strtrim(char(string(name)));
if isempty(name)
    return;
end

nodeType = lower(char(string(localGet(node, 'type', ''))));
pkgName = lower(char(string(localGet(node, 'pkg', ''))));
params = localGet(node, 'params', struct());
if isempty(pkgName) && isstruct(params) && isfield(params, 'pkg') && ~isempty(params.pkg)
    pkgName = lower(char(string(params.pkg)));
end
resourceType = lower(char(string(localGet(spec, 'type', ''))));
role = lower(char(string(localGet(spec, 'role', ''))));

if strcmp(nodeType, 'processor') && strcmp(pkgName, 'computemetrics') && ...
        strcmp(resourceType, 'dataseries') && strcmp(role, 'metrics') && ...
        ~isempty(regexp(name, '^processor_computemetrics(_\d+)?$', 'once'))
    name = 'channel_quantification';
elseif strcmp(nodeType, 'classifier') && strcmp(pkgName, 'cellposesam') && ...
        strcmp(resourceType, 'mask') && strcmp(role, 'segmentation')
    name = cellposeSegmentationName(params, name);
elseif strcmp(nodeType, 'classifier') && strcmp(pkgName, 'deeplab_pixel_classification') && ...
        strcmp(resourceType, 'mask') && strcmp(role, 'segmentation')
    name = prefixedResultsName(name);
elseif strcmp(nodeType, 'classifier') && ...
        any(strcmp(pkgName, ...
            {'trackastra','celllatenttracker','celllatentmodel'})) && ...
        strcmp(resourceType, 'channel') && strcmp(role, 'tracking')
    name = prefixedResultsName(name);
elseif strcmp(nodeType, 'processor') && strcmp(pkgName, 'trackmotherlineageviterbi') && ...
        strcmp(resourceType, 'channel') && ...
        any(strcmp(role, {'lineage_mask','lineage_cell_mask','lineage_confidence', ...
                          'lineage_mother_mask','lineage_bud_mask'}))
    name = lineageChannelName(name, role);
end
end

function name = prefixedResultsName(name)
if ~startsWith(name, 'results_', 'IgnoreCase', true)
    name = ['results_' name];
end
end

function name = cellposeSegmentationName(params, name)
if startsWith(name, 'results_', 'IgnoreCase', true)
    return;
end
className = 'cell';
if isstruct(params)
    keys = {'classes','classNames','className','labels'};
    for i = 1:numel(keys)
        if isfield(params, keys{i}) && ~isempty(params.(keys{i}))
            className = firstTextValue(params.(keys{i}), 'cell');
            break;
        end
    end
end
name = ['results_' name '_' className];
end

function name = lineageChannelName(name, role)
if endsWith(name, '_cell', 'IgnoreCase', true) || ...
        endsWith(name, '_bud', 'IgnoreCase', true) || ...
        endsWith(name, '_conf', 'IgnoreCase', true)
    return;
end
if any(strcmpi(role, {'lineage_confidence','lineage_bud_mask'}))
    name = [name '_bud'];
else
    name = [name '_cell'];
end
end

function txt = firstTextValue(value, fallback)
txt = fallback;
try
    if iscell(value)
        idx = find(~cellfun(@isempty, value), 1, 'first');
        if isempty(idx)
            return;
        end
        value = value{idx};
    elseif isstring(value) && ~isscalar(value)
        idx = find(strlength(value) > 0, 1, 'first');
        if isempty(idx)
            return;
        end
        value = value(idx);
    end
    candidate = strtrim(char(string(value)));
    if ~isempty(candidate)
        txt = candidate;
    end
catch
    txt = fallback;
end
end

function value = localGet(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
end
end
