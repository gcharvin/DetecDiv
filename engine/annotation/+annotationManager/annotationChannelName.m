function name = annotationChannelName(classif, className)
%ANNOTATIONMANAGER.ANNOTATIONCHANNELNAME Resolve the canonical legacy GT channel.

if nargin < 2, className = ''; end
name = '';
pkg = propertyText(classif, 'classifierPkg');
if ~isempty(pkg)
    hook = [pkg '.annotationChannelName'];
    try
        if ~isempty(which(hook))
            name = char(string(feval(hook, classif)));
        end
    catch
        name = '';
    end
end
if ~isempty(name), return; end

classifierId = propertyText(classif, 'strid');
if isempty(className)
    classes = propertyValue(classif, 'classes', {});
    if ischar(classes) || isstring(classes)
        classes = cellstr(string(classes));
    end
    if iscell(classes) && ~isempty(classes)
        className = char(string(classes{1}));
    end
end
if isempty(className), className = 'cell'; end
if ~isempty(classifierId)
    name = [classifierId '_' char(string(className))];
end
end

function value = propertyText(obj, name)
value = propertyValue(obj, name, '');
try, value = char(string(value)); catch, value = ''; end
end

function value = propertyValue(obj, name, fallback)
value = fallback;
try
    if isobject(obj) && isprop(obj, name)
        value = obj.(name);
    elseif isstruct(obj) && isfield(obj, name)
        value = obj.(name);
    end
catch
    value = fallback;
end
end
