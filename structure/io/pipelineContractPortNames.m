function [inputs, outputs] = pipelineContractPortNames(contract)
% pipelineContractPortNames  Compatibility port names derived from contract.
%
% Newer code should consume contract.resources directly. This helper keeps
% graph/UI code that still expects node.inputs/node.outputs or contract.in/out
% on a derived, non-persisted path.

inputs = {};
outputs = {};

if ~isstruct(contract)
    return;
end

if isfield(contract, 'in') && ~isempty(contract.in)
    inputs = portNamesLocal(contract.in);
end
if isfield(contract, 'out') && ~isempty(contract.out)
    outputs = portNamesLocal(contract.out);
end

resources = getFieldLocal(contract, 'resources', struct());
if isempty(inputs)
    inputs = resourcePortNamesLocal(getFieldLocal(resources, 'in', struct([])));
end
if isempty(outputs)
    outputs = resourcePortNamesLocal(getFieldLocal(resources, 'out', struct([])));
end

inputs = unique(inputs(~cellfun(@isempty, inputs)), 'stable');
outputs = unique(outputs(~cellfun(@isempty, outputs)), 'stable');
end

function names = portNamesLocal(ports)
names = {};
if ~isstruct(ports) || isempty(ports)
    return;
end
for i = 1:numel(ports)
    if isfield(ports(i), 'name') && ~isempty(ports(i).name)
        names{end+1} = char(string(ports(i).name)); %#ok<AGROW>
    end
end
end

function names = resourcePortNamesLocal(resources)
names = {};
if ~isstruct(resources) || isempty(resources)
    return;
end
for i = 1:numel(resources)
    port = '';
    if isfield(resources(i), 'port') && ~isempty(resources(i).port)
        port = char(string(resources(i).port));
    elseif isfield(resources(i), 'type') && ~isempty(resources(i).type)
        port = resourceTypeToPortLocal(resources(i));
    end
    if ~isempty(port)
        names{end+1} = port; %#ok<AGROW>
    end
end
end

function port = resourceTypeToPortLocal(resource)
type = lower(char(string(getFieldLocal(resource, 'type', ''))));
role = lower(char(string(getFieldLocal(resource, 'role', ''))));
switch type
    case 'channel'
        port = 'channels';
    case 'mask'
        port = 'masks';
    case 'dataseries'
        port = 'dataSeries';
    case 'roi'
        port = 'roiList';
    case 'imageset'
        port = 'images';
    otherwise
        if strcmp(role, 'roi')
            port = 'roiList';
        else
            port = type;
        end
end
end

function v = getFieldLocal(s, name, defaultValue)
v = defaultValue;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end
