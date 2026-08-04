function spec = newSpec(classif)
%ANNOTATIONMANAGER.NEWSPEC Create a classifier annotation contract.

if nargin < 1, classif = []; end
classifierId = textProperty(classif, 'strid', 'classifier');
packageName = textProperty(classif, 'classifierPkg', '');
category = normalizedCategory(classif);
classes = cellProperty(classif, 'classes');

spec = struct( ...
    'schemaVersion', uint16(1), ...
    'id', classifierId, ...
    'classifierId', classifierId, ...
    'package', packageName, ...
    'category', category, ...
    'displayName', classifierId, ...
    'components', repmat(annotationManager.newComponent(), 0, 1), ...
    'classes', {classes}, ...
    'defaultEditor', '', ...
    'supportsBootstrap', false, ...
    'allowPartialApproval', false, ...
    'legacyFallback', false);
end

function value = textProperty(obj, name, fallback)
value = fallback;
try
    if isobject(obj) && isprop(obj, name)
        raw = obj.(name);
    elseif isstruct(obj) && isfield(obj, name)
        raw = obj.(name);
    else
        return;
    end
    if ~isempty(raw), value = char(string(raw)); end
catch
end
end

function value = cellProperty(obj, name)
value = {};
try
    if isobject(obj) && isprop(obj, name)
        raw = obj.(name);
    elseif isstruct(obj) && isfield(obj, name)
        raw = obj.(name);
    else
        return;
    end
    if ischar(raw) || isstring(raw)
        value = cellstr(string(raw));
    elseif iscell(raw)
        value = cellfun(@(x) char(string(x)), raw, 'UniformOutput', false);
    end
catch
end
end

function category = normalizedCategory(classif)
category = '';
try
    if isobject(classif) && isprop(classif, 'category')
        raw = classif.category;
    elseif isstruct(classif) && isfield(classif, 'category')
        raw = classif.category;
    else
        return;
    end
    if iscell(raw) && ~isempty(raw), raw = raw{1}; end
    category = char(string(raw));
catch
end
end
