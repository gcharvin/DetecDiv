function requests = annotationInputMappingRequests(plan)
%ANNOTATIONINPUTMAPPINGREQUESTS List only ambiguous/unresolved input roles.

requests = repmat(struct('roiPosition', 0, 'roiIndex', 0, 'roiId', '', ...
    'selector', '', 'label', '', 'candidates', {{}}, 'ambiguous', false), 0, 1);
try, items = plan.items; catch, items = []; end
for i = 1:numel(items)
    try, resolution = items(i).inputs.resolution; catch, continue; end
    roles = fieldnames(resolution);
    for j = 1:numel(roles)
        role = roles{j};
        value = resolution.(role);
        selected = fieldText(value, 'selected');
        candidates = fieldCell(value, 'candidates');
        ambiguous = fieldLogical(value, 'ambiguous');
        required = fieldLogical(value, 'required') || ...
            strcmp(role, 'instanceChannelName');
        if ~ambiguous && ~(required && isempty(selected)), continue; end
        if isempty(candidates), continue; end
        requests(end+1,1) = struct( ... %#ok<AGROW>
            'roiPosition', i, ...
            'roiIndex', double(items(i).roiIndex), ...
            'roiId', char(string(items(i).roiId)), ...
            'selector', role, ...
            'label', roleLabel(role), ...
            'candidates', {candidates}, ...
            'ambiguous', ambiguous);
    end
end
end

function value = fieldText(item, name)
value = '';
try, value = strtrim(char(string(item.(name)))); catch, end
end

function value = fieldCell(item, name)
value = {};
try, value = cellstr(string(item.(name))); catch, end
value = value(~cellfun('isempty', value));
end

function value = fieldLogical(item, name)
value = false;
try, value = logical(item.(name)); catch, end
end

function label = roleLabel(role)
switch char(string(role))
    case 'inputChannelName', label = 'Microscopy image';
    case 'instanceChannelName', label = 'Frame-local instance masks';
    case 'brightfieldChannelName', label = 'Brightfield image';
    case 'nucleusChannelName', label = 'Division/nucleus image';
    case 'budneckChannelName', label = 'Bud-neck image';
    otherwise, label = char(string(role));
end
end
